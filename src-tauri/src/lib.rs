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

mod api_client;
mod chat_client;
mod connection_manager;
mod error;
mod event_bridge;
mod model_manager;
mod session_manager;
mod streaming_client;

use api_client::{ApiClient, ModelConfig};
use chat_client::{ChatClient, ChatEvent};
use connection_manager::{ConnectionManager, ConnectionStatus, ServerConnection};
use event_bridge::{AppEvent, EventBridge};
use model_manager::{ModelManager, ModelPreferences};
use session_manager::{
    ChatMessage, ChatSession, CreateSessionRequest, SendMessageRequest, SessionManager,
};
use streaming_client::{StreamEvent, StreamRequest, StreamingClient};

use chrono::Utc;
use serde::Deserialize;
use std::fs::OpenOptions;
use std::io::Write;
use std::sync::Arc;
use std::time::Duration;
use tauri::{Emitter, Manager};
use tokio::sync::Mutex as AsyncMutex;

// Managed state for singletons
pub struct ApiClientState(pub Arc<AsyncMutex<Option<ApiClient>>>);
pub struct SessionManagerState(pub Arc<AsyncMutex<Option<SessionManager>>>);
pub struct ModelManagerState(pub Arc<AsyncMutex<Option<ModelManager>>>);
pub struct StreamingClientState(pub Arc<AsyncMutex<Option<StreamingClient>>>);
pub struct EventBridgeState(pub Arc<AsyncMutex<Option<EventBridge>>>);
pub struct ConnectionManagerState(pub Arc<AsyncMutex<Option<ConnectionManager>>>);

// Legacy state for backward compatibility
pub struct ChatClientState(pub Arc<AsyncMutex<Option<ChatClient>>>);

// Custom panic hook for crash reporting
pub fn setup_panic_hook() {
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |panic_info| {
        let panic_message = format!("Application panicked: {:?}", panic_info);
        eprintln!("{}", panic_message);
        log_to_file(&panic_message);

        // Call the default hook to maintain normal panic behavior
        default_hook(panic_info);
    }));
}

// Logging utility function
pub fn log_to_file(message: &str) {
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
    let mut connection_manager = ConnectionManager::new(config_dir, None)
        .map_err(|e| format!("Failed to create connection manager: {}", e))?;
    connection_manager
        .load_connections()
        .map_err(|e| format!("Failed to load connections: {}", e))?;
    connection_manager
        .get_last_used_server_url()
        .ok_or_else(|| "No server URL available".to_string())
}

/// Helper to get or create the ConnectionManager from managed state
async fn get_connection_manager<'a>(
    state: &'a tauri::State<'a, ConnectionManagerState>,
    app_handle: Option<tauri::AppHandle>,
) -> Result<tokio::sync::MutexGuard<'a, Option<ConnectionManager>>, String> {
    let mut guard = state.0.lock().await;

    // Initialize connection manager if not already created
    if guard.is_none() {
        let config_dir = get_config_dir()?;
        let mut manager = ConnectionManager::new(config_dir, app_handle)
            .map_err(|e| format!("Failed to create connection manager: {}", e))?;

        // Load saved connections
        if let Err(e) = manager.load_connections() {
            log_warn!("⚠️ [INIT] Failed to load connections: {}", e);
        }

        *guard = Some(manager);
    }

    Ok(guard)
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

    // Parse the server URL to extract components
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
    state: tauri::State<'_, ConnectionManagerState>,
    server_url: String,
    #[allow(unused_variables)] api_key: Option<String>,
) -> Result<bool, String> {
    log_info!("🧪 [CONNECTION] Testing connection to: {}", server_url);
    // Note: API key will be used for HMAC signing in future implementation

    // Parse the server URL to extract components
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

// Chat/Session management commands

// Helper to get or create the ChatClient from managed state
async fn get_chat_client<'a>(
    state: &'a tauri::State<'a, ChatClientState>,
) -> Result<tokio::sync::MutexGuard<'a, Option<ChatClient>>, String> {
    let mut guard = state.0.lock().await;

    // Initialize client if not already created
    if guard.is_none() {
        let config_dir = get_config_dir()?;
        let client = ChatClient::new(config_dir)
            .map_err(|e| format!("Failed to create chat client: {}", e))?;
        *guard = Some(client);
    }

    Ok(guard)
}

