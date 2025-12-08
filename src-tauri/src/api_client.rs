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

use crate::error::AppError;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use url::Url;

/// Configuration for a specific model provider
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelConfig {
    pub provider_id: String,
    pub model_id: String,
}

/// Information about an available model
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelInfo {
    pub id: String,
    pub model_id: String,
    pub name: String,
    pub provider_id: String,
    pub provider_name: String,
}

/// Provider information from the server
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderInfo {
    pub id: String,
    pub name: String,
    pub models: Vec<ModelInfo>,
}

/// Response from /config/providers endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProvidersResponse {
    pub providers: Vec<ProviderConfig>,
    pub default: HashMap<String, String>,
}

/// Provider configuration from server
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderConfig {
    pub id: String,
    pub models: Vec<ModelConfig>,
}

/// API client for OpenCode server communication
pub struct ApiClient {
    client: Client,
    server_url: Arc<RwLock<Option<String>>>,
    api_key: Arc<RwLock<Option<String>>>,
}

impl ApiClient {
    /// Create a new API client
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let client = Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

        Ok(Self {
            client,
            server_url: Arc::new(RwLock::new(None)),
            api_key: Arc::new(RwLock::new(None)),
        })
    }

    /// Set the server URL for all subsequent requests
    pub async fn set_server_url(&self, url: String) -> Result<(), Box<dyn std::error::Error>> {
        // Validate URL format
        let _parsed = Url::parse(&url).map_err(|e| format!("Invalid server URL: {}", e))?;

        *self.server_url.write().await = Some(url);
        Ok(())
    }

    /// Set the API key for authenticated requests
    pub async fn set_api_key(&self, api_key: String) {
        *self.api_key.write().await = Some(api_key);
    }

    /// Get the current server URL (public getter for other modules)
    pub async fn get_server_url(&self) -> Option<String> {
        self.server_url.read().await.clone()
    }

    /// Get the current server URL, or return an error if not set
    async fn require_server_url(&self) -> Result<String, Box<dyn std::error::Error>> {
        self.server_url.read().await.clone().ok_or_else(|| {
            AppError::ConnectionError {
                message: "No server URL configured".to_string(),
                details: Some("Server URL has not been set".to_string()),
            }
            .into()
        })
    }

    /// Get the current API key
    async fn get_api_key(&self) -> Option<String> {
        self.api_key.read().await.clone()
    }

    /// Build a request with authentication headers
    async fn build_request(
        &self,
        method: reqwest::Method,
        path: &str,
    ) -> Result<reqwest::RequestBuilder, Box<dyn std::error::Error>> {
        let base_url = self.require_server_url().await?;
        let url = format!(
            "{}/{}",
            base_url.trim_end_matches('/'),
            path.trim_start_matches('/')
        );

        let mut request = self.client.request(method, &url);

        // Add API key if available
        if let Some(api_key) = self.get_api_key().await {
            request = request.header("Authorization", format!("Bearer {}", api_key));
        }

        Ok(request)
    }

    /// Get available models from the server
    pub async fn get_available_models(&self) -> Result<Vec<ModelInfo>, Box<dyn std::error::Error>> {
        let request = self
            .build_request(reqwest::Method::GET, "config/providers")
            .await?;

        let response = request.send().await.map_err(|e| AppError::NetworkError {
            message: "Failed to fetch providers".to_string(),
            details: e.to_string(),
            retry_after: Some(2),
        })?;

        if !response.status().is_success() {
            return Err(AppError::ServerError {
                status_code: response.status().as_u16(),
                message: format!("Server responded with status: {}", response.status()),
                details: response.text().await.unwrap_or_default(),
            }
            .into());
        }

        let providers_response: ProvidersResponse =
            response.json().await.map_err(|e| AppError::ParseError {
                message: "Failed to parse providers response".to_string(),
                details: Some(e.to_string()),
            })?;

        // Convert to flat list of ModelInfo
        let mut models = Vec::new();
        for provider in providers_response.providers {
            for model in provider.models {
                let model_info = ModelInfo {
                    id: format!("{}/{}", provider.id, model.model_id),
                    model_id: model.model_id.clone(),
                    name: model.model_id.clone(), // Use model_id as name for now
                    provider_id: provider.id.clone(),
                    provider_name: provider.id.clone(), // Use provider.id as name for now
                };
                models.push(model_info);
            }
        }

        Ok(models)
    }

    /// Get server health/status
    pub async fn get_health(&self) -> Result<ServerHealth, Box<dyn std::error::Error>> {
        let request = self.build_request(reqwest::Method::GET, "health").await?;

        let response = request.send().await.map_err(|e| AppError::NetworkError {
            message: "Failed to fetch health status".to_string(),
            details: e.to_string(),
            retry_after: Some(2),
        })?;

        if !response.status().is_success() {
            return Err(AppError::ServerError {
                status_code: response.status().as_u16(),
                message: format!("Server responded with status: {}", response.status()),
                details: response.text().await.unwrap_or_default(),
            }
            .into());
        }

        let health: ServerHealth = response.json().await.map_err(|e| AppError::ParseError {
            message: "Failed to parse health response".to_string(),
            details: Some(e.to_string()),
        })?;

        Ok(health)
    }

    /// Test connection to the server
    pub async fn test_connection(&self) -> Result<bool, Box<dyn std::error::Error>> {
        match self.get_health().await {
            Ok(_) => Ok(true),
            Err(_) => Ok(false),
        }
    }

    /// Get server information
    pub async fn get_server_info(&self) -> Result<ServerInfo, Box<dyn std::error::Error>> {
        let request = self.build_request(reqwest::Method::GET, "info").await?;

        let response = request.send().await.map_err(|e| AppError::NetworkError {
            message: "Failed to fetch server info".to_string(),
            details: e.to_string(),
            retry_after: Some(2),
        })?;

        if !response.status().is_success() {
            return Err(AppError::ServerError {
                status_code: response.status().as_u16(),
                message: format!("Server responded with status: {}", response.status()),
                details: response.text().await.unwrap_or_default(),
            }
            .into());
        }

        let info: ServerInfo = response.json().await.map_err(|e| AppError::ParseError {
            message: "Failed to parse server info".to_string(),
            details: Some(e.to_string()),
        })?;

        Ok(info)
    }
}

