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

// Copyright (c) 2025 OpenCode Nexus Contributors
// SPDX-License-Identifier: MIT

/// Comprehensive error handling for OpenCode Nexus
///
/// Provides structured error types with user-friendly messages,
/// retry logic with exponential backoff, and detailed error context.
use serde::{Deserialize, Serialize};
use std::fmt;
use std::future::Future;
use std::time::Duration;

/// Main error type for the application
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AppError {
    /// Network connection errors (DNS, timeout, refused, etc.)
    NetworkError {
        message: String,
        details: String,
        retry_after: Option<u64>, // seconds
    },
    /// Server returned an error response (4xx, 5xx)
    ServerError {
        status_code: u16,
        message: String,
        details: String,
    },
    /// Authentication/authorization failures
    AuthError { message: String, details: String },
    /// Invalid input or configuration
    ValidationError { field: String, message: String },
    /// Session not found or invalid
    SessionError { session_id: String, message: String },
    /// File system errors (read, write, permissions)
    FileSystemError {
        path: String,
        message: String,
        details: String,
    },
    /// Data parsing or serialization errors
    DataError { message: String, details: String },
    /// JSON parsing errors
    ParseError { message: String, details: String },
    /// I/O operation errors (file, network)
    IoError { message: String, details: String },
    /// Connection establishment errors
    ConnectionError { message: String, details: String },
    /// Server is not connected
    NotConnectedError { message: String },
    /// Operation timed out
    TimeoutError {
        operation: String,
        timeout_secs: u64,
    },
    /// Data parsing error (JSON, serialization)
    ParseError {
        message: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        details: Option<String>,
    },
    /// Connection/network error
    ConnectionError {
        message: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        details: Option<String>,
    },
    /// I/O operation error
    IoError {
        message: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        details: Option<String>,
    },
    /// Generic error with message
    Other { message: String },
}

impl AppError {
    /// Get user-friendly error message
    pub fn user_message(&self) -> String {
        match self {
            AppError::NetworkError { message, .. } => {
                format!("Network error: {}", message)
            }
            AppError::ServerError {
                status_code,
                message,
                ..
            } => match status_code {
                400 => format!("Invalid request: {}", message),
                401 => "Authentication required. Please check your API key.".to_string(),
                403 => "Access denied. Please verify your permissions.".to_string(),
                404 => format!("Not found: {}", message),
                429 => "Too many requests. Please wait a moment and try again.".to_string(),
                500..=599 => format!("Server error: {}", message),
                _ => format!("Server responded with error ({}): {}", status_code, message),
            },
            AppError::AuthError { message, .. } => {
                format!("Authentication failed: {}", message)
            }
            AppError::ValidationError { field, message } => {
                format!("Invalid {}: {}", field, message)
            }
            AppError::SessionError { message, .. } => {
                format!("Session error: {}", message)
            }
            AppError::FileSystemError { message, .. } => {
                format!("File error: {}", message)
            }
            AppError::DataError { message, .. } => {
                format!("Data error: {}", message)
            }
            AppError::ParseError { message, .. } => {
                format!("Parse error: {}", message)
            }
            AppError::IoError { message, .. } => {
                format!("I/O error: {}", message)
            }
            AppError::ConnectionError { message, .. } => {
                format!("Connection error: {}", message)
            }
            AppError::NotConnectedError { message } => {
                format!("Not connected: {}", message)
            }
            AppError::TimeoutError {
                operation,
                timeout_secs,
            } => {
                format!("{} timed out after {} seconds", operation, timeout_secs)
            }
            AppError::ParseError { message, .. } => {
                format!("Parse error: {}", message)
            }
            AppError::ConnectionError { message, .. } => {
                format!("Connection error: {}", message)
            }
            AppError::IoError { message, .. } => {
                format!("I/O error: {}", message)
            }
            AppError::Other { message } => message.clone(),
        }
    }

    /// Get technical details for logging/debugging
    pub fn technical_details(&self) -> String {
        match self {
            AppError::NetworkError { details, .. } => details.clone(),
            AppError::ServerError { details, .. } => details.clone(),
            AppError::AuthError { details, .. } => details.clone(),
            AppError::ValidationError { field, message } => {
                format!("Field: {}, Message: {}", field, message)
            }
            AppError::SessionError {
                session_id,
                message,
            } => {
                format!("Session: {}, Message: {}", session_id, message)
            }
            AppError::FileSystemError { path, details, .. } => {
                format!("Path: {}, Details: {}", path, details)
            }
            AppError::DataError { details, .. } => details.clone(),
            AppError::ParseError { details, .. } => details.clone(),
            AppError::IoError { details, .. } => details.clone(),
            AppError::ConnectionError { details, .. } => details.clone(),
            AppError::NotConnectedError { message } => message.clone(),
            AppError::TimeoutError {
                operation,
                timeout_secs,
            } => {
                format!("Operation: {}, Timeout: {}s", operation, timeout_secs)
            }
            AppError::ParseError { details, .. } => details.clone().unwrap_or_default(),
            AppError::ConnectionError { details, .. } => details.clone().unwrap_or_default(),
            AppError::IoError { details, .. } => details.clone().unwrap_or_default(),
            AppError::Other { message } => message.clone(),
        }
    }

