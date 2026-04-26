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

mod connection_manager;
mod error;

use connection_manager::{ConnectionManager, ConnectionStatus, ServerConnection};

use chrono::Utc;
use std::fs::OpenOptions;
use std::io::Write;
use std::sync::Arc;
use tauri::Manager;
use tokio::sync::Mutex as AsyncMutex;

pub struct ConnectionManagerState(pub Arc<AsyncMutex<Option<ConnectionManager>>>);

pub fn setup_panic_hook() {
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |panic_info| {
        let panic_message = format!("Application panicked: {:?}", panic_info);
        eprintln!("{}", panic_message);
        log_to_file(&panic_message);

        default_hook(panic_info);
    }));
}

pub fn log_to_file(message: &str) {
    if let Some(config_dir) = dirs::config_dir() {
        let log_path = config_dir.join("opencode-nexus").join("application.log");

        if let Some(parent) = log_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }

        let timestamp = Utc::now().format("%Y-%m-%d %H:%M:%S UTC");
        let log_entry = format!("[{}] {}\n", timestamp, message);

        if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(log_path) {
            let _ = file.write_all(log_entry.as_bytes());
            let _ = file.flush();
        }
    }
}

#[macro_export]
macro_rules! log_info {
    ($($arg:tt)*) => {
        let message = format!("[INFO] {}", format!($($arg)*));
        println!("{}", message);
        log_to_file(&message);
    };
}

#[macro_export]
macro_rules! log_error {
    ($($arg:tt)*) => {
        let message = format!("[ERROR] {}", format!($($arg)*));
        eprintln!("{}", message);
        log_to_file(&message);
    };
}

#[macro_export]
macro_rules! log_warn {
    ($($arg:tt)*) => {
        let message = format!("[WARN] {}", format!($($arg)*));
        println!("{}", message);
        log_to_file(&message);
    };
}

#[macro_export]
macro_rules! log_debug {
    ($($arg:tt)*) => {
        let message = format!("[DEBUG] {}", format!($($arg)*));
        println!("{}", message);
        log_to_file(&message);
    };
}

fn get_config_dir() -> Result<std::path::PathBuf, String> {
    dirs::config_dir()
        .map(|dir| dir.join("opencode-nexus"))
        .ok_or_else(|| "Could not determine config directory".to_string())
}

fn get_server_url() -> Result<String, String> {
    let config_dir = get_config_dir()?;
    let mut connection_manager = ConnectionManager::new(config_dir, None)
        .map_err(|e| format!("Failed to create connection manager: {}", e))?;
    connection_manager
        .load_connections()
        .map_err(|e| format!("Failed to load connections: {}", e))?;
    connection_manager
        .get_last_used_server_url()
        .ok_or_else(|| "No server URL available".to_string())
}

async fn get_connection_manager<'a>(
    state: &'a tauri::State<'a, ConnectionManagerState>,
    app_handle: Option<tauri::AppHandle>,
) -> Result<tokio::sync::MutexGuard<'a, Option<ConnectionManager>>, String> {
    let mut guard = state.0.lock().await;

    if guard.is_none() {
        let config_dir = get_config_dir()?;
        let mut manager = ConnectionManager::new(config_dir, app_handle)
            .map_err(|e| format!("Failed to create connection manager: {}", e))?;

        if let Err(e) = manager.load_connections() {
            log_warn!("⚠️ [INIT] Failed to load connections: {}", e);
        }

        *guard = Some(manager);
    }

    Ok(guard)
}

fn ensure_server_connected() -> Result<String, String> {
    get_server_url().map_err(|_| {
        "Please connect to an OpenCode server first. Use the Connection settings to add a server."
            .to_string()
    })
}

#[tauri::command]
async fn connect_to_server(
    app_handle: tauri::AppHandle,
    state: tauri::State<'_, ConnectionManagerState>,
    server_url: String,
    api_key: Option<String>,
    method: String,
    _name: String,
) -> Result<String, String> {
    log_info!(
        "🔗 [CONNECTION] Connecting to server: {} (method: {})",
        server_url,
        method
    );

    let url = url::Url::parse(&server_url).map_err(|e| format!("Invalid server URL: {}", e))?;
    let hostname = url.host_str().ok_or("No hostname in URL")?.to_string();
    let port = url
        .port()
        .unwrap_or(if url.scheme() == "https" { 443 } else { 4096 });
    let secure = url.scheme() == "https";

    let mut connection_manager_guard =
        get_connection_manager(&state, Some(app_handle.clone())).await?;
    let connection_manager = connection_manager_guard
        .as_mut()
        .ok_or("Connection manager not initialized")?;

    connection_manager
        .connect_to_server(&hostname, port, secure)
        .await?;

    if let Some(key) = &api_key {
        log_info!("🔐 [CONNECTION] API key provided (length: {})", key.len());
    }

    log_info!("✅ [CONNECTION] Successfully connected to: {}", server_url);

    let connection_id = format!("{}-{}", method, hostname);
    Ok(connection_id)
}

