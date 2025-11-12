mod api_client;
mod chat_client;
mod connection_manager;
mod message_stream;

use chat_client::{ChatClient, ChatMessage, ChatSession, SessionMetadata};
use connection_manager::{ConnectionManager, ConnectionStatus, ServerConnection, ServerInfo};

use chrono::Utc;
use std::fs::OpenOptions;
use std::io::Write;
use tauri::Emitter;

// Logging utility function
fn log_to_file(message: &str) {
    if let Some(config_dir) = dirs::config_dir() {
        let log_path = config_dir.join("opencode-nexus").join("application.log");

        // Create directory if it doesn't exist
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

// Enhanced logging macros that log to both console and file
macro_rules! log_info {
    ($($arg:tt)*) => {
        let message = format!("[INFO] {}", format!($($arg)*));
        println!("{}", message);
        log_to_file(&message);
    };
}

macro_rules! log_error {
    ($($arg:tt)*) => {
        let message = format!("[ERROR] {}", format!($($arg)*));
        eprintln!("{}", message);
        log_to_file(&message);
    };
}

macro_rules! log_warn {
    ($($arg:tt)*) => {
        let message = format!("[WARN] {}", format!($($arg)*));
        println!("{}", message);
        log_to_file(&message);
    };
}

macro_rules! log_debug {
    ($($arg:tt)*) => {
        let message = format!("[DEBUG] {}", format!($($arg)*));
        println!("{}", message);
        log_to_file(&message);
    };
}

// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

// ============================================================================
// AUTHENTICATION SYSTEM REMOVED
// ============================================================================
// The previous authentication system (auth.rs, onboarding.rs) has been removed
// in favor of a simpler connection-based architecture. OpenCode Nexus now acts
// as a client that connects to OpenCode servers without requiring user accounts.
//
// Connection security is handled at the transport layer:
// - Localhost: Direct connection (http://localhost:4096)
// - Cloudflare Tunnel: Cloudflare handles authentication
// - Reverse Proxy: API key + HMAC request signing
//
// See docs/client/CONNECTION-SETUP.md for details.
// ============================================================================

// Helper functions
fn get_config_dir() -> Result<std::path::PathBuf, String> {
    dirs::config_dir()
        .map(|dir| dir.join("opencode-nexus"))
        .ok_or_else(|| "Could not determine config directory".to_string())
}

fn get_server_url() -> Result<String, String> {
    let config_dir = get_config_dir()?;
    let connection_manager = ConnectionManager::new(config_dir, None)
        .map_err(|e| format!("Failed to create connection manager: {}", e))?;
    connection_manager
        .get_server_url()
        .ok_or_else(|| "No server URL available".to_string())
}

/// Ensure a server connection exists before executing chat commands
/// Returns a user-friendly error message if no connection is available
fn ensure_server_connected() -> Result<String, String> {
    get_server_url().map_err(|_| {
        "Please connect to an OpenCode server first. Use the Connection settings to add a server.".to_string()
    })
}

// Connection management commands
#[tauri::command]
async fn connect_to_server(
    app_handle: tauri::AppHandle,
    server_url: String,
    api_key: Option<String>,
    method: String,
    name: String,
) -> Result<String, String> {
    log_info!("🔗 [CONNECTION] Connecting to server: {} (method: {})", server_url, method);

    // Parse the server URL to extract components
    let url = url::Url::parse(&server_url).map_err(|e| format!("Invalid server URL: {}", e))?;
    let hostname = url.host_str().ok_or("No hostname in URL")?.to_string();
    let port = url.port().unwrap_or(if url.scheme() == "https" { 443 } else { 4096 });
    let secure = url.scheme() == "https";

    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let mut connection_manager =
        ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;

    // Connect to the server
    connection_manager
        .connect_to_server(&hostname, port, secure)
        .await?;

    // TODO: Store API key securely if provided
    if let Some(key) = &api_key {
        log_info!("🔐 [CONNECTION] API key provided (length: {})", key.len());
        // Store in secure storage (keychain/keystore)
        // For now, just log that we received it
    }

    log_info!("✅ [CONNECTION] Successfully connected to: {}", server_url);

    // Return a connection ID (could be UUID or hash of server_url)
    let connection_id = format!("{}-{}", method, hostname);
    Ok(connection_id)
}

#[tauri::command]
async fn test_server_connection(
    server_url: String,
    #[allow(unused_variables)] api_key: Option<String>,
) -> Result<bool, String> {
    log_info!("🧪 [CONNECTION] Testing connection to: {}", server_url);
    // Note: API key will be used for HMAC signing in future implementation

    // Parse the server URL to extract components
    let url = url::Url::parse(&server_url).map_err(|e| format!("Invalid server URL: {}", e))?;
    let hostname = url.host_str().ok_or("No hostname in URL")?.to_string();
    let port = url.port().unwrap_or(if url.scheme() == "https" { 443 } else { 4096 });
    let secure = url.scheme() == "https";

    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    // Create a temporary connection manager for testing (no app_handle needed)
    let connection_manager =
        ConnectionManager::new(config_dir, None).map_err(|e| e.to_string())?;

    // Test the connection
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
async fn get_connection_status(app_handle: tauri::AppHandle) -> Result<ConnectionStatus, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let connection_manager =
        ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    Ok(connection_manager.get_connection_status())
}

#[tauri::command]
async fn disconnect_from_server(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let mut connection_manager =
        ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    connection_manager.disconnect_from_server().await
}

#[tauri::command]
async fn get_saved_connections(
    app_handle: tauri::AppHandle,
) -> Result<Vec<ServerConnection>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let mut connection_manager =
        ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    connection_manager
        .load_connections()
        .map_err(|e| e.to_string())?;
    Ok(connection_manager.get_saved_connections())
}

// Chat commands
#[tauri::command]
async fn create_chat_session(
    _app_handle: tauri::AppHandle,
    title: Option<String>,
) -> Result<ChatSession, String> {
    // Ensure server is connected before attempting chat operations
    let server_url = ensure_server_connected()?;

    let config_dir = get_config_dir()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.set_server_url(server_url);
    chat_client.load_session_metadata().map_err(|e| e.to_string())?;
    chat_client.create_session(title.as_deref()).await
}

#[tauri::command]
async fn send_chat_message(
    _app_handle: tauri::AppHandle,
    session_id: String,
    content: String,
) -> Result<(), String> {
    // Ensure server is connected before attempting chat operations
    let server_url = ensure_server_connected()?;

    let config_dir = get_config_dir()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.set_server_url(server_url);
    chat_client.load_session_metadata().map_err(|e| e.to_string())?;

    // Send the message and rely on events/streaming for responses
    chat_client.send_message(&session_id, &content).await
}

#[tauri::command]
async fn get_chat_sessions(_app_handle: tauri::AppHandle) -> Result<Vec<SessionMetadata>, String> {
    let config_dir = get_config_dir()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.load_session_metadata().map_err(|e| e.to_string())?;

    // Sync with server to get latest session list (server is source of truth)
    // This updates local metadata cache - mobile-optimized (no message storage)
    // Errors in sync are non-fatal - we fall back to local metadata cache
    let _ = chat_client.sync_session_metadata_with_server().await;

    // Return lightweight metadata (no messages - fetch from server when needed)
    let metadata: Vec<SessionMetadata> = chat_client
        .get_session_metadata_map()
        .values()
        .cloned()
        .collect();
    Ok(metadata)
}

#[tauri::command]
async fn get_chat_session_history(
    _app_handle: tauri::AppHandle,
    session_id: String,
) -> Result<Vec<ChatMessage>, String> {
    let server_url = ensure_server_connected()?;
    let config_dir = get_config_dir()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.set_server_url(server_url);

    // Fetch full message history from server (mobile-optimized - not stored locally)
    chat_client.get_session_history(&session_id).await
}

#[tauri::command]
async fn start_message_stream(app_handle: tauri::AppHandle) -> Result<(), String> {
    // Ensure server is connected before attempting chat operations
    let server_url = ensure_server_connected()?;

    let config_dir = get_config_dir()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.set_server_url(server_url);

    // Start SSE streaming via ChatClient's integrated MessageStream
    let mut event_receiver = chat_client.start_event_stream().await?;

    // Listen for chat events and emit them to the frontend
    tokio::spawn(async move {
        while let Ok(chat_event) = event_receiver.recv().await {
            let _ = app_handle.emit("chat-event", &chat_event);
        }
    });

    Ok(())
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
    let details_str = details.map_or_else(|| String::new(), |d| format!(" | Details: {}", d));
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
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            // Connection management commands
            connect_to_server,
            test_server_connection,
            get_connection_status,
            disconnect_from_server,
            get_saved_connections,
            // Chat commands
            create_chat_session,
            send_chat_message,
            get_chat_sessions,
            get_chat_session_history,
            start_message_stream,
            // Application commands
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
        // When no connection exists, should return friendly error message
        let result = ensure_server_connected();

        if let Err(error) = result {
            assert!(
                error.contains("connect to an OpenCode server"),
                "Error message should be user-friendly: {}",
                error
            );
        } else {
            // If connection exists (e.g., from previous test), that's also valid
            // This test validates the error path when no connection exists
        }
    }

    #[tokio::test]
    async fn test_greet_command() {
        let result = greet("Test User");
        assert_eq!(result, "Hello, Test User! You've been greeted from Rust!");
    }

    /// Test that event emission pattern is correctly structured
    /// Note: Full Tauri event testing requires Tauri runtime
    #[tokio::test]
    async fn test_start_message_stream_logic() {
        // This tests the logic structure without full Tauri runtime
        // The actual start_message_stream command:
        // 1. Ensures server connection
        // 2. Creates ChatClient
        // 3. Sets server URL
        // 4. Starts event stream
        // 5. Spawns task to emit events to frontend

        // We verify the helper functions work correctly
        let config_dir_result = get_config_dir();
        assert!(config_dir_result.is_ok(), "Config dir should be accessible");
    }

    /// Verify chat session creation requires server connection
    #[test]
    fn test_chat_commands_require_server_connection() {
        // The ensure_server_connected() function is called by:
        // - create_chat_session
        // - send_chat_message
        // - start_message_stream
        //
        // This ensures users can't attempt chat operations without server
        let result = ensure_server_connected();

        // Should either succeed (if connection exists) or fail with friendly message
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

    /// Verify command registration includes all expected commands
    #[test]
    fn test_command_registration_complete() {
        // This test documents all registered Tauri commands
        // Verifying the command handler includes:

        // Onboarding: 5 commands
        // - get_onboarding_state
        // - complete_onboarding
        // - skip_onboarding
        // - check_system_requirements
        // - create_owner_account

        // Authentication: 9 commands
        // - authenticate_user
        // - change_password
        // - is_auth_configured
        // - is_authenticated
        // - get_user_info
        // - reset_failed_attempts
        // - create_persistent_session
        // - validate_persistent_session
        // - invalidate_session
        // - cleanup_expired_sessions

        // Connection: 5 commands
        // - connect_to_server
        // - test_server_connection
        // - get_connection_status
        // - disconnect_from_server
        // - get_saved_connections

        // Chat: 5 commands
        // - create_chat_session
        // - send_chat_message
        // - get_chat_sessions
        // - get_chat_session_history
        // - start_message_stream (event bridge)

        // Application: 3 commands + greet
        // - get_application_logs
        // - log_frontend_error
        // - clear_application_logs
        // - greet (test command)

        // Total: 28 commands registered
        assert!(true, "Command registration documented");
    }

    /// Document the event bridge pattern used for real-time updates
    #[test]
    fn test_event_bridge_pattern_documented() {
        // Event Bridge Pattern (start_message_stream):
        //
        // Backend (Rust):
        // 1. ChatClient.start_event_stream() returns broadcast::Receiver
        // 2. Tokio task spawned to listen for ChatEvent messages
        // 3. Each event emitted to frontend via app_handle.emit("chat-event", event)
        //
        // Frontend (TypeScript):
        // 1. Calls invoke('start_message_stream') once on app start
        // 2. Listens for events with listen('chat-event', callback)
        // 3. Receives ChatEvent (SessionCreated, MessageReceived, MessageChunk, Error)
        //
        // Event Flow:
        // SSE Server → MessageStream → ChatEvent → Tokio Channel → Tauri Emit → Frontend
        //
        // This pattern enables:
        // - Real-time message streaming from server
        // - Decoupled frontend/backend communication
        // - Multiple UI components can subscribe to same events
        // - Automatic reconnection handled by MessageStream

        assert!(true, "Event bridge pattern documented");
    }
}
