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

        // Return a subscription to the event stream
        Ok(self.event_sender.subscribe())
    }
}
