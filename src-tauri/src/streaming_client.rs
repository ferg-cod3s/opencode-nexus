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

use crate::api_client::ApiClient;
use crate::error::{AppError, RetryConfig};
use crate::session_manager::{ChatMessage, MessageRole};
use futures_util::{Stream, StreamExt};
use reqwest::EventSource;
use serde::{Deserialize, Serialize};
use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll};
use tokio::sync::broadcast;
use tokio::time::{timeout, Duration};

/// Event types for streaming responses
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum StreamEvent {
    /// Start of a new message stream
    Start {
        session_id: String,
        message_id: String,
        role: MessageRole,
    },
    /// Content chunk for a message
    Chunk {
        session_id: String,
        message_id: String,
        content: String,
        index: usize,
    },
    /// Message completed
    Complete {
        session_id: String,
        message_id: String,
        final_content: String,
        metadata: Option<serde_json::Value>,
    },
    /// Error occurred during streaming
    Error {
        session_id: String,
        message_id: Option<String>,
        error: String,
        retryable: bool,
    },
    /// Stream ended
    End {
        session_id: String,
        message_id: String,
    },
}

/// Request to start a streaming session
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamRequest {
    pub session_id: String,
    pub content: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model_config: Option<crate::api_client::ModelConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub system_prompt: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub temperature: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_tokens: Option<u32>,
}

/// Configuration for streaming behavior
#[derive(Debug, Clone)]
pub struct StreamConfig {
    /// Timeout for establishing connection
    pub connect_timeout_secs: u64,
    /// Timeout for receiving chunks
    pub chunk_timeout_secs: u64,
    /// Maximum number of retry attempts
    pub max_retries: u32,
    /// Whether to automatically reconnect on connection loss
    pub auto_reconnect: bool,
    /// Buffer size for event broadcasting
    pub buffer_size: usize,
}

impl Default for StreamConfig {
    fn default() -> Self {
        Self {
            connect_timeout_secs: 30,
            chunk_timeout_secs: 60,
            max_retries: 3,
            auto_reconnect: true,
            buffer_size: 100,
        }
    }
}

/// Streaming client for real-time chat responses
#[derive(Clone)]
pub struct StreamingClient {
    api_client: Arc<ApiClient>,
    config: StreamConfig,
    event_sender: broadcast::Sender<StreamEvent>,
    active_streams:
        Arc<tokio::sync::RwLock<std::collections::HashMap<String, tokio::task::JoinHandle<()>>>>,
}

impl StreamingClient {
    /// Create a new streaming client
    pub fn new(api_client: Arc<ApiClient>) -> Result<Self, Box<dyn std::error::Error>> {
        Self::with_config(api_client, StreamConfig::default())
    }

    /// Create a streaming client with custom configuration
    pub fn with_config(
        api_client: Arc<ApiClient>,
        config: StreamConfig,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let (event_sender, _) = broadcast::channel(config.buffer_size);

        Ok(Self {
            api_client,
            config,
            event_sender,
            active_streams: Arc::new(tokio::sync::RwLock::new(std::collections::HashMap::new())),
        })
    }

    /// Subscribe to stream events
    pub fn subscribe(&self) -> broadcast::Receiver<StreamEvent> {
        self.event_sender.subscribe()
    }

    /// Start a streaming message session
    pub async fn start_stream(
        &self,
        request: StreamRequest,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let stream_id = uuid::Uuid::new_v4().to_string();
        let session_id = request.session_id.clone();
        let message_id = uuid::Uuid::new_v4().to_string();

        // Send start event
        let start_event = StreamEvent::Start {
            session_id: session_id.clone(),
            message_id: message_id.clone(),
            role: MessageRole::Assistant,
        };
        let _ = self.event_sender.send(start_event);

        // Start the streaming task
        let task_handle = self
            .spawn_streaming_task(stream_id.clone(), request, message_id)
            .await?;

        // Store the active stream
        let mut active_streams = self.active_streams.write().await;
        active_streams.insert(stream_id.clone(), task_handle);

        Ok(stream_id)
    }

