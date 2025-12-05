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

use crate::connection_manager::{ConnectionEvent, ConnectionEventType};
use crate::session_manager::{ChatMessage, ChatSession, MessageRole};
use crate::streaming_client::StreamEvent;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use tokio::sync::{broadcast, RwLock};

/// Unified event type for all application events
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "event_type")]
pub enum AppEvent {
    /// Connection-related events
    Connection {
        event_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
        data: ConnectionEventData,
    },
    /// Chat session events
    Session {
        event_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
        data: SessionEventData,
    },
    /// Message events
    Message {
        event_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
        data: MessageEventData,
    },
    /// Streaming events
    Stream {
        event_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
        data: StreamEventData,
    },
    /// Application lifecycle events
    Application {
        event_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
        data: ApplicationEventData,
    },
    /// Error events
    Error {
        event_id: String,
        timestamp: chrono::DateTime<chrono::Utc>,
        data: ErrorEventData,
    },
}

/// Connection event data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ConnectionEventData {
    Connected {
        server_url: String,
        server_info: Option<ServerInfo>,
    },
    Disconnected {
        reason: Option<String>,
    },
    Connecting {
        server_url: String,
    },
    Error {
        error: String,
        server_url: Option<String>,
        retryable: bool,
    },
    HealthCheck {
        status: String,
        latency_ms: Option<u64>,
    },
}

/// Session event data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum SessionEventData {
    Created {
        session: ChatSession,
    },
    Updated {
        session_id: String,
        changes: HashMap<String, serde_json::Value>,
    },
    Deleted {
        session_id: String,
    },
    Selected {
        session_id: String,
    },
    Listed {
        sessions: Vec<ChatSession>,
    },
}

/// Message event data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum MessageEventData {
    Sent {
        session_id: String,
        message: ChatMessage,
    },
    Received {
        session_id: String,
        message: ChatMessage,
    },
    Updated {
        session_id: String,
        message_id: String,
        changes: HashMap<String, serde_json::Value>,
    },
    Deleted {
        session_id: String,
        message_id: String,
    },
}

/// Stream event data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum StreamEventData {
    Started {
        session_id: String,
        stream_id: String,
        message_id: String,
    },
    Chunk {
        session_id: String,
        stream_id: String,
        message_id: String,
        content: String,
        index: usize,
    },
    Completed {
        session_id: String,
        stream_id: String,
        message_id: String,
        final_content: String,
    },
    Error {
        session_id: String,
        stream_id: String,
        error: String,
        retryable: bool,
    },
    Stopped {
        session_id: String,
        stream_id: String,
    },
}

/// Application event data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ApplicationEventData {
    Started {
        version: String,
    },
    Ready {
        features: Vec<String>,
    },
    Shutdown {
        reason: Option<String>,
    },
    ConfigChanged {
        key: String,
        value: serde_json::Value,
    },
}

/// Error event data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ErrorEventData {
    Network {
        error: String,
        context: String,
        retryable: bool,
    },
    Authentication {
        error: String,
        context: String,
    },
    Validation {
        field: String,
        error: String,
        value: Option<serde_json::Value>,
    },
    Session {
        session_id: String,
        error: String,
    },
    Internal {
        error: String,
        component: String,
        details: Option<String>,
    },
}

/// Server information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub name: String,
    pub version: Option<String>,
    pub url: String,
    pub features: Option<Vec<String>>,
}

/// Event bridge for converting and emitting events to frontend
pub struct EventBridge {
    app_handle: Option<Arc<AppHandle>>,
    event_sender: broadcast::Sender<AppEvent>,
    subscribers: Arc<RwLock<HashMap<String, broadcast::Sender<AppEvent>>>>,
}

