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
    SessionCreated { session: ChatSession },
    MessageReceived { session_id: String, message: ChatMessage },
    MessageChunk { session_id: String, chunk: String },
    Error { message: String },
}

pub struct ChatClient {
    server_url: Option<String>,
    client: Client,
    sessions: HashMap<String, ChatSession>,
    pub event_sender: broadcast::Sender<ChatEvent>,
    config_dir: PathBuf,
    current_session: Option<String>,
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
            event_sender,
            config_dir,
            current_session: None,
        })
    }

    pub fn set_server_url(&mut self, url: String) {
        self.server_url = Some(url);
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<ChatEvent> {
        self.event_sender.subscribe()
    }

    pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
        let server_url = self.server_url.as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        // Create session via OpenCode API
        #[derive(Serialize)]
        struct CreateSessionRequest {
            title: Option<String>,
        }

        let request = CreateSessionRequest {
            title: title.map(|s| s.to_string()),
        };

        let url = format!("{}/session", server_url);
        let response = self.client.post(&url)
            .json(&request)
            .send()
            .await
            .map_err(|e| format!("Failed to create session: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("API error: {} - {}", response.status(), response.text().await.unwrap_or_default()));
        }

        let session: ChatSession = response.json()
            .await
            .map_err(|e| format!("Failed to parse session response: {}", e))?;

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
        let server_url = self.server_url.as_ref()
            .ok_or_else(|| "Server URL not set".to_string())?;

        // Ensure session exists locally
        let session = self.sessions.get_mut(session_id)
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

        // Send message via OpenCode API
        #[derive(Serialize)]
        struct SendMessageRequest {
            content: String,
        }

        let request = SendMessageRequest {
            content: content.to_string(),
        };

        let url = format!("{}/session/{}/message", server_url, session_id);
        let response = self.client.post(&url)
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
        self.sessions.remove(session_id)
            .ok_or_else(|| format!("Session {} not found", session_id))?;
        Ok(())
    }

    pub async fn get_session_history(&self, session_id: &str) -> Result<Vec<ChatMessage>, String> {
        let session = self.sessions.get(session_id)
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
        self.current_session.as_ref()
            .and_then(|id| self.sessions.get(id))
    }

    pub fn set_current_session(&mut self, session_id: Option<String>) {
        self.current_session = session_id;
    }
}