    /// Stop an active stream
    pub async fn stop_stream(&self, stream_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        let mut active_streams = self.active_streams.write().await;

        if let Some(handle) = active_streams.remove(stream_id) {
            handle.abort();
        }

        Ok(())
    }

    /// Get list of active stream IDs
    pub async fn get_active_streams(&self) -> Vec<String> {
        let active_streams = self.active_streams.read().await;
        active_streams.keys().cloned().collect()
    }

    /// Spawn a task to handle the actual streaming
    async fn spawn_streaming_task(
        &self,
        stream_id: String,
        request: StreamRequest,
        message_id: String,
    ) -> Result<tokio::task::JoinHandle<()>, Box<dyn std::error::Error>> {
        let api_client = Arc::clone(&self.api_client);
        let event_sender = self.event_sender.clone();
        let config = self.config.clone();
        let session_id = request.session_id.clone();

        let handle = tokio::spawn(async move {
            let mut retry_count = 0;
            let mut accumulated_content = String::new();

            while retry_count <= config.max_retries {
                match Self::attempt_stream(
                    &api_client,
                    &request,
                    &message_id,
                    &session_id,
                    &event_sender,
                    &config,
                    &mut accumulated_content,
                )
                .await
                {
                    Ok(_) => {
                        // Stream completed successfully
                        break;
                    }
                    Err(e) => {
                        let error_msg = e.to_string();
                        let is_retryable =
                            matches!(e.downcast_ref::<AppError>(), Some(err) if err.is_retryable());

                        // Send error event
                        let error_event = StreamEvent::Error {
                            session_id: session_id.clone(),
                            message_id: Some(message_id.clone()),
                            error: error_msg,
                            retryable: is_retryable,
                        };
                        let _ = event_sender.send(error_event);

                        if !is_retryable || retry_count >= config.max_retries {
                            break;
                        }

                        retry_count += 1;
                        tokio::time::sleep(Duration::from_secs(2u64.pow(retry_count))).await;
                    }
                }
            }

            // Send end event if we have accumulated content
            if !accumulated_content.is_empty() {
                let end_event = StreamEvent::End {
                    session_id,
                    message_id,
                };
                let _ = event_sender.send(end_event);
            }
        });

        Ok(handle)
    }

    /// Attempt to establish and process a stream
    async fn attempt_stream(
        api_client: &Arc<ApiClient>,
        request: &StreamRequest,
        message_id: &str,
        session_id: &str,
        event_sender: &broadcast::Sender<StreamEvent>,
        config: &StreamConfig,
        accumulated_content: &mut String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Build the streaming URL
        let server_url = {
            let url_guard = api_client.server_url.read().await;
            url_guard.clone().ok_or_else(|| AppError::ConnectionError {
                message: "No server URL configured".to_string(),
                details: "Server URL has not been set".to_string(),
            })?
        };

        let stream_url = format!("{}/session/{}/stream", server_url, request.session_id);

        // Create EventSource connection
        let event_source = EventSource::builder()
            .method(reqwest::Method::POST)
            .header("Content-Type", "application/json")
            .body(serde_json::to_string(request)?)
            .url(&stream_url)
            .build()
            .map_err(|e| AppError::ConnectionError {
                message: "Failed to create EventSource".to_string(),
                details: e.to_string(),
            })?;

        // Process events with timeout
        let mut event_stream = event_source
            .stream()
            .map_err(|e| AppError::ConnectionError {
                message: "Failed to create event stream".to_string(),
                details: e.to_string(),
            })?;

        let mut chunk_index = 0;

        while let Some(event_result) = timeout(
            Duration::from_secs(config.chunk_timeout_secs),
            event_stream.next(),
        )
        .await
        .map_err(|_| AppError::TimeoutError {
            operation: "Waiting for stream chunk".to_string(),
            timeout_secs: config.chunk_timeout_secs,
        })? {
            match event_result {
                Ok(event) => {
                    match event {
                        reqwest::sse::Event::Message(message) => {
                            // Parse the chunk
                            if let Ok(chunk_data) =
                                serde_json::from_str::<serde_json::Value>(&message.data)
                            {
                                if let Some(content) =
                                    chunk_data.get("content").and_then(|v| v.as_str())
                                {
                                    accumulated_content.push_str(content);

                                    // Send chunk event
                                    let chunk_event = StreamEvent::Chunk {
                                        session_id: session_id.to_string(),
                                        message_id: message_id.to_string(),
                                        content: content.to_string(),
                                        index: chunk_index,
                                    };
                                    let _ = event_sender.send(chunk_event);
                                    chunk_index += 1;
                                }

                                // Check for completion
                                if let Some(done) = chunk_data.get("done").and_then(|v| v.as_bool())
                                {
                                    if done {
                                        // Send completion event
                                        let complete_event = StreamEvent::Complete {
                                            session_id: session_id.to_string(),
                                            message_id: message_id.to_string(),
                                            final_content: accumulated_content.clone(),
                                            metadata: chunk_data.get("metadata").cloned(),
                                        };
                                        let _ = event_sender.send(complete_event);
                                        break;
                                    }
                                }
                            }
                        }
                        reqwest::sse::Event::Open => {
                            // Connection opened - could send a status event if needed
                        }
                        reqwest::sse::Event::Error(error) => {
                            return Err(AppError::ConnectionError {
                                message: "Server-sent event error".to_string(),
                                details: error.to_string(),
                            }
                            .into());
                        }
                    }
                }
                Err(e) => {
                    return Err(AppError::ConnectionError {
                        message: "Stream event error".to_string(),
                        details: e.to_string(),
                    }
                    .into());
                }
            }
        }

        Ok(())
    }

