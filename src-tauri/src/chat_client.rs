use crate::api_client::ApiClient;
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
    sessions: HashMap<String, ChatSession>,
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
            sessions: HashMap::new(),
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

        // Convert to our ChatSession format
        let session = ChatSession {
            id: open_code_session.id,
            title: open_code_session.title,
            created_at: open_code_session.created_at,
            messages: Vec::new(),
        };

        // Store session locally
        self.sessions.insert(session.id.clone(), session.clone());
        self.current_session = Some(session.id.clone());

        // Persist to disk
        if let Err(e) = self.save_sessions() {
            eprintln!("Warning: Failed to persist session: {}", e);
        }

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

        // Ensure session exists locally
        let session = self
            .sessions
            .get_mut(session_id)
            .ok_or_else(|| format!("Session {} not found", session_id))?;

        // Create user message
        let user_message = ChatMessage {
            id: format!("msg_{}", chrono::Utc::now().timestamp_millis()),
            role: MessageRole::User,
            content: content.to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
        };

        // Add user message to local session
        session.messages.push(user_message.clone());

        // Send message via OpenCode API using the correct format
        #[derive(Serialize)]
        struct ModelConfig {
            provider_id: String,
            model_id: String,
        }

        #[derive(Serialize)]
        struct MessagePart {
            r#type: String,
            text: String,
        }

        #[derive(Serialize)]
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

        let url = format!("{}/session/{}/prompt", server_url, session_id);
        let response = self
            .client
            .post(&url)
            .json(&request)
            .send()
            .await
            .map_err(|e| format!("Failed to send message: {}", e))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(format!("API error: {} - {}", status, error_text));
        }

        // For now, we'll rely on streaming events for AI responses
        // The MessageStream will handle receiving the AI response via SSE

        // Persist updated session to disk
        if let Err(e) = self.save_sessions() {
            eprintln!("Warning: Failed to persist session after message: {}", e);
        }

        // Emit user message event
        let _ = self.event_sender.send(ChatEvent::MessageReceived {
            session_id: session_id.to_string(),
            message: user_message,
        });

        Ok(())
    }

    pub fn get_session(&self, session_id: &str) -> Option<&ChatSession> {
        self.sessions.get(session_id)
    }

    pub fn get_all_sessions(&self) -> Vec<&ChatSession> {
        self.sessions.values().collect()
    }

    pub fn get_sessions(&self) -> &HashMap<String, ChatSession> {
        &self.sessions
    }

    pub fn get_sessions_mut(&mut self) -> &mut HashMap<String, ChatSession> {
        &mut self.sessions
    }

    pub fn delete_session(&mut self, session_id: &str) -> Result<(), String> {
        self.sessions
            .remove(session_id)
            .ok_or_else(|| format!("Session {} not found", session_id))?;
        Ok(())
    }

    pub async fn get_session_history(&self, session_id: &str) -> Result<Vec<ChatMessage>, String> {
        let session = self
            .sessions
            .get(session_id)
            .ok_or_else(|| format!("Session {} not found", session_id))?;

        Ok(session.messages.clone())
    }

    fn get_sessions_file_path(&self) -> PathBuf {
        self.config_dir.join("chat_sessions.json")
    }

    pub fn save_sessions(&self) -> Result<(), String> {
        let sessions_vec: Vec<&ChatSession> = self.sessions.values().collect();
        let json = serde_json::to_string_pretty(&sessions_vec)
            .map_err(|e| format!("Failed to serialize sessions: {}", e))?;

        std::fs::write(self.get_sessions_file_path(), json)
            .map_err(|e| format!("Failed to write sessions file: {}", e))?;

        Ok(())
    }

    pub fn load_sessions(&mut self) -> Result<(), String> {
        let file_path = self.get_sessions_file_path();

        if !file_path.exists() {
            return Ok(()); // No sessions file yet, that's fine
        }

        let json = std::fs::read_to_string(&file_path)
            .map_err(|e| format!("Failed to read sessions file: {}", e))?;

        let sessions_vec: Vec<ChatSession> = serde_json::from_str(&json)
            .map_err(|e| format!("Failed to deserialize sessions: {}", e))?;

        self.sessions.clear();
        for session in sessions_vec {
            self.sessions.insert(session.id.clone(), session);
        }

        Ok(())
    }

    /// Sync sessions with the server, merging server sessions with local cache
    /// Server is the source of truth - any server sessions will override local ones
    pub async fn sync_sessions_with_server(&mut self) -> Result<(), String> {
        // Try to fetch sessions from server
        match self.list_sessions_from_server().await {
            Ok(server_sessions) => {
                // Merge server sessions into local cache
                for server_session in server_sessions {
                    // Server sessions override local ones (server is source of truth)
                    self.sessions
                        .insert(server_session.id.clone(), server_session);
                }
                // Persist the merged sessions to disk
                self.save_sessions()?;
                Ok(())
            }
            Err(e) => {
                // If server sync fails, just continue with local sessions
                // This allows offline-first behavior
                eprintln!(
                    "Warning: Failed to sync sessions with server: {}. Using local cache.",
                    e
                );
                Ok(())
            }
        }
    }

    pub fn persist_session(&mut self, session: &ChatSession) -> Result<(), String> {
        self.sessions.insert(session.id.clone(), session.clone());
        self.save_sessions()
    }

    pub fn get_current_session(&self) -> Option<&ChatSession> {
        self.current_session
            .as_ref()
            .and_then(|id| self.sessions.get(id))
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
    async fn test_save_sessions_to_disk() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Create a test session
        let session = ChatSession {
            id: "session_123".to_string(),
            title: Some("Test Session".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            messages: vec![],
        };

        // Add session to client
        chat_client
            .sessions
            .insert(session.id.clone(), session.clone());

        // Save sessions to disk
        let result = chat_client.save_sessions();
        assert!(result.is_ok(), "Should save sessions successfully");

        // Verify file was created
        let file_path = chat_client.get_sessions_file_path();
        assert!(file_path.exists(), "Sessions file should exist");

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
    async fn test_load_sessions_from_disk() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Create and save a session
        let session = ChatSession {
            id: "session_456".to_string(),
            title: Some("Persisted Session".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            messages: vec![],
        };

        chat_client
            .sessions
            .insert(session.id.clone(), session.clone());
        chat_client.save_sessions().expect("Should save sessions");

        // Clear sessions in memory
        chat_client.sessions.clear();
        assert_eq!(chat_client.sessions.len(), 0, "Sessions should be cleared");

        // Load sessions from disk
        let result = chat_client.load_sessions();
        assert!(result.is_ok(), "Should load sessions successfully");

        // Verify session was loaded
        assert_eq!(
            chat_client.sessions.len(),
            1,
            "Should have 1 session loaded"
        );
        assert!(
            chat_client.sessions.contains_key("session_456"),
            "Should contain the saved session"
        );

        let loaded_session = &chat_client.sessions["session_456"];
        assert_eq!(loaded_session.title, Some("Persisted Session".to_string()));
    }

    #[tokio::test]
    async fn test_load_sessions_when_file_not_exists() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Try to load sessions when file doesn't exist
        let result = chat_client.load_sessions();

        // Should succeed (no-op) when file doesn't exist
        assert!(result.is_ok(), "Should succeed when file doesn't exist");
        assert_eq!(chat_client.sessions.len(), 0, "Should have no sessions");
    }

    #[tokio::test]
    async fn test_persist_session() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Create a session
        let session = ChatSession {
            id: "session_persist".to_string(),
            title: Some("Persist Test".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            messages: vec![],
        };

        // Persist the session
        let result = chat_client.persist_session(&session);
        assert!(result.is_ok(), "Should persist session successfully");

        // Verify session is in memory
        assert!(
            chat_client.sessions.contains_key("session_persist"),
            "Session should be in memory"
        );

        // Verify session is on disk
        let file_path = chat_client.get_sessions_file_path();
        assert!(file_path.exists(), "Sessions file should exist");

        let json = std::fs::read_to_string(&file_path).expect("Should read file");
        assert!(
            json.contains("session_persist"),
            "File should contain session"
        );
    }

    #[tokio::test]
    async fn test_sessions_survive_restart() {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().to_path_buf();

        // Create first client instance and save a session
        {
            let mut client1 =
                ChatClient::new(config_path.clone()).expect("Failed to create first client");

            let session = ChatSession {
                id: "session_restart".to_string(),
                title: Some("Restart Test".to_string()),
                created_at: chrono::Utc::now().to_rfc3339(),
                messages: vec![ChatMessage {
                    id: "msg_1".to_string(),
                    role: MessageRole::User,
                    content: "Test message".to_string(),
                    timestamp: chrono::Utc::now().to_rfc3339(),
                }],
            };

            client1.persist_session(&session).expect("Should persist");
        } // client1 dropped here, simulating app shutdown

        // Create second client instance and load sessions
        {
            let mut client2 =
                ChatClient::new(config_path.clone()).expect("Failed to create second client");

            // Load sessions from disk
            client2.load_sessions().expect("Should load sessions");

            // Verify session survived restart
            assert_eq!(client2.sessions.len(), 1, "Should have 1 session");
            assert!(
                client2.sessions.contains_key("session_restart"),
                "Should contain persisted session"
            );

            let session = &client2.sessions["session_restart"];
            assert_eq!(session.title, Some("Restart Test".to_string()));
            assert_eq!(session.messages.len(), 1, "Should have 1 message");
            assert_eq!(session.messages[0].content, "Test message");
        }
    }

    #[tokio::test]
    async fn test_get_current_session() {
        let (mut chat_client, _temp) = create_test_chat_client();

        // Initially no current session
        assert!(chat_client.get_current_session().is_none());

        // Add a session
        let session = ChatSession {
            id: "session_current".to_string(),
            title: Some("Current Session".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            messages: vec![],
        };

        chat_client
            .sessions
            .insert(session.id.clone(), session.clone());
        chat_client.set_current_session(Some("session_current".to_string()));

        // Should now have current session
        let current = chat_client.get_current_session();
        assert!(current.is_some(), "Should have current session");
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
