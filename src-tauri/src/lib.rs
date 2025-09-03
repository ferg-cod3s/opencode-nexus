mod onboarding;
mod auth;
mod server_manager;

use auth::AuthManager;
use onboarding::{OnboardingManager, OnboardingState};
use server_manager::{ServerManager, ServerInfo};

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
async fn complete_onboarding(opencode_server_path: Option<String>) -> Result<(), String> {
    let manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let path = opencode_server_path.map(std::path::PathBuf::from);
    manager.complete_onboarding(path).map_err(|e| e.to_string())
}

// Authentication commands
#[tauri::command]
async fn create_user(username: String, password: String) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let auth_manager = AuthManager::new(config_dir).map_err(|e| e.to_string())?;
    auth_manager.create_user(&username, &password).map_err(|e| e.to_string())
}

#[tauri::command]
async fn authenticate_user(username: String, password: String) -> Result<bool, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
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

// Server management commands
#[tauri::command]
async fn get_server_info() -> Result<ServerInfo, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;
    
    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path).map_err(|e| e.to_string())?;
            Ok(server_manager.get_server_info())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn start_opencode_server() -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;
    
    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path).map_err(|e| e.to_string())?;
            server_manager.start_server().await.map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn stop_opencode_server() -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;
    
    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path).map_err(|e| e.to_string())?;
            server_manager.stop_server().await.map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn restart_opencode_server() -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;
    
    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path).map_err(|e| e.to_string())?;
            server_manager.restart_server().await.map_err(|e| e.to_string())
        } else {
            Err("OpenCode server path not configured".to_string())
        }
    } else {
        Err("Onboarding not completed".to_string())
    }
}

#[tauri::command]
async fn update_server_config(port: Option<u16>, host: Option<String>) -> Result<(), String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
    
    let onboarding_manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let onboarding_state = onboarding_manager.get_onboarding_state().map_err(|e| e.to_string())?;
    
    if let Some(config) = onboarding_state.config {
        if let Some(binary_path) = config.opencode_server_path {
            let server_manager = ServerManager::new(config_dir, binary_path).map_err(|e| e.to_string())?;
            server_manager.update_server_config(port, host).map_err(|e| e.to_string())
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
            create_user,
            authenticate_user,
            change_password,
            is_auth_configured,
            get_user_info,
            reset_failed_attempts,
            get_server_info,
            start_opencode_server,
            stop_opencode_server,
            restart_opencode_server,
            update_server_config
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