#[tauri::command]
async fn test_server_connection(
    state: tauri::State<'_, ConnectionManagerState>,
    server_url: String,
    #[allow(unused_variables)] api_key: Option<String>,
) -> Result<bool, String> {
    log_info!("🧪 [CONNECTION] Testing connection to: {}", server_url);

    let url = url::Url::parse(&server_url).map_err(|e| format!("Invalid server URL: {}", e))?;
    let hostname = url.host_str().ok_or("No hostname in URL")?.to_string();
    let port = url
        .port()
        .unwrap_or(if url.scheme() == "https" { 443 } else { 4096 });
    let secure = url.scheme() == "https";

    let connection_manager_guard = get_connection_manager(&state, None).await?;
    let connection_manager = connection_manager_guard
        .as_ref()
        .ok_or("Connection manager not initialized")?;

    match connection_manager
        .test_server_connection(&hostname, port, secure)
        .await
    {
        Ok(_server_info) => {
            log_info!("✅ [CONNECTION] Test successful: {}", server_url);
            Ok(true)
        }
        Err(e) => {
            log_error!("❌ [CONNECTION] Test failed: {}", e);
            Err(e)
        }
    }
}

#[tauri::command]
async fn get_connection_status(
    state: tauri::State<'_, ConnectionManagerState>,
    app_handle: tauri::AppHandle,
) -> Result<ConnectionStatus, String> {
    let connection_manager_guard = get_connection_manager(&state, Some(app_handle)).await?;
    let connection_manager = connection_manager_guard
        .as_ref()
        .ok_or("Connection manager not initialized")?;
    Ok(connection_manager.get_connection_status())
}

#[tauri::command]
async fn get_current_connection(
    state: tauri::State<'_, ConnectionManagerState>,
    app_handle: tauri::AppHandle,
) -> Result<Option<ServerConnection>, String> {
    let connection_manager_guard = get_connection_manager(&state, Some(app_handle)).await?;
    let connection_manager = connection_manager_guard
        .as_ref()
        .ok_or("Connection manager not initialized")?;
    Ok(connection_manager.get_current_connection())
}

#[tauri::command]
async fn disconnect_from_server(
    state: tauri::State<'_, ConnectionManagerState>,
    app_handle: tauri::AppHandle,
) -> Result<(), String> {
    let mut connection_manager_guard = get_connection_manager(&state, Some(app_handle)).await?;
    let connection_manager = connection_manager_guard
        .as_mut()
        .ok_or("Connection manager not initialized")?;
    connection_manager.disconnect_from_server().await
}

#[tauri::command]
async fn get_saved_connections(
    state: tauri::State<'_, ConnectionManagerState>,
    app_handle: tauri::AppHandle,
) -> Result<Vec<ServerConnection>, String> {
    let mut connection_manager_guard = get_connection_manager(&state, Some(app_handle)).await?;
    let connection_manager = connection_manager_guard
        .as_mut()
        .ok_or("Connection manager not initialized")?;
    connection_manager
        .load_connections()
        .map_err(|e| e.to_string())?;
    Ok(connection_manager.get_saved_connections())
}

#[tauri::command]
async fn save_connection(
    state: tauri::State<'_, ConnectionManagerState>,
    app_handle: tauri::AppHandle,
    connection: ServerConnection,
) -> Result<(), String> {
    let mut connection_manager_guard = get_connection_manager(&state, Some(app_handle)).await?;
    let connection_manager = connection_manager_guard
        .as_mut()
        .ok_or("Connection manager not initialized")?;
    connection_manager
        .load_connections()
        .map_err(|e| e.to_string())?;
    connection_manager.save_connection(connection)
}

#[tauri::command]
async fn get_last_used_connection(
    state: tauri::State<'_, ConnectionManagerState>,
    app_handle: tauri::AppHandle,
) -> Result<Option<ServerConnection>, String> {
    let mut connection_manager_guard = get_connection_manager(&state, Some(app_handle)).await?;
    let connection_manager = connection_manager_guard
        .as_mut()
        .ok_or("Connection manager not initialized")?;
    connection_manager
        .load_connections()
        .map_err(|e| e.to_string())?;
    Ok(connection_manager.get_last_used_connection())
}

