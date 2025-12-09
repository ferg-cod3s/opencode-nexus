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

use crate::api_client::{ApiClient, ModelConfig};
use crate::error::{AppError, RetryConfig};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tokio::sync::RwLock;
use uuid::Uuid;

/// Message role in a chat session
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MessageRole {
    User,
    Assistant,
    System,
    Tool,
}

/// A single message in a chat session
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id: String,
    pub role: MessageRole,
    pub content: String,
    pub timestamp: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<HashMap<String, serde_json::Value>>,
}

/// A chat session containing messages and metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatSession {
    pub id: String,
    pub title: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub messages: Vec<ChatMessage>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model_config: Option<ModelConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<HashMap<String, serde_json::Value>>,
}

/// Request to create a new session
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSessionRequest {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model_config: Option<ModelConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub system_prompt: Option<String>,
}

/// Request to send a message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendMessageRequest {
    pub content: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model_config: Option<ModelConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stream: Option<bool>,
}

/// Response from sending a message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendMessageResponse {
    pub message: ChatMessage,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub session_id: Option<String>,
}

/// Session manager for handling chat sessions
pub struct SessionManager {
    api_client: Arc<ApiClient>,
    config_dir: PathBuf,
    sessions: Arc<RwLock<HashMap<String, ChatSession>>>,
    current_session_id: Arc<RwLock<Option<String>>>,
}

impl SessionManager {
    /// Create a new session manager
    pub fn new(api_client: Arc<ApiClient>, config_dir: PathBuf) -> Self {
        Self {
            api_client,
            config_dir,
            sessions: Arc::new(RwLock::new(HashMap::new())),
            current_session_id: Arc::new(RwLock::new(None)),
        }
    }

    /// Get the sessions file path
    fn get_sessions_file_path(&self) -> PathBuf {
        self.config_dir.join("chat_sessions.json")
    }

    /// Load sessions from disk
    pub async fn load_sessions(&self) -> Result<(), Box<dyn std::error::Error>> {
        let sessions_file = self.get_sessions_file_path();

        if !sessions_file.exists() {
            return Ok(());
        }

        let sessions_json =
            std::fs::read_to_string(&sessions_file).map_err(|e| AppError::FileSystemError {
                path: sessions_file.to_string_lossy().to_string(),
                message: "Failed to read sessions file".to_string(),
                details: e.to_string(),
            })?;

        let loaded_sessions: HashMap<String, ChatSession> = serde_json::from_str(&sessions_json)
            .map_err(|e| AppError::ParseError {
                message: "Failed to parse sessions file".to_string(),
                details: Some(e.to_string()),
            })?;

        let mut sessions = self.sessions.write().await;
        *sessions = loaded_sessions;

        Ok(())
    }

    /// Save sessions to disk
    pub async fn save_sessions(&self) -> Result<(), Box<dyn std::error::Error>> {
        let sessions = self.sessions.read().await;
        let sessions_json =
            serde_json::to_string_pretty(&*sessions).map_err(|e| AppError::ParseError {
                message: "Failed to serialize sessions".to_string(),
                details: Some(e.to_string()),
            })?;

        std::fs::write(self.get_sessions_file_path(), sessions_json).map_err(|e| {
            AppError::FileSystemError {
                path: self.get_sessions_file_path().to_string_lossy().to_string(),
                message: "Failed to write sessions file".to_string(),
                details: e.to_string(),
            }
        })?;

        Ok(())
    }

