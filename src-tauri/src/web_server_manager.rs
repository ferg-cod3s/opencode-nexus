use anyhow::{anyhow, Result};
use axum::{
    extract::State,
    http::{Method, StatusCode},
    middleware::{self, Next},
    response::{Json, Response},
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use tokio::net::TcpListener;
use tokio::sync::broadcast;
use tower::ServiceBuilder;
use tower_http::cors::{CorsLayer, Any};
use tower_http::services::ServeDir;

use crate::auth::AuthManager;
// use crate::server_manager::ServerManager; // TODO: Update for client architecture

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum WebServerStatus {
    Stopped,
    Starting,
    Running,
    Stopping,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebServerConfig {
    pub enabled: bool,
    pub port: u16,
    pub host: String,
    pub cors_origins: Vec<String>,
    pub serve_frontend: bool,
    pub frontend_dist_path: Option<PathBuf>,
}

impl Default for WebServerConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            port: 3000,
            host: "0.0.0.0".to_string(), // Allow external access for web/mobile
            cors_origins: vec!["*".to_string()], // Default to allow all origins for development
            serve_frontend: true,
            frontend_dist_path: None, // Will be set to ../frontend/dist by default
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebServerInfo {
    pub status: WebServerStatus,
    pub port: u16,
    pub host: String,
    pub started_at: Option<u64>,
    pub last_error: Option<String>,
    pub config: WebServerConfig,
}

#[derive(Clone)]
pub struct AppState {
    pub auth_manager: Arc<Mutex<AuthManager>>,
    // pub server_manager: Arc<Mutex<ServerManager>>, // TODO: Update for client architecture
}

#[derive(Debug, Clone, Serialize)]
pub struct WebServerEvent {
    pub timestamp: SystemTime,
    pub event_type: WebServerEventType,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub enum WebServerEventType {
    Started,
    Stopped,
    Error,
    ConfigChanged,
    RequestProcessed,
}

pub struct WebServerManager {
    config: Arc<Mutex<WebServerConfig>>,
    server_info: Arc<Mutex<WebServerInfo>>,
    server_handle: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
    event_sender: broadcast::Sender<WebServerEvent>,
    app_state: AppState,
}

impl WebServerManager {
    pub fn new(
        auth_manager: Arc<Mutex<AuthManager>>,
        // server_manager: Arc<Mutex<ServerManager>>, // TODO: Update for client architecture
    ) -> Result<Self> {
        let (event_sender, _) = broadcast::channel(100);
        let config = WebServerConfig::default();
        
        let server_info = WebServerInfo {
            status: WebServerStatus::Stopped,
            port: config.port,
            host: config.host.clone(),
            started_at: None,
            last_error: None,
            config: config.clone(),
        };

        let app_state = AppState {
            auth_manager: auth_manager.clone(),
            // server_manager: server_manager.clone(), // TODO: Update for client architecture
        };

        Ok(Self {
            config: Arc::new(Mutex::new(config)),
            server_info: Arc::new(Mutex::new(server_info)),
            server_handle: Arc::new(Mutex::new(None)),
            event_sender,
            app_state,
        })
    }

    pub fn get_server_info(&self) -> WebServerInfo {
        self.server_info.lock().unwrap().clone()
    }

    pub fn is_running(&self) -> bool {
        matches!(self.get_server_info().status, WebServerStatus::Running)
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<WebServerEvent> {
        self.event_sender.subscribe()
    }

    pub async fn start_server(&mut self) -> Result<()> {
        // Check if already running
        {
            let mut server_info = self.server_info.lock().unwrap();
            if matches!(server_info.status, WebServerStatus::Running | WebServerStatus::Starting) {
                return Err(anyhow!("Web server is already running or starting"));
            }
            server_info.status = WebServerStatus::Starting;
        }

        let config = self.config.lock().unwrap().clone();
        let app_state = self.app_state.clone();
        let event_sender = self.event_sender.clone();
        let server_info = self.server_info.clone();

        // Create the Axum app
        let app = self.create_app(app_state.clone()).await?;

        // Create listener
        let addr = format!("{}:{}", config.host, config.port);
        let listener = TcpListener::bind(&addr).await
            .map_err(|e| anyhow!("Failed to bind to {}: {}", addr, e))?;

        // Get the actual bound address in case port was 0
        let actual_addr = listener.local_addr()
            .map_err(|e| anyhow!("Failed to get local address: {}", e))?;

        // Update server info with actual port
        {
            let mut info = server_info.lock().unwrap();
            info.port = actual_addr.port();
            info.started_at = Some(SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
            info.status = WebServerStatus::Running;
        }

        // Start the server in a background task
        let server_handle = tokio::spawn(async move {
            if let Err(e) = axum::serve(listener, app).await {
                let _ = event_sender.send(WebServerEvent {
                    timestamp: SystemTime::now(),
                    event_type: WebServerEventType::Error,
                    message: format!("Web server error: {}", e),
                });
                
                let mut info = server_info.lock().unwrap();
                info.status = WebServerStatus::Error;
                info.last_error = Some(e.to_string());
            }
        });

        // Store server handle
        *self.server_handle.lock().unwrap() = Some(server_handle);

        // Emit started event
        let _ = self.event_sender.send(WebServerEvent {
            timestamp: SystemTime::now(),
            event_type: WebServerEventType::Started,
            message: format!("Web server started on {}", actual_addr),
        });

        Ok(())
    }

    pub async fn stop_server(&mut self) -> Result<()> {
        let mut server_handle = self.server_handle.lock().unwrap();
        
        {
            let mut server_info = self.server_info.lock().unwrap();
            server_info.status = WebServerStatus::Stopping;
        }

        if let Some(handle) = server_handle.take() {
            handle.abort();
            
            // Wait a bit for graceful shutdown
            tokio::time::sleep(Duration::from_millis(100)).await;
        }

        // Update status
        {
            let mut server_info = self.server_info.lock().unwrap();
            server_info.status = WebServerStatus::Stopped;
            server_info.started_at = None;
        }

        // Emit stopped event
        let _ = self.event_sender.send(WebServerEvent {
            timestamp: SystemTime::now(),
            event_type: WebServerEventType::Stopped,
            message: "Web server stopped".to_string(),
        });

        Ok(())
    }

    async fn create_app(&self, app_state: AppState) -> Result<Router> {
        let config = self.config.lock().unwrap().clone();

        // Create CORS layer
        let cors = CorsLayer::new()
            .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE, Method::OPTIONS])
            .allow_headers(Any)
            .allow_origin(Any); // TODO: Configure properly based on config.cors_origins

        // Create the main API router
        let api_router = Router::new()
            // .route("/server/status", get(get_server_status)) // TODO: Update for client architecture
            // TODO: Fix async handler issues for server control endpoints
            // .route("/server/start", post(start_server_endpoint))
            // .route("/server/stop", post(stop_server_endpoint))
            .route("/auth/login", post(login_endpoint))
            .route("/auth/logout", post(logout_endpoint))
            .route("/auth/status", get(auth_status_endpoint))
            .layer(middleware::from_fn_with_state(app_state.clone(), auth_middleware))
            .with_state(app_state.clone());

        let mut app = Router::new()
            .nest("/api", api_router)
            .layer(
                ServiceBuilder::new()
                    .layer(cors)
                    .layer(middleware::from_fn(logging_middleware))
                    .into_inner()
            );

        // Add static file serving if enabled
        if config.serve_frontend {
            if let Some(dist_path) = &config.frontend_dist_path {
                if dist_path.exists() {
                    app = app.nest_service("/", ServeDir::new(dist_path));
                }
            } else {
                // Default path relative to src-tauri directory
                let default_dist = PathBuf::from("../frontend/dist");
                if default_dist.exists() {
                    app = app.nest_service("/", ServeDir::new(default_dist));
                }
            }
        }

        Ok(app)
    }

    pub fn update_config(&mut self, new_config: WebServerConfig) -> Result<()> {
        if self.is_running() {
            return Err(anyhow!("Cannot update config while server is running"));
        }

        *self.config.lock().unwrap() = new_config.clone();
        
        // Update server info
        {
            let mut info = self.server_info.lock().unwrap();
            info.config = new_config;
            info.port = info.config.port;
            info.host = info.config.host.clone();
        }

        // Emit config changed event
        let _ = self.event_sender.send(WebServerEvent {
            timestamp: SystemTime::now(),
            event_type: WebServerEventType::ConfigChanged,
            message: "Web server configuration updated".to_string(),
        });

        Ok(())
    }
}

// Middleware functions
async fn logging_middleware(
    request: axum::http::Request<axum::body::Body>,
    next: Next,
) -> Response {
    let method = request.method().clone();
    let uri = request.uri().clone();
    
    let response = next.run(request).await;
    
    println!("[{}] {} {}", 
        chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        method,
        uri
    );
    
    response
}

async fn auth_middleware(
    State(_app_state): State<AppState>,
    request: axum::http::Request<axum::body::Body>,
    next: Next,
) -> Response {
    // Skip auth for certain endpoints
    let path = request.uri().path();
    if path == "/api/auth/login" || path.starts_with("/api/auth/") {
        return next.run(request).await;
    }

    // TODO: Implement JWT token validation here
    // For now, just pass through
    next.run(request).await
}

// API endpoint handlers
// TODO: Update for client architecture - these endpoints depend on server_manager
/*
async fn get_server_status(State(app_state): State<AppState>) -> impl axum::response::IntoResponse {
    let server_manager = app_state.server_manager.lock().unwrap();
    let server_info = server_manager.get_server_info();
    Json(serde_json::to_value(server_info).unwrap())
}

async fn start_server_endpoint(State(app_state): State<AppState>) -> impl axum::response::IntoResponse {
    let mut server_manager = app_state.server_manager.lock().unwrap();
    match server_manager.start_server().await {
        Ok(_) => (StatusCode::OK, Json(serde_json::json!({"success": true}))),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))),
    }
}

async fn stop_server_endpoint(State(app_state): State<AppState>) -> impl axum::response::IntoResponse {
    let server_manager = app_state.server_manager.lock().unwrap();
    match server_manager.stop_server().await {
        Ok(_) => (StatusCode::OK, Json(serde_json::json!({"success": true}))),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))),
    }
}
*/

#[derive(Deserialize)]
struct LoginRequest {
    username: String,
    password: String,
}

async fn login_endpoint(
    State(app_state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> impl axum::response::IntoResponse {
    let auth_manager = app_state.auth_manager.lock().unwrap();

    match auth_manager.authenticate(&payload.username, &payload.password) {
        Ok(session_id) => {
            // TODO: Generate JWT token instead of session ID
            (StatusCode::OK, Json(serde_json::json!({
                "success": true,
                "session_id": session_id
            })))
        },
        Err(e) => {
            (StatusCode::UNAUTHORIZED, Json(serde_json::json!({
                "success": false,
                "error": e.to_string()
            })))
        }
    }
}

async fn logout_endpoint(State(_app_state): State<AppState>) -> impl axum::response::IntoResponse {
    // TODO: Implement logout functionality
    (StatusCode::OK, Json(serde_json::json!({"success": true})))
}

async fn auth_status_endpoint(State(_app_state): State<AppState>) -> impl axum::response::IntoResponse {
    // TODO: Check auth status based on JWT token
    (StatusCode::OK, Json(serde_json::json!({"authenticated": false})))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::AuthManager;
    use std::path::PathBuf;
    use tempfile::TempDir;

    // TODO: Update tests for client architecture
    /*
    #[tokio::test]
    async fn test_web_server_manager_creation() {
        let temp_dir = TempDir::new().unwrap();
        let auth_manager = Arc::new(Mutex::new(
            AuthManager::new(temp_dir.path().to_path_buf()).unwrap()
        ));

        // Create a mock ServerManager - this would need proper implementation
        let server_binary = temp_dir.path().join("opencode");
        std::fs::write(&server_binary, "").unwrap(); // Create empty file
        let server_manager = Arc::new(Mutex::new(
            crate::server_manager::ServerManager::new(
                temp_dir.path().to_path_buf(),
                server_binary,
                None
            ).unwrap()
        ));

        let web_manager = WebServerManager::new(auth_manager, server_manager);
        assert!(web_manager.is_ok());

        let manager = web_manager.unwrap();
        assert!(!manager.is_running());
        assert_eq!(manager.get_server_info().status, WebServerStatus::Stopped);
    }

    #[tokio::test]
    async fn test_web_server_config_update() {
        let temp_dir = TempDir::new().unwrap();
        let auth_manager = Arc::new(Mutex::new(
            AuthManager::new(temp_dir.path().to_path_buf()).unwrap()
        ));

        let server_binary = temp_dir.path().join("opencode");
        std::fs::write(&server_binary, "").unwrap();
        let server_manager = Arc::new(Mutex::new(
            crate::server_manager::ServerManager::new(
                temp_dir.path().to_path_buf(),
                server_binary,
                None
            ).unwrap()
        ));

        let mut manager = WebServerManager::new(auth_manager, server_manager).unwrap();
        
        let mut new_config = WebServerConfig::default();
        new_config.port = 8080;
        new_config.host = "127.0.0.1".to_string();

        let result = manager.update_config(new_config);
        assert!(result.is_ok());

        let info = manager.get_server_info();
        assert_eq!(info.port, 8080);
        assert_eq!(info.host, "127.0.0.1");
    }
    */
}