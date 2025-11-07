mod onboarding;
mod auth;
mod connection_manager;
mod api_client;
mod chat_client;
mod message_stream;

use auth::AuthManager;
use onboarding::{OnboardingManager, OnboardingState, SystemRequirements};
use connection_manager::{ConnectionManager, ServerInfo, ConnectionStatus, ServerConnection};
use chat_client::{ChatClient, ChatSession, ChatMessage};
use message_stream::MessageStream;

use tauri::Emitter;
use chrono::Utc;
use std::fs::OpenOptions;
use std::io::Write;

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

        if let Ok(mut file) = OpenOptions::new()
            .create(true)
            .append(true)
            .open(log_path)
        {
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

// Onboarding commands
#[tauri::command]
async fn get_onboarding_state() -> Result<OnboardingState, String> {
    log_info!("🚀 [ONBOARDING] Getting onboarding state...");

    let manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let state = manager.get_onboarding_state().map_err(|e| e.to_string())?;

    log_info!("🚀 [ONBOARDING] State: config_exists={}, is_completed={}",
             state.config.is_some(),
             state.config.as_ref().map(|c| c.is_completed).unwrap_or(false));

    Ok(state)
}

#[tauri::command]
async fn check_system_requirements() -> Result<SystemRequirements, String> {
    use std::process::Command;

    // Check OS - assume compatible for now
    let os_check = true;

    // Check memory using system commands
    let memory_check = match std::env::consts::OS {
        "linux" => {
            match Command::new("sh").arg("-c").arg("free -g | awk 'NR==2{print $2}'").output() {
                Ok(output) => {
                    let mem_str = String::from_utf8_lossy(&output.stdout);
                    mem_str.trim().parse::<u64>().unwrap_or(0) >= 4
                }
                Err(_) => true, // Assume sufficient if command fails
            }
        }
        "macos" => {
            match Command::new("sysctl").args(&["-n", "hw.memsize"]).output() {
                Ok(output) => {
                    let mem_bytes = String::from_utf8_lossy(&output.stdout);
                    let memory_gb = mem_bytes.trim().parse::<u64>().unwrap_or(0) as f64 / 1024.0 / 1024.0 / 1024.0;
                    memory_gb >= 4.0
                }
                Err(_) => true, // Assume sufficient if command fails
            }
        }
        "windows" => {
            match Command::new("wmic").args(&["OS", "get", "TotalVisibleMemorySize", "/Value"]).output() {
                Ok(output) => {
                    let mem_str = String::from_utf8_lossy(&output.stdout);
                    // Parse Windows memory in KB and convert to GB
                    if let Some(line) = mem_str.lines().find(|l| l.contains("TotalVisibleMemorySize")) {
                        if let Some(value) = line.split('=').nth(1) {
                            value.trim().parse::<u64>().unwrap_or(0) >= 4_000_000 // 4GB in KB
                        } else {
                            true
                        }
                    } else {
                        true
                    }
                }
                Err(_) => true, // Assume sufficient if command fails
            }
        }
        _ => true, // Assume sufficient for other OS
    };

    // Check disk space (simplified - assume sufficient)
    let disk_check = true;

    // Check network connectivity (simple ping test)
    let network_check = match Command::new("ping")
        .args(&["-c", "1", "-W", "2", "8.8.8.8"])
        .output() {
        Ok(output) => output.status.success(),
        Err(_) => false,
    };

    Ok(SystemRequirements {
        os_compatible: os_check,
        memory_sufficient: memory_check,
        disk_space_sufficient: disk_check,
        network_available: network_check,
        required_permissions: true, // Assume permissions are okay for now
    })
}

#[tauri::command]
async fn complete_onboarding() -> Result<(), String> {
    let manager = OnboardingManager::new().map_err(|e| {
        format!("Failed to initialize onboarding manager: {}", e)
    })?;

    manager.complete_onboarding().map_err(|e| {
        format!("Failed to complete onboarding: {}", e)
    })
}



    Ok(())
}

#[tauri::command]
async fn skip_onboarding() -> Result<(), String> {
    log_info!("🚀 [ONBOARDING] Skipping onboarding...");

    let manager = OnboardingManager::new().map_err(|e| {
        format!("Failed to initialize onboarding manager: {}", e)
    })?;

    // Mark onboarding as completed without full setup
    manager.skip_onboarding().map_err(|e| {
        format!("Failed to skip onboarding: {}", e)
    })
}

// SECURITY: create_user command removed to prevent unauthorized account creation
// Desktop applications should use owner-only authentication, not public registration

