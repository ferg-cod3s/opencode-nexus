use reqwest::{Client, RequestBuilder};
use serde::{Deserialize, Serialize};
use std::time::Duration;

/// Authentication type for connecting to OpenCode servers
///
/// Design Decision: Support multiple auth methods to accommodate different deployment scenarios
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum AuthType {
    /// No authentication (local development only)
    None,
    /// Cloudflare Access Service Tokens for cloudflared tunnels
    CloudflareAccess,
    /// API Key authentication for reverse proxy setups
    ApiKey,
    /// Custom header authentication for extensibility
    CustomHeader,
}

/// Authentication credentials for server connections
///
/// Design Decision: Enum pattern allows type-safe credential storage
/// Security Note: Sensitive fields (secrets, keys) should be encrypted at rest
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuthCredentials {
    /// No credentials
    None,
    /// Cloudflare Access Service Token credentials
    CloudflareAccess {
        client_id: String,
        client_secret: String, // TODO: Encrypt at rest
    },
    /// API Key for reverse proxy authentication
    ApiKey {
        key: String, // TODO: Encrypt at rest
    },
    /// Custom header-based authentication
    CustomHeader {
        header_name: String,
        header_value: String, // TODO: Encrypt at rest
    },
}

/// HTTP client for communicating with the OpenCode server API
///
/// Design Decisions:
/// - Uses reqwest for HTTP client due to its async support and JSON handling
/// - 30-second timeout to prevent hanging requests
/// - User-Agent header for server identification
/// - Generic error handling with String return type for Tauri compatibility
/// - Connection pooling enabled for performance
/// - Supports multiple authentication methods (Cloudflare Access, API Key, Custom)
#[derive(Debug, Clone)]
pub struct ApiClient {
    pub client: Client,
    pub base_url: String,
    pub timeout: Duration,
    pub auth_type: AuthType,
    pub auth_credentials: AuthCredentials,
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
        Self::new_with_auth(base_url, AuthType::None, AuthCredentials::None)
    }

    /// Creates a new ApiClient with authentication
    ///
    /// # Arguments
    /// * `base_url` - The base URL of the OpenCode server
    /// * `auth_type` - The type of authentication to use
    /// * `auth_credentials` - The authentication credentials
    ///
    /// # Returns
    /// * `Ok(ApiClient)` if creation succeeds
    /// * `Err(String)` if the URL is invalid or client creation fails
    ///
    /// Design Decision: Separate method for auth to maintain backward compatibility
    pub fn new_with_auth(
        base_url: &str,
        auth_type: AuthType,
        auth_credentials: AuthCredentials,
    ) -> Result<Self, String> {
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
            auth_type,
            auth_credentials,
        })
    }

    /// Adds authentication headers to a request based on configured auth type
    ///
    /// # Arguments
    /// * `request` - The RequestBuilder to add headers to
    ///
    /// # Returns
    /// * `RequestBuilder` with authentication headers added
    ///
    /// Design Decision: Centralized auth header injection for consistency
    fn add_auth_headers(&self, request: RequestBuilder) -> RequestBuilder {
        match (&self.auth_type, &self.auth_credentials) {
            (AuthType::CloudflareAccess, AuthCredentials::CloudflareAccess { client_id, client_secret }) => {
                request
                    .header("CF-Access-Client-Id", client_id)
                    .header("CF-Access-Client-Secret", client_secret)
            }
            (AuthType::ApiKey, AuthCredentials::ApiKey { key }) => {
                request.header("X-API-Key", key)
            }
            (AuthType::CustomHeader, AuthCredentials::CustomHeader { header_name, header_value }) => {
                request.header(header_name, header_value)
            }
            _ => request, // No auth or mismatched type/credentials
        }
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

        let request = self.client.get(&url);
        let request = self.add_auth_headers(request);

        let response = request
            .send()
            .await
            .map_err(|e| format!("Request failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "API error: {} - {}",
                response.status(),
                response
                    .status()
                    .canonical_reason()
                    .unwrap_or("Unknown error")
            ));
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

        let request = self.client.post(&url).json(body);
        let request = self.add_auth_headers(request);

        let response = request
            .send()
            .await
            .map_err(|e| format!("Request failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "API error: {} - {}",
                response.status(),
                response
                    .status()
                    .canonical_reason()
                    .unwrap_or("Unknown error")
            ));
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

        let request = self.client.delete(&url);
        let request = self.add_auth_headers(request);

        let response = request
            .send()
            .await
            .map_err(|e| format!("Request failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!(
                "API error: {} - {}",
                response.status(),
                response
                    .status()
                    .canonical_reason()
                    .unwrap_or("Unknown error")
            ));
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
        assert_eq!(client.auth_type, AuthType::None);
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

    #[test]
    fn test_api_client_with_cloudflare_auth() {
        let result = ApiClient::new_with_auth(
            "https://opencode.example.com",
            AuthType::CloudflareAccess,
            AuthCredentials::CloudflareAccess {
                client_id: "test-client-id".to_string(),
                client_secret: "test-client-secret".to_string(),
            },
        );
        assert!(result.is_ok());

        let client = result.unwrap();
        assert_eq!(client.auth_type, AuthType::CloudflareAccess);
        match client.auth_credentials {
            AuthCredentials::CloudflareAccess { client_id, client_secret } => {
                assert_eq!(client_id, "test-client-id");
                assert_eq!(client_secret, "test-client-secret");
            }
            _ => panic!("Expected CloudflareAccess credentials"),
        }
    }

    #[test]
    fn test_api_client_with_api_key_auth() {
        let result = ApiClient::new_with_auth(
            "https://opencode.example.com",
            AuthType::ApiKey,
            AuthCredentials::ApiKey {
                key: "test-api-key".to_string(),
            },
        );
        assert!(result.is_ok());

        let client = result.unwrap();
        assert_eq!(client.auth_type, AuthType::ApiKey);
        match client.auth_credentials {
            AuthCredentials::ApiKey { key } => {
                assert_eq!(key, "test-api-key");
            }
            _ => panic!("Expected ApiKey credentials"),
        }
    }

    #[test]
    fn test_api_client_with_custom_header_auth() {
        let result = ApiClient::new_with_auth(
            "https://opencode.example.com",
            AuthType::CustomHeader,
            AuthCredentials::CustomHeader {
                header_name: "X-Custom-Auth".to_string(),
                header_value: "custom-value".to_string(),
            },
        );
        assert!(result.is_ok());

        let client = result.unwrap();
        assert_eq!(client.auth_type, AuthType::CustomHeader);
        match client.auth_credentials {
            AuthCredentials::CustomHeader { header_name, header_value } => {
                assert_eq!(header_name, "X-Custom-Auth");
                assert_eq!(header_value, "custom-value");
            }
            _ => panic!("Expected CustomHeader credentials"),
        }
    }
}
