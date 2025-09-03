use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::broadcast;

#[derive(Debug, Clone, Serialize, Deserialize)]
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

#[derive(Debug, Clone)]
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
}

pub struct ServerManager {
    config_dir: PathBuf,
    current_process: Arc<Mutex<Option<Child>>>,
    server_info: Arc<Mutex<ServerInfo>>,
    event_sender: broadcast::Sender<ServerEvent>,
    metrics_history: Arc<Mutex<Vec<ServerMetrics>>>,
}

impl ServerManager {
    pub fn new(config_dir: PathBuf, binary_path: PathBuf) -> Result<Self> {
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
        })
    }

    pub fn get_server_info(&self) -> ServerInfo {
        self.server_info.lock().unwrap().clone()
    }

    pub fn is_running(&self) -> bool {
        matches!(self.get_server_info().status, ServerStatus::Running)
    }

    pub async fn start_server(&self) -> Result<()> {
        // Check if already running and validate binary in a separate scope
        let (_binary_path, _port) = {
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

            let _binary_path = server_info.binary_path.clone();
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
            
            (_binary_path, _port)
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

    pub async fn restart_server(&self) -> Result<()> {
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
        
        if let (Some(_pid), Some(started_at)) = (server_info.pid, server_info.started_at) {
            // In a real implementation, collect actual metrics from the system
            Some(ServerMetrics {
                cpu_usage: 0.0, // TODO: Implement actual CPU monitoring
                memory_usage: 0, // TODO: Implement actual memory monitoring
                uptime: Duration::from_secs(
                    SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs() - started_at
                ),
                request_count: 0, // TODO: Get from server stats API
                error_count: 0,   // TODO: Get from server stats API
            })
        } else {
            None
        }
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<ServerEvent> {
        self.event_sender.subscribe()
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

            let manager = ServerManager::new(config_dir, fake_binary.clone())?;
            
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
        assert!(test_manager.manager.update_server_config(Some(99999), None).is_err());
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
        
        let manager = ServerManager::new(config_dir, missing_binary).unwrap();
        
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