    /// Clean up completed streams
    pub async fn cleanup_completed_streams(&self) {
        let mut active_streams = self.active_streams.write().await;
        let mut to_remove = Vec::new();

        for (stream_id, handle) in active_streams.iter() {
            if handle.is_finished() {
                to_remove.push(stream_id.clone());
            }
        }

        for stream_id in to_remove {
            active_streams.remove(&stream_id);
        }
    }

    /// Stop all active streams
    pub async fn stop_all_streams(&self) {
        let mut active_streams = self.active_streams.write().await;

        for (stream_id, handle) in active_streams.drain() {
            handle.abort();
        }
    }
}

/// Custom stream implementation for StreamEvent
pub struct EventStream {
    receiver: broadcast::Receiver<StreamEvent>,
}

impl EventStream {
    pub fn new(receiver: broadcast::Receiver<StreamEvent>) -> Self {
        Self { receiver }
    }
}

impl Stream for EventStream {
    type Item = StreamEvent;

    fn poll_next(mut self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        match self.receiver.try_recv() {
            Ok(event) => Poll::Ready(Some(event)),
            Err(broadcast::error::TryRecvError::Empty) => Poll::Pending,
            Err(broadcast::error::TryRecvError::Closed) => Poll::Ready(None),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api_client::ApiClient;
    use tempfile::TempDir;

    fn create_test_streaming_client() -> (StreamingClient, TempDir) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().to_path_buf();
        let api_client = Arc::new(ApiClient::new().expect("Failed to create ApiClient"));
        let client = StreamingClient::new(api_client).expect("Failed to create StreamingClient");
        (client, temp_dir)
    }

    #[test]
    fn test_streaming_client_creation() {
        let (client, _temp) = create_test_streaming_client();

        // Should have no active streams initially
        tokio::task::block_in_place(|| {
            tokio::runtime::Handle::current().block_on(async {
                let active = client.get_active_streams().await;
                assert!(active.is_empty());
            });
        });
    }

    #[test]
    fn test_stream_event_serialization() {
        let event = StreamEvent::Chunk {
            session_id: "test-session".to_string(),
            message_id: "test-message".to_string(),
            content: "Hello".to_string(),
            index: 0,
        };

        let json = serde_json::to_string(&event).expect("Should serialize StreamEvent");
        assert!(json.contains("Chunk"));
        assert!(json.contains("Hello"));

        let deserialized: StreamEvent =
            serde_json::from_str(&json).expect("Should deserialize StreamEvent");
        match deserialized {
            StreamEvent::Chunk { content, .. } => {
                assert_eq!(content, "Hello");
            }
            _ => panic!("Expected Chunk event"),
        }
    }

    #[test]
    fn test_stream_config_default() {
        let config = StreamConfig::default();
        assert_eq!(config.connect_timeout_secs, 30);
        assert_eq!(config.chunk_timeout_secs, 60);
        assert_eq!(config.max_retries, 3);
        assert!(config.auto_reconnect);
        assert_eq!(config.buffer_size, 100);
    }

    #[test]
    fn test_stream_request_structure() {
        let request = StreamRequest {
            session_id: "session-123".to_string(),
            content: "Test message".to_string(),
            model_config: None,
            system_prompt: Some("You are helpful".to_string()),
            temperature: Some(0.7),
            max_tokens: Some(1000),
        };

        assert_eq!(request.session_id, "session-123");
        assert_eq!(request.content, "Test message");
        assert_eq!(request.system_prompt, Some("You are helpful".to_string()));
        assert_eq!(request.temperature, Some(0.7));
        assert_eq!(request.max_tokens, Some(1000));
    }

    #[tokio::test]
    async fn test_event_subscription() {
        let (client, _temp) = create_test_streaming_client();
        let mut receiver = client.subscribe();

        // Send a test event
        let test_event = StreamEvent::Start {
            session_id: "test".to_string(),
            message_id: "msg-123".to_string(),
            role: MessageRole::User,
        };

        let _ = client.event_sender.send(test_event.clone());

        // Receive the event
        let received = tokio::time::timeout(Duration::from_secs(1), receiver.recv()).await;
        assert!(received.is_ok(), "Should receive event");

        let event = received
            .unwrap()
            .expect("Should successfully receive event");
        match event {
            StreamEvent::Start { session_id, .. } => {
                assert_eq!(session_id, "test");
            }
            _ => panic!("Expected Start event"),
        }
    }

    #[tokio::test]
    async fn test_active_stream_management() {
        let (client, _temp) = create_test_streaming_client();

        // Initially no active streams
        let active = client.get_active_streams().await;
        assert!(active.is_empty());

        // Mock a stream by creating a dummy task
        let stream_id = "test-stream".to_string();
        let handle = tokio::spawn(async {
            tokio::time::sleep(Duration::from_secs(1)).await;
        });

        let mut active_streams = client.active_streams.write().await;
        active_streams.insert(stream_id.clone(), handle);
        drop(active_streams);

        // Should now have one active stream
        let active = client.get_active_streams().await;
        assert_eq!(active.len(), 1);
        assert!(active.contains(&stream_id));

        // Stop the stream
        client
            .stop_stream(&stream_id)
            .await
            .expect("Should stop stream");

        // Should have no active streams
        let active = client.get_active_streams().await;
        assert!(active.is_empty());
    }

    #[tokio::test]
    async fn test_cleanup_completed_streams() {
        let (client, _temp) = create_test_streaming_client();

        // Add a completed task
        let stream_id = "completed-stream".to_string();
        let handle = tokio::spawn(async {});

        // Wait for task to complete
        tokio::time::sleep(Duration::from_millis(10)).await;

        let mut active_streams = client.active_streams.write().await;
        active_streams.insert(stream_id.clone(), handle);
        drop(active_streams);

        // Should show as active before cleanup
        let active = client.get_active_streams().await;
        assert_eq!(active.len(), 1);

        // Cleanup
        client.cleanup_completed_streams().await;

        // Should be empty after cleanup
        let active = client.get_active_streams().await;
        assert!(active.is_empty());
    }

    #[tokio::test]
    async fn test_stop_all_streams() {
        let (client, _temp) = create_test_streaming_client();

        // Add multiple streams
        for i in 1..=3 {
            let stream_id = format!("stream-{}", i);
            let handle = tokio::spawn(async {
                tokio::time::sleep(Duration::from_secs(10)).await;
            });

            let mut active_streams = client.active_streams.write().await;
            active_streams.insert(stream_id, handle);
            drop(active_streams);
        }

        // Should have 3 active streams
        let active = client.get_active_streams().await;
        assert_eq!(active.len(), 3);

        // Stop all
        client.stop_all_streams().await;

        // Should have no active streams
        let active = client.get_active_streams().await;
        assert!(active.is_empty());
    }
}
