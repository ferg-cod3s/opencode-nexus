use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::broadcast;
use tauri::Emitter;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Copy)]
pub enum ConnectionStatus {
    Disconnected,
    Connecting,
    Connected,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub name: String,
    pub hostname: String,
    pub port: u16,
    pub secure: bool,
    pub version: Option<String>,
    pub status: ConnectionStatus,
    pub last_connected: Option<String>,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionEvent {
    pub timestamp: SystemTime,
    pub event_type: ConnectionEventType,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConnectionEventType {
    Connected,
    Disconnected,
    Error,
    HealthCheck,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConnection {
    pub name: String,
    pub hostname: String,
    pub port: u16,
    pub secure: bool,
    pub last_connected: Option<String>,
}

impl ServerConnection {
    pub fn to_url(&self) -> String {
        let protocol = if self.secure { "https" } else { "http" };
        format!("{}://{}:{}", protocol, self.hostname, self.port)
    }
}

pub struct ConnectionManager {
    config_dir: PathBuf,
    client: Client,
    server_url: Arc<Mutex<Option<String>>>,
    connection_status: Arc<Mutex<ConnectionStatus>>,
    event_sender: broadcast::Sender<ConnectionEvent>,
    app_handle: Option<tauri::AppHandle>,
    connections: Arc<Mutex<HashMap<String, ServerConnection>>>,
    current_connection: Arc<Mutex<Option<String>>>,
}

impl ConnectionManager {
    pub fn new(
        config_dir: PathBuf,
        app_handle: Option<tauri::AppHandle>,
    ) -> Result<Self, String> {
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

        let (event_sender, _) = broadcast::channel(100);

        Ok(Self {
            config_dir,
            client,
            server_url: Arc::new(Mutex::new(None)),
            connection_status: Arc::new(Mutex::new(ConnectionStatus::Disconnected)),
            event_sender,
            app_handle,
            connections: Arc::new(Mutex::new(HashMap::new())),
            current_connection: Arc::new(Mutex::new(None)),
        })
    }

    pub async fn connect_to_server(&mut self, hostname: &str, port: u16, secure: bool) -> Result<(), String> {
        // Check if already connected
        let current_status = *self.connection_status.lock().unwrap();
        if matches!(current_status, ConnectionStatus::Connected | ConnectionStatus::Connecting) {
            return Err("Already connected to a server".to_string());
        }

        // Update status to connecting
        *self.connection_status.lock().unwrap() = ConnectionStatus::Connecting;

        // Send connecting event
        let _ = self.event_sender.send(ConnectionEvent {
            timestamp: SystemTime::now(),
            event_type: ConnectionEventType::Connected,
            message: format!("Connecting to {}:{}...", hostname, port),
        });

        // Test the connection
        let server_info = self.test_server_connection(hostname, port, secure).await?;

        // Store the server URL
        let server_url = format!("{}://{}:{}", if secure { "https" } else { "http" }, hostname, port);
        *self.server_url.lock().unwrap() = Some(server_url.clone());

        // Update status to connected
        *self.connection_status.lock().unwrap() = ConnectionStatus::Connected;

        // Store connection info
        let connection = ServerConnection {
            name: format!("{}:{}", hostname, port),
            hostname: hostname.to_string(),
            port,
            secure,
            last_connected: Some(chrono::Utc::now().to_rfc3339()),
        };

        let connection_id = connection.name.clone();
        self.connections.lock().unwrap().insert(connection_id.clone(), connection);
        *self.current_connection.lock().unwrap() = Some(connection_id.clone());

        // Save connections to disk
        self.save_connections()?;

        // Send connected event
        let _ = self.event_sender.send(ConnectionEvent {
            timestamp: SystemTime::now(),
            event_type: ConnectionEventType::Connected,
            message: format!("Connected to {} (version: {})", server_info.name, server_info.version.unwrap_or_else(|| "unknown".to_string())),
        });

        // Start health monitoring
        self.start_health_monitoring();

        Ok(())
    }

    pub async fn test_server_connection(&self, hostname: &str, port: u16, secure: bool) -> Result<ServerInfo, String> {
        let url = format!("{}://{}:{}/app", if secure { "https" } else { "http" }, hostname, port);

        match self.client.get(&url).send().await {
            Ok(response) => {
                if response.status().is_success() {
                    // Try to parse server info from response
                    match response.json::<serde_json::Value>().await {
                        Ok(json) => {
                            let version = json.get("version").and_then(|v| v.as_str()).map(|s| s.to_string());
                            let name = json.get("name").and_then(|v| v.as_str()).unwrap_or("OpenCode Server").to_string();

                            Ok(ServerInfo {
                                name,
                                hostname: hostname.to_string(),
                                port,
                                secure,
                                version,
                                status: ConnectionStatus::Connected,
                                last_connected: Some(chrono::Utc::now().to_rfc3339()),
                                last_error: None,
                            })
                        }
                        Err(_) => {
                            // Server responded but not with expected JSON - still consider it valid
                            Ok(ServerInfo {
                                name: format!("{}:{}", hostname, port),
                                hostname: hostname.to_string(),
                                port,
                                secure,
                                version: None,
                                status: ConnectionStatus::Connected,
                                last_connected: Some(chrono::Utc::now().to_rfc3339()),
                                last_error: None,
                            })
                        }
                    }
                } else {
                    Err(format!("Server responded with status: {}", response.status()))
                }
            }
            Err(e) => {
                Err(format!("Failed to connect to server: {}", e))
            }
        }
    }

    pub fn get_connection_status(&self) -> ConnectionStatus {
        *self.connection_status.lock().unwrap()
    }

    pub fn get_server_url(&self) -> Option<String> {
        self.server_url.lock().unwrap().clone()
    }

    pub fn get_current_connection(&self) -> Option<ServerConnection> {
        self.current_connection.lock().unwrap().as_ref()
            .and_then(|id| self.connections.lock().unwrap().get(id).cloned())
    }

    pub fn get_saved_connections(&self) -> Vec<ServerConnection> {
        self.connections.lock().unwrap().values().cloned().collect()
    }

    pub async fn disconnect_from_server(&mut self) -> Result<(), String> {
        let current_status = *self.connection_status.lock().unwrap();
        if matches!(current_status, ConnectionStatus::Disconnected) {
            return Ok(());
        }

        // Update status
        *self.connection_status.lock().unwrap() = ConnectionStatus::Disconnected;

        // Clear server URL
        *self.server_url.lock().unwrap() = None;

        // Send disconnected event
        let _ = self.event_sender.send(ConnectionEvent {
            timestamp: SystemTime::now(),
            event_type: ConnectionEventType::Disconnected,
            message: "Disconnected from server".to_string(),
        });

        Ok(())
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<ConnectionEvent> {
        self.event_sender.subscribe()
    }

    /// Emit a connection event to the frontend via Tauri event system
    pub fn emit_event(&self, event: &ConnectionEvent) {
        if let Some(app_handle) = &self.app_handle {
            let _ = app_handle.emit("connection_event", event);
        }
    }

    fn get_connections_file_path(&self) -> PathBuf {
        self.config_dir.join("server_connections.json")
    }

    fn save_connections(&self) -> Result<(), String> {
        let connections_guard = self.connections.lock().unwrap();
        let connections: Vec<&ServerConnection> = connections_guard.values().collect();
        let json = serde_json::to_string_pretty(&connections)
            .map_err(|e| format!("Failed to serialize connections: {}", e))?;

        std::fs::write(self.get_connections_file_path(), json)
            .map_err(|e| format!("Failed to write connections file: {}", e))?;

        Ok(())
    }

    pub fn load_connections(&mut self) -> Result<(), String> {
        let file_path = self.get_connections_file_path();

        if !file_path.exists() {
            return Ok(()); // No connections file yet, that's fine
        }

        let json = std::fs::read_to_string(&file_path)
            .map_err(|e| format!("Failed to read connections file: {}", e))?;

        let connections: Vec<ServerConnection> = serde_json::from_str(&json)
            .map_err(|e| format!("Failed to deserialize connections: {}", e))?;

        let mut connections_map = self.connections.lock().unwrap();
        connections_map.clear();
        for connection in connections {
            connections_map.insert(connection.name.clone(), connection);
        }

        Ok(())
    }

    fn start_health_monitoring(&self) {
        let connection_status = Arc::clone(&self.connection_status);
        let server_url = Arc::clone(&self.server_url);
        let event_sender = self.event_sender.clone();

        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(30)).await;

                let should_continue = {
                    matches!(*connection_status.lock().unwrap(), ConnectionStatus::Connected)
                };

                if !should_continue {
                    break;
                }

                // Perform health check - extract URL before async operation
                let url_to_check = {
                    server_url.lock().unwrap().clone()
                };

                if let Some(url) = url_to_check {
                    let health_url = format!("{}/app", url);
                    match reqwest::get(&health_url).await {
                        Ok(response) if response.status().is_success() => {
                            // Server is healthy
                            let _ = event_sender.send(ConnectionEvent {
                                timestamp: SystemTime::now(),
                                event_type: ConnectionEventType::HealthCheck,
                                message: "Server health check passed".to_string(),
                            });
                        }
                        _ => {
                            // Server is unhealthy
                            *connection_status.lock().unwrap() = ConnectionStatus::Error;
                            let _ = event_sender.send(ConnectionEvent {
                                timestamp: SystemTime::now(),
                                event_type: ConnectionEventType::Error,
                                message: "Server health check failed".to_string(),
                            });
                            break;
                        }
                    }
                }
            }
        });
    }
}