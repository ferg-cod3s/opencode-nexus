use crate::api_client::ApiClient;
use crate::chat_client::{ChatEvent, ChatMessage, MessageRole};
use futures_util::StreamExt;
use reqwest::Client;
use serde::Deserialize;
use std::time::Duration;
use tokio::sync::broadcast;
use tokio::time;

#[derive(Debug, Deserialize)]
struct SSEEvent {
    event: Option<String>,
    data: String,
}

#[derive(Debug, Deserialize)]
struct StreamingMessage {
    id: String,
    content: String,
    role: String,
    session_id: String,
    #[serde(rename = "is_chunk")]
    is_chunk: Option<bool>,
}

pub struct MessageStream {
    api_client: Option<ApiClient>,
    event_sender: broadcast::Sender<ChatEvent>,
    is_streaming: std::sync::atomic::AtomicBool,
}

impl MessageStream {
    pub fn new(event_sender: broadcast::Sender<ChatEvent>) -> Self {
        Self {
            api_client: None,
            event_sender,
            is_streaming: std::sync::atomic::AtomicBool::new(false),
        }
    }

    pub fn set_api_client(&mut self, api_client: ApiClient) {
        self.api_client = Some(api_client);
    }

    pub fn is_streaming(&self) -> bool {
        self.is_streaming.load(std::sync::atomic::Ordering::Relaxed)
    }

    pub async fn start_streaming(&mut self) -> Result<(), String> {
        if self.is_streaming() {
            return Err("Already streaming".to_string());
        }

        let api_client = self
            .api_client
            .as_ref()
            .ok_or_else(|| "API client not available".to_string())?;

        self.is_streaming
            .store(true, std::sync::atomic::Ordering::Relaxed);

        // Start streaming in a background task
        let event_sender = self.event_sender.clone();
        let base_url = api_client.base_url.clone();

        tokio::spawn(async move {
            if let Err(e) = Self::stream_events(&base_url, event_sender).await {
                eprintln!("Streaming error: {}", e);
            }
        });

        Ok(())
    }

    pub fn stop_streaming(&mut self) {
        self.is_streaming
            .store(false, std::sync::atomic::Ordering::Relaxed);
    }

