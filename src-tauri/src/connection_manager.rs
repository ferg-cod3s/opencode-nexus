// MIT License
//
// Copyright (c) 2025 OpenCode Nexus Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

use crate::error::{retry_with_backoff, AppError, RetryConfig};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use tauri::Emitter;
use tokio::sync::broadcast;

// Enhanced logging macros that log to both console and file
macro_rules! log_info {
    ($($arg:tt)*) => {
        let message = format!("[INFO] {}", format!($($arg)*));
        println!("{}", message);
        crate::log_to_file(&message);
    };
}

macro_rules! log_warn {
    ($($arg:tt)*) => {
        let message = format!("[WARN] {}", format!($($arg)*));
        println!("{}", message);
        crate::log_to_file(&message);
    };
}

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
    pub fn new(config_dir: PathBuf, app_handle: Option<tauri::AppHandle>) -> Result<Self, String> {
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

    pub async fn connect_to_server(
        &mut self,
        hostname: &str,
        port: u16,
        secure: bool,
    ) -> Result<(), String> {
        // Check if already connected
        let current_status = match self.connection_status.lock() {
            Ok(status) => *status,
            Err(poisoned) => {
                eprintln!(
                    "[ERROR] ConnectionManager connect: status mutex poisoned, recovering..."
                );
                *poisoned.into_inner()
            }
        };
        if matches!(
            current_status,
            ConnectionStatus::Connected | ConnectionStatus::Connecting
        ) {
            return Err("Already connected to a server".to_string());
        }

        // Update status to connecting
        match self.connection_status.lock() {
            Ok(mut status) => *status = ConnectionStatus::Connecting,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager connect: failed to set connecting status, mutex poisoned");
                return Err("Internal error: connection state corrupted".to_string());
            }
        }

        // Send connecting event
        let _ = self.event_sender.send(ConnectionEvent {
            timestamp: SystemTime::now(),
            event_type: ConnectionEventType::Connected,
            message: format!("Connecting to {}:{}...", hostname, port),
        });

        // Test the connection
        let server_info = self.test_server_connection(hostname, port, secure).await?;

        // Store the server URL
        let server_url = format!(
            "{}://{}:{}",
            if secure { "https" } else { "http" },
            hostname,
            port
        );
        match self.server_url.lock() {
            Ok(mut url) => *url = Some(server_url.clone()),
            Err(poisoned) => {
                eprintln!(
                    "[ERROR] ConnectionManager connect: failed to store server URL, mutex poisoned"
                );
                return Err("Internal error: connection state corrupted".to_string());
            }
        }

        // Update status to connected
        match self.connection_status.lock() {
            Ok(mut status) => *status = ConnectionStatus::Connected,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager connect: failed to set connected status, mutex poisoned");
                return Err("Internal error: connection state corrupted".to_string());
            }
        }

        // Store connection info
        let connection = ServerConnection {
            name: format!("{}:{}", hostname, port),
            hostname: hostname.to_string(),
            port,
            secure,
            last_connected: Some(chrono::Utc::now().to_rfc3339()),
        };

        let connection_id = connection.name.clone();
        match self.connections.lock() {
            Ok(mut connections) => {
                connections.insert(connection_id.clone(), connection);
            }
            Err(poisoned) => {
                eprintln!(
                    "[ERROR] ConnectionManager connect: connections mutex poisoned, recovering..."
                );
                poisoned
                    .into_inner()
                    .insert(connection_id.clone(), connection);
            }
        }
        match self.current_connection.lock() {
            Ok(mut current) => *current = Some(connection_id.clone()),
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager connect: current_connection mutex poisoned, recovering...");
                *poisoned.into_inner() = Some(connection_id.clone());
            }
        }

        // Save connections to disk
        self.save_connections()?;

        // Send connected event
        let _ = self.event_sender.send(ConnectionEvent {
            timestamp: SystemTime::now(),
            event_type: ConnectionEventType::Connected,
            message: format!(
                "Connected to {} (version: {})",
                server_info.name,
                server_info.version.unwrap_or_else(|| "unknown".to_string())
            ),
        });

        // Start health monitoring
        self.start_health_monitoring();

        Ok(())
    }

    pub async fn test_server_connection(
        &self,
        hostname: &str,
        port: u16,
        secure: bool,
    ) -> Result<ServerInfo, String> {
        let client = self.client.clone();
        let hostname_clone = hostname.to_string();

        // Use retry logic with exponential backoff for network resilience
        let result = retry_with_backoff(
            || {
                let client = client.clone();
                let hostname = hostname_clone.clone();
                async move {
                    let url = format!(
                        "{}://{}:{}/session",
                        if secure { "https" } else { "http" },
                        hostname,
                        port
                    );

                    let response = client.get(&url).send().await?;

                    if !response.status().is_success() {
                        return Err(AppError::ServerError {
                            status_code: response.status().as_u16(),
                            message: format!("Server responded with status: {}", response.status()),
                            details: response.text().await.unwrap_or_default(),
                        });
                    }

                    // Try to parse server info from response
                    let json_result = response.json::<serde_json::Value>().await;

                    let (name, version) = match json_result {
                        Ok(json) => {
                            let version = json
                                .get("version")
                                .and_then(|v| v.as_str())
                                .map(|s| s.to_string());
                            let name = json
                                .get("name")
                                .and_then(|v| v.as_str())
                                .unwrap_or("OpenCode Server")
                                .to_string();
                            (name, version)
                        }
                        Err(_) => {
                            // Server responded but not with expected JSON - still consider it valid
                            (format!("{}:{}", hostname, port), None)
                        }
                    };

                    Ok(ServerInfo {
                        name,
                        hostname: hostname.clone(),
                        port,
                        secure,
                        version,
                        status: ConnectionStatus::Connected,
                        last_connected: Some(chrono::Utc::now().to_rfc3339()),
                        last_error: None,
                    })
                }
            },
            RetryConfig::default(),
        )
        .await;

        // Convert AppError to String for backward compatibility
        result.map_err(|e| e.user_message())
    }

    pub fn get_connection_status(&self) -> ConnectionStatus {
        match self.connection_status.lock() {
            Ok(status) => *status,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager get_connection_status: mutex poisoned, returning Disconnected");
                ConnectionStatus::Disconnected
            }
        }
    }

    pub fn get_server_url(&self) -> Option<String> {
        match self.server_url.lock() {
            Ok(url) => url.clone(),
            Err(poisoned) => {
                eprintln!(
                    "[ERROR] ConnectionManager get_server_url: mutex poisoned, returning None"
                );
                None
            }
        }
    }

    pub fn get_current_connection(&self) -> Option<ServerConnection> {
        let current_id = match self.current_connection.lock() {
            Ok(id) => id.clone(),
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager get_current_connection: current_connection mutex poisoned");
                None
            }
        };

        if let Some(id) = current_id {
            match self.connections.lock() {
                Ok(connections) => connections.get(&id).cloned(),
                Err(poisoned) => {
                    eprintln!("[ERROR] ConnectionManager get_current_connection: connections mutex poisoned");
                    None
                }
            }
        } else {
            None
        }
    }

    pub fn get_saved_connections(&self) -> Vec<ServerConnection> {
        match self.connections.lock() {
            Ok(connections) => connections.values().cloned().collect(),
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager get_saved_connections: mutex poisoned, returning empty vec");
                Vec::new()
            }
        }
    }

    pub fn get_last_used_connection(&self) -> Option<ServerConnection> {
        let connections_guard = match self.connections.lock() {
            Ok(guard) => guard,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager get_last_used_connection: mutex poisoned, returning None");
                return None;
            }
        };

        let last_used = connections_guard
            .values()
            .filter(|c| c.last_connected.is_some())
            .max_by_key(|c| c.last_connected.as_ref().unwrap_or(&"".to_string()).clone());

        match last_used {
            Some(connection) => Some(connection.clone()),
            None => connections_guard.values().next().cloned(),
        }
    }

    pub fn get_last_used_server_url(&self) -> Option<String> {
        self.get_last_used_connection().map(|c| c.to_url())
    }

    pub fn save_connection(&mut self, connection: ServerConnection) -> Result<(), String> {
        let mut connections_guard = match self.connections.lock() {
            Ok(guard) => guard,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager save_connection: mutex poisoned, cannot save connection");
                return Err("Internal error: connection state corrupted".to_string());
            }
        };
        connections_guard.insert(connection.name.clone(), connection);
        drop(connections_guard); // Release lock before calling save_connections
        self.save_connections()
    }

    pub async fn disconnect_from_server(&mut self) -> Result<(), String> {
        let current_status = match self.connection_status.lock() {
            Ok(status) => *status,
            Err(poisoned) => {
                eprintln!(
                    "[ERROR] ConnectionManager disconnect: status mutex poisoned, recovering..."
                );
                *poisoned.into_inner()
            }
        };
        if matches!(current_status, ConnectionStatus::Disconnected) {
            return Ok(());
        }

        // Update status
        match self.connection_status.lock() {
            Ok(mut status) => *status = ConnectionStatus::Disconnected,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager disconnect: failed to set disconnected status, mutex poisoned");
                return Err("Internal error: connection state corrupted".to_string());
            }
        }

        // Clear server URL
        match self.server_url.lock() {
            Ok(mut url) => *url = None,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager disconnect: failed to clear server URL, mutex poisoned");
                return Err("Internal error: connection state corrupted".to_string());
            }
        }

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
        let connections_guard = match self.connections.lock() {
            Ok(guard) => guard,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager save_connections: mutex poisoned, cannot save connections");
                return Err("Internal error: connection state corrupted".to_string());
            }
        };
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

        let mut connections_map = match self.connections.lock() {
            Ok(map) => map,
            Err(poisoned) => {
                eprintln!("[ERROR] ConnectionManager load_connections: connections mutex poisoned, recovering...");
                poisoned.into_inner()
            }
        };
        connections_map.clear();
        for connection in connections {
            connections_map.insert(connection.name.clone(), connection);
        }

        Ok(())
    }

    /// Restore the last known connection on app startup
    /// Attempts to reconnect to the most recently used server
    pub async fn restore_connection(&mut self) -> Result<(), String> {
        // Load saved connections first
        self.load_connections()?;

        // Find the most recent connection (by last_connected timestamp)
        let connection_to_restore = {
            let connections_guard = match self.connections.lock() {
                Ok(guard) => guard,
                Err(poisoned) => {
                    eprintln!("[ERROR] ConnectionManager restore_connection: connections mutex poisoned, recovering...");
                    poisoned.into_inner()
                }
            };
            connections_guard
                .values()
                .filter(|c| c.last_connected.is_some())
                .max_by_key(|c| c.last_connected.clone().unwrap_or_else(|| "".to_string()))
                .or_else(|| connections_guard.values().next())
                .cloned() // Clone the connection to avoid borrowing issues
        };

        if let Some(connection) = connection_to_restore {
            log_info!(
                "🔄 [CONNECTION] Attempting to restore connection to: {}",
                connection.to_url()
            );

            // Attempt to reconnect
            match self
                .connect_to_server(&connection.hostname, connection.port, connection.secure)
                .await
            {
                Ok(_) => {
                    log_info!(
                        "✅ [CONNECTION] Successfully restored connection to: {}",
                        connection.to_url()
                    );
                    self.emit_event(&ConnectionEvent {
                        timestamp: SystemTime::now(),
                        event_type: ConnectionEventType::Connected,
                        message: format!("Restored connection to {}", connection.to_url()),
                    });
                    Ok(())
                }
                Err(e) => {
                    log_warn!(
                        "⚠️ [CONNECTION] Failed to restore connection to {}: {}",
                        connection.to_url(),
                        e
                    );
                    self.emit_event(&ConnectionEvent {
                        timestamp: SystemTime::now(),
                        event_type: ConnectionEventType::Error,
                        message: format!("Failed to restore connection: {}", e),
                    });
                    // Don't return error - just log it. App can still function without auto-connection
                    Ok(())
                }
            }
        } else {
            log_info!("ℹ️ [CONNECTION] No previous connections found to restore");
            Ok(())
        }
    }

    fn start_health_monitoring(&self) {
        let connection_status = Arc::clone(&self.connection_status);
        let server_url = Arc::clone(&self.server_url);
        let event_sender = self.event_sender.clone();

        // Spawn health monitoring task with panic recovery
        let health_task = tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(30)).await;

                let should_continue = {
                    match connection_status.lock() {
                        Ok(status) => matches!(*status, ConnectionStatus::Connected),
                        Err(poisoned) => {
                            eprintln!("[ERROR] ConnectionManager health check: mutex poisoned, assuming disconnected");
                            false // Stop health checks if mutex is poisoned
                        }
                    }
                };

                if !should_continue {
                    break;
                }

                // Perform health check - extract URL before async operation
                let url_to_check = match server_url.lock() {
                    Ok(url) => url.clone(),
                    Err(poisoned) => {
                        eprintln!(
                            "[ERROR] ConnectionManager health check: server_url mutex poisoned"
                        );
                        None
                    }
                };

                if let Some(url) = url_to_check {
                    let health_url = format!("{}/session", url);
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
                            match connection_status.lock() {
                                Ok(mut status) => *status = ConnectionStatus::Error,
                                Err(poisoned) => {
                                    eprintln!("[ERROR] ConnectionManager health check: failed to set error status, mutex poisoned");
                                    // Continue trying health checks even if we can't update status
                                }
                            }
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

        // Wrap the task join handle with panic recovery
        tokio::spawn(async move {
            if let Err(join_error) = health_task.await {
                // Check if the task panicked
                if join_error.is_panic() {
                    eprintln!("[ERROR] ConnectionManager health check task panicked");
                } else {
                    eprintln!(
                        "[ERROR] ConnectionManager health check task failed: {:?}",
                        join_error
                    );
                }
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    /// Helper function to create a test ConnectionManager with a temp directory
    fn create_test_connection_manager() -> (ConnectionManager, TempDir) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().to_path_buf();
        let manager =
            ConnectionManager::new(config_path, None).expect("Failed to create connection manager");
        (manager, temp_dir)
    }

    #[tokio::test]
    async fn test_connection_manager_initializes() {
        let (manager, _temp) = create_test_connection_manager();

        // Should start disconnected
        assert_eq!(
            manager.get_connection_status(),
            ConnectionStatus::Disconnected
        );

        // Should have no server URL initially
        assert_eq!(manager.get_server_url(), None);
    }

    #[tokio::test]
    async fn test_get_server_url_before_connection() {
        let (manager, _temp) = create_test_connection_manager();

        // Before connection, server_url should be None
        let url = manager.get_server_url();
        assert!(url.is_none(), "Server URL should be None before connection");
    }

    #[tokio::test]
    async fn test_server_url_stored_after_connection() {
        let (manager, _temp) = create_test_connection_manager();

        // Initially None
        assert_eq!(manager.get_server_url(), None);

        // After successful connection (would test with mock server)
        // For now, we verify the data structure is correct
        *manager.server_url.lock().unwrap() = Some("http://localhost:3000".to_string());

        // Should now have server URL
        let url = manager.get_server_url();
        assert!(url.is_some(), "Server URL should be set after connection");
        assert_eq!(url, Some("http://localhost:3000".to_string()));
    }

    #[tokio::test]
    async fn test_connection_status_transitions() {
        let (manager, _temp) = create_test_connection_manager();

        // Initial state
        assert_eq!(
            manager.get_connection_status(),
            ConnectionStatus::Disconnected
        );

        // Simulate connection status change
        *manager.connection_status.lock().unwrap() = ConnectionStatus::Connecting;
        assert_eq!(
            manager.get_connection_status(),
            ConnectionStatus::Connecting
        );

        // Connected
        *manager.connection_status.lock().unwrap() = ConnectionStatus::Connected;
        assert_eq!(manager.get_connection_status(), ConnectionStatus::Connected);

        // Disconnected
        *manager.connection_status.lock().unwrap() = ConnectionStatus::Disconnected;
        assert_eq!(
            manager.get_connection_status(),
            ConnectionStatus::Disconnected
        );
    }

    #[tokio::test]
    async fn test_save_and_load_connections() {
        let (manager, _temp) = create_test_connection_manager();

        // Add a test connection
        let connection = ServerConnection {
            name: "test_server".to_string(),
            hostname: "localhost".to_string(),
            port: 3000,
            secure: false,
            last_connected: Some("2025-11-11T10:00:00Z".to_string()),
        };

        manager
            .connections
            .lock()
            .unwrap()
            .insert(connection.name.clone(), connection.clone());

        // Save to disk
        manager
            .save_connections()
            .expect("Failed to save connections");

        // Verify file was created
        let file_path = manager.get_connections_file_path();
        assert!(file_path.exists(), "Connections file should exist");

        // Create new manager and load connections
        let mut manager2 = ConnectionManager::new(manager.config_dir.clone(), None)
            .expect("Failed to create second manager");

        manager2
            .load_connections()
            .expect("Failed to load connections");

        // Verify connections were loaded
        let loaded_connections = manager2.get_saved_connections();
        assert_eq!(
            loaded_connections.len(),
            1,
            "Should have 1 loaded connection"
        );
        assert_eq!(loaded_connections[0].name, "test_server");
        assert_eq!(loaded_connections[0].hostname, "localhost");
        assert_eq!(loaded_connections[0].port, 3000);
    }

    #[tokio::test]
    async fn test_disconnect_clears_server_url() {
        let (mut manager, _temp) = create_test_connection_manager();

        // Set server URL
        *manager.server_url.lock().unwrap() = Some("http://localhost:3000".to_string());
        *manager.connection_status.lock().unwrap() = ConnectionStatus::Connected;

        // Verify it's set
        assert!(manager.get_server_url().is_some());

        // Disconnect
        manager
            .disconnect_from_server()
            .await
            .expect("Failed to disconnect");

        // URL should be cleared
        assert_eq!(manager.get_server_url(), None);
        assert_eq!(
            manager.get_connection_status(),
            ConnectionStatus::Disconnected
        );
    }

    #[tokio::test]
    async fn test_event_subscription() {
        let (manager, _temp) = create_test_connection_manager();

        // Create a subscriber
        let mut receiver = manager.subscribe_to_events();

        // Send an event
        let event = ConnectionEvent {
            timestamp: SystemTime::now(),
            event_type: ConnectionEventType::Connected,
            message: "Test event".to_string(),
        };

        let _ = manager.event_sender.send(event.clone());

        // Receive the event (with timeout)
        let received = tokio::time::timeout(Duration::from_secs(1), receiver.recv()).await;

        assert!(received.is_ok(), "Should receive the event");
        assert!(
            received.unwrap().is_ok(),
            "Event should be received successfully"
        );
    }

    #[tokio::test]
    async fn test_server_connection_url_generation() {
        // Test HTTP connection
        let connection = ServerConnection {
            name: "http_server".to_string(),
            hostname: "example.com".to_string(),
            port: 3000,
            secure: false,
            last_connected: None,
        };

        let url = connection.to_url();
        assert_eq!(url, "http://example.com:3000");

        // Test HTTPS connection
        let secure_connection = ServerConnection {
            name: "https_server".to_string(),
            hostname: "example.com".to_string(),
            port: 3001,
            secure: true,
            last_connected: None,
        };

        let secure_url = secure_connection.to_url();
        assert_eq!(secure_url, "https://example.com:3001");
    }

    #[tokio::test]
    async fn test_get_current_connection_with_saved_connection() {
        let (manager, _temp) = create_test_connection_manager();

        let connection = ServerConnection {
            name: "test_server:3000".to_string(),
            hostname: "localhost".to_string(),
            port: 3000,
            secure: false,
            last_connected: None,
        };

        let connection_id = connection.name.clone();
        manager
            .connections
            .lock()
            .unwrap()
            .insert(connection_id.clone(), connection.clone());
        *manager.current_connection.lock().unwrap() = Some(connection_id);

        let current = manager.get_current_connection();
        assert!(current.is_some(), "Should have current connection");
        assert_eq!(current.unwrap().hostname, "localhost");
    }

    #[tokio::test]
    async fn test_get_last_used_connection_picks_most_recent() {
        let (manager, _temp) = create_test_connection_manager();

        let older = ServerConnection {
            name: "older".to_string(),
            hostname: "example.com".to_string(),
            port: 4096,
            secure: true,
            last_connected: Some("2025-01-01T00:00:00Z".to_string()),
        };

        let newer = ServerConnection {
            name: "newer".to_string(),
            hostname: "example.com".to_string(),
            port: 4096,
            secure: true,
            last_connected: Some("2025-02-01T00:00:00Z".to_string()),
        };

        manager
            .connections
            .lock()
            .unwrap()
            .insert(older.name.clone(), older.clone());
        manager
            .connections
            .lock()
            .unwrap()
            .insert(newer.name.clone(), newer.clone());

        let last_used = manager
            .get_last_used_connection()
            .expect("Should pick a last used connection");
        assert_eq!(last_used.name, "newer");
        assert_eq!(last_used.hostname, "example.com");
        assert!(last_used.secure);

        let url = manager.get_last_used_server_url().expect("Should get URL");
        assert_eq!(url, "https://example.com:4096");
    }

    #[tokio::test]
    async fn test_get_last_used_connection_without_timestamps() {
        let (manager, _temp) = create_test_connection_manager();

        let connection = ServerConnection {
            name: "test_no_timestamp".to_string(),
            hostname: "localhost".to_string(),
            port: 3000,
            secure: false,
            last_connected: None,
        };

        manager
            .connections
            .lock()
            .unwrap()
            .insert(connection.name.clone(), connection.clone());

        let last_used = manager
            .get_last_used_connection()
            .expect("Should pick a connection even without timestamps");
        assert_eq!(last_used.name, "test_no_timestamp");

        let url = manager.get_last_used_server_url().expect("Should get URL");
        assert_eq!(url, "http://localhost:3000");
    }
}
