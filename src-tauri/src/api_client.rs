use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

/// HTTP client for communicating with the OpenCode server API
///
/// Design Decisions:
/// - Uses reqwest for HTTP client due to its async support and JSON handling
/// - 30-second timeout to prevent hanging requests
/// - User-Agent header for server identification
/// - Generic error handling with String return type for Tauri compatibility
/// - Connection pooling enabled for performance
#[derive(Debug, Clone)]
pub struct ApiClient {
    pub client: Client,
    pub base_url: String,
    pub timeout: Duration,
}

impl ApiClient {
    /// Creates a new ApiClient with the specified base URL
    ///
    /// # Arguments
    /// * `base_url` - The base URL of the OpenCode server (e.g., "http://localhost:4096")
    ///
    /// # Returns
    /// * `Ok(ApiClient)` if creation succeeds
    /// * `Err(String)` if the URL is invalid or client creation fails
    ///
    /// Design Decision: Validates URL format during construction to catch configuration errors early
    pub fn new(base_url: &str) -> Result<Self, String> {
        // Validate URL format
        if !base_url.starts_with("http://") && !base_url.starts_with("https://") {
            return Err("Base URL must start with http:// or https://".to_string());
        }

        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .user_agent("OpenCode-Nexus/1.0")
            .build()
            .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

        Ok(Self {
            client,
            base_url: base_url.to_string(),
            timeout: Duration::from_secs(30),
        })
    }

    /// Makes a GET request to the specified endpoint
    ///
    /// # Arguments
    /// * `endpoint` - The API endpoint (e.g., "/app")
    ///
    /// # Returns
    /// * `Ok(T)` if the request succeeds and response is valid JSON
    /// * `Err(String)` if the request fails or response is invalid
    ///
    /// Design Decision: Generic return type allows flexible response handling
    /// Design Decision: Automatic JSON deserialization for API responses
    /// Design Decision: User-friendly error messages for Tauri integration
    pub async fn get<T: for<'de> Deserialize<'de>>(&self, endpoint: &str) -> Result<T, String> {
        let url = format!("{}{}", self.base_url, endpoint);

        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("Request failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("API error: {} - {}", response.status(), response.status().canonical_reason().unwrap_or("Unknown error")));
        }

        response
            .json::<T>()
            .await
            .map_err(|e| format!("Failed to parse response JSON: {}", e))
    }

    /// Makes a POST request to the specified endpoint with a JSON body
    ///
    /// # Arguments
    /// * `endpoint` - The API endpoint (e.g., "/session")
    /// * `body` - The request body that can be serialized to JSON
    ///
    /// # Returns
    /// * `Ok(T)` if the request succeeds and response is valid JSON
    /// * `Err(String)` if the request fails or response is invalid
    ///
    /// Design Decision: Generic body type allows flexible request structures
    /// Design Decision: Automatic JSON serialization for request bodies
    /// Design Decision: Consistent error handling pattern with GET requests
    pub async fn post<T: for<'de> Deserialize<'de>, B: Serialize>(
        &self,
        endpoint: &str,
        body: &B,
    ) -> Result<T, String> {
        let url = format!("{}{}", self.base_url, endpoint);

        let response = self.client
            .post(&url)
            .json(body)
            .send()
            .await
            .map_err(|e| format!("Request failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("API error: {} - {}", response.status(), response.status().canonical_reason().unwrap_or("Unknown error")));
        }

        response
            .json::<T>()
            .await
            .map_err(|e| format!("Failed to parse response JSON: {}", e))
    }

    /// Makes a DELETE request to the specified endpoint
    ///
    /// # Arguments
    /// * `endpoint` - The API endpoint (e.g., "/session/123")
    ///
    /// # Returns
    /// * `Ok(T)` if the request succeeds and response is valid JSON
    /// * `Err(String)` if the request fails or response is invalid
    ///
    /// Design Decision: Generic return type allows flexible response handling
    /// Design Decision: Consistent error handling pattern with other methods
    pub async fn delete<T: for<'de> Deserialize<'de>>(&self, endpoint: &str) -> Result<T, String> {
        let url = format!("{}{}", self.base_url, endpoint);

        let response = self.client
            .delete(&url)
            .send()
            .await
            .map_err(|e| format!("Request failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("API error: {} - {}", response.status(), response.status().canonical_reason().unwrap_or("Unknown error")));
        }

        response
            .json::<T>()
            .await
            .map_err(|e| format!("Failed to parse response JSON: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_api_client_creation_valid_url() {
        let result = ApiClient::new("http://localhost:4096");
        assert!(result.is_ok());

        let client = result.unwrap();
        assert_eq!(client.base_url, "http://localhost:4096");
        assert_eq!(client.timeout, Duration::from_secs(30));
    }

    #[test]
    fn test_api_client_creation_invalid_url() {
        let result = ApiClient::new("invalid-url");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("must start with"));
    }

    #[test]
    fn test_api_client_creation_https_url() {
        let result = ApiClient::new("https://opencode.example.com");
        assert!(result.is_ok());

        let client = result.unwrap();
        assert_eq!(client.base_url, "https://opencode.example.com");
    }
}