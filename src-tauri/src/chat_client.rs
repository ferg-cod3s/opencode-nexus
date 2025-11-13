use crate::api_client::ApiClient;
use crate::error::{retry_with_backoff, AppError, RetryConfig};
use crate::message_stream::MessageStream;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::Duration;
use tokio::sync::broadcast;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatSession {
    pub id: String,
    pub title: Option<String>,
    pub created_at: String,
    pub messages: Vec<ChatMessage>,
}

/// Lightweight metadata for local caching (mobile-optimized)
/// Full message history is fetched from server on-demand
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionMetadata {
    pub id: String,
    pub title: Option<String>,
    pub created_at: String,
    pub updated_at: Option<String>,
    pub message_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id: String,
    pub role: MessageRole,
    pub content: String,
    pub timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageRole {
    #[serde(rename = "user")]
    User,
    #[serde(rename = "assistant")]
    Assistant,
}

#[derive(Debug, Clone, Serialize)]
pub enum ChatEvent {
    SessionCreated {
        session: ChatSession,
    },
    MessageReceived {
        session_id: String,
        message: ChatMessage,
    },
    MessageChunk {
        session_id: String,
        chunk: String,
    },
    Error {
        message: String,
    },
}

pub struct ChatClient {
    server_url: Option<String>,
    client: Client,
    /// Lightweight metadata cache (mobile-optimized - no full messages stored locally)
    session_metadata: HashMap<String, SessionMetadata>,
    pub event_sender: broadcast::Sender<ChatEvent>,
    config_dir: PathBuf,
    current_session: Option<String>,
    message_stream: Option<MessageStream>,
}

impl ChatClient {
    pub fn new(config_dir: PathBuf) -> Result<Self, String> {
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .user_agent("OpenCode-Nexus/1.0")
            .build()
            .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

        let (event_sender, _) = broadcast::channel(100);

        Ok(Self {
            server_url: None,
            client,
            session_metadata: HashMap::new(),
            event_sender: event_sender.clone(),
            config_dir,
            current_session: None,
            message_stream: Some(MessageStream::new(event_sender)),
        })
    }

    pub fn set_server_url(&mut self, url: String) {
        self.server_url = Some(url.clone());

        // Initialize API client for message streaming
        if let Ok(api_client) = ApiClient::new(&url) {
            if let Some(stream) = &mut self.message_stream {
                stream.set_api_client(api_client);
            }
        }
        // Silently ignore API client creation errors - can retry on streaming
    }

    pub fn get_server_url(&self) -> Option<String> {
        self.server_url.clone()
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<ChatEvent> {
        self.event_sender.subscribe()
    }

    pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
        let server_url = self
            .server_url
            .as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        // Create session via OpenCode API
        #[derive(Serialize)]
        struct CreateSessionRequest {
            title: Option<String>,
        }

        #[derive(Deserialize)]
        struct OpenCodeSession {
            id: String,
            title: Option<String>,
            created_at: String,
        }

        let request = CreateSessionRequest {
            title: title.map(|s| s.to_string()),
        };

        let url = format!("{}/session", server_url);
        let response = self
            .client
            .post(&url)
            .json(&request)
            .send()
            .await
            .map_err(|e| format!("Failed to create session: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "API error: {} - {}",
                response.status(),
                response.text().await.unwrap_or_default()
            ));
        }

        let open_code_session: OpenCodeSession = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse session response: {}", e))?;

        // Store lightweight metadata locally (mobile-optimized)
        let metadata = SessionMetadata {
            id: open_code_session.id.clone(),
            title: open_code_session.title.clone(),
            created_at: open_code_session.created_at.clone(),
            updated_at: None,
            message_count: 0,
        };

        self.session_metadata
            .insert(metadata.id.clone(), metadata.clone());
        self.current_session = Some(metadata.id.clone());

        // Persist metadata to disk
        if let Err(e) = self.save_session_metadata() {
            eprintln!("Warning: Failed to persist session metadata: {}", e);
        }

        // Convert to ChatSession for response (no messages yet)
        let session = ChatSession {
            id: open_code_session.id,
            title: open_code_session.title,
            created_at: open_code_session.created_at,
            messages: Vec::new(),
        };

        // Emit event
        let _ = self.event_sender.send(ChatEvent::SessionCreated {
            session: session.clone(),
        });

        Ok(session)
    }

    pub async fn send_message(&mut self, session_id: &str, content: &str) -> Result<(), String> {
        let server_url = self
            .server_url
            .as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        // Create user message (for event emission only - not stored locally)
        let user_message = ChatMessage {
            id: format!("msg_{}", chrono::Utc::now().timestamp_millis()),
            role: MessageRole::User,
            content: content.to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
        };

        // Send message via OpenCode API with retry logic
        #[derive(Serialize, Clone)]
        struct ModelConfig {
            provider_id: String,
            model_id: String,
        }

        #[derive(Serialize, Clone)]
        struct MessagePart {
            r#type: String,
            text: String,
        }

        #[derive(Serialize, Clone)]
        struct PromptRequest {
            model: ModelConfig,
            parts: Vec<MessagePart>,
        }

        let request = PromptRequest {
            model: ModelConfig {
                provider_id: "anthropic".to_string(), // Default provider
                model_id: "claude-3-5-sonnet-20241022".to_string(), // Default model
            },
            parts: vec![MessagePart {
                r#type: "text".to_string(),
                text: content.to_string(),
            }],
        };

        let client = self.client.clone();
        let url = format!("{}/session/{}/prompt", server_url, session_id);

        // Use retry logic with exponential backoff for network resilience
        let result = retry_with_backoff(
            || {
                let client = client.clone();
                let url = url.clone();
                let request = request.clone();
                async move {
                    let response = client.post(&url).json(&request).send().await?;

                    if !response.status().is_success() {
                        let status_code = response.status().as_u16();
                        let error_text = response.text().await.unwrap_or_default();
                        return Err(AppError::ServerError {
                            status_code,
                            message: format!("Failed to send message (status {})", status_code),
                            details: error_text,
                        });
                    }

                    Ok(())
                }
            },
            RetryConfig::default(),
        )
        .await;

        // Convert AppError to String for backward compatibility
        result.map_err(|e| e.user_message())?;

        // Update metadata: increment message count, update timestamp
        if let Some(metadata) = self.session_metadata.get_mut(session_id) {
            metadata.message_count += 1;
            metadata.updated_at = Some(chrono::Utc::now().to_rfc3339());

            // Persist metadata to disk
            if let Err(e) = self.save_session_metadata() {
                eprintln!("Warning: Failed to persist metadata after message: {}", e);
            }
        }

        // Emit user message event
        let _ = self.event_sender.send(ChatEvent::MessageReceived {
            session_id: session_id.to_string(),
            message: user_message,
        });

        // MessageStream will handle receiving AI responses via SSE
        Ok(())
    }

    /// Get session metadata from local cache
    pub fn get_session_metadata(&self, session_id: &str) -> Option<&SessionMetadata> {
        self.session_metadata.get(session_id)
    }

    /// Get all session metadata from local cache
    pub fn get_all_session_metadata(&self) -> Vec<&SessionMetadata> {
        self.session_metadata.values().collect()
    }

    /// Get session metadata map (for iteration)
    pub fn get_session_metadata_map(&self) -> &HashMap<String, SessionMetadata> {
        &self.session_metadata
    }

    /// Delete session from server and local cache
    pub async fn delete_session(&mut self, session_id: &str) -> Result<(), String> {
        // Delete from server first
        self.delete_session_from_server(session_id).await?;

        // Then remove from local metadata cache
        self.session_metadata
            .remove(session_id)
            .ok_or_else(|| format!("Session {} not found in local cache", session_id))?;

        // Persist updated metadata
        self.save_session_metadata()?;

        Ok(())
    }

    /// Get full session history from server (not cached locally)
    pub async fn get_session_history(&self, session_id: &str) -> Result<Vec<ChatMessage>, String> {
        // Always fetch from server - mobile-optimized (no local message storage)
        self.get_session_messages_from_server(session_id).await
    }

    fn get_session_metadata_file_path(&self) -> PathBuf {
        self.config_dir.join("session_metadata.json")
    }

    /// Save lightweight metadata to disk (mobile-optimized - only IDs, titles, counts)
    pub fn save_session_metadata(&self) -> Result<(), String> {
        let metadata_vec: Vec<&SessionMetadata> = self.session_metadata.values().collect();
        let json = serde_json::to_string_pretty(&metadata_vec)
            .map_err(|e| format!("Failed to serialize metadata: {}", e))?;

        std::fs::write(self.get_session_metadata_file_path(), json)
            .map_err(|e| format!("Failed to write metadata file: {}", e))?;

        Ok(())
    }

    /// Load lightweight metadata from disk (mobile-optimized)
    pub fn load_session_metadata(&mut self) -> Result<(), String> {
        let file_path = self.get_session_metadata_file_path();

        if !file_path.exists() {
            return Ok(()); // No metadata file yet, that's fine
        }

        let json = std::fs::read_to_string(&file_path)
            .map_err(|e| format!("Failed to read metadata file: {}", e))?;

        let metadata_vec: Vec<SessionMetadata> = serde_json::from_str(&json)
            .map_err(|e| format!("Failed to deserialize metadata: {}", e))?;

        self.session_metadata.clear();
        for metadata in metadata_vec {
            self.session_metadata.insert(metadata.id.clone(), metadata);
        }

        Ok(())
    }

    /// Sync session metadata with server (mobile-optimized - only metadata, no messages)
    /// Server is the source of truth for session list
    pub async fn sync_session_metadata_with_server(&mut self) -> Result<(), String> {
        // Try to fetch sessions from server
        match self.list_sessions_from_server().await {
            Ok(server_sessions) => {
                // Convert server sessions to lightweight metadata
                for server_session in server_sessions {
                    // Preserve message count if we already have this session cached
                    let existing_count = self
                        .session_metadata
                        .get(&server_session.id)
                        .map(|m| m.message_count)
                        .unwrap_or(0);

                    let metadata = SessionMetadata {
                        id: server_session.id.clone(),
                        title: server_session.title,
                        created_at: server_session.created_at,
                        updated_at: None, // Will be updated when messages arrive
                        message_count: existing_count,
                    };

                    // Server metadata overrides local (server is source of truth)
                    self.session_metadata.insert(metadata.id.clone(), metadata);
                }

                // Persist the merged metadata to disk
                self.save_session_metadata()?;
                Ok(())
            }
            Err(e) => {
                // If server sync fails, continue with local metadata
                // Allows viewing cached sessions when offline
                eprintln!(
                    "Warning: Failed to sync with server: {}. Using local metadata cache.",
                    e
                );
                Ok(())
            }
        }
    }

    pub fn get_current_session_id(&self) -> Option<&String> {
        self.current_session.as_ref()
    }

    pub fn get_current_session_metadata(&self) -> Option<&SessionMetadata> {
        self.current_session
            .as_ref()
            .and_then(|id| self.session_metadata.get(id))
    }

    pub fn set_current_session(&mut self, session_id: Option<String>) {
        self.current_session = session_id;
    }

    // OpenCode API integration methods
    pub async fn list_sessions_from_server(&self) -> Result<Vec<ChatSession>, String> {
        let server_url = self
            .server_url
            .as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        #[derive(Deserialize)]
        struct OpenCodeSession {
            id: String,
            title: Option<String>,
            created_at: String,
        }

        let url = format!("{}/session", server_url);
        let response = self
            .client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to list sessions: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "API error: {} - {}",
                response.status(),
                response.text().await.unwrap_or_default()
            ));
        }

        let open_code_sessions: Vec<OpenCodeSession> = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse sessions response: {}", e))?;

        // Convert to our ChatSession format
        let sessions: Vec<ChatSession> = open_code_sessions
            .into_iter()
            .map(|ocs| ChatSession {
                id: ocs.id,
                title: ocs.title,
                created_at: ocs.created_at,
                messages: Vec::new(), // Will be loaded separately
            })
            .collect();

        Ok(sessions)
    }

    pub async fn get_session_messages_from_server(
        &self,
        session_id: &str,
    ) -> Result<Vec<ChatMessage>, String> {
        let server_url = self
            .server_url
            .as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        #[derive(Deserialize)]
        struct MessageInfo {
            id: String,
            role: String,
            created_at: String,
        }

        #[derive(Deserialize)]
        struct MessagePart {
            r#type: String,
            text: Option<String>,
        }

        #[derive(Deserialize)]
        struct MessageResponse {
            info: MessageInfo,
            parts: Vec<MessagePart>,
        }

        let url = format!("{}/session/{}/messages", server_url, session_id);
        let response = self
            .client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to get session messages: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "API error: {} - {}",
                response.status(),
                response.text().await.unwrap_or_default()
            ));
        }

        let messages: Vec<MessageResponse> = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse messages response: {}", e))?;

        // Convert to our ChatMessage format
        let chat_messages: Vec<ChatMessage> = messages
            .into_iter()
            .map(|msg| {
                let content: Vec<String> = msg
                    .parts
                    .iter()
                    .filter_map(|part| part.text.as_ref())
                    .cloned()
                    .collect();
                let content = content.join("\n");

                let role = match msg.info.role.as_str() {
                    "user" => MessageRole::User,
                    "assistant" => MessageRole::Assistant,
                    _ => MessageRole::User, // Default fallback
                };

                ChatMessage {
                    id: msg.info.id,
                    role,
                    content,
                    timestamp: msg.info.created_at,
                }
            })
            .collect();

        Ok(chat_messages)
    }

    pub async fn delete_session_from_server(&self, session_id: &str) -> Result<(), String> {
        let server_url = self
            .server_url
            .as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        let url = format!("{}/session/{}", server_url, session_id);
        let response = self
            .client
            .delete(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to delete session: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "API error: {} - {}",
                response.status(),
                response.text().await.unwrap_or_default()
            ));
        }

        Ok(())
    }

    // Subscribe to Server-Sent Events for real-time updates
    pub async fn start_event_stream(&mut self) -> Result<broadcast::Receiver<ChatEvent>, String> {
        // Verify server URL is set
        let _server_url = self
            .server_url
            .as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        // Start SSE streaming via MessageStream
        if let Some(stream) = &mut self.message_stream {
            stream.start_streaming().await?;
        } else {
            return Err("Message stream not initialized".to_string());
        }

        // Note: Messages received via SSE are persisted to the server and available via
        // the get_session_history API, so they'll be loaded when the client syncs sessions
        // This is simpler than trying to maintain local persistence of streaming messages

        // Return a subscription to the event stream
        Ok(self.event_sender.subscribe())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    /// Helper function to create a test ChatClient with a temp directory
    fn create_test_chat_client() -> (ChatClient, TempDir) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().to_path_buf();
        let client = ChatClient::new(config_path).expect("Failed to create chat client");
        (client, temp_dir)
    }

    #[tokio::test]
    async fn test_chat_client_initialization() {
        let (chat_client, _temp) = create_test_chat_client();

        // Should start with no server URL
        assert!(chat_client.get_server_url().is_none());

        // Should start with no sessions
        assert_eq!(chat_client.get_all_sessions().len(), 0);
    }

    #[tokio::test]
    async fn test_set_server_url_initializes_api_client() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Set server URL
        chat_client.set_server_url("http://localhost:3000".to_string());

        // Verify URL is stored
        assert_eq!(
            chat_client.get_server_url(),
            Some("http://localhost:3000".to_string())
        );

        // Note: api_client is internal to MessageStream, so we verify indirectly
        // by checking that server_url is set, which is required for API operations
    }

    #[tokio::test]
    async fn test_create_session_requires_server_url() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Try to create session without server URL
        let result = chat_client.create_session(None).await;

        // Should fail with clear error
        assert!(result.is_err());
        let error_msg = result.unwrap_err();
        assert!(
            error_msg.contains("server") || error_msg.contains("Server"),
            "Error message should mention server: {}",
            error_msg
        );
    }

    #[tokio::test]
    async fn test_send_message_uses_correct_server_url() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Set server URL
        chat_client.set_server_url("http://example.com:3000".to_string());

        // Verify the URL is what we expect
        assert_eq!(
            chat_client.get_server_url(),
            Some("http://example.com:3000".to_string())
        );

        // Try to send message without a session (should fail but with different error)
        let result = chat_client.send_message("fake_session_id", "test").await;

        // Should fail, but because session doesn't exist, not because of server URL
        assert!(result.is_err());
        let error_msg = result.unwrap_err();
        assert!(
            error_msg.contains("Session") || error_msg.contains("not found"),
            "Error should be about missing session, not server URL: {}",
            error_msg
        );
    }

    #[tokio::test]
    async fn test_save_session_metadata_to_disk() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Create test metadata
        let metadata = SessionMetadata {
            id: "session_123".to_string(),
            title: Some("Test Session".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            updated_at: None,
            message_count: 0,
        };

        // Add metadata to client
        chat_client
            .session_metadata
            .insert(metadata.id.clone(), metadata.clone());

        // Save metadata to disk
        let result = chat_client.save_session_metadata();
        assert!(result.is_ok(), "Should save metadata successfully");

        // Verify file was created
        let file_path = chat_client.get_session_metadata_file_path();
        assert!(file_path.exists(), "Metadata file should exist");

        // Verify file contents
        let json = std::fs::read_to_string(&file_path).expect("Should read file");
        assert!(
            json.contains("session_123"),
            "File should contain session ID"
        );
        assert!(
            json.contains("Test Session"),
            "File should contain session title"
        );
    }

    #[tokio::test]
    async fn test_load_session_metadata_from_disk() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Create and save metadata
        let metadata = SessionMetadata {
            id: "session_456".to_string(),
            title: Some("Persisted Session".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            updated_at: None,
            message_count: 5,
        };

        chat_client
            .session_metadata
            .insert(metadata.id.clone(), metadata.clone());
        chat_client
            .save_session_metadata()
            .expect("Should save metadata");

        // Clear metadata in memory
        chat_client.session_metadata.clear();
        assert_eq!(
            chat_client.session_metadata.len(),
            0,
            "Metadata should be cleared"
        );

        // Load metadata from disk
        let result = chat_client.load_session_metadata();
        assert!(result.is_ok(), "Should load metadata successfully");

        // Verify metadata was loaded
        assert_eq!(
            chat_client.session_metadata.len(),
            1,
            "Should have 1 metadata loaded"
        );
        assert!(
            chat_client.session_metadata.contains_key("session_456"),
            "Should contain the saved metadata"
        );

        let loaded_metadata = &chat_client.session_metadata["session_456"];
        assert_eq!(loaded_metadata.title, Some("Persisted Session".to_string()));
        assert_eq!(loaded_metadata.message_count, 5);
    }

    #[tokio::test]
    async fn test_load_metadata_when_file_not_exists() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Try to load metadata when file doesn't exist
        let result = chat_client.load_session_metadata();

        // Should succeed (no-op) when file doesn't exist
        assert!(result.is_ok(), "Should succeed when file doesn't exist");
        assert_eq!(
            chat_client.session_metadata.len(),
            0,
            "Should have no metadata"
        );
    }

    #[tokio::test]
    async fn test_metadata_survives_restart() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().to_path_buf();

        // Create first client instance and save metadata
        {
            let mut client1 =
                ChatClient::new(config_path.clone()).expect("Failed to create first client");

            let metadata = SessionMetadata {
                id: "session_restart".to_string(),
                title: Some("Restart Test".to_string()),
                created_at: chrono::Utc::now().to_rfc3339(),
                updated_at: Some(chrono::Utc::now().to_rfc3339()),
                message_count: 5,
            };

            client1
                .session_metadata
                .insert(metadata.id.clone(), metadata);
            client1
                .save_session_metadata()
                .expect("Should save metadata");
        } // client1 dropped here, simulating app shutdown

        // Create second client instance and load metadata
        {
            let mut client2 =
                ChatClient::new(config_path.clone()).expect("Failed to create second client");

            // Load metadata from disk
            client2
                .load_session_metadata()
                .expect("Should load metadata");

            // Verify metadata survived restart
            assert_eq!(client2.session_metadata.len(), 1, "Should have 1 metadata");
            assert!(
                client2.session_metadata.contains_key("session_restart"),
                "Should contain persisted metadata"
            );

            let metadata = &client2.session_metadata["session_restart"];
            assert_eq!(metadata.title, Some("Restart Test".to_string()));
            assert_eq!(metadata.message_count, 5);
        }
    }

    #[tokio::test]
    async fn test_get_current_session_metadata() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Initially no current session
        assert!(chat_client.get_current_session_metadata().is_none());

        // Add metadata
        let metadata = SessionMetadata {
            id: "session_current".to_string(),
            title: Some("Current Session".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            updated_at: None,
            message_count: 0,
        };

        chat_client
            .session_metadata
            .insert(metadata.id.clone(), metadata.clone());
        chat_client.set_current_session(Some("session_current".to_string()));

        // Should now have current session metadata
        let current = chat_client.get_current_session_metadata();
        assert!(current.is_some(), "Should have current session metadata");
        assert_eq!(current.unwrap().id, "session_current");
    }

    #[tokio::test]
    async fn test_set_current_session() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Set current session
        chat_client.set_current_session(Some("session_xyz".to_string()));

        // Verify it was set
        assert_eq!(chat_client.current_session, Some("session_xyz".to_string()));

        // Clear current session
        chat_client.set_current_session(None);
        assert_eq!(chat_client.current_session, None);
    }
}
