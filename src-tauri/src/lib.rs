mod onboarding;
mod auth;
mod server_manager;
mod api_client;
mod chat_manager;
mod message_stream;
#[cfg(test)]
mod tests;

use auth::AuthManager;
use onboarding::{OnboardingManager, OnboardingState, SystemRequirements};
use server_manager::{ServerManager, ServerInfo, TunnelConfig, TunnelStatus};
use chat_manager::{ChatManager, ChatSession, ChatMessage, MessageRole};
use message_stream::MessageStream;
use tauri::Emitter;

// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

// Onboarding commands
#[tauri::command]
async fn get_onboarding_state() -> Result<OnboardingState, String> {
    let manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    manager.get_onboarding_state().map_err(|e| e.to_string())
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
async fn complete_onboarding(opencode_server_path: Option<String>) -> Result<(), String> {
    let manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let path = opencode_server_path.map(std::path::PathBuf::from);
    manager.complete_onboarding(path).map_err(|e| e.to_string())
}

// App management commands
#[tauri::command]
async fn get_app_info(app_handle: tauri::AppHandle) -> Result<crate::server_manager::AppInfo, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;

            server_manager.get_app_info().await.map_err(|e| {
                let err = anyhow::anyhow!("Failed to get app info: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn initialize_app(app_handle: tauri::AppHandle) -> Result<bool, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;

            server_manager.initialize_app().await.map_err(|e| {
                let err = anyhow::anyhow!("Failed to initialize app: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_server_metrics(app_handle: tauri::AppHandle) -> Result<crate::server_manager::ServerMetrics, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;

            // For now, return stubbed metrics - will be replaced with real API data in Phase 3
            Ok(crate::server_manager::ServerMetrics {
                cpu_usage: 15.5, // Placeholder - will be replaced with real API data
                memory_usage: 1024 * 1024 * 256, // 256MB placeholder
                uptime: std::time::Duration::from_secs(3600), // 1 hour placeholder
                request_count: 150, // Placeholder
                error_count: 2, // Placeholder
            })
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
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
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;

    // Check if auth is configured and if there's a valid persistent session
    if !auth_manager.is_configured() {
        return Ok(false);
    }

    // For now, just check if auth is configured - persistent sessions can be added later
    // TODO: Check for valid persistent session when session management is fully implemented
    Ok(true)
}

#[tauri::command]
async fn get_user_info() -> Result<Option<(String, String, Option<String>)>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    
    match auth_manager.get_user_info() {
        Ok(Some((username, created_at, last_login_at))) => {
            Ok(Some((
                username,
                created_at.format("%Y-%m-%d %H:%M:%S UTC").to_string(),
                last_login_at.map(|dt| dt.format("%Y-%m-%d %H:%M:%S UTC").to_string())
            )))
        }
        Ok(None) => Ok(None),
        Err(e) => Err(e.to_string()),
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

#[tauri::command]
async fn cleanup_expired_sessions() -> Result<usize, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    auth_manager.cleanup_expired_sessions().map_err(|e| e.to_string())
}

// Server management commands
#[tauri::command]
async fn get_server_info(app_handle: tauri::AppHandle) -> Result<ServerInfo, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;
    
    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;
            Ok(server_manager.get_server_info())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn start_opencode_server(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;
            server_manager.start_server().await.map_err(|e| {
                let err = anyhow::anyhow!("Failed to start OpenCode server: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })
        } else {
            let err = anyhow::anyhow!("OpenCode server path not configured");
            sentry::capture_message(&format!("{}", err), sentry::Level::Error);
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        let err = anyhow::anyhow!("Onboarding not completed");
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn stop_opencode_server(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;
            server_manager.stop_server().await.map_err(|e| {
                let err = anyhow::anyhow!("Failed to stop OpenCode server: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })
        } else {
            let err = anyhow::anyhow!("OpenCode server path not configured");
            sentry::capture_message(&format!("{}", err), sentry::Level::Error);
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        let err = anyhow::anyhow!("Onboarding not completed");
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn restart_opencode_server(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;
            server_manager.restart_server().await.map_err(|e| {
                let err = anyhow::anyhow!("Failed to restart OpenCode server: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })
        } else {
            let err = anyhow::anyhow!("OpenCode server path not configured");
            sentry::capture_message(&format!("{}", err), sentry::Level::Error);
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        let err = anyhow::anyhow!("Onboarding not completed");
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn update_server_config(app_handle: tauri::AppHandle, port: Option<u16>, host: Option<String>) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path, None).map_err(|e| e.to_string())?;
            server_manager.update_server_config(port, host).map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_active_sessions(app_handle: tauri::AppHandle) -> Result<Vec<crate::server_manager::OpenCodeSession>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, None).map_err(|e| e.to_string())?;
            server_manager.get_active_sessions().await.map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn disconnect_session(app_handle: tauri::AppHandle, session_id: String) -> Result<bool, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, None).map_err(|e| e.to_string())?;
            server_manager.disconnect_session(&session_id).await.map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_session_stats(app_handle: tauri::AppHandle) -> Result<crate::server_manager::SessionStats, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, None).map_err(|e| e.to_string())?;
            server_manager.get_session_stats().await.map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

// Chat commands
#[tauri::command]
async fn create_chat_session(app_handle: tauri::AppHandle, title: Option<String>) -> Result<ChatSession, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir.clone(), binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;

            // Get API client from server manager
            if let Some(api_client) = &server_manager.api_client {
                let mut chat_manager = ChatManager::new(config_dir.clone());
                chat_manager.set_api_client(api_client.clone());
                chat_manager.create_session(title.as_deref()).await
            } else {
                Err("Server not running or API client not available".to_string())
            }
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn send_chat_message(app_handle: tauri::AppHandle, session_id: String, content: String) -> Result<ChatMessage, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir.clone(), binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;

            // Get API client from server manager
            if let Some(api_client) = &server_manager.api_client {
                let mut chat_manager = ChatManager::new(config_dir.clone());
                chat_manager.set_api_client(api_client.clone());
                chat_manager.send_message(&session_id, &content).await
            } else {
                Err("Server not running or API client not available".to_string())
            }
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_chat_sessions(app_handle: tauri::AppHandle) -> Result<Vec<ChatSession>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir.clone(), binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;

            // Get API client from server manager
            if let Some(api_client) = &server_manager.api_client {
                let mut chat_manager = ChatManager::new(config_dir.clone());
                chat_manager.set_api_client(api_client.clone());

                // Load persisted sessions first
                if let Err(e) = chat_manager.load_sessions() {
                    eprintln!("Warning: Failed to load persisted sessions: {}", e);
                }

                // If no persisted sessions, try to fetch from server
                if chat_manager.get_sessions().is_empty() {
                    // Fetch sessions from OpenCode server API
                    let sessions: Vec<ChatSession> = api_client
                        .get("/session")
                        .await
                        .map_err(|e| format!("Failed to fetch sessions: {}", e))?;

                    // Store fetched sessions
                    for session in &sessions {
                        chat_manager.get_sessions_mut().insert(session.id.clone(), session.clone());
                    }

                    // Persist them
                    if let Err(e) = chat_manager.save_sessions() {
                        eprintln!("Warning: Failed to persist fetched sessions: {}", e);
                    }

                    Ok(sessions)
                } else {
                    // Return persisted sessions
                    let sessions: Vec<ChatSession> = chat_manager.get_sessions().values().cloned().collect();
                    Ok(sessions)
                }
            } else {
                Err("Server not running or API client not available".to_string())
            }
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_chat_session_history(app_handle: tauri::AppHandle, session_id: String) -> Result<Vec<ChatMessage>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir.clone(), binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;

            // Get API client from server manager
            if let Some(api_client) = &server_manager.api_client {
                let mut chat_manager = ChatManager::new(config_dir.clone());
                chat_manager.set_api_client(api_client.clone());
                chat_manager.get_session_history(&session_id).await
            } else {
                Err("Server not running or API client not available".to_string())
            }
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn start_message_stream(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir.clone(), binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;

            // Get API client from server manager
            if let Some(api_client) = &server_manager.api_client {
                let mut chat_manager = ChatManager::new(config_dir.clone());
                chat_manager.set_api_client(api_client.clone());

                let event_sender = chat_manager.event_sender.clone();
                let mut message_stream = MessageStream::new(event_sender);
                message_stream.set_api_client(api_client.clone());

                // Start streaming and set up event forwarding to Tauri frontend
                message_stream.start_streaming().await?;

                // Set up event forwarding from broadcast channel to Tauri events
                let mut event_receiver = chat_manager.event_sender.subscribe();
                let app_handle_clone = app_handle.clone();

                tokio::spawn(async move {
                    while let Ok(chat_event) = event_receiver.recv().await {
                        let _ = app_handle_clone.emit("chat-event", &chat_event);
                    }
                });

                Ok(())
            } else {
                Err("Server not running or API client not available".to_string())
            }
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

// Tunnel management commands
#[tauri::command]
async fn start_cloudflared_tunnel(app_handle: tauri::AppHandle, config: TunnelConfig) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(onboarding_config) = onboarding_state.config {
        if let Some(binary_path) = onboarding_config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;

            server_manager.start_cloudflared_tunnel(&config).await.map_err(|e| {
                let err = anyhow::anyhow!("Failed to start Cloudflared tunnel: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })
        } else {
            let err = anyhow::anyhow!("OpenCode server path not configured");
            sentry::capture_message(&format!("{}", err), sentry::Level::Error);
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        let err = anyhow::anyhow!("Onboarding not completed");
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn stop_cloudflared_tunnel(app_handle: tauri::AppHandle) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| {
        let err = anyhow::anyhow!("Failed to create onboarding manager: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| {
        let err = anyhow::anyhow!("Failed to get onboarding state: {}", e);
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        e.to_string()
    })?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| {
                let err = anyhow::anyhow!("Failed to create server manager: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })?;

            server_manager.stop_cloudflared_tunnel().map_err(|e| {
                let err = anyhow::anyhow!("Failed to stop Cloudflared tunnel: {}", e);
                sentry::capture_message(&format!("{}", err), sentry::Level::Error);
                e.to_string()
            })
        } else {
            let err = anyhow::anyhow!("OpenCode server path not configured");
            sentry::capture_message(&format!("{}", err), sentry::Level::Error);
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        let err = anyhow::anyhow!("Onboarding not completed");
        sentry::capture_message(&format!("{}", err), sentry::Level::Error);
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_tunnel_status(app_handle: tauri::AppHandle) -> Result<TunnelStatus, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;
            Ok(server_manager.get_tunnel_status())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn update_tunnel_config(app_handle: tauri::AppHandle, config: TunnelConfig) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(onboarding_config) = onboarding_state.config {
        if let Some(binary_path) = onboarding_config.opencode_server_path {
            let mut server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;
            server_manager.update_tunnel_config(config).map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_tunnel_config(app_handle: tauri::AppHandle) -> Result<Option<TunnelConfig>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;
            Ok(server_manager.get_tunnel_config())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn get_tunnel_url(app_handle: tauri::AppHandle) -> Result<Option<String>, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");

    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;

    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path, Some(app_handle.clone())).map_err(|e| e.to_string())?;
            Ok(server_manager.get_tunnel_url())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            get_onboarding_state,
            complete_onboarding,
            check_system_requirements,
            get_app_info,
            get_server_metrics,
            // create_user removed for security - no public registration in desktop app
            create_owner_account, // Secure owner account creation during onboarding only
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
            get_server_info,
            start_opencode_server,
            stop_opencode_server,
            restart_opencode_server,
            update_server_config,
            get_active_sessions,
            disconnect_session,
            get_session_stats,
            create_chat_session,
            send_chat_message,
            get_chat_sessions,
            get_chat_session_history,
            start_message_stream,
            start_cloudflared_tunnel,
            stop_cloudflared_tunnel,
            get_tunnel_status,
            update_tunnel_config,
            get_tunnel_config,
            get_tunnel_url
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