    /// List all sessions
    pub async fn list_sessions(&self) -> Result<Vec<ChatSession>, Box<dyn std::error::Error>> {
        let sessions = self.sessions.read().await;
        let mut session_list: Vec<ChatSession> = sessions.values().cloned().collect();

        // Sort by updated_at (most recent first)
        session_list.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));

        Ok(session_list)
    }

    /// Get a session by ID
    pub async fn get_session(
        &self,
        session_id: &str,
    ) -> Result<Option<ChatSession>, Box<dyn std::error::Error>> {
        let sessions = self.sessions.read().await;
        Ok(sessions.get(session_id).cloned())
    }

    /// Create a new session
    pub async fn create_session(
        &self,
        request: CreateSessionRequest,
    ) -> Result<ChatSession, Box<dyn std::error::Error>> {
        let session_id = Uuid::new_v4().to_string();
        let now = Utc::now();

        // Generate title from system prompt or use provided title
        let title = request.title.or_else(|| {
            request.system_prompt.as_ref().map(|prompt| {
                if prompt.len() > 50 {
                    format!("{}...", &prompt[..50])
                } else {
                    prompt.clone()
                }
            })
        });

        let session = ChatSession {
            id: session_id.clone(),
            title,
            created_at: now,
            updated_at: now,
            messages: Vec::new(),
            model_config: request.model_config,
            metadata: request.system_prompt.map(|prompt| {
                let mut meta = HashMap::new();
                meta.insert(
                    "system_prompt".to_string(),
                    serde_json::Value::String(prompt),
                );
                meta
            }),
        };

        // Store session locally
        let mut sessions = self.sessions.write().await;
        sessions.insert(session_id.clone(), session.clone());
        drop(sessions);

        // Save to disk
        self.save_sessions().await?;

        Ok(session)
    }

    /// Send a message in a session
    pub async fn send_message(
        &self,
        session_id: &str,
        request: SendMessageRequest,
    ) -> Result<ChatMessage, Box<dyn std::error::Error>> {
        // Validate session exists and get mutable reference
        let mut sessions = self.sessions.write().await;
        let session = sessions.get_mut(session_id).ok_or_else(|| {
            AppError::SessionError {
                session_id: session_id.to_string(),
                message: "Session not found".to_string(),
            }
        })?;
        let now = Utc::now();

        // Create user message
        let user_message = ChatMessage {
            id: Uuid::new_v4().to_string(),
            role: MessageRole::User,
            content: request.content.clone(),
            timestamp: now,
            model: request.model_config.as_ref().map(|m| m.model_id.clone()),
            metadata: None,
        };

        // Add user message to session
        session.messages.push(user_message.clone());
        session.updated_at = now;

        // For now, create a simple assistant response
        // In a real implementation, this would call the OpenCode server
        let assistant_message = ChatMessage {
            id: Uuid::new_v4().to_string(),
            role: MessageRole::Assistant,
            content: format!("Received your message: {}", request.content),
            timestamp: now + chrono::Duration::milliseconds(100),
            model: request.model_config.as_ref().map(|m| m.model_id.clone()),
            metadata: None,
        };

        // Add assistant message to session
        session.messages.push(assistant_message.clone());
        session.updated_at = now + chrono::Duration::milliseconds(100);

        // Update title if this is the first message and no title exists
        if session.messages.len() == 2 && session.title.is_none() {
            let content_preview = if request.content.len() > 50 {
                format!("{}...", &request.content[..50])
            } else {
                request.content.clone()
            };
            session.title = Some(content_preview);
        }

        drop(sessions);

        // Save to disk
        self.save_sessions().await?;

        Ok(assistant_message)
    }

    /// Get messages for a session
    pub async fn get_session_messages(
        &self,
        session_id: &str,
    ) -> Result<Vec<ChatMessage>, Box<dyn std::error::Error>> {
        let sessions = self.sessions.read().await;

        match sessions.get(session_id) {
            Some(session) => Ok(session.messages.clone()),
            None => Err(AppError::SessionError {
                session_id: session_id.to_string(),
                message: "Session not found".to_string(),
            }
            .into()),
        }
    }

    /// Delete a session
    pub async fn delete_session(&self, session_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let mut sessions = self.sessions.write().await;

        if sessions.remove(session_id).is_none() {
            return Err(AppError::SessionError {
                session_id: session_id.to_string(),
                message: "Session not found".to_string(),
            }
            .into());
        }

        // Clear current session if it was the deleted one
        let mut current_session = self.current_session_id.write().await;
        if *current_session == Some(session_id.to_string()) {
            *current_session = None;
        }

        drop(sessions);
        drop(current_session);

        // Save to disk
        self.save_sessions().await?;

        Ok(())
    }

    /// Set the current active session
    pub async fn set_current_session(&self, session_id: Option<String>) {
        let mut current = self.current_session_id.write().await;
        *current = session_id;
    }

    /// Get the current active session
    pub async fn get_current_session(
        &self,
    ) -> Result<Option<ChatSession>, Box<dyn std::error::Error>> {
        let current_id = self.current_session_id.read().await;

        match current_id.as_ref() {
            Some(session_id) => {
                let sessions = self.sessions.read().await;
                Ok(sessions.get(session_id).cloned())
            }
            None => Ok(None),
        }
    }

    /// Get the current session ID
    pub async fn get_current_session_id(&self) -> Option<String> {
        self.current_session_id.read().await.clone()
    }

    /// Update session title
    pub async fn update_session_title(
        &self,
        session_id: &str,
        title: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut sessions = self.sessions.write().await;

        if let Some(session) = sessions.get_mut(session_id) {
            session.title = Some(title);
            session.updated_at = Utc::now();
            drop(sessions);

            // Save to disk
            self.save_sessions().await?;
            Ok(())
        } else {
            Err(AppError::SessionError {
                session_id: session_id.to_string(),
                message: "Session not found".to_string(),
            }
            .into())
        }
    }

    /// Get session statistics
    pub async fn get_session_stats(
        &self,
        session_id: &str,
    ) -> Result<SessionStats, Box<dyn std::error::Error>> {
        let sessions = self.sessions.read().await;

        match sessions.get(session_id) {
            Some(session) => {
                let user_messages = session
                    .messages
                    .iter()
                    .filter(|m| matches!(m.role, MessageRole::User))
                    .count();
                let assistant_messages = session
                    .messages
                    .iter()
                    .filter(|m| matches!(m.role, MessageRole::Assistant))
                    .count();
                let total_chars: usize = session.messages.iter().map(|m| m.content.len()).sum();

                Ok(SessionStats {
                    message_count: session.messages.len(),
                    user_message_count: user_messages,
                    assistant_message_count: assistant_messages,
                    total_characters: total_chars,
                    created_at: session.created_at,
                    updated_at: session.updated_at,
                })
            }
            None => Err(AppError::SessionError {
                session_id: session_id.to_string(),
                message: "Session not found".to_string(),
            }
            .into()),
        }
    }
}