    /// Check if error is retryable
    pub fn is_retryable(&self) -> bool {
        match self {
            AppError::NetworkError { .. } => true,
            AppError::ConnectionError { .. } => true,
            AppError::ServerError { status_code, .. } => {
                // Retry on 429 (rate limit), 500-599 (server errors)
                *status_code == 429 || (*status_code >= 500 && *status_code < 600)
            }
            AppError::TimeoutError { .. } => true,
            AppError::ConnectionError { .. } => true,
            AppError::IoError { .. } => true,
            AppError::ParseError { .. } => false,
            _ => false,
        }
    }

    /// Get suggested retry delay in seconds
    pub fn retry_delay_secs(&self) -> Option<u64> {
        match self {
            AppError::NetworkError { retry_after, .. } => *retry_after,
            AppError::ConnectionError { .. } => Some(2), // Connection errors - wait 2 seconds
            AppError::ServerError { status_code, .. } => {
                if *status_code == 429 {
                    Some(60) // Rate limited - wait 1 minute
                } else if *status_code >= 500 {
                    Some(5) // Server error - wait 5 seconds
                } else {
                    None
                }
            }
            AppError::TimeoutError { .. } => Some(2),
            AppError::ConnectionError { .. } => Some(2),
            AppError::IoError { .. } => Some(1),
            AppError::ParseError { .. } => None,
            _ => None,
        }
    }
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.user_message())
    }
}

impl std::error::Error for AppError {}

/// Convert from reqwest::Error to AppError
impl From<reqwest::Error> for AppError {
    fn from(error: reqwest::Error) -> Self {
        if error.is_timeout() {
            AppError::TimeoutError {
                operation: "HTTP request".to_string(),
                timeout_secs: 30,
            }
        } else if error.is_connect() {
            AppError::NetworkError {
                message: "Failed to connect to server".to_string(),
                details: error.to_string(),
                retry_after: Some(2),
            }
        } else if error.is_request() {
            AppError::NetworkError {
                message: "Request failed".to_string(),
                details: error.to_string(),
                retry_after: Some(2),
            }
        } else if let Some(status) = error.status() {
            AppError::ServerError {
                status_code: status.as_u16(),
                message: status
                    .canonical_reason()
                    .unwrap_or("Unknown error")
                    .to_string(),
                details: error.to_string(),
            }
        } else {
            AppError::NetworkError {
                message: "Network error occurred".to_string(),
                details: error.to_string(),
                retry_after: Some(2),
            }
        }
    }
}

/// Convert from serde_json::Error to AppError
impl From<serde_json::Error> for AppError {
    fn from(error: serde_json::Error) -> Self {
        AppError::DataError {
            message: "Failed to parse JSON data".to_string(),
            details: error.to_string(),
        }
    }
}

/// Convert from std::io::Error to AppError
impl From<std::io::Error> for AppError {
    fn from(error: std::io::Error) -> Self {
        AppError::FileSystemError {
            path: "unknown".to_string(),
            message: "File system operation failed".to_string(),
            details: error.to_string(),
        }
    }
}

/// Retry configuration for operations
#[derive(Debug, Clone)]
pub struct RetryConfig {
    pub max_retries: u32,
    pub initial_delay_ms: u64,
    pub max_delay_ms: u64,
    pub backoff_multiplier: f64,
}

impl Default for RetryConfig {
    fn default() -> Self {
        Self {
            max_retries: 3,
            initial_delay_ms: 1000,
            max_delay_ms: 30000,
            backoff_multiplier: 2.0,
        }
    }
}

impl RetryConfig {
    /// Create aggressive retry config (more retries, faster)
    pub fn aggressive() -> Self {
        Self {
            max_retries: 5,
            initial_delay_ms: 500,
            max_delay_ms: 10000,
            backoff_multiplier: 1.5,
        }
    }

    /// Create conservative retry config (fewer retries, slower)
    pub fn conservative() -> Self {
        Self {
            max_retries: 2,
            initial_delay_ms: 2000,
            max_delay_ms: 60000,
            backoff_multiplier: 3.0,
        }
    }

    /// Get delay for retry attempt number (0-indexed)
    pub fn get_delay(&self, attempt: u32) -> Duration {
        let delay_ms =
            (self.initial_delay_ms as f64 * self.backoff_multiplier.powi(attempt as i32)) as u64;
        let capped_delay_ms = delay_ms.min(self.max_delay_ms);
        Duration::from_millis(capped_delay_ms)
    }
}