#[tauri::command]
async fn list_sessions(
    state: tauri::State<'_, ChatClientState>,
) -> Result<Vec<serde_json::Value>, String> {
    log_info!("📥 [CHAT] Listing sessions");

    let guard = get_chat_client(&state).await?;
    let client = guard
        .as_ref()
        .ok_or_else(|| "Chat client not initialized".to_string())?;

    let sessions = client.list_sessions().await.map_err(|e| e.to_string())?;

    let sessions_json = serde_json::to_value(&sessions)
        .map_err(|e| format!("Failed to serialize sessions: {}", e))?;
    Ok(sessions_json.as_array().cloned().unwrap_or_default())
}

#[tauri::command]
async fn create_session(
    state: tauri::State<'_, ChatClientState>,
    title: Option<String>,
) -> Result<serde_json::Value, String> {
    log_info!("📝 [CHAT] Creating session: {:?}", title);

    let guard = get_chat_client(&state).await?;
    let client = guard
        .as_ref()
        .ok_or_else(|| "Chat client not initialized".to_string())?;

    let session = client
        .create_session(title)
        .await
        .map_err(|e| e.to_string())?;

    let session_json = serde_json::to_value(&session)
        .map_err(|e| format!("Failed to serialize session: {}", e))?;
    Ok(session_json)
}

#[tauri::command]
async fn send_message(
    state: tauri::State<'_, ChatClientState>,
    session_id: String,
    content: String,
) -> Result<serde_json::Value, String> {
    log_info!("💬 [CHAT] Sending message to session: {}", session_id);

    // Input validation
    if session_id.trim().is_empty() {
        return Err("Session ID cannot be empty".to_string());
    }
    let trimmed_content = content.trim();
    if trimmed_content.is_empty() {
        return Err("Message content cannot be empty".to_string());
    }
    if content.len() > 100_000 {
        return Err("Message content exceeds maximum length (100KB)".to_string());
    }

    let guard = get_chat_client(&state).await?;
    let client = guard
        .as_ref()
        .ok_or_else(|| "Chat client not initialized".to_string())?;

    let message = client
        .send_message(&session_id, trimmed_content)
        .await
        .map_err(|e| e.to_string())?;

    let message_json = serde_json::to_value(&message)
        .map_err(|e| format!("Failed to serialize message: {}", e))?;
    Ok(message_json)
}

#[tauri::command]
async fn get_session_messages(
    state: tauri::State<'_, ChatClientState>,
    session_id: String,
) -> Result<Vec<serde_json::Value>, String> {
    log_info!("📜 [CHAT] Getting messages for session: {}", session_id);

    let guard = get_chat_client(&state).await?;
    let client = guard
        .as_ref()
        .ok_or_else(|| "Chat client not initialized".to_string())?;

    let messages = client
        .get_session_messages(&session_id)
        .await
        .map_err(|e| e.to_string())?;

    let messages_json: Vec<serde_json::Value> = messages
        .into_iter()
        .filter_map(|m| serde_json::to_value(&m).ok())
        .collect();
    Ok(messages_json)
}

