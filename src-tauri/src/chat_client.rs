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

use crate::connection_manager::ConnectionManager;
use crate::error::{AppError, RetryConfig};
use chrono::Utc;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use tokio::sync::broadcast;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id: String,
    pub role: String,
    pub content: String,
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatSession {
    pub id: String,
    pub title: Option<String>,
    pub created_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub messages: Option<Vec<ChatMessage>>,
}

#[derive(Debug, Clone)]
pub enum ChatEvent {
    MessageReceived {
        session_id: String,
        message: ChatMessage,
    },
    MessageChunk {
        session_id: String,
        chunk: String,
    },
    SessionCreated {
        session: ChatSession,
    },
    Error {
        message: String,
    },
}

pub struct ChatClient {
    config_dir: PathBuf,
    client: Client,
    server_url: Arc<Mutex<Option<String>>>,
    event_sender: broadcast::Sender<ChatEvent>,
    connection_manager: Arc<Mutex<Option<ConnectionManager>>>,
}

impl ChatClient {
    pub fn new(config_dir: PathBuf) -> Result<Self, Box<dyn std::error::Error>> {
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

        let (event_sender, _) = broadcast::channel(100);

        Ok(Self {
            config_dir,
            client,
            server_url: Arc::new(Mutex::new(None)),
            event_sender,
            connection_manager: Arc::new(Mutex::new(None)),
        })
    }

    pub fn set_server_url(&self, url: String) -> Result<(), Box<dyn std::error::Error>> {
        *self.server_url.lock().unwrap() = Some(url.clone());

        // Update connection manager if it exists
        if let Some(conn_manager) = self.connection_manager.lock().unwrap().as_mut() {
            // Parse URL to get hostname and port
            if let Ok(parsed_url) = url::Url::parse(&url) {
                let hostname = parsed_url.host_str().unwrap_or("localhost").to_string();
                let port = parsed_url.port().unwrap_or(80);
                let secure = parsed_url.scheme() == "https";

                // Use connection manager to establish connection
                let rt = tokio::runtime::Runtime::new()?;
                rt.block_on(async {
                    conn_manager
                        .connect_to_server(&hostname, port as u16, secure)
                        .await
                })?;
            }
        }

        Ok(())
    }

    pub async fn list_sessions(&self) -> Result<Vec<ChatSession>, Box<dyn std::error::Error>> {
        let server_url = self.get_server_url()?;

        let response = self
            .client
            .get(&format!("{}/session", server_url))
            .send()
            .await
            .map_err(|e| AppError::NetworkError {
                message: format!("Failed to fetch sessions: {}", e),
                details: e.to_string(),
                retry_after: Some(2),
            })?;

        if !response.status().is_success() {
            return Err(AppError::ServerError {
                status_code: response.status().as_u16(),
                message: format!("Server responded with status: {}", response.status()),
                details: response.text().await.unwrap_or_default(),
            }
            .into());
        }

        let sessions: Vec<ChatSession> =
            response.json().await.map_err(|e| AppError::DataError {
                message: format!("Failed to parse sessions: {}", e),
                details: e.to_string(),
            })?;

        Ok(sessions)
    }

    pub async fn create_session(
        &self,
        title: Option<String>,
    ) -> Result<ChatSession, Box<dyn std::error::Error>> {
        let server_url = self.get_server_url()?;

        let mut params = HashMap::new();
        if let Some(t) = title {
            params.insert("title".to_string(), t);
        }

        let response = self
            .client
            .post(&format!("{}/session", server_url))
            .json(&params)
            .send()
            .await
            .map_err(|e| AppError::NetworkError {
                message: format!("Failed to create session: {}", e),
                details: e.to_string(),
                retry_after: Some(2),
            })?;

        if !response.status().is_success() {
            return Err(AppError::ServerError {
                status_code: response.status().as_u16(),
                message: format!("Server responded with status: {}", response.status()),
                details: response.text().await.unwrap_or_default(),
            }
            .into());
        }

        let session: ChatSession = response.json().await.map_err(|e| AppError::ParseError {
            message: format!("Failed to parse session: {}", e),
            details: Some(e.to_string()),
        })?;

        // Emit session created event
        let _ = self.event_sender.send(ChatEvent::SessionCreated {
            session: session.clone(),
        });

        Ok(session)
    }