impl EventBridge {
    /// Create a new event bridge
    pub fn new() -> Self {
        let (event_sender, _) = broadcast::channel(1000);

        Self {
            app_handle: None,
            event_sender,
            subscribers: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Create event bridge with app handle
    pub fn with_app_handle(app_handle: AppHandle) -> Self {
        let (event_sender, _) = broadcast::channel(1000);

        Self {
            app_handle: Some(Arc::new(app_handle)),
            event_sender,
            subscribers: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Subscribe to all events
    pub fn subscribe(&self) -> broadcast::Receiver<AppEvent> {
        self.event_sender.subscribe()
    }

    /// Subscribe to specific event type
    pub async fn subscribe_to_type(&self, event_type: &str) -> broadcast::Receiver<AppEvent> {
        let subscriber_id = format!("{}-{}", event_type, uuid::Uuid::new_v4());
        let (sender, receiver) = broadcast::channel(100);

        let mut subscribers = self.subscribers.write().await;
        subscribers.insert(subscriber_id, sender);

        receiver
    }

    /// Emit an event to all subscribers and frontend
    pub async fn emit(&self, event: AppEvent) -> Result<(), Box<dyn std::error::Error>> {
        // Send to all subscribers
        let _ = self.event_sender.send(event.clone());

        // Send to type-specific subscribers
        let event_type = match &event {
            AppEvent::Connection { .. } => "connection",
            AppEvent::Session { .. } => "session",
            AppEvent::Message { .. } => "message",
            AppEvent::Stream { .. } => "stream",
            AppEvent::Application { .. } => "application",
            AppEvent::Error { .. } => "error",
        };

        let subscribers = self.subscribers.read().await;
        for (id, sender) in subscribers.iter() {
            if id.starts_with(event_type) {
                let _ = sender.send(event.clone());
            }
        }

        // Emit to frontend via Tauri
        if let Some(app_handle) = &self.app_handle {
            let event_name = match &event {
                AppEvent::Connection { .. } => "connection-event",
                AppEvent::Session { .. } => "session-event",
                AppEvent::Message { .. } => "message-event",
                AppEvent::Stream { .. } => "stream-event",
                AppEvent::Application { .. } => "application-event",
                AppEvent::Error { .. } => "error-event",
            };

            app_handle.emit(event_name, &event)?;
        }

        Ok(())
    }

    /// Convert connection event to app event
    pub fn connection_to_app_event(&self, connection_event: ConnectionEvent) -> AppEvent {
        let data = match connection_event.event_type {
            ConnectionEventType::Connected => ConnectionEventData::Connected {
                server_url: "Unknown".to_string(), // Would be populated from actual connection
                server_info: None,
            },
            ConnectionEventType::Disconnected => ConnectionEventData::Disconnected {
                reason: Some(connection_event.message),
            },
            ConnectionEventType::Error => ConnectionEventData::Error {
                error: connection_event.message,
                server_url: None,
                retryable: true,
            },
            ConnectionEventType::HealthCheck => ConnectionEventData::HealthCheck {
                status: connection_event.message,
                latency_ms: None,
            },
        };

        AppEvent::Connection {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::DateTime::from(connection_event.timestamp),
            data,
        }
    }

    /// Convert stream event to app event
    pub fn stream_to_app_event(&self, stream_event: StreamEvent, session_id: String) -> AppEvent {
        let data = match stream_event {
            StreamEvent::Start { message_id, .. } => StreamEventData::Started {
                session_id: session_id.clone(),
                stream_id: uuid::Uuid::new_v4().to_string(),
                message_id,
            },
            StreamEvent::Chunk { message_id, content, index, .. } => StreamEventData::Chunk {
                session_id: session_id.clone(),
                stream_id: uuid::Uuid::new_v4().to_string(),
                message_id,
                content,
                index,
            },
            StreamEvent::Complete { message_id, final_content, .. } => StreamEventData::Completed {
                session_id: session_id.clone(),
                stream_id: uuid::Uuid::new_v4().to_string(),
                message_id,
                final_content,
            },
            StreamEvent::Error { message_id, error, retryable, .. } => StreamEventData::Error {
                session_id: session_id.clone(),
                stream_id: uuid::Uuid::new_v4().to_string(),
                error,
                retryable,
            },
            StreamEvent::End { message_id, .. } => StreamEventData::Stopped {
                session_id: session_id.clone(),
                stream_id: uuid::Uuid::new_v4().to_string(),
                message_id,
            },
        };

        AppEvent::Stream {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            data,
        }
    }

    /// Emit connection event
    pub async fn emit_connection_event(&self, connection_event: ConnectionEvent) -> Result<(), Box<dyn std::error::Error>> {
        let app_event = self.connection_to_app_event(connection_event);
        self.emit(app_event).await
    }

    /// Emit session created event
    pub async fn emit_session_created(&self, session: ChatSession) -> Result<(), Box<dyn std::error::Error>> {
        let event = AppEvent::Session {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            data: SessionEventData::Created { session },
        };
        self.emit(event).await
    }

    /// Emit session selected event
    pub async fn emit_session_selected(&self, session_id: String) -> Result<(), Box<dyn std::error::Error>> {
        let event = AppEvent::Session {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            data: SessionEventData::Selected { session_id },
        };
        self.emit(event).await
    }

    /// Emit message received event
    pub async fn emit_message_received(&self, session_id: String, message: ChatMessage) -> Result<(), Box<dyn std::error::Error>> {
        let event = AppEvent::Message {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            data: MessageEventData::Received { session_id, message },
        };
        self.emit(event).await
    }

    /// Emit stream event
    pub async fn emit_stream_event(&self, stream_event: StreamEvent, session_id: String) -> Result<(), Box<dyn std::error::Error>> {
        let app_event = self.stream_to_app_event(stream_event, session_id);
        self.emit(app_event).await
    }

    /// Emit error event
    pub async fn emit_error(&self, error_data: ErrorEventData) -> Result<(), Box<dyn std::error::Error>> {
        let event = AppEvent::Error {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            data: error_data,
        };
        self.emit(event).await
    }

    /// Emit application ready event
    pub async fn emit_application_ready(&self, features: Vec<String>) -> Result<(), Box<dyn std::error::Error>> {
        let event = AppEvent::Application {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now(),
            data: ApplicationEventData::Ready { features },
        };
        self.emit(event).await
    }

    /// Get number of active subscribers
    pub async fn subscriber_count(&self) -> usize {
        let subscribers = self.subscribers.read().await;
        subscribers.len()
    }

    /// Clean up inactive subscribers
    pub async fn cleanup_subscribers(&self) {
        let mut subscribers = self.subscribers.write().await;
        let mut to_remove = Vec::new();

        for (id, sender) in subscribers.iter() {
            if sender.receiver_count() == 0 {
                to_remove.push(id.clone());
            }
        }

        for id in to_remove {
            subscribers.remove(&id);
        }
    }
}

impl Default for EventBridge {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use std::time::SystemTime;

    #[test]
    fn test_event_bridge_creation() {
        let bridge = EventBridge::new();
        assert!(bridge.app_handle.is_none());
        assert_eq!(bridge.subscriber_count().now_or_never(), Some(0));
    }

    #[test]
    fn test_app_event_serialization() {
        let event = AppEvent::Connection {
            event_id: "test-123".to_string(),
            timestamp: Utc::now(),
            data: ConnectionEventData::Connected {
                server_url: "https://example.com".to_string(),
                server_info: None,
            },
        };

        let json = serde_json::to_string(&event).expect("Should serialize AppEvent");
        assert!(json.contains("Connection"));
        assert!(json.contains("https://example.com"));

        let deserialized: AppEvent = serde_json::from_str(&json).expect("Should deserialize AppEvent");
        match deserialized {
            AppEvent::Connection { data, .. } => {
                match data {
                    ConnectionEventData::Connected { server_url, .. } => {
                        assert_eq!(server_url, "https://example.com");
                    }
                    _ => panic!("Expected Connected event data"),
                }
            }
            _ => panic!("Expected Connection event"),
        }
    }

    #[test]
    fn test_connection_event_conversion() {
        let bridge = EventBridge::new();
        
        let connection_event = ConnectionEvent {
            timestamp: SystemTime::now(),
            event_type: ConnectionEventType::Connected,
            message: "Connected successfully".to_string(),
        };

        let app_event = bridge.connection_to_app_event(connection_event);
        
        match app_event {
            AppEvent::Connection { data, .. } => {
                match data {
                    ConnectionEventData::Connected { server_url, .. } => {
                        assert_eq!(server_url, "Unknown");
                    }
                    _ => panic!("Expected Connected data"),
                }
            }
            _ => panic!("Expected Connection event"),
        }
    }

    #[test]
    fn test_stream_event_conversion() {
        let bridge = EventBridge::new();
        
        let stream_event = StreamEvent::Chunk {
            session_id: "session-123".to_string(),
            message_id: "message-456".to_string(),
            content: "Hello".to_string(),
            index: 0,
        };

        let app_event = bridge.stream_to_app_event(stream_event, "session-123".to_string());
        
        match app_event {
            AppEvent::Stream { data, .. } => {
                match data {
                    StreamEventData::Chunk { content, index, .. } => {
                        assert_eq!(content, "Hello");
                        assert_eq!(index, 0);
                    }
                    _ => panic!("Expected Chunk data"),
                }
            }
            _ => panic!("Expected Stream event"),
        }
    }

    #[tokio::test]
    async fn test_event_subscription() {
        let bridge = EventBridge::new();
        let mut receiver = bridge.subscribe();

        let test_event = AppEvent::Application {
            event_id: "test-app".to_string(),
            timestamp: Utc::now(),
            data: ApplicationEventData::Started {
                version: "1.0.0".to_string(),
            },
        };

        // Emit event
        bridge.emit(test_event).await.expect("Should emit event");

        // Receive event
        let received = tokio::time::timeout(Duration::from_secs(1), receiver.recv()).await;
        assert!(received.is_ok(), "Should receive event");
        
        let event = received.unwrap().expect("Should successfully receive event");
        match event {
            AppEvent::Application { data, .. } => {
                match data {
                    ApplicationEventData::Started { version } => {
                        assert_eq!(version, "1.0.0");
                    }
                    _ => panic!("Expected Started data"),
                }
            }
            _ => panic!("Expected Application event"),
        }
    }

    #[tokio::test]
    async fn test_type_specific_subscription() {
        let bridge = EventBridge::new();
        let mut receiver = bridge.subscribe_to_type("connection").await;

        let test_event = AppEvent::Connection {
            event_id: "test-conn".to_string(),
            timestamp: Utc::now(),
            data: ConnectionEventData::Disconnected {
                reason: Some("Test disconnect".to_string()),
            },
        };

        // Emit event
        bridge.emit(test_event).await.expect("Should emit event");

        // Receive event
        let received = tokio::time::timeout(Duration::from_secs(1), receiver.recv()).await;
        assert!(received.is_ok(), "Should receive type-specific event");
        
        let event = received.unwrap().expect("Should successfully receive event");
        match event {
            AppEvent::Connection { data, .. } => {
                match data {
                    ConnectionEventData::Disconnected { reason } => {
                        assert_eq!(reason, Some("Test disconnect".to_string()));
                    }
                    _ => panic!("Expected Disconnected data"),
                }
            }
            _ => panic!("Expected Connection event"),
        }
    }

    #[tokio::test]
    async fn test_subscriber_count() {
        let bridge = EventBridge::new();
        
        // Initially no subscribers
        assert_eq!(bridge.subscriber_count().await, 0);

        // Add subscribers
        let _receiver1 = bridge.subscribe();
        let _receiver2 = bridge.subscribe_to_type("connection").await;
        
        // Should have 2 subscribers
        assert_eq!(bridge.subscriber_count().await, 2);
    }

    #[tokio::test]
    async fn test_cleanup_subscribers() {
        let bridge = EventBridge::new();
        
        // Add subscriber
        {
            let _receiver = bridge.subscribe();
            assert_eq!(bridge.subscriber_count().await, 1);
        } // Receiver goes out of scope

        // Cleanup should remove inactive subscriber
        bridge.cleanup_subscribers().await;
        assert_eq!(bridge.subscriber_count().await, 0);
    }

    #[test]
    fn test_error_event_data() {
        let error_data = ErrorEventData::Network {
            error: "Connection failed".to_string(),
            context: "Sending message".to_string(),
            retryable: true,
        };

        let json = serde_json::to_string(&error_data).expect("Should serialize ErrorEventData");
        assert!(json.contains("Network"));
        assert!(json.contains("Connection failed"));

        let deserialized: ErrorEventData = serde_json::from_str(&json).expect("Should deserialize ErrorEventData");
        match deserialized {
            ErrorEventData::Network { error, context, retryable } => {
                assert_eq!(error, "Connection failed");
                assert_eq!(context, "Sending message");
                assert!(retryable);
            }
            _ => panic!("Expected Network error data"),
        }
    }
}