/// Server health information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerHealth {
    pub status: String,
    pub version: Option<String>,
    pub uptime: Option<u64>,
    pub timestamp: Option<String>,
}

/// Server information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub name: String,
    pub version: String,
    pub description: Option<String>,
    pub features: Option<Vec<String>>,
}

impl Default for ApiClient {
    fn default() -> Self {
        Self::new().expect("Failed to create ApiClient")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_api_client_creation() {
        let client = ApiClient::new();
        assert!(client.is_ok(), "ApiClient should be created successfully");
    }

    #[test]
    fn test_model_config_serialization() {
        let config = ModelConfig {
            provider_id: "anthropic".to_string(),
            model_id: "claude-3-5-sonnet-20241022".to_string(),
        };

        let json = serde_json::to_string(&config).expect("Should serialize ModelConfig");
        assert!(json.contains("anthropic"));
        assert!(json.contains("claude-3-5-sonnet-20241022"));

        let deserialized: ModelConfig =
            serde_json::from_str(&json).expect("Should deserialize ModelConfig");
        assert_eq!(deserialized.provider_id, "anthropic");
        assert_eq!(deserialized.model_id, "claude-3-5-sonnet-20241022");
    }

    #[test]
    fn test_model_info_structure() {
        let model = ModelInfo {
            id: "anthropic/claude-3-5-sonnet-20241022".to_string(),
            model_id: "claude-3-5-sonnet-20241022".to_string(),
            name: "Claude 3.5 Sonnet".to_string(),
            provider_id: "anthropic".to_string(),
            provider_name: "Anthropic".to_string(),
        };

        assert_eq!(model.provider_id, "anthropic");
        assert!(model.id.contains("/"));
        assert_eq!(model.name, "Claude 3.5 Sonnet");
    }

    #[tokio::test]
    async fn test_server_url_validation() {
        let client = ApiClient::new().expect("Should create client");

        // Valid URL should work
        let result = client
            .set_server_url("https://example.com".to_string())
            .await;
        assert!(result.is_ok(), "Valid URL should be accepted");

        // Invalid URL should fail
        let result = client.set_server_url("not-a-url".to_string()).await;
        assert!(result.is_err(), "Invalid URL should be rejected");
    }

    #[tokio::test]
    async fn test_api_key_management() {
        let client = ApiClient::new().expect("Should create client");

        // Initially no API key
        let api_key = client.get_api_key().await;
        assert!(api_key.is_none(), "Initially should have no API key");

        // Set API key
        client.set_api_key("test-key-123".to_string()).await;

        // Should now have API key
        let api_key = client.get_api_key().await;
        assert!(api_key.is_some(), "Should have API key after setting");
        assert_eq!(api_key.unwrap(), "test-key-123");
    }

    #[tokio::test]
    async fn test_server_url_required_for_operations() {
        let client = ApiClient::new().expect("Should create client");

        // Operations should fail without server URL
        let result = client.get_available_models().await;
        assert!(result.is_err(), "Should fail without server URL");

        let result = client.get_health().await;
        assert!(result.is_err(), "Should fail without server URL");

        let result = client.get_server_info().await;
        assert!(result.is_err(), "Should fail without server URL");
    }

    #[test]
    fn test_server_health_structure() {
        let health = ServerHealth {
            status: "healthy".to_string(),
            version: Some("1.0.0".to_string()),
            uptime: Some(3600),
            timestamp: Some("2025-01-01T00:00:00Z".to_string()),
        };

        assert_eq!(health.status, "healthy");
        assert_eq!(health.version, Some("1.0.0".to_string()));
        assert_eq!(health.uptime, Some(3600));
    }

    #[test]
    fn test_server_info_structure() {
        let info = ServerInfo {
            name: "OpenCode Server".to_string(),
            version: "1.0.0".to_string(),
            description: Some("Test server".to_string()),
            features: Some(vec!["chat".to_string(), "streaming".to_string()]),
        };

        assert_eq!(info.name, "OpenCode Server");
        assert_eq!(info.version, "1.0.0");
        assert!(info.description.is_some());
        assert!(info.features.as_ref().unwrap().len() == 2);
    }
}
