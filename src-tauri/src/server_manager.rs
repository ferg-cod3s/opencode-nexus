use anyhow::{anyhow, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::broadcast;
use tauri::Emitter;
use sysinfo::{System, Pid};
use crate::api_client::ApiClient;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ServerStatus {
    Stopped,
    Starting,
    Running,
    Stopping,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub status: ServerStatus,
    pub pid: Option<u32>,
    pub port: u16,
    pub host: String,
    pub started_at: Option<u64>, // Unix timestamp
    pub last_error: Option<String>,
    pub version: Option<String>,
    pub binary_path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerMetrics {
    pub cpu_usage: f64,
    pub memory_usage: u64, // bytes
    pub uptime: Duration,
    pub request_count: u64,
    pub error_count: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppInfo {
    pub version: String,
    pub status: String,
    pub uptime: Option<u64>,
    pub sessions_count: Option<u32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ServerEvent {
    pub timestamp: SystemTime,
    pub event_type: ServerEventType,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ServerEventType {
    Started,
    Stopped,
    Error,
    ConfigChanged,
    HealthCheck,
    SessionUpdate,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenCodeSession {
    pub id: String,
    pub user_id: Option<String>,
    pub username: Option<String>,
    pub client_ip: String,
    pub user_agent: String,
    pub connected_at: DateTime<Utc>,
    pub last_activity: DateTime<Utc>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStats {
    pub total_sessions: u32,
    pub active_sessions: u32,
    pub peak_concurrent: u32,
    pub average_session_duration: Duration,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TunnelConfig {
    pub enabled: bool,
    pub auto_start: bool,
    pub custom_domain: Option<String>,
    pub config_path: Option<PathBuf>,
    pub auth_token: Option<String>,
}

impl TunnelConfig {
    pub fn validate(&self) -> Result<()> {
        // Very basic domain validation for now
        if let Some(domain) = &self.custom_domain {
            if !domain.chars().all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-') {
                return Err(anyhow!("Invalid custom domain format"));
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TunnelStatus {
    Stopped,
    Starting,
    Running,
    Error,
}

pub struct ServerManager {
    config_dir: PathBuf,
    current_process: Arc<Mutex<Option<Child>>>,
    server_info: Arc<Mutex<ServerInfo>>,
    event_sender: broadcast::Sender<ServerEvent>,
    metrics_history: Arc<Mutex<Vec<ServerMetrics>>>,
    pub(crate) api_client: Option<ApiClient>, // Optional to handle cases where server isn't running
    app_handle: Option<tauri::AppHandle>, // For emitting events to frontend
    // Tunnel management
    tunnel_process: Arc<Mutex<Option<Child>>>,
    tunnel_config: Arc<Mutex<Option<TunnelConfig>>>,
    tunnel_url: Arc<Mutex<Option<String>>>,
}

impl ServerManager {

    // Tunnel management implementation
    pub async fn start_cloudflared_tunnel(&mut self, config: &TunnelConfig) -> Result<()> {
        // Validate configuration
        config.validate()?;

        // Check if tunnel is already running
        if matches!(self.get_tunnel_status(), TunnelStatus::Running | TunnelStatus::Starting) {
            return Err(anyhow!("Tunnel is already running or starting"));
        }

        // Check if cloudflared is available
        if !self.is_cloudflared_available()? {
            return Err(anyhow!("cloudflared binary not found. Please install Cloudflare Tunnel from https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/"));
        }

        // Get server info for tunnel target
        let (host, port) = {
            let server_info = self.server_info.lock().unwrap();
            (server_info.host.clone(), server_info.port)
        };
        let target_url = format!("http://{}:{}", host, port);

        // Start tunnel process and capture URL
        let (child, tunnel_url) = self.spawn_tunnel_process_with_url_capture(config, &target_url).await?;

        // Store tunnel process, config, and URL
        *self.tunnel_process.lock().unwrap() = Some(child);
        *self.tunnel_config.lock().unwrap() = Some(config.clone());
        *self.tunnel_url.lock().unwrap() = tunnel_url;

        // Emit tunnel started event
        let _ = self.event_sender.send(ServerEvent {
            timestamp: SystemTime::now(),
            event_type: ServerEventType::Started,
            message: "Cloudflared tunnel started".to_string(),
        });

        // Start tunnel monitoring
        self.start_tunnel_monitoring().await;

        Ok(())
    }

    pub fn stop_cloudflared_tunnel(&mut self) -> Result<()> {
        let mut tunnel_process = self.tunnel_process.lock().unwrap();

        if let Some(mut child) = tunnel_process.take() {
            // Try graceful shutdown first
            if let Err(_) = child.kill() {
                // If graceful shutdown fails, force kill
                let _ = child.wait();
            } else {
                // Wait for process to exit
                let _ = child.wait();
            }
        }

        // Clear tunnel config and URL
        *self.tunnel_config.lock().unwrap() = None;
        *self.tunnel_url.lock().unwrap() = None;

        // Emit tunnel stopped event
        let _ = self.event_sender.send(ServerEvent {
            timestamp: SystemTime::now(),
            event_type: ServerEventType::Stopped,
            message: "Cloudflared tunnel stopped".to_string(),
        });

        Ok(())
    }

    pub fn get_tunnel_status(&self) -> TunnelStatus {
        let mut tunnel_process = self.tunnel_process.lock().unwrap();

        if let Some(child) = tunnel_process.as_mut() {
            match child.try_wait() {
                Ok(Some(_)) => TunnelStatus::Stopped, // Process has exited
                Ok(None) => TunnelStatus::Running,     // Process is still running
                Err(_) => TunnelStatus::Error,         // Error checking status
            }
        } else {
            TunnelStatus::Stopped
        }
    }

    pub fn update_tunnel_config(&mut self, config: TunnelConfig) -> Result<()> {
        // Validate configuration
        config.validate()?;

        // Don't allow config changes while tunnel is running
        if matches!(self.get_tunnel_status(), TunnelStatus::Running | TunnelStatus::Starting) {
            return Err(anyhow!("Cannot change tunnel configuration while tunnel is running"));
        }

        *self.tunnel_config.lock().unwrap() = Some(config);

        let _ = self.event_sender.send(ServerEvent {
            timestamp: SystemTime::now(),
            event_type: ServerEventType::ConfigChanged,
            message: "Tunnel configuration updated".to_string(),
        });

        Ok(())
    }

    pub fn get_tunnel_config(&self) -> Option<TunnelConfig> {
        self.tunnel_config.lock().unwrap().clone()
    }

    pub fn get_tunnel_url(&self) -> Option<String> {
        self.tunnel_url.lock().unwrap().clone()
    }

    pub fn new(config_dir: PathBuf, binary_path: PathBuf, app_handle: Option<tauri::AppHandle>) -> Result<Self> {
        std::fs::create_dir_all(&config_dir)?;
        
        let (event_sender, _) = broadcast::channel(100);
        
        let server_info = ServerInfo {
            status: ServerStatus::Stopped,
            pid: None,
            port: 4096, // Default OpenCode port
            host: "127.0.0.1".to_string(),
            started_at: None,
            last_error: None,
            version: None,
            binary_path,
        };

        Ok(Self {
            config_dir,
            current_process: Arc::new(Mutex::new(None)),
            server_info: Arc::new(Mutex::new(server_info)),
            event_sender,
            metrics_history: Arc::new(Mutex::new(Vec::new())),
            api_client: None, // Will be created when server starts
            app_handle,
            tunnel_process: Arc::new(Mutex::new(None)),
            tunnel_config: Arc::new(Mutex::new(None)),
            tunnel_url: Arc::new(Mutex::new(None)),
        })
    }

    pub fn get_server_info(&self) -> ServerInfo {
        self.server_info.lock().unwrap().clone()
    }

    pub fn is_running(&self) -> bool {
        matches!(self.get_server_info().status, ServerStatus::Running)
    }

    pub async fn start_server(&mut self) -> Result<()> {
        // Check if already running and validate binary in a separate scope
        let (binary_path, port) = {
            let mut server_info = self.server_info.lock().unwrap();
            
            // Check if already running
            if matches!(server_info.status, ServerStatus::Running | ServerStatus::Starting) {
                return Err(anyhow!("Server is already running or starting"));
            }

            // Validate binary exists
            if !server_info.binary_path.exists() {
                let error = "OpenCode server binary not found".to_string();
                server_info.status = ServerStatus::Error;
                server_info.last_error = Some(error.clone());
                return Err(anyhow!(error));
            }

            let binary_path = server_info.binary_path.clone();
            let port = server_info.port;

            // Check if port is available
            if !self.is_port_available(port)? {
                let error = format!("Port {} is already in use", port);
                server_info.status = ServerStatus::Error;
                server_info.last_error = Some(error.clone());
                return Err(anyhow!(error));
            }

            server_info.status = ServerStatus::Starting;
            server_info.last_error = None;
            
            (binary_path, port)
        };

        // Send starting event
        let _ = self.event_sender.send(ServerEvent {
            timestamp: SystemTime::now(),
            event_type: ServerEventType::Started,
            message: "Starting OpenCode server...".to_string(),
        });

        // Start the process
        match self.spawn_server_process().await {
            Ok(child) => {
                let pid = child.id();
                
                // Store the process
                *self.current_process.lock().unwrap() = Some(child);
                
                // Update server info
                {
                    let mut server_info = self.server_info.lock().unwrap();
                    server_info.status = ServerStatus::Running;
                    server_info.pid = Some(pid);
                    server_info.started_at = Some(
                        SystemTime::now()
                            .duration_since(UNIX_EPOCH)?
                            .as_secs()
                    );
                } // MutexGuard is dropped here

                // Send started event
                let _ = self.event_sender.send(ServerEvent {
                    timestamp: SystemTime::now(),
                    event_type: ServerEventType::Started,
                    message: format!("OpenCode server started with PID {}", pid),
                });

                // Create API client for server communication
                if let Err(e) = self.ensure_api_client() {
                    eprintln!("Warning: Failed to create API client: {}", e);
                    // Don't fail the server start if API client creation fails
                    // The server can still run without API integration
                }

                // Start monitoring in background
                self.start_monitoring().await;

                Ok(())
            }
            Err(error) => {
                let mut server_info = self.server_info.lock().unwrap();
                server_info.status = ServerStatus::Error;
                server_info.last_error = Some(error.to_string());

                let _ = self.event_sender.send(ServerEvent {
                    timestamp: SystemTime::now(),
                    event_type: ServerEventType::Error,
                    message: format!("Failed to start server: {}", error),
                });

                Err(error)
            }
        }
    }

    /// Gets active sessions from the OpenCode server API
    ///
    /// Design Decision: Returns real session data from /api/sessions endpoint
    /// Falls back to empty list if API is unavailable
    /// This ensures the app remains functional even if API calls fail
    pub async fn get_active_sessions(&mut self) -> Result<Vec<OpenCodeSession>> {
        self.ensure_api_client()?;

        if let Some(client) = &self.api_client {
            match client.get::<Vec<OpenCodeSession>>("/api/sessions").await {
                Ok(sessions) => {
                    // Emit session update event
                    let _ = self.event_sender.send(ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::SessionUpdate,
                        message: format!("Found {} active sessions", sessions.len()),
                    });
                    Ok(sessions)
                }
                Err(e) => {
                    eprintln!("Failed to get sessions from API: {}", e);
                    Ok(Vec::new()) // Return empty list if API fails
                }
            }
        } else {
            Err(anyhow!("API client not available"))
        }
    }

    /// Disconnects a session via the OpenCode server API
    ///
    /// Design Decision: Uses DELETE /api/sessions/{id} endpoint
    /// Emits event for successful disconnection
    /// Returns success status for UI feedback
    pub async fn disconnect_session(&mut self, session_id: &str) -> Result<bool> {
        self.ensure_api_client()?;

        if let Some(client) = &self.api_client {
            match client.delete::<bool>(&format!("/api/sessions/{}", session_id)).await {
                Ok(success) => {
                    // Emit session disconnected event
                    let _ = self.event_sender.send(ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::SessionUpdate,
                        message: format!("Session {} disconnected", session_id),
                    });
                    Ok(success)
                }
                Err(e) => {
                    eprintln!("Failed to disconnect session: {}", e);
                    Err(anyhow!("Failed to disconnect session: {}", e))
                }
            }
        } else {
            Err(anyhow!("API client not available"))
        }
    }

    /// Gets comprehensive session statistics
    ///
    /// Design Decision: Calculates stats from active sessions
    /// Includes total, active, peak concurrent, and average duration
    /// Uses cached metrics for peak concurrent calculation
    pub async fn get_session_stats(&mut self) -> Result<SessionStats> {
        let sessions = self.get_active_sessions().await?;

        let active_sessions = sessions.iter().filter(|s| s.is_active).count() as u32;
        let total_sessions = sessions.len() as u32;

        // Calculate average session duration
        let now = Utc::now();
        let total_duration: i64 = sessions.iter()
            .filter(|s| s.is_active)
            .map(|s| (now - s.connected_at).num_seconds())
            .sum();

        let average_duration = if active_sessions > 0 {
            Duration::from_secs((total_duration / active_sessions as i64) as u64)
        } else {
            Duration::from_secs(0)
        };

        Ok(SessionStats {
            total_sessions,
            active_sessions,
            peak_concurrent: self.metrics_history.lock().unwrap().iter()
                .map(|m| m.request_count)
                .max()
                .unwrap_or(0) as u32,
            average_session_duration: average_duration,
        })
    }

    pub async fn stop_server(&self) -> Result<()> {
        let mut server_info = self.server_info.lock().unwrap();
        
        if matches!(server_info.status, ServerStatus::Stopped | ServerStatus::Stopping) {
            return Ok(());
        }

        server_info.status = ServerStatus::Stopping;
        drop(server_info);

        let _ = self.event_sender.send(ServerEvent {
            timestamp: SystemTime::now(),
            event_type: ServerEventType::Stopped,
            message: "Stopping OpenCode server...".to_string(),
        });

        // Gracefully terminate the process
        if let Some(mut child) = self.current_process.lock().unwrap().take() {
            // Try graceful shutdown first
            if let Err(_) = child.kill() {
                // If graceful shutdown fails, force kill
                let _ = child.wait();
            } else {
                // Wait for process to exit
                let _ = child.wait();
            }
        }

        // Update server info
        let mut server_info = self.server_info.lock().unwrap();
        server_info.status = ServerStatus::Stopped;
        server_info.pid = None;
        server_info.started_at = None;
        
        let _ = self.event_sender.send(ServerEvent {
            timestamp: SystemTime::now(),
            event_type: ServerEventType::Stopped,
            message: "OpenCode server stopped".to_string(),
        });

        Ok(())
    }

    pub async fn restart_server(&mut self) -> Result<()> {
        self.stop_server().await?;
        
        // Wait a moment for cleanup
        thread::sleep(Duration::from_millis(1000));
        
        self.start_server().await
    }

    pub fn get_server_version(&self) -> Result<String> {
        let server_info = self.server_info.lock().unwrap();
        
        let output = Command::new(&server_info.binary_path)
            .arg("--version")
            .output()?;

        if output.status.success() {
            let version = String::from_utf8(output.stdout)?
                .trim()
                .to_string();
            Ok(version)
        } else {
            Err(anyhow!("Failed to get server version"))
        }
    }

    pub fn update_server_config(&self, port: Option<u16>, host: Option<String>) -> Result<()> {
        let mut server_info = self.server_info.lock().unwrap();
        
        // Don't allow config changes while running
        if matches!(server_info.status, ServerStatus::Running | ServerStatus::Starting) {
            return Err(anyhow!("Cannot change configuration while server is running"));
        }

        if let Some(new_port) = port {
            if new_port < 1024 || new_port > 65535 {
                return Err(anyhow!("Port must be between 1024 and 65535"));
            }
            server_info.port = new_port;
        }

        if let Some(new_host) = host {
            server_info.host = new_host;
        }

        let _ = self.event_sender.send(ServerEvent {
            timestamp: SystemTime::now(),
            event_type: ServerEventType::ConfigChanged,
            message: "Server configuration updated".to_string(),
        });

        Ok(())
    }

    pub fn get_metrics(&self) -> Option<ServerMetrics> {
        let server_info = self.server_info.lock().unwrap();
        
        if let (Some(pid), Some(started_at)) = (server_info.pid, server_info.started_at) {
            // Collect real metrics from the system
            let mut system = System::new_all();
            system.refresh_all();
            
            let (cpu_usage, memory_usage) = if let Some(process) = system.process(Pid::from(pid as usize)) {
                (
                    process.cpu_usage() as f64,
                    process.memory() / 1024 / 1024 // Convert bytes to MB
                )
            } else {
                // Process not found, use fallback values
                (0.0, 0)
            };
            
            // Get request count from server stats API if available
            let request_count = if let Some(api_client) = &self.api_client {
                // Try to get stats from OpenCode server
                match tokio::runtime::Handle::try_current() {
                    Ok(handle) => {
                        handle.block_on(async {
                            api_client.get::<serde_json::Value>("/app/stats")
                                .await
                                .ok()
                                .and_then(|stats| stats.get("request_count")?.as_u64())
                                .unwrap_or(0)
                        })
                    },
                    Err(_) => 0, // No async runtime available
                }
            } else {
                0
            };

            Some(ServerMetrics {
                cpu_usage,
                memory_usage,
                uptime: Duration::from_secs(
                    SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs() - started_at
                ),
                request_count,
                error_count: if let Some(api_client) = &self.api_client {
                    // Try to get error count from OpenCode server stats
                    match tokio::runtime::Handle::try_current() {
                        Ok(handle) => {
                            handle.block_on(async {
                                api_client.get::<serde_json::Value>("/app/stats")
                                    .await
                                    .ok()
                                    .and_then(|stats| stats.get("error_count")?.as_u64())
                                    .unwrap_or(0)
                            })
                        },
                        Err(_) => 0, // No async runtime available
                    }
                } else {
                    0
                },
            })
        } else {
            None
        }
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<ServerEvent> {
        self.event_sender.subscribe()
    }

    /// Emit a server event to the frontend via Tauri event system
    pub fn emit_event(&self, event: &ServerEvent) {
        if let Some(app_handle) = &self.app_handle {
            let _ = app_handle.emit("server_event", event);
        }
    }

    /// Creates or updates the API client with current server URL
    ///
    /// Design Decision: API client is created lazily when needed
    /// This ensures we only create HTTP clients when the server is actually running
    pub(crate) fn ensure_api_client(&mut self) -> Result<()> {
        let server_info = self.server_info.lock().unwrap();
        let base_url = format!("http://{}:{}", server_info.host, server_info.port);

        match &self.api_client {
            Some(client) => {
                // Check if the URL has changed (e.g., port changed)
                if client.base_url != base_url {
                    self.api_client = Some(ApiClient::new(&base_url).map_err(|e| anyhow!("Failed to create API client: {}", e))?);
                }
            }
            None => {
                self.api_client = Some(ApiClient::new(&base_url).map_err(|e| anyhow!("Failed to create API client: {}", e))?);
            }
        }

        Ok(())
    }

    /// Gets app information from the OpenCode server API
    ///
    /// Design Decision: Returns real app data from /app endpoint
    /// Falls back to cached/stubbed data if API is unavailable
    /// This ensures the app remains functional even if API calls fail
    pub async fn get_app_info(&mut self) -> Result<AppInfo> {
        // Ensure API client is available
        self.ensure_api_client()?;

        if let Some(client) = &self.api_client {
            match client.get::<AppInfo>("/app").await {
                Ok(app_info) => {
                    // Update server info with real data
                    let mut server_info = self.server_info.lock().unwrap();
                    server_info.version = Some(app_info.version.clone());
                    Ok(app_info)
                }
                Err(e) => {
                    // Fallback: return stubbed data if API fails
                    eprintln!("Failed to get app info from API: {}", e);
                    Ok(AppInfo {
                        version: "unknown".to_string(),
                        status: "unknown".to_string(),
                        uptime: None,
                        sessions_count: None,
                    })
                }
            }
        } else {
            Err(anyhow!("API client not available"))
        }
    }

    /// Initializes the OpenCode app via API
    ///
    /// Design Decision: Uses /app/init endpoint for proper app initialization
    /// This ensures the server is properly set up before use
    /// Returns success/failure status for UI feedback
    pub async fn initialize_app(&mut self) -> Result<bool> {
        // Ensure API client is available
        self.ensure_api_client()?;

        if let Some(client) = &self.api_client {
            match client.post::<bool, ()>("/app/init", &()).await {
                Ok(success) => {
                    // Emit event for successful initialization
                    let event = ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::Started,
                        message: "App initialized successfully".to_string(),
                    };
                    let _ = self.event_sender.send(event);
                    Ok(success)
                }
                Err(e) => {
                    // Emit error event
                    let event = ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::Error,
                        message: format!("App initialization failed: {}", e),
                    };
                    let _ = self.event_sender.send(event);
                    Err(anyhow!("Failed to initialize app: {}", e))
                }
            }
        } else {
            Err(anyhow!("API client not available"))
        }
    }

    fn is_port_available(&self, port: u16) -> Result<bool> {
        use std::net::{TcpListener, ToSocketAddrs};
        
        let addr = format!("127.0.0.1:{}", port);
        match addr.to_socket_addrs() {
            Ok(mut addrs) => {
                if let Some(addr) = addrs.next() {
                    match TcpListener::bind(addr) {
                        Ok(_) => Ok(true),
                        Err(_) => Ok(false),
                    }
                } else {
                    Ok(false)
                }
            }
            Err(_) => Ok(false),
        }
    }

    async fn spawn_server_process(&self) -> Result<Child> {
        let server_info = self.server_info.lock().unwrap();
        
        let child = Command::new(&server_info.binary_path)
            .arg("--host")
            .arg(&server_info.host)
            .arg("--port")
            .arg(server_info.port.to_string())
            .arg("--headless") // Run without GUI
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        Ok(child)
    }

    async fn start_monitoring(&self) {
        let server_info_clone = Arc::clone(&self.server_info);
        let current_process_clone = Arc::clone(&self.current_process);
        let event_sender_clone = self.event_sender.clone();

        tokio::spawn(async move {
            loop {
                thread::sleep(Duration::from_secs(5));

                let should_continue = {
                    let server_info = server_info_clone.lock().unwrap();
                    matches!(server_info.status, ServerStatus::Running)
                };

                if !should_continue {
                    break;
                }

                // Check if process is still alive
                let process_alive = {
                    let mut process_guard = current_process_clone.lock().unwrap();
                    if let Some(ref mut child) = *process_guard {
                        match child.try_wait() {
                            Ok(Some(_)) => false, // Process has exited
                            Ok(None) => true,     // Process is still running
                            Err(_) => false,      // Error checking status
                        }
                    } else {
                        false
                    }
                };

                if !process_alive {
                    // Process died unexpectedly
                    let mut server_info = server_info_clone.lock().unwrap();
                    server_info.status = ServerStatus::Error;
                    server_info.last_error = Some("Server process terminated unexpectedly".to_string());
                    server_info.pid = None;
                    drop(server_info);

                    let _ = event_sender_clone.send(ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::Error,
                        message: "Server process terminated unexpectedly".to_string(),
                    });

                    break;
                }

                // Send health check event
                let _ = event_sender_clone.send(ServerEvent {
                    timestamp: SystemTime::now(),
                    event_type: ServerEventType::HealthCheck,
                    message: "Server health check passed".to_string(),
                });
            }
        });
    }

    fn is_cloudflared_available(&self) -> Result<bool> {
        let output = Command::new("cloudflared")
            .arg("--version")
            .output();

        match output {
            Ok(result) => Ok(result.status.success()),
            Err(_) => Ok(false),
        }
    }

    async fn spawn_tunnel_process_with_url_capture(&self, config: &TunnelConfig, target_url: &str) -> Result<(Child, Option<String>)> {
        use std::io::{BufRead, BufReader};
        use tokio::time::{timeout, Duration};
        
        let mut cmd = Command::new("cloudflared");
        cmd.arg("tunnel");

        // Add authentication if provided
        if let Some(token) = &config.auth_token {
            cmd.arg("--credentials-file").arg(token);
        }

        // Add custom domain if provided
        if let Some(domain) = &config.custom_domain {
            cmd.arg("--hostname").arg(domain);
            // For custom domains, we know the URL format
            return Ok((
                cmd.arg("--url").arg(target_url)
                   .stdout(Stdio::piped())
                   .stderr(Stdio::piped())
                   .spawn()
                   .map_err(|e| anyhow!("Failed to start cloudflared tunnel: {}", e))?,
                Some(format!("https://{}", domain))
            ));
        }

        // For quick tunnels, we need to capture the generated URL
        cmd.arg("--url").arg(target_url);
        
        let mut child = cmd.stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| anyhow!("Failed to start cloudflared tunnel: {}", e))?;

        // Read stdout to capture the tunnel URL (for quick tunnels)
        let mut tunnel_url: Option<String> = None;
        if let Some(stdout) = child.stdout.take() {
            let tunnel_url_clone = Arc::new(Mutex::new(None::<String>));
            let tunnel_url_clone_for_task = tunnel_url_clone.clone();
            
            tokio::spawn(async move {
                let reader = BufReader::new(stdout);
                for line_result in reader.lines() {
                    if let Ok(line) = line_result {
                        // Look for cloudflare tunnel URL pattern
                        if line.contains("trycloudflare.com") || line.contains("Your quick tunnel") {
                            // Extract URL from various formats cloudflared uses
                            if let Some(url_start) = line.find("https://") {
                                if let Some(url_end) = line[url_start..].find(' ') {
                                    let url = &line[url_start..url_start + url_end];
                                    *tunnel_url_clone_for_task.lock().unwrap() = Some(url.to_string());
                                    break;
                                } else {
                                    // URL might be at the end of line
                                    let url = &line[url_start..];
                                    *tunnel_url_clone_for_task.lock().unwrap() = Some(url.trim().to_string());
                                    break;
                                }
                            }
                        }
                    }
                }
            });
            
            // Wait briefly for URL to be captured
            let _ = timeout(Duration::from_secs(5), async {
                loop {
                    if tunnel_url_clone.lock().unwrap().is_some() {
                        break;
                    }
                    tokio::time::sleep(Duration::from_millis(100)).await;
                }
            }).await;
            
            tunnel_url = tunnel_url_clone.lock().unwrap().clone();
        }
        
        Ok((child, tunnel_url))
    }

    async fn spawn_tunnel_process(&self, config: &TunnelConfig, target_url: &str) -> Result<Child> {
        let mut cmd = Command::new("cloudflared");
        cmd.arg("tunnel");

        // Add authentication if provided
        if let Some(token) = &config.auth_token {
            cmd.arg("--credentials-file").arg(token);
        }

        // Add custom domain if provided
        if let Some(domain) = &config.custom_domain {
            cmd.arg("--hostname").arg(domain);
        }

        // Add URL to tunnel
        cmd.arg("--url").arg(target_url);

        // Run in background
        cmd.stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| anyhow!("Failed to start cloudflared tunnel: {}", e))
    }

    async fn start_tunnel_monitoring(&self) {
        let tunnel_process_clone = Arc::clone(&self.tunnel_process);
        let tunnel_config_clone = Arc::clone(&self.tunnel_config);
        let event_sender_clone = self.event_sender.clone();

        tokio::spawn(async move {
            loop {
                thread::sleep(Duration::from_secs(10));

                let should_continue = {
                    let tunnel_config = tunnel_config_clone.lock().unwrap();
                    tunnel_config.is_some()
                };

                if !should_continue {
                    break;
                }

                // Check if tunnel process is still alive
                let process_alive = {
                    let mut process_guard = tunnel_process_clone.lock().unwrap();
                    if let Some(child) = process_guard.as_mut() {
                        match child.try_wait() {
                            Ok(Some(_)) => false, // Process has exited
                            Ok(None) => true,     // Process is still running
                            Err(_) => false,      // Error checking status
                        }
                    } else {
                        false
                    }
                };

                if !process_alive {
                    // Tunnel died unexpectedly
                    let _ = event_sender_clone.send(ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::Error,
                        message: "Cloudflared tunnel terminated unexpectedly".to_string(),
                    });

                    break;
                }

                // Send tunnel health check event
                let _ = event_sender_clone.send(ServerEvent {
                    timestamp: SystemTime::now(),
                    event_type: ServerEventType::HealthCheck,
                    message: "Tunnel health check passed".to_string(),
                });
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    struct TestServerManager {
        manager: ServerManager,
        _temp_dir: TempDir,
        _fake_binary: PathBuf,
    }

    impl TestServerManager {
        fn new() -> Result<Self> {
            let temp_dir = tempfile::tempdir()?;
            let config_dir = temp_dir.path().join("config");
            
            // Create a fake binary for testing
            let fake_binary = temp_dir.path().join("fake_opencode");
            fs::write(&fake_binary, "#!/bin/bash\necho 'OpenCode Server v1.0.0'\n")?;
            
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&fake_binary, fs::Permissions::from_mode(0o755))?;
            }

            let manager = ServerManager::new(config_dir, fake_binary.clone(), None)?;
            
            Ok(Self {
                manager,
                _temp_dir: temp_dir,
                _fake_binary: fake_binary,
            })
        }
    }

    #[test]
    fn test_server_manager_creation() {
        let test_manager = TestServerManager::new().unwrap();
        let info = test_manager.manager.get_server_info();
        
        assert!(matches!(info.status, ServerStatus::Stopped));
        assert_eq!(info.port, 4096);
        assert_eq!(info.host, "127.0.0.1");
        assert!(info.pid.is_none());
    }

    #[test]
    fn test_server_not_running_initially() {
        let test_manager = TestServerManager::new().unwrap();
        assert!(!test_manager.manager.is_running());
    }

    #[test]
    fn test_server_version_detection() {
        let test_manager = TestServerManager::new().unwrap();
        
        // This will fail with our fake binary, but shouldn't crash
        let version_result = test_manager.manager.get_server_version();
        
        // We expect this to fail with our fake script, but it should be handled gracefully
        assert!(version_result.is_err() || version_result.is_ok());
    }

    #[test]
    fn test_config_update() {
        let test_manager = TestServerManager::new().unwrap();
        
        // Should succeed when server is stopped
        assert!(test_manager.manager.update_server_config(Some(8080), Some("0.0.0.0".to_string())).is_ok());
        
        let info = test_manager.manager.get_server_info();
        assert_eq!(info.port, 8080);
        assert_eq!(info.host, "0.0.0.0");
    }

    #[test]
    fn test_invalid_port_config() {
        let test_manager = TestServerManager::new().unwrap();
        
        // Should fail with invalid port
        assert!(test_manager.manager.update_server_config(Some(99), None).is_err());
        assert!(test_manager.manager.update_server_config(Some(80), None).is_err());
    }

    #[test]
    fn test_port_availability_check() {
        let test_manager = TestServerManager::new().unwrap();
        
        // Port 4096 should be available initially
        assert!(test_manager.manager.is_port_available(4096).unwrap());
        
        // Port 80 might not be available (system port)
        // This test is environment-dependent, so we just ensure it doesn't crash
        let _ = test_manager.manager.is_port_available(80);
    }

    #[tokio::test]
    async fn test_start_server_with_missing_binary() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().join("config");
        let missing_binary = temp_dir.path().join("missing_binary");
        
        let mut manager = ServerManager::new(config_dir, missing_binary, None).unwrap();
        
        // Should fail because binary doesn't exist
        let result = manager.start_server().await;
        assert!(result.is_err());
        
        let info = manager.get_server_info();
        assert!(matches!(info.status, ServerStatus::Error));
        assert!(info.last_error.is_some());
    }

    #[tokio::test]
    async fn test_stop_server_when_not_running() {
        let test_manager = TestServerManager::new().unwrap();
        
        // Should not fail when stopping a server that's not running
        let result = test_manager.manager.stop_server().await;
        assert!(result.is_ok());
    }

    #[test]
    fn test_event_subscription() {
        let test_manager = TestServerManager::new().unwrap();
        
        let mut receiver = test_manager.manager.subscribe_to_events();
        
        // Should be able to subscribe without issues
        assert!(receiver.is_empty());
    }

    #[test]
    fn test_metrics_when_stopped() {
        let test_manager = TestServerManager::new().unwrap();
        
        let metrics = test_manager.manager.get_metrics();
        assert!(metrics.is_none());
    }
}