#[tauri::command]
async fn get_application_logs() -> Result<Vec<String>, String> {
    log_info!("📋 [LOGS] Getting application logs...");

    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let log_path = config_dir.join("application.log");

    if !log_path.exists() {
        log_info!("📋 [LOGS] No log file found, returning empty logs");
        return Ok(Vec::new());
    }

    match std::fs::read_to_string(&log_path) {
        Ok(content) => {
            let logs: Vec<String> = content.lines().map(|line| line.to_string()).collect();

            log_info!("📋 [LOGS] Retrieved {} log entries", logs.len());
            Ok(logs)
        }
        Err(e) => {
            log_error!("❌ [LOGS] Failed to read log file: {}", e);
            Err(format!("Failed to read log file: {}", e))
        }
    }
}

#[tauri::command]
async fn log_frontend_error(
    level: String,
    message: String,
    details: Option<String>,
) -> Result<(), String> {
    let details_str = details.map_or_else(String::new, |d| format!(" | Details: {}", d));
    let full_message = format!("🌐 [FRONTEND] {}{}", message, details_str);

    match level.to_lowercase().as_str() {
        "error" => {
            log_error!("{}", full_message);
        }
        "warn" => {
            log_warn!("{}", full_message);
        }
        "info" => {
            log_info!("{}", full_message);
        }
        _ => {
            log_debug!("{}", full_message);
        }
    }
    Ok(())
}

#[tauri::command]
async fn clear_application_logs() -> Result<(), String> {
    log_info!("🗑️ [LOGS] Clearing application logs...");

    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let log_path = config_dir.join("application.log");

    if log_path.exists() {
        std::fs::remove_file(&log_path).map_err(|e| format!("Failed to clear log file: {}", e))?;
    }

    log_info!("✅ [LOGS] Application logs cleared successfully");
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let connection_manager_state = ConnectionManagerState(Arc::new(AsyncMutex::new(None)));

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(connection_manager_state)
        .setup(|app| {
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                let config_dir = match dirs::config_dir() {
                    Some(dir) => dir.join("opencode-nexus"),
                    None => {
                        log_warn!("Could not determine config directory");
                        return;
                    }
                };

                {
                    let connection_manager_state = app_handle.state::<ConnectionManagerState>();
                    let mut state_guard = connection_manager_state.0.lock().await;
                    if state_guard.is_none() {
                        match ConnectionManager::new(config_dir.clone(), Some(app_handle.clone())) {
                            Ok(mut cm) => {
                                if let Err(e) = cm.load_connections() {
                                    log_warn!("⚠️ [INIT] Failed to load connections: {}", e);
                                }
                                *state_guard = Some(cm);
                            }
                            Err(e) => {
                                log_error!(
                                    "❌ [INIT] Failed to create connection manager: {}",
                                    e
                                );
                                return;
                            }
                        }
                    }

                    if let Some(ref mut cm) = *state_guard {
                        if let Err(e) = cm.restore_connection().await {
                            log_warn!(
                                "⚠️ [INIT] Failed to restore connection on startup: {}",
                                e
                            );
                        }
                    }
                }

                log_info!("✅ [INIT] OpenCode Nexus initialized successfully");
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            connect_to_server,
            test_server_connection,
            get_connection_status,
            get_current_connection,
            disconnect_from_server,
            get_saved_connections,
            save_connection,
            get_last_used_connection,
            get_application_logs,
            log_frontend_error,
            clear_application_logs
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_config_dir() {
        let result = get_config_dir();
        assert!(result.is_ok(), "Should get config directory");
        let path = result.unwrap();
        assert!(path.to_string_lossy().contains("opencode-nexus"));
    }

    #[test]
    fn test_ensure_server_connected_without_connection() {
        let result = ensure_server_connected();

        if let Err(error) = result {
            assert!(
                error.contains("connect to an OpenCode server"),
                "Error message should be user-friendly: {}",
                error
            );
        }
    }

    #[test]
    fn test_chat_commands_require_server_connection() {
        let result = ensure_server_connected();

        match result {
            Ok(url) => {
                assert!(!url.is_empty(), "Server URL should not be empty");
            }
            Err(msg) => {
                assert!(
                    msg.contains("connect to an OpenCode server"),
                    "Should provide user-friendly error"
                );
            }
        }
    }
}