/// Retry a future with exponential backoff
pub async fn retry_with_backoff<F, Fut, T>(operation: F, config: RetryConfig) -> Result<T, AppError>
where
    F: Fn() -> Fut,
    Fut: Future<Output = Result<T, AppError>>,
{
    let mut _last_error: Option<AppError> = None;
    let mut attempt = 0;

    loop {
        match operation().await {
            Ok(result) => return Ok(result),
            Err(error) => {
                _last_error = Some(error.clone());

                // Check if we should retry
                if !error.is_retryable() {
                    return Err(error);
                }

                if attempt >= config.max_retries {
                    return Err(error);
                }

                // Calculate delay for this attempt
                let delay = config.get_delay(attempt);

                // Log retry attempt (for debugging)
                eprintln!(
                    "Retry attempt {} after {:?}: {}",
                    attempt + 1,
                    delay,
                    error.user_message()
                );

                // Wait before retrying
                tokio::time::sleep(delay).await;

                attempt += 1;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_user_messages() {
        let network_err = AppError::NetworkError {
            message: "Connection refused".to_string(),
            details: "TCP connection failed".to_string(),
            retry_after: Some(5),
        };
        assert!(network_err.user_message().contains("Network error"));
        assert!(network_err.is_retryable());

        let auth_err = AppError::ServerError {
            status_code: 401,
            message: "Unauthorized".to_string(),
            details: "Invalid API key".to_string(),
        };
        assert!(auth_err.user_message().contains("Authentication required"));
        assert!(!auth_err.is_retryable());

        let rate_limit_err = AppError::ServerError {
            status_code: 429,
            message: "Too many requests".to_string(),
            details: "Rate limit exceeded".to_string(),
        };
        assert!(rate_limit_err.is_retryable());
        assert_eq!(rate_limit_err.retry_delay_secs(), Some(60));
    }

    #[test]
    fn test_retry_config_delays() {
        let config = RetryConfig::default();

        // Attempt 0: 1000ms
        assert_eq!(config.get_delay(0), Duration::from_millis(1000));

        // Attempt 1: 2000ms (1000 * 2^1)
        assert_eq!(config.get_delay(1), Duration::from_millis(2000));

        // Attempt 2: 4000ms (1000 * 2^2)
        assert_eq!(config.get_delay(2), Duration::from_millis(4000));

        // Capped at max_delay_ms
        assert_eq!(config.get_delay(10), Duration::from_millis(30000));
    }

    #[test]
    fn test_aggressive_retry_config() {
        let config = RetryConfig::aggressive();
        assert_eq!(config.max_retries, 5);
        assert_eq!(config.initial_delay_ms, 500);

        // Faster backoff
        assert_eq!(config.get_delay(0), Duration::from_millis(500));
        assert_eq!(config.get_delay(1), Duration::from_millis(750)); // 500 * 1.5
    }

    #[tokio::test]
    async fn test_retry_succeeds_after_failure() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        use std::sync::Arc;

        let attempts = Arc::new(AtomicUsize::new(0));
        let attempts_clone = attempts.clone();

        let operation = move || {
            let attempts = attempts_clone.clone();
            async move {
                let count = attempts.fetch_add(1, Ordering::SeqCst);
                if count < 2 {
                    Err(AppError::NetworkError {
                        message: "Connection failed".to_string(),
                        details: "Temporary failure".to_string(),
                        retry_after: Some(1),
                    })
                } else {
                    Ok(42)
                }
            }
        };

        let config = RetryConfig {
            max_retries: 5,
            initial_delay_ms: 10, // Fast for testing
            max_delay_ms: 100,
            backoff_multiplier: 2.0,
        };

        let result = retry_with_backoff(operation, config).await;
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), 42);
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn test_retry_stops_on_non_retryable_error() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        use std::sync::Arc;

        let attempts = Arc::new(AtomicUsize::new(0));
        let attempts_clone = attempts.clone();

        let operation = move || {
            let attempts = attempts_clone.clone();
            async move {
                attempts.fetch_add(1, Ordering::SeqCst);
                Err::<i32, _>(AppError::ValidationError {
                    field: "test".to_string(),
                    message: "Invalid input".to_string(),
                })
            }
        };

        let config = RetryConfig::default();
        let result = retry_with_backoff(operation, config).await;

        assert!(result.is_err());
        assert_eq!(attempts.load(Ordering::SeqCst), 1); // Should not retry
    }

    #[tokio::test]
    async fn test_retry_exhausts_max_retries() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        use std::sync::Arc;

        let attempts = Arc::new(AtomicUsize::new(0));
        let attempts_clone = attempts.clone();

        let operation = move || {
            let attempts = attempts_clone.clone();
            async move {
                attempts.fetch_add(1, Ordering::SeqCst);
                Err::<i32, _>(AppError::NetworkError {
                    message: "Always fails".to_string(),
                    details: "Test error".to_string(),
                    retry_after: Some(1),
                })
            }
        };

        let config = RetryConfig {
            max_retries: 3,
            initial_delay_ms: 10,
            max_delay_ms: 100,
            backoff_multiplier: 2.0,
        };

        let result = retry_with_backoff(operation, config).await;

        assert!(result.is_err());
        assert_eq!(attempts.load(Ordering::SeqCst), 4); // Initial attempt + 3 retries
    }
}