    async fn stream_events(
        base_url: &str,
        event_sender: broadcast::Sender<ChatEvent>,
    ) -> Result<(), String> {
        let client = Client::builder()
            .timeout(Duration::from_secs(300)) // Long timeout for streaming
            .build()
            .map_err(|e| format!("Failed to create streaming client: {}", e))?;

        let url = format!("{}/event", base_url);

        loop {
            match Self::connect_and_stream(&client, &url, &event_sender).await {
                Ok(()) => {
                    // Stream ended normally, might reconnect
                    time::sleep(Duration::from_secs(1)).await;
                }
                Err(e) => {
                    // Emit error event
                    let _ = event_sender.send(ChatEvent::Error {
                        message: format!("Streaming error: {}", e),
                    });

                    // Wait before reconnecting
                    time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    }

    async fn connect_and_stream(
        client: &Client,
        url: &str,
        event_sender: &broadcast::Sender<ChatEvent>,
    ) -> Result<(), String> {
        let response = client
            .get(url)
            .header("Accept", "text/event-stream")
            .header("Cache-Control", "no-cache")
            .send()
            .await
            .map_err(|e| format!("Failed to connect to event stream: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "Event stream returned status: {}",
                response.status()
            ));
        }

        let mut stream = response.bytes_stream();

        while let Some(chunk_result) = stream.next().await {
            let chunk = chunk_result.map_err(|e| format!("Stream read error: {}", e))?;
            let text = String::from_utf8_lossy(&chunk);

            // Parse SSE events
            for line in text.lines() {
                if line.starts_with("data: ") {
                    let data = &line[6..]; // Remove "data: " prefix

                    if let Ok(streaming_msg) = serde_json::from_str::<StreamingMessage>(data) {
                        Self::handle_streaming_message(&streaming_msg, event_sender).await;
                    }
                }
            }
        }

        Ok(())
    }

    async fn handle_streaming_message(
        msg: &StreamingMessage,
        event_sender: &broadcast::Sender<ChatEvent>,
    ) {
        let role = match msg.role.as_str() {
            "user" => MessageRole::User,
            "assistant" => MessageRole::Assistant,
            _ => return, // Skip unknown roles
        };

        let message = ChatMessage {
            id: msg.id.clone(),
            role,
            content: msg.content.clone(),
            timestamp: chrono::Utc::now().to_rfc3339(),
        };

        if msg.is_chunk.unwrap_or(false) {
            // Emit chunk event
            let _ = event_sender.send(ChatEvent::MessageChunk {
                session_id: msg.session_id.clone(),
                chunk: msg.content.clone(),
            });
        } else {
            // Emit full message event
            let _ = event_sender.send(ChatEvent::MessageReceived {
                session_id: msg.session_id.clone(),
                message,
            });
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::broadcast;

    /// Helper function to create a test MessageStream
    fn create_test_message_stream() -> (MessageStream, broadcast::Receiver<ChatEvent>) {
        let (sender, receiver) = broadcast::channel(100);
        let stream = MessageStream::new(sender);
        (stream, receiver)
    }

    #[test]
    fn test_message_stream_creation() {
        let (sender, _) = broadcast::channel(10);
        let stream = MessageStream::new(sender);
        assert!(!stream.is_streaming());
        assert!(stream.api_client.is_none());
    }

    #[test]
    fn test_streaming_state() {
        let (sender, _) = broadcast::channel(10);
        let mut stream = MessageStream::new(sender);

        assert!(!stream.is_streaming());

        // Test starting streaming without API client
        let result = futures::executor::block_on(stream.start_streaming());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("API client not available"));
    }

    #[test]
    fn test_stop_streaming() {
        let (sender, _) = broadcast::channel(10);
        let mut stream = MessageStream::new(sender);

        stream.stop_streaming();
        assert!(!stream.is_streaming());
    }

    #[test]
    fn test_set_api_client() {
        let (mut stream, _receiver) = create_test_message_stream();

        // Initially no API client
        assert!(stream.api_client.is_none());

        // Set API client
        let api_client =
            ApiClient::new("http://localhost:3000").expect("Failed to create API client");
        stream.set_api_client(api_client);

        // Should now have API client
        assert!(stream.api_client.is_some());
    }

    #[tokio::test]
    async fn test_start_streaming_requires_api_client() {
        let (mut stream, _receiver) = create_test_message_stream();

        // Try to start streaming without API client
        let result = stream.start_streaming().await;

        // Should fail with clear error
        assert!(result.is_err());
        let error_msg = result.unwrap_err();
        assert!(
            error_msg.contains("API client not available"),
            "Error should mention API client: {}",
            error_msg
        );
    }

    #[tokio::test]
    async fn test_parse_sse_message_chunk() {
        let (sender, mut receiver) = broadcast::channel(100);

        // Simulate streaming message chunk
        let streaming_msg = StreamingMessage {
            id: "msg_123".to_string(),
            content: "Hello".to_string(),
            role: "assistant".to_string(),
            session_id: "session_456".to_string(),
            is_chunk: Some(true),
        };

        // Handle the streaming message
        MessageStream::handle_streaming_message(&streaming_msg, &sender).await;

        // Should receive MessageChunk event
        let event = receiver.recv().await.expect("Should receive event");
        match event {
            ChatEvent::MessageChunk { session_id, chunk } => {
                assert_eq!(session_id, "session_456");
                assert_eq!(chunk, "Hello");
            }
            _ => panic!("Expected MessageChunk event, got {:?}", event),
        }
    }

    #[tokio::test]
    async fn test_parse_sse_complete_message() {
        let (sender, mut receiver) = broadcast::channel(100);

        // Simulate complete message
        let streaming_msg = StreamingMessage {
            id: "msg_789".to_string(),
            content: "Complete message".to_string(),
            role: "assistant".to_string(),
            session_id: "session_456".to_string(),
            is_chunk: Some(false),
        };

        // Handle the streaming message
        MessageStream::handle_streaming_message(&streaming_msg, &sender).await;

        // Should receive MessageReceived event
        let event = receiver.recv().await.expect("Should receive event");
        match event {
            ChatEvent::MessageReceived {
                session_id,
                message,
            } => {
                assert_eq!(session_id, "session_456");
                assert_eq!(message.id, "msg_789");
                assert_eq!(message.content, "Complete message");
                assert!(matches!(message.role, MessageRole::Assistant));
            }
            _ => panic!("Expected MessageReceived event, got {:?}", event),
        }
    }

    #[tokio::test]
    async fn test_handle_streaming_message_user_role() {
        let (sender, mut receiver) = broadcast::channel(100);

        // Simulate user message
        let streaming_msg = StreamingMessage {
            id: "msg_user".to_string(),
            content: "User message".to_string(),
            role: "user".to_string(),
            session_id: "session_789".to_string(),
            is_chunk: Some(false),
        };

        // Handle the streaming message
        MessageStream::handle_streaming_message(&streaming_msg, &sender).await;

        // Should receive MessageReceived event with User role
        let event = receiver.recv().await.expect("Should receive event");
        match event {
            ChatEvent::MessageReceived { message, .. } => {
                assert!(matches!(message.role, MessageRole::User));
                assert_eq!(message.content, "User message");
            }
            _ => panic!("Expected MessageReceived event, got {:?}", event),
        }
    }

    #[tokio::test]
    async fn test_handle_streaming_message_assistant_role() {
        let (sender, mut receiver) = broadcast::channel(100);

        // Simulate assistant message
        let streaming_msg = StreamingMessage {
            id: "msg_assistant".to_string(),
            content: "Assistant response".to_string(),
            role: "assistant".to_string(),
            session_id: "session_789".to_string(),
            is_chunk: Some(false),
        };

        // Handle the streaming message
        MessageStream::handle_streaming_message(&streaming_msg, &sender).await;

        // Should receive MessageReceived event with Assistant role
        let event = receiver.recv().await.expect("Should receive event");
        match event {
            ChatEvent::MessageReceived { message, .. } => {
                assert!(matches!(message.role, MessageRole::Assistant));
                assert_eq!(message.content, "Assistant response");
            }
            _ => panic!("Expected MessageReceived event, got {:?}", event),
        }
    }

    #[tokio::test]
    async fn test_handle_streaming_message_unknown_role() {
        let (sender, mut receiver) = broadcast::channel(100);

        // Simulate message with unknown role
        let streaming_msg = StreamingMessage {
            id: "msg_unknown".to_string(),
            content: "Unknown role message".to_string(),
            role: "unknown_role".to_string(),
            session_id: "session_789".to_string(),
            is_chunk: Some(false),
        };

        // Handle the streaming message
        MessageStream::handle_streaming_message(&streaming_msg, &sender).await;

        // Should not emit any event for unknown roles
        let result =
            tokio::time::timeout(std::time::Duration::from_millis(100), receiver.recv()).await;

        // Should timeout because no event was emitted
        assert!(result.is_err(), "Should not emit event for unknown role");
    }
}
