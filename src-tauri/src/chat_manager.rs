use crate::api_client::ApiClient;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
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

pub struct ChatManager {
    api_client: Option<ApiClient>,
    sessions: HashMap<String, ChatSession>,
    pub event_sender: broadcast::Sender<ChatEvent>,
    config_dir: PathBuf,
}

impl ChatManager {
    pub fn new(config_dir: PathBuf) -> Self {
        let (event_sender, _) = broadcast::channel(100);

        Self {
            api_client: None,
            sessions: HashMap::new(),
            event_sender,
            config_dir,
        }
    }

    pub fn set_api_client(&mut self, api_client: ApiClient) {
        self.api_client = Some(api_client);
    }

    pub fn subscribe_to_events(&self) -> broadcast::Receiver<ChatEvent> {
        self.event_sender.subscribe()
    }

    pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
        let api_client = self.api_client.as_ref()
            .ok_or_else(|| "API client not available".to_string())?;

        // Create session request payload matching OpenCode server API
        #[derive(Serialize)]
        struct CreateSessionRequest {
            title: Option<String>,
        }

        let request = CreateSessionRequest {
            title: title.map(|s| s.to_string()),
        };

        let session: ChatSession = api_client
            .post("/session", &request)
            .await
            .map_err(|e| format!("Failed to create session: {}", e))?;

        // Store session locally
        self.sessions.insert(session.id.clone(), session.clone());

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

    pub async fn send_message(&mut self, session_id: &str, content: &str) -> Result<ChatMessage, String> {
        let api_client = self.api_client.as_ref()
            .ok_or_else(|| "API client not available".to_string())?;

        // Ensure session exists
        let session = self.sessions.get_mut(session_id)
            .ok_or_else(|| format!("Session {} not found", session_id))?;

        // Create message request payload matching OpenCode server ChatInput format
        #[derive(Serialize)]
        struct SendMessageRequest {
            content: String,
        }

        let request = SendMessageRequest {
            content: content.to_string(),
        };

        let message: ChatMessage = api_client
            .post(&format!("/session/{}/message", session_id), &request)
            .await
            .map_err(|e| format!("Failed to send message: {}", e))?;

        // Add message to session
        session.messages.push(message.clone());

        // Persist updated session to disk
        if let Err(e) = self.save_sessions() {
            eprintln!("Warning: Failed to persist session after message: {}", e);
        }

        // Emit event
        let _ = self.event_sender.send(ChatEvent::MessageReceived {
            session_id: session_id.to_string(),
            message: message.clone(),
        });

        Ok(message)
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
        let api_client = self.api_client.as_ref()
            .ok_or_else(|| "API client not available".to_string())?;

        // Get messages from OpenCode server API
        // The API returns an array of message objects with info and parts
        #[derive(Deserialize)]
        struct MessageResponse {
            info: ChatMessage,
            parts: Vec<serde_json::Value>, // Parts structure not needed for basic chat
        }

        let messages_response: Vec<MessageResponse> = api_client
            .get(&format!("/session/{}/message", session_id))
            .await
            .map_err(|e| format!("Failed to get session history: {}", e))?;

        // Extract just the message info from the response
        let messages = messages_response
            .into_iter()
            .map(|msg| msg.info)
            .collect();

        Ok(messages)
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
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_chat_manager_creation() {
        let temp_dir = std::env::temp_dir().join("test_chat_manager");
        let manager = ChatManager::new(temp_dir);
        assert!(manager.api_client.is_none());
        assert!(manager.sessions.is_empty());
    }

    #[test]
    fn test_message_operations() {
        let temp_dir = std::env::temp_dir().join("test_chat_manager");
        let mut manager = ChatManager::new(temp_dir);

        // Test message sending (without API client)
        let result = futures::executor::block_on(manager.send_message("test-session", "Hello"));
        assert!(result.is_err()); // Should fail without API client
        assert!(result.unwrap_err().contains("API client not available"));
    }

    #[test]
    fn test_session_operations() {
        let temp_dir = std::env::temp_dir().join("test_chat_manager");
        let mut manager = ChatManager::new(temp_dir);

        // Test session creation (without API client)
        let result = futures::executor::block_on(manager.create_session(Some("Test Session")));
        assert!(result.is_err()); // Should fail without API client
        assert!(result.unwrap_err().contains("API client not available"));

        // Test session retrieval
        let session = manager.get_session("nonexistent");
        assert!(session.is_none());

        // Test session deletion
        let result = manager.delete_session("nonexistent");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }

    #[test]
    fn test_message_role_serialization() {
        // Test that MessageRole serializes correctly
        let user_msg = ChatMessage {
            id: "test-id".to_string(),
            role: MessageRole::User,
            content: "Hello".to_string(),
            timestamp: "2024-01-01T00:00:00Z".to_string(),
        };

        let json = serde_json::to_string(&user_msg).unwrap();
        assert!(json.contains(r#""role":"user""#));

        let assistant_msg = ChatMessage {
            id: "test-id-2".to_string(),
            role: MessageRole::Assistant,
            content: "Hi there!".to_string(),
            timestamp: "2024-01-01T00:00:01Z".to_string(),
        };

        let json = serde_json::to_string(&assistant_msg).unwrap();
        assert!(json.contains(r#""role":"assistant""#));
    }
}