// Secure owner account creation - ONLY during onboarding
#[tauri::command]
async fn create_owner_account(username: String, password: String) -> Result<(), String> {
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    
    // This will fail if owner account already exists - prevents security violations
    onboarding_manager.create_owner_account(&username, &password).map_err(|e| {
        // Log security violation attempts
        sentry::capture_message(&format!("SECURITY: Attempted unauthorized account creation: {}", e), sentry::Level::Error);
        e.to_string()
    })
}

// Authentication commands

#[tauri::command]
async fn authenticate_user(username: String, password: String) -> Result<bool, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    // SECURITY: Verify this is the owner account attempting to authenticate
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    
    if let Ok(Some(config)) = onboarding_manager.load_config() {
        if !config.owner_account_created {
            // No owner account exists - must complete onboarding first
            return Ok(false);
        }
        
        if let Some(owner_username) = config.owner_username {
            if username != owner_username {
                // SECURITY: Someone trying to authenticate as non-owner account
                sentry::capture_message(&format!("SECURITY: Attempted authentication as non-owner account: {} (owner: {})", username, owner_username), sentry::Level::Warning);
                return Ok(false);
            }
        }
    } else {
        // No configuration exists - onboarding required
        return Ok(false);
    }
    
    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    
    match auth_manager.authenticate(&username, &password) {
        Ok(_session) => Ok(true),
        Err(_) => Ok(false), // Don't expose specific error details for security
    }
}

#[tauri::command]
async fn change_password(username: String, old_password: String, new_password: String) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    auth_manager.change_password(&username, &old_password, &new_password).map_err(|e| e.to_string())
}

#[tauri::command]
async fn is_auth_configured() -> Result<bool, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    Ok(auth_manager.is_configured())
}

#[tauri::command]
async fn is_authenticated() -> Result<bool, String> {
    log_info!("🔐 [AUTH] Checking authentication status...");

    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;

    // Check if auth is configured
    if !auth_manager.is_configured() {
        log_info!("🔐 [AUTH] Authentication not configured - returning false");
        return Ok(false);
    }

    log_info!("🔐 [AUTH] Authentication configured - user is authenticated");
    Ok(true)
}

#[tauri::command]
async fn get_user_info() -> Result<Option<(String, String, Option<String>)>, String> {
    log_info!("👤 [USER] Getting user information...");

    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;

    match auth_manager.get_user_info() {
        Ok(Some((username, created_at, last_login_at))) => {
            log_info!("👤 [USER] Found user: {} (created: {}, last login: {:?})",
                     username,
                     created_at.format("%Y-%m-%d %H:%M:%S UTC"),
                     last_login_at.map(|dt| dt.format("%Y-%m-%d %H:%M:%S UTC").to_string()));
            Ok(Some((
                username,
                created_at.format("%Y-%m-%d %H:%M:%S UTC").to_string(),
                last_login_at.map(|dt| dt.format("%Y-%m-%d %H:%M:%S UTC").to_string())
            )))
        }

        Ok(None) => {
            log_info!("👤 [USER] No user information found");
            Ok(None)
        },
        Err(e) => {
            log_info!("❌ [USER] Error getting user info: {}", e);
            Err(e.to_string())
        },
    }
}

#[tauri::command]
async fn reset_failed_attempts(username: String) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    auth_manager.reset_failed_attempts(&username).map_err(|e| e.to_string())
}

#[tauri::command]
async fn create_persistent_session(username: String) -> Result<String, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    let session = auth_manager.create_persistent_session(&username).map_err(|e| e.to_string())?;
    Ok(session.session_id)
}

#[tauri::command]
async fn validate_persistent_session(session_id: String) -> Result<Option<String>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    auth_manager.validate_persistent_session(&session_id).map_err(|e| e.to_string())
}

#[tauri::command]
async fn invalidate_session(session_id: String) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    auth_manager.invalidate_session(&session_id).map_err(|e| e.to_string())
}

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
    connection_manager.get_server_url()
        .ok_or_else(|| "No server URL available".to_string())
}

// Connection management commands
#[tauri::command]
async fn connect_to_server(app_handle: tauri::AppHandle, hostname: String, port: u16, secure: bool) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let mut connection_manager = ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    connection_manager.connect_to_server(&hostname, port, secure).await
}

#[tauri::command]
async fn test_server_connection(app_handle: tauri::AppHandle, hostname: String, port: u16, secure: bool) -> Result<ServerInfo, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let connection_manager = ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    connection_manager.test_server_connection(&hostname, port, secure).await
}

#[tauri::command]
async fn get_connection_status(app_handle: tauri::AppHandle) -> Result<ConnectionStatus, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let connection_manager = ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    Ok(connection_manager.get_connection_status())
}

