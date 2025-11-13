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

// Example usage of the updated ChatClient with OpenCode API integration

use crate::chat_client::{ChatClient, ChatEvent};
use tokio::sync::broadcast;
use std::path::PathBuf;

pub async fn example_usage() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize the chat client
    let config_dir = dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("opencode-nexus");
    
    let mut client = ChatClient::new(config_dir)?;

    // Set the OpenCode server URL
    client.set_server_url("http://localhost:4096".to_string());

    // Subscribe to real-time events
    let mut event_receiver = client.subscribe_to_events().await?;

    // Spawn a task to handle events
    let event_sender = client.event_sender.clone();
    tokio::spawn(async move {
        while let Ok(event) = event_receiver.recv().await {
            match event {
                ChatEvent::MessageReceived { session_id, message } => {
                    println!("New message in session {}: {}", session_id, message.content);
                }
                ChatEvent::MessageChunk { session_id, chunk } => {
                    print!("Chunk from {}: {}", session_id, chunk);
                }
                ChatEvent::SessionCreated { session } => {
                    println!("Created session: {:?}", session.title);
                }
                ChatEvent::Error { message } => {
                    eprintln!("Error: {}", message);
                }
            }
        }
    });

    // Load existing sessions from disk
    client.load_sessions()?;

    // Sync sessions from server
    let server_sessions = client.list_sessions_from_server().await?;
    println!("Found {} sessions on server", server_sessions.len());

    // Create a new session
    let new_session = client.create_session(Some("My OpenCode Session")).await?;
    println!("Created session: {}", new_session.id);

    // Send a message
    client.send_message(&new_session.id, "Hello, OpenCode!").await?;

    // Get session history from server
    let messages = client.get_session_messages_from_server(&new_session.id).await?;
    println!("Session has {} messages", messages.len());

    // Wait for a bit to receive streaming responses
    tokio::time::sleep(tokio::time::Duration::from_secs(10)).await;

    Ok(())
}

// Helper function to configure model for a message
pub fn create_message_request(content: &str, provider_id: &str, model_id: &str) -> serde_json::Value {
    serde_json::json!({
        "model": {
            "provider_id": provider_id,
            "model_id": model_id
        },
        "parts": [
            {
                "type": "text",
                "text": content
            }
        ]
    })
}

// Example of using different providers
pub async fn send_message_with_provider(
    client: &mut ChatClient,
    session_id: &str,
    content: &str,
    provider_id: &str,
    model_id: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let server_url = client.server_url.as_ref()
        .ok_or("Server URL not set")?;

    let request = create_message_request(content, provider_id, model_id);
    
    let url = format!("{}/session/{}/prompt", server_url, session_id);
    let response = client.client.post(&url)
        .json(&request)
        .send()
        .await?;

    if !response.status().is_success() {
        return Err(format!("API error: {}", response.status()).into());
    }

    println!("Message sent with provider: {}/{}", provider_id, model_id);
    Ok(())
}