/// Statistics for a session
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStats {
    pub message_count: usize,
    pub user_message_count: usize,
    pub assistant_message_count: usize,
    pub total_characters: usize,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api_client::ApiClient;
    use tempfile::TempDir;

    fn create_test_session_manager() -> (SessionManager, TempDir) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().to_path_buf();
        let api_client = Arc::new(ApiClient::new().expect("Failed to create ApiClient"));
        let manager = SessionManager::new(api_client, config_path);
        (manager, temp_dir)
    }

    #[tokio::test]
    async fn test_session_creation() {
        let (manager, _temp) = create_test_session_manager();

        let request = CreateSessionRequest {
            title: Some("Test Session".to_string()),
            model_config: None,
            system_prompt: None,
        };

        let session = manager
            .create_session(request)
            .await
            .expect("Should create session");

        assert!(!session.id.is_empty());
        assert_eq!(session.title, Some("Test Session".to_string()));
        assert!(session.messages.is_empty());
    }

    #[tokio::test]
    async fn test_send_message() {
        let (manager, _temp) = create_test_session_manager();

        // Create session first
        let create_request = CreateSessionRequest {
            title: Some("Test Chat".to_string()),
            model_config: None,
            system_prompt: None,
        };
        let session = manager
            .create_session(create_request)
            .await
            .expect("Should create session");

        // Send message
        let send_request = SendMessageRequest {
            content: "Hello, world!".to_string(),
            model_config: None,
            stream: None,
        };

        let response = manager
            .send_message(&session.id, send_request)
            .await
            .expect("Should send message");

        assert_eq!(response.role, MessageRole::Assistant);
        assert!(response.content.contains("Hello, world!"));
    }

    #[tokio::test]
    async fn test_session_listing() {
        let (manager, _temp) = create_test_session_manager();

        // Create multiple sessions
        for i in 1..=3 {
            let request = CreateSessionRequest {
                title: Some(format!("Session {}", i)),
                model_config: None,
                system_prompt: None,
            };
            manager
                .create_session(request)
                .await
                .expect("Should create session");
        }

        let sessions = manager.list_sessions().await.expect("Should list sessions");
        assert_eq!(sessions.len(), 3);
    }

    #[tokio::test]
    async fn test_session_deletion() {
        let (manager, _temp) = create_test_session_manager();

        // Create session
        let request = CreateSessionRequest {
            title: Some("To Delete".to_string()),
            model_config: None,
            system_prompt: None,
        };
        let session = manager
            .create_session(request)
            .await
            .expect("Should create session");

        // Verify it exists
        let found = manager
            .get_session(&session.id)
            .await
            .expect("Should get session");
        assert!(found.is_some());

        // Delete it
        manager
            .delete_session(&session.id)
            .await
            .expect("Should delete session");

        // Verify it's gone
        let found = manager
            .get_session(&session.id)
            .await
            .expect("Should get session");
        assert!(found.is_none());
    }

    #[tokio::test]
    async fn test_current_session_management() {
        let (manager, _temp) = create_test_session_manager();

        // Initially no current session
        let current = manager
            .get_current_session()
            .await
            .expect("Should get current session");
        assert!(current.is_none());

        // Create session
        let request = CreateSessionRequest {
            title: Some("Current".to_string()),
            model_config: None,
            system_prompt: None,
        };
        let session = manager
            .create_session(request)
            .await
            .expect("Should create session");

        // Set as current
        manager.set_current_session(Some(session.id.clone())).await;

        // Verify it's current
        let current = manager
            .get_current_session()
            .await
            .expect("Should get current session");
        assert!(current.is_some());
        assert_eq!(current.unwrap().id, session.id);

        // Clear current
        manager.set_current_session(None).await;

        // Verify no current session
        let current = manager
            .get_current_session()
            .await
            .expect("Should get current session");
        assert!(current.is_none());
    }

    #[tokio::test]
    async fn test_session_stats() {
        let (manager, _temp) = create_test_session_manager();

        // Create session
        let request = CreateSessionRequest {
            title: Some("Stats Test".to_string()),
            model_config: None,
            system_prompt: None,
        };
        let session = manager
            .create_session(request)
            .await
            .expect("Should create session");

        // Send a message
        let send_request = SendMessageRequest {
            content: "Test message".to_string(),
            model_config: None,
            stream: None,
        };
        manager
            .send_message(&session.id, send_request)
            .await
            .expect("Should send message");

        // Get stats
        let stats = manager
            .get_session_stats(&session.id)
            .await
            .expect("Should get stats");

        assert_eq!(stats.message_count, 2); // User + Assistant
        assert_eq!(stats.user_message_count, 1);
        assert_eq!(stats.assistant_message_count, 1);
        assert!(stats.total_characters > 0);
    }

    #[test]
    fn test_message_role_serialization() {
        let role = MessageRole::User;
        let json = serde_json::to_string(&role).expect("Should serialize role");
        assert!(json.contains("User"));

        let deserialized: MessageRole =
            serde_json::from_str(&json).expect("Should deserialize role");
        assert_eq!(deserialized, MessageRole::User);
    }

    #[test]
    fn test_chat_message_structure() {
        let message = ChatMessage {
            id: "test-id".to_string(),
            role: MessageRole::User,
            content: "Hello".to_string(),
            timestamp: Utc::now(),
            model: Some("gpt-4".to_string()),
            metadata: None,
        };

        assert_eq!(message.id, "test-id");
        assert_eq!(message.role, MessageRole::User);
        assert_eq!(message.content, "Hello");
        assert_eq!(message.model, Some("gpt-4".to_string()));
    }
}