    pub async fn send_message(
        &self,
        session_id: &str,
        content: &str,
    ) -> Result<ChatMessage, Box<dyn std::error::Error>> {
        let server_url = self.get_server_url()?;

        let mut params = HashMap::new();
        params.insert("content".to_string(), content.to_string());

        let response = self
            .client
            .post(&format!("{}/session/{}/message", server_url, session_id))
            .json(&params)
            .send()
            .await
            .map_err(|e| AppError::NetworkError {
                message: format!("Failed to send message: {}", e),
                details: e.to_string(),
                retry_after: Some(2),
            })?;

        if !response.status().is_success() {
            return Err(AppError::ServerError {
                status_code: response.status().as_u16(),
                message: format!("Server responded with status: {}", response.status()),
                details: response.text().await.unwrap_or_default(),
            }
            .into());
        }

        let message: ChatMessage = response.json().await.map_err(|e| AppError::DataError {
            message: format!("Failed to parse message: {}", e),
            details: e.to_string(),
        })?;

        // Emit message received event
        let _ = self.event_sender.send(ChatEvent::MessageReceived {
            session_id: session_id.to_string(),
            message: message.clone(),
        });

        Ok(message)
    }

    pub async fn get_session_messages(
        &self,
        session_id: &str,
    ) -> Result<Vec<ChatMessage>, Box<dyn std::error::Error>> {
        let server_url = self.get_server_url()?;

        let response = self
            .client
            .get(&format!("{}/session/{}/messages", server_url, session_id))
            .send()
            .await
            .map_err(|e| AppError::NetworkError {
                message: format!("Failed to fetch session messages: {}", e),
                details: e.to_string(),
                retry_after: Some(2),
            })?;

        if !response.status().is_success() {
            return Err(AppError::ServerError {
                status_code: response.status().as_u16(),
                message: format!("Server responded with status: {}", response.status()),
                details: response.text().await.unwrap_or_default(),
            }
            .into());
        }

        let messages: Vec<ChatMessage> =
            response.json().await.map_err(|e| AppError::DataError {
                message: format!("Failed to parse messages: {}", e),
                details: e.to_string(),
            })?;

        Ok(messages)
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<ChatEvent> {
        self.event_sender.subscribe()
    }

    fn get_server_url(&self) -> Result<String, Box<dyn std::error::Error>> {
        self.server_url.lock().unwrap().clone().ok_or_else(|| {
            AppError::ConnectionError {
                message: "No server URL configured".to_string(),
                details: None,
            }
            .into()
        })
    }

    pub fn load_sessions(&self) -> Result<(), Box<dyn std::error::Error>> {
        let sessions_file = self.config_dir.join("chat_sessions.json");

        if !sessions_file.exists() {
            return Ok(());
        }

        let sessions_json =
            std::fs::read_to_string(&sessions_file).map_err(|e| AppError::IoError {
                message: format!("Failed to read sessions file: {}", e),
                details: Some(e.to_string()),
            })?;

        let _sessions: Vec<ChatSession> =
            serde_json::from_str(&sessions_json).map_err(|e| AppError::ParseError {
                message: format!("Failed to parse sessions file: {}", e),
                details: Some(e.to_string()),
            })?;

        Ok(())
    }

    pub fn save_sessions(
        &self,
        sessions: &[ChatSession],
    ) -> Result<(), Box<dyn std::error::Error>> {
        let sessions_file = self.config_dir.join("chat_sessions.json");

        let sessions_json =
            serde_json::to_string_pretty(sessions).map_err(|e| AppError::ParseError {
                message: format!("Failed to serialize sessions: {}", e),
                details: Some(e.to_string()),
            })?;

        std::fs::write(sessions_file, sessions_json).map_err(|e| AppError::IoError {
            message: format!("Failed to write sessions file: {}", e),
            details: Some(e.to_string()),
        })?;

        Ok(())
    }
}