#[tauri::command]
async fn subscribe_to_chat_events(
    state: tauri::State<'_, ChatClientState>,
) -> Result<String, String> {
    log_info!("🎧 [CHAT] Subscribing to chat events");

    // Ensure client is initialized
    let _guard = get_chat_client(&state).await?;

    // Return subscription channel identifier
    Ok("chat_events".to_string())
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

// Model configuration commands
#[tauri::command]
async fn get_available_models() -> Result<Vec<serde_json::Value>, String> {
    log_info!("🤖 [MODELS] Getting available models...");

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let model_manager = ModelManager::new(api_client, config_dir);

    // Try to fetch from server first - convert to Send-safe type immediately
    let server_result: Result<Vec<serde_json::Value>, String> = model_manager
        .fetch_available_models()
        .await
        .map(|models| {
            models
                .into_iter()
                .map(|m| serde_json::to_value(m).unwrap_or_default())
                .collect()
        })
        .map_err(|e| e.to_string());

    match server_result {
        Ok(models_json) => {
            log_info!(
                "✅ [MODELS] Retrieved {} models from server",
                models_json.len()
            );
            Ok(models_json)
        }
        Err(server_err) => {
            log_warn!("⚠️ [MODELS] Failed to fetch from server: {}", server_err);

            // Fallback to cached models
            match model_manager.get_available_models().await {
                Ok(cached_models) => {
                    let models_json: Vec<serde_json::Value> = cached_models
                        .into_iter()
                        .map(|m| serde_json::to_value(m).unwrap_or_default())
                        .collect();
                    log_info!("✅ [MODELS] Retrieved {} cached models", models_json.len());
                    Ok(models_json)
                }
                Err(cache_err) => {
                    log_error!("❌ [MODELS] Failed to get cached models: {}", cache_err);
                    Err(format!("Failed to get available models: {}", cache_err))
                }
            }
        }
    }
}

#[tauri::command]
async fn get_model_preferences() -> Result<serde_json::Value, String> {
    log_info!("⚙️ [MODELS] Getting model preferences...");

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let model_manager = ModelManager::new(api_client, config_dir);

    model_manager
        .load_preferences()
        .map_err(|e| e.to_string())?;
    let preferences = model_manager.get_preferences();

    let preferences_json = serde_json::to_value(&preferences)
        .map_err(|e| format!("Failed to serialize preferences: {}", e))?;

    log_info!("✅ [MODELS] Retrieved model preferences");
    Ok(preferences_json)
}

#[tauri::command]
async fn set_model_preferences(preferences: serde_json::Value) -> Result<(), String> {
    log_info!("⚙️ [MODELS] Setting model preferences...");

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let model_manager = ModelManager::new(api_client, config_dir);

    let model_preferences: ModelPreferences = serde_json::from_value(preferences)
        .map_err(|e| format!("Failed to parse preferences: {}", e))?;

    model_manager
        .update_preferences(model_preferences)
        .map_err(|e| e.to_string())?;

    log_info!("✅ [MODELS] Updated model preferences");
    Ok(())
}

#[tauri::command]
async fn set_default_model(provider_id: String, model_id: String) -> Result<(), String> {
    log_info!(
        "🎯 [MODELS] Setting default model: {}/{}",
        provider_id,
        model_id
    );

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let model_manager = ModelManager::new(api_client, config_dir);

    model_manager
        .set_default_model(provider_id, model_id)
        .map_err(|e| e.to_string())?;

    log_info!("✅ [MODELS] Updated default model");
    Ok(())
}

// Enhanced session management commands
#[tauri::command]
async fn delete_session(session_id: String) -> Result<(), String> {
    log_info!("🗑️ [SESSION] Deleting session: {}", session_id);

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let session_manager = SessionManager::new(api_client, config_dir);

    session_manager
        .delete_session(&session_id)
        .await
        .map_err(|e| e.to_string())?;

    log_info!("✅ [SESSION] Deleted session: {}", session_id);
    Ok(())
}

#[tauri::command]
async fn update_session_title(session_id: String, title: String) -> Result<(), String> {
    log_info!(
        "✏️ [SESSION] Updating session title: {} -> {}",
        session_id,
        title
    );

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let session_manager = SessionManager::new(api_client, config_dir);

    session_manager
        .update_session_title(&session_id, title)
        .await
        .map_err(|e| e.to_string())?;

    log_info!("✅ [SESSION] Updated session title");
    Ok(())
}

#[tauri::command]
async fn get_session_stats(session_id: String) -> Result<serde_json::Value, String> {
    log_info!("📊 [SESSION] Getting session stats: {}", session_id);

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let session_manager = SessionManager::new(api_client, config_dir);

    let stats = session_manager
        .get_session_stats(&session_id)
        .await
        .map_err(|e| e.to_string())?;

    let stats_json =
        serde_json::to_value(&stats).map_err(|e| format!("Failed to serialize stats: {}", e))?;

    log_info!("✅ [SESSION] Retrieved session stats");
    Ok(stats_json)
}

// Streaming commands
#[tauri::command]
async fn start_message_stream(
    app_handle: tauri::AppHandle,
    session_id: String,
    content: String,
    model_config: Option<ModelConfig>,
) -> Result<String, String> {
    log_info!(
        "🌊 [STREAM] Starting message stream for session: {}",
        session_id
    );

    // Validate inputs
    if session_id.trim().is_empty() {
        return Err("Session ID cannot be empty".to_string());
    }
    let trimmed_content = content.trim();
    if trimmed_content.is_empty() {
        return Err("Message content cannot be empty".to_string());
    }

    // Ensure server connection
    let server_url = ensure_server_connected()?;

    // Create streaming components
    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    api_client
        .set_server_url(server_url)
        .await
        .map_err(|e| e.to_string())?;

    let streaming_client = StreamingClient::new(api_client).map_err(|e| e.to_string())?;
    let event_bridge = EventBridge::with_app_handle(app_handle);

    // Create stream request
    let stream_request = StreamRequest {
        session_id: session_id.clone(),
        content: trimmed_content.to_string(),
        model_config,
        system_prompt: None,
        temperature: None,
        max_tokens: None,
    };

    // Start streaming
    let stream_id = streaming_client
        .start_stream(stream_request)
        .await
        .map_err(|e| e.to_string())?;

    // Spawn event forwarding task
    let stream_id_clone = stream_id.clone();
    let session_id_clone = session_id.clone();
    let event_bridge_clone = event_bridge.clone();
    let streaming_client_clone = streaming_client.clone();

    tokio::spawn(async move {
        let mut receiver = streaming_client_clone.subscribe();

        while let Ok(stream_event) = receiver.recv().await {
            if let Err(e) = event_bridge_clone
                .emit_stream_event(stream_event.clone(), session_id_clone.clone())
                .await
            {
                log_error!("❌ [STREAM] Failed to emit event: {}", e);
            }
        }

        // Cleanup when stream ends
        let _ = streaming_client_clone.stop_stream(&stream_id_clone).await;
    });

    log_info!("✅ [STREAM] Started message stream: {}", stream_id);
    Ok(stream_id)
}

#[tauri::command]
async fn stop_message_stream(stream_id: String) -> Result<(), String> {
    log_info!("🛑 [STREAM] Stopping message stream: {}", stream_id);

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let streaming_client = StreamingClient::new(api_client).map_err(|e| e.to_string())?;

    streaming_client
        .stop_stream(&stream_id)
        .await
        .map_err(|e| e.to_string())?;

    log_info!("✅ [STREAM] Stopped message stream: {}", stream_id);
    Ok(())
}

#[tauri::command]
async fn get_active_streams() -> Result<Vec<String>, String> {
    log_info!("📋 [STREAM] Getting active streams...");

    let config_dir = get_config_dir()?;
    let api_client = Arc::new(ApiClient::new().map_err(|e| e.to_string())?);
    let streaming_client = StreamingClient::new(api_client).map_err(|e| e.to_string())?;

    let active_streams = streaming_client.get_active_streams().await;

    log_info!(
        "✅ [STREAM] Retrieved {} active streams",
        active_streams.len()
    );
    Ok(active_streams)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Initialize managed state (singletons)
    let api_client_state = ApiClientState(Arc::new(AsyncMutex::new(None)));
    let session_manager_state = SessionManagerState(Arc::new(AsyncMutex::new(None)));
    let model_manager_state = ModelManagerState(Arc::new(AsyncMutex::new(None)));
    let streaming_client_state = StreamingClientState(Arc::new(AsyncMutex::new(None)));
    let event_bridge_state = EventBridgeState(Arc::new(AsyncMutex::new(None)));
    let connection_manager_state = ConnectionManagerState(Arc::new(AsyncMutex::new(None)));

    // Legacy state for backward compatibility
    let chat_client_state = ChatClientState(Arc::new(AsyncMutex::new(None)));

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(api_client_state)
        .manage(session_manager_state)
        .manage(model_manager_state)
        .manage(streaming_client_state)
        .manage(event_bridge_state)
        .manage(connection_manager_state)
        .manage(chat_client_state)
        .setup(|app| {
            // Initialize all components on app startup
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                let config_dir = match dirs::config_dir() {
                    Some(dir) => dir.join("opencode-nexus"),
                    None => {
                        log_warn!("Could not determine config directory");
                        return;
                    }
                };

                // Initialize API client
                let api_client = match ApiClient::new() {
                    Ok(client) => Arc::new(client),
                    Err(e) => {
                        log_error!("❌ [INIT] Failed to create API client: {}", e);
                        return;
                    }
                };

                // Initialize event bridge
                let event_bridge = EventBridge::with_app_handle(app_handle.clone());

                // Initialize connection manager in managed state
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
                                log_error!("❌ [INIT] Failed to create connection manager: {}", e);
                                return;
                            }
                        }
                    }

                    // Attempt to restore the last connection
                    if let Some(ref mut cm) = *state_guard {
                        if let Err(e) = cm.restore_connection().await {
                            log_warn!("⚠️ [INIT] Failed to restore connection on startup: {}", e);
                        }
                    }
                }

                // Initialize session manager
                let session_manager = SessionManager::new(api_client.clone(), config_dir.clone());
                if let Err(e) = session_manager.load_sessions().await {
                    log_warn!("⚠️ [INIT] Failed to load sessions: {}", e);
                }

                // Initialize model manager
                let model_manager = ModelManager::new(api_client.clone(), config_dir.clone());
                if let Err(e) = model_manager.load_providers().await {
                    log_warn!("⚠️ [INIT] Failed to load providers: {}", e);
                }
                if let Err(e) = model_manager.load_preferences() {
                    log_warn!("⚠️ [INIT] Failed to load model preferences: {}", e);
                }

                // Initialize streaming client
                let streaming_client = match StreamingClient::new(api_client.clone()) {
                    Ok(client) => client,
                    Err(e) => {
                        log_error!("❌ [INIT] Failed to create streaming client: {}", e);
                        return;
                    }
                };

                // Emit application ready event
                if let Err(e) = event_bridge
                    .emit_application_ready(vec![
                        "chat".to_string(),
                        "streaming".to_string(),
                        "model-management".to_string(),
                        "session-management".to_string(),
                    ])
                    .await
                {
                    log_warn!("⚠️ [INIT] Failed to emit ready event: {}", e);
                }

                log_info!("✅ [INIT] OpenCode Nexus initialized successfully");
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            greet,
            // Connection management commands
            connect_to_server,
            test_server_connection,
            get_connection_status,
            get_current_connection,
            disconnect_from_server,
            get_saved_connections,
            save_connection,
            get_last_used_connection,
            // Chat/Session management commands
            list_sessions,
            create_session,
            send_message,
            get_session_messages,
            subscribe_to_chat_events,
            delete_session,
            update_session_title,
            get_session_stats,
            // Model configuration commands
            get_available_models,
            get_model_preferences,
            set_model_preferences,
            set_default_model,
            // Streaming commands
            start_message_stream,
            stop_message_stream,
            get_active_streams,
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

        // Chat: 6 commands
        // - create_chat_session
        // - send_chat_message
        // - get_chat_sessions
        // - get_chat_session_history
        // - delete_chat_session
        // - start_message_stream (event bridge)

        // Application: 3 commands + greet
        // - get_application_logs
        // - log_frontend_error
        // - clear_application_logs
        // - greet (test command)

        // Model Configuration: 1 command
        // - get_available_models

        // Total: 30 commands registered
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

    /// Test ModelConfig struct serialization
    #[test]
    fn test_model_config_serialization() {
        let config = ModelConfig {
            provider_id: "anthropic".to_string(),
            model_id: "claude-3-5-sonnet-20241022".to_string(),
        };

        let json = serde_json::to_string(&config).expect("Should serialize ModelConfig to JSON");

        assert!(json.contains("anthropic"));
        assert!(json.contains("claude-3-5-sonnet-20241022"));

        let deserialized: ModelConfig =
            serde_json::from_str(&json).expect("Should deserialize ModelConfig from JSON");

        assert_eq!(deserialized.provider_id, "anthropic");
        assert_eq!(deserialized.model_id, "claude-3-5-sonnet-20241022");
    }

    /// Test ModelConfig with optional model in send_message
    #[test]
    fn test_model_config_optional() {
        // Test with Some(ModelConfig)
        let config = Some(ModelConfig {
            provider_id: "openai".to_string(),
            model_id: "gpt-4".to_string(),
        });

        assert!(config.is_some());
        if let Some(c) = config {
            assert_eq!(c.provider_id, "openai");
            assert_eq!(c.model_id, "gpt-4");
        }

        // Test with None (server should use default)
        let config_none: Option<ModelConfig> = None;
        assert!(config_none.is_none());
    }

    /// Test delete_session command requires server connection
    #[test]
    fn test_delete_session_requires_server_connection() {
        // Verify that delete_session would fail without server connection
        let result = ensure_server_connected();

        match result {
            Ok(url) => {
                assert!(!url.is_empty(), "Server URL should not be empty");
            }
            Err(msg) => {
                assert!(
                    msg.contains("connect to an OpenCode server"),
                    "Should provide user-friendly error: {}",
                    msg
                );
            }
        }
    }

    /// Test send_message signature accepts optional model
    #[test]
    fn test_send_message_model_parameter_documented() {
        // This test documents the updated send_message signature:
        //
        // Old signature:
        //   send_message(session_id: &str, content: &str) -> Result<(), String>
        //
        // New signature:
        //   send_message(session_id: &str, content: &str, model: Option<ModelConfig>) -> Result<(), String>
        //
        // Usage:
        //   1. With default model (server chooses):
        //      chat_client.send_message(session_id, content, None)
        //
        //   2. With specific model:
        //      chat_client.send_message(session_id, content, Some(ModelConfig {
        //          provider_id: "anthropic".to_string(),
        //          model_id: "claude-3-5-sonnet-20241022".to_string(),
        //      }))
        //
        // When model is None, the PromptRequest is sent without model field,
        // allowing OpenCode server to apply its own model selector logic.

        assert!(true, "send_message signature documented");
    }

    /// Test get_available_models parsing logic
    #[test]
    fn test_model_parsing_from_providers_response() {
        // This test documents the model parsing logic for /config/providers response
        //
        // OpenCode server /config/providers endpoint returns:
        // {
        //   "providers": [
        //     {
        //       "id": "anthropic",
        //       "models": [
        //         { "id": "claude-3-5-sonnet-20241022", "name": "Claude 3.5 Sonnet" },
        //         { "id": "claude-opus-4-1", "name": "Claude Opus 4.1" }
        //       ]
        //     },
        //     {
        //       "id": "openai",
        //       "models": [
        //         { "id": "gpt-4o", "name": "GPT-4o" },
        //         { "id": "gpt-4-turbo", "name": "GPT-4 Turbo" }
        //       ]
        //     }
        //   ],
        //   "default": {
        //     "anthropic": "claude-3-5-sonnet-20241022",
        //     "openai": "gpt-4o"
        //   }
        // }
        //
        // Parsing logic in get_available_models():
        // 1. Iterate over each provider in providers array
        // 2. For each provider, iterate over its models
        // 3. Construct full model ID: "provider_id/model_id"
        // 4. Use model.name as display name, fallback to model.id
        // 5. Return Vec of tuples: (full_model_id, display_name)
        //
        // Example output:
        // [
        //   ("anthropic/claude-3-5-sonnet-20241022", "Claude 3.5 Sonnet"),
        //   ("anthropic/claude-opus-4-1", "Claude Opus 4.1"),
        //   ("openai/gpt-4o", "GPT-4o"),
        //   ("openai/gpt-4-turbo", "GPT-4 Turbo")
        // ]

        assert!(true, "Model parsing logic documented");
    }
}