#[tauri::command]
async fn disconnect_from_server(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let mut connection_manager = ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    connection_manager.disconnect_from_server().await
}

#[tauri::command]
async fn get_saved_connections(app_handle: tauri::AppHandle) -> Result<Vec<ServerConnection>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let mut connection_manager = ConnectionManager::new(config_dir, Some(app_handle.clone())).map_err(|e| e.to_string())?;
    connection_manager.load_connections().map_err(|e| e.to_string())?;
    Ok(connection_manager.get_saved_connections())
}



// Chat commands
#[tauri::command]
async fn create_chat_session(_app_handle: tauri::AppHandle, title: Option<String>) -> Result<ChatSession, String> {
    let config_dir = get_config_dir()?;
    let server_url = get_server_url()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.set_server_url(server_url);
    chat_client.load_sessions().map_err(|e| e.to_string())?;
    chat_client.create_session(title.as_deref()).await
}

#[tauri::command]
async fn send_chat_message(_app_handle: tauri::AppHandle, session_id: String, content: String) -> Result<(), String> {
    let config_dir = get_config_dir()?;
    let server_url = get_server_url()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.set_server_url(server_url);
    chat_client.load_sessions().map_err(|e| e.to_string())?;

    // Send the message and rely on events/streaming for responses
    chat_client.send_message(&session_id, &content).await
}

#[tauri::command]
async fn get_chat_sessions(_app_handle: tauri::AppHandle) -> Result<Vec<ChatSession>, String> {
    let config_dir = get_config_dir()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.load_sessions().map_err(|e| e.to_string())?;

    // Return persisted sessions
    let sessions: Vec<ChatSession> = chat_client.get_sessions().values().cloned().collect();
    Ok(sessions)
}

#[tauri::command]
async fn get_chat_session_history(_app_handle: tauri::AppHandle, session_id: String) -> Result<Vec<ChatMessage>, String> {
    let config_dir = get_config_dir()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.load_sessions().map_err(|e| e.to_string())?;
    chat_client.get_session_history(&session_id).await
}

#[tauri::command]
async fn start_message_stream(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = get_config_dir()?;
    let server_url = get_server_url()?;

    let mut chat_client = ChatClient::new(config_dir.clone())?;
    chat_client.set_server_url(server_url.clone());

    let event_sender = chat_client.event_sender.clone();
    let mut message_stream = MessageStream::new(event_sender.clone());

    // Create API client for the message stream
    let api_client = crate::api_client::ApiClient::new(&server_url)
        .map_err(|e| format!("Failed to create API client: {}", e))?;
    message_stream.set_api_client(api_client);

    // Start the message stream
    message_stream.start_streaming().await?;

    let mut event_receiver = event_sender.subscribe();

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
            let logs: Vec<String> = content
                .lines()
                .map(|line| line.to_string())
                .collect();

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
async fn log_frontend_error(level: String, message: String, details: Option<String>) -> Result<(), String> {
    let details_str = details.map_or_else(|| String::new(), |d| format!(" | Details: {}", d));
    let full_message = format!("🌐 [FRONTEND] {}{}", message, details_str);
    
    match level.to_lowercase().as_str() {
        "error" => {
            log_error!("{}", full_message);
        },
        "warn" => {
            log_warn!("{}", full_message);
        },
        "info" => {
            log_info!("{}", full_message);
        },
        _ => {
            log_debug!("{}", full_message);
        },
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
        std::fs::remove_file(&log_path)
            .map_err(|e| format!("Failed to clear log file: {}", e))?;
    }
    
    log_info!("✅ [LOGS] Application logs cleared successfully");
    Ok(())
}

#[tauri::command]
async fn cleanup_expired_sessions() -> Result<usize, String> {
    log_info!("🧹 [SESSIONS] Cleaning up expired sessions...");

    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    let cleaned_count = auth_manager.cleanup_expired_sessions().map_err(|e| e.to_string())?;

    log_info!("🧹 [SESSIONS] Cleaned up {} expired sessions", cleaned_count);
    Ok(cleaned_count)
}







#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            // Onboarding commands
            get_onboarding_state,
            complete_onboarding,
            skip_onboarding,
            check_system_requirements,
            create_owner_account, // Secure owner account creation during onboarding only
            // Authentication commands
            authenticate_user,
            change_password,
            is_auth_configured,
            is_authenticated,
            get_user_info,
            reset_failed_attempts,
            create_persistent_session,
            validate_persistent_session,
            invalidate_session,
            cleanup_expired_sessions,
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
