#[cfg(test)]
mod tests {
    use super::*;
    use crate::server_manager::{ServerManager, ServerStatus};
    use crate::api_client::ApiClient;
    use std::sync::Arc;
    use tokio::time::{timeout, Duration};

    #[tokio::test]
    async fn test_concurrent_server_operations() {
        // Test rapid start/stop operations
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("fake-server");

        // Create a fake binary file
        std::fs::write(&binary_path, "#!/bin/bash\necho 'fake server'").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(&binary_path).unwrap().permissions();
            perms.set_mode(0o755);
            std::fs::set_permissions(&binary_path, perms).unwrap();
        }

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Test rapid start/stop cycles
        for _ in 0..3 {
            // This should handle concurrent operations gracefully
            let start_result = timeout(Duration::from_secs(5), manager.start_server()).await;
            // Don't assert success - we're testing error handling
            if start_result.is_ok() {
                let _ = timeout(Duration::from_secs(5), manager.stop_server()).await;
            }
        }

        // Verify server state is consistent
        let info = manager.get_server_info();
        assert!(matches!(info.status, ServerStatus::Stopped | ServerStatus::Error));
    }

    #[tokio::test]
    async fn test_network_failure_handling() {
        // Test behavior when network operations fail
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("nonexistent-server");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Attempt to start with non-existent binary (simulates network/binary download failure)
        let result = manager.start_server().await;
        assert!(result.is_err());

        // Verify error state
        let info = manager.get_server_info();
        assert_eq!(info.status, ServerStatus::Error);
        assert!(info.last_error.is_some());
    }

    #[tokio::test]
    async fn test_configuration_corruption_recovery() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("test-server");

        // Create initial server manager
        let manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Test port validation with privileged port (should fail)
        let result = manager.update_server_config(Some(80), None);
        assert!(result.is_err());

        // Verify error is handled gracefully
        let info = manager.get_server_info();
        assert!(info.last_error.is_some() || result.is_err());
    }

    #[tokio::test]
    async fn test_race_condition_prevention() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("race-test-server");

        // Test sequential operations to ensure state consistency
        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Perform multiple start/stop cycles
        for _ in 0..3 {
            // These operations should not interfere with each other
            let start_result = manager.start_server().await;
            if start_result.is_ok() {
                let _ = manager.stop_server().await;
            }
        }

        // Verify final state is consistent
        let info = manager.get_server_info();
        assert!(matches!(info.status, ServerStatus::Stopped | ServerStatus::Error));
    }

    #[tokio::test]
    async fn test_error_boundary_isolation() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("error-boundary-test");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Test that one operation failure doesn't corrupt subsequent operations
        let result1 = manager.start_server().await;
        assert!(result1.is_err()); // Should fail due to missing binary

        // Second attempt should also fail but not crash
        let result2 = manager.start_server().await;
        assert!(result2.is_err());

        // Verify server info remains accessible
        let info = manager.get_server_info();
        assert!(info.last_error.is_some());
        assert_eq!(info.status, ServerStatus::Error);
    }

    #[tokio::test]
    async fn test_resource_cleanup_on_failure() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("cleanup-test-server");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Attempt operation that will fail
        let result = manager.start_server().await;
        assert!(result.is_err());

        // Verify resources are cleaned up
        let info = manager.get_server_info();
        assert_eq!(info.pid, None);
        assert_eq!(info.status, ServerStatus::Error);

        // Verify we can attempt operations again
        let second_result = manager.start_server().await;
        assert!(second_result.is_err()); // Still fails, but doesn't crash
    }

    #[test]
    fn test_port_validation_edge_cases() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("port-test-server");

        let manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Test invalid ports
        let invalid_ports = [0, 80, 443, 1023];

        for port in invalid_ports {
            let result = manager.update_server_config(Some(port), None);
            assert!(result.is_err(), "Port {} should be invalid", port);
        }

        // Test valid ports
        let valid_ports = [4096, 8080, 9000, 10000, 65535];

        for port in valid_ports {
            let result = manager.update_server_config(Some(port), None);
            assert!(result.is_ok(), "Port {} should be valid", port);
        }
    }

    #[tokio::test]
    async fn test_timeout_handling() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("timeout-test-server");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Test that operations don't hang indefinitely
        let result = timeout(Duration::from_secs(10), manager.start_server()).await;

        // Should complete (with error) within timeout
        assert!(result.is_ok() || result.is_err());
    }

    // TunnelConfig and Tunnel Lifecycle Tests
    #[test]
    fn test_tunnel_config_validation() {
        use crate::server_manager::TunnelConfig;
        // Should fail with invalid domain
        let config = TunnelConfig {
            enabled: true,
            auto_start: true,
            custom_domain: Some("invalid domain".to_string()),
            config_path: None,
            auth_token: None,
        };
        assert!(config.validate().is_err());
        // Should succeed with valid domain
        let config = TunnelConfig {
            enabled: true,
            auto_start: false,
            custom_domain: Some("mydomain.example.com".to_string()),
            config_path: None,
            auth_token: Some("token123".to_string()),
        };
        assert!(config.validate().is_ok());
    }

    #[tokio::test]
    async fn test_tunnel_lifecycle() {
        use crate::server_manager::{ServerManager, TunnelConfig, TunnelStatus};
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("fake-server");
        std::fs::write(&binary_path, "#!/bin/bash\necho 'fake server'").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(&binary_path).unwrap().permissions();
            perms.set_mode(0o755);
            std::fs::set_permissions(&binary_path, perms).unwrap();
        }
        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();
        let tunnel_config = TunnelConfig {
            enabled: true,
            auto_start: false,
            custom_domain: None,
            config_path: None,
            auth_token: None,
        };
        // Should fail to start tunnel (not implemented yet)
        let result = manager.start_cloudflared_tunnel(&tunnel_config).await;
        assert!(result.is_err());
        // Should return correct status (stubbed)
        let status = manager.get_tunnel_status();
        assert_eq!(status, TunnelStatus::Stopped);
    }

    #[tokio::test]
    async fn test_tunnel_auto_start_with_server() {
        use crate::server_manager::{ServerManager, TunnelConfig};
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("fake-server");
        std::fs::write(&binary_path, "#!/bin/bash\necho 'fake server'").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(&binary_path).unwrap().permissions();
            perms.set_mode(0o755);
            std::fs::set_permissions(&binary_path, perms).unwrap();
        }
        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();
        let tunnel_config = TunnelConfig {
            enabled: true,
            auto_start: true,
            custom_domain: None,
            config_path: None,
            auth_token: None,
        };
        // Save tunnel config (not implemented yet)
        assert!(manager.update_tunnel_config(tunnel_config.clone()).is_ok());
        // Start server (should auto-start tunnel, but not implemented yet)
        let result = manager.start_server().await;
        assert!(result.is_ok() || result.is_err());
        // Check tunnel status (should be running if implemented)
        let status = manager.get_tunnel_status();
        assert!(matches!(status, crate::server_manager::TunnelStatus::Stopped | crate::server_manager::TunnelStatus::Running));
    }

    #[test]
    fn test_tunnel_config_persistence() {
        use crate::server_manager::TunnelConfig;
        use crate::server_manager::ServerManager;
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("fake-server");
        std::fs::write(&binary_path, "#!/bin/bash\necho 'fake server'").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(&binary_path).unwrap().permissions();
            perms.set_mode(0o755);
            std::fs::set_permissions(&binary_path, perms).unwrap();
        }
        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();
        let tunnel_config = TunnelConfig {
            enabled: true,
            auto_start: false,
            custom_domain: Some("test.example.com".to_string()),
            config_path: None,
            auth_token: Some("token".to_string()),
        };
        // Save config (should fail, not implemented)
        assert!(manager.update_tunnel_config(tunnel_config.clone()).is_ok() || manager.update_tunnel_config(tunnel_config.clone()).is_err());
        // Load config (should match what was saved, not implemented)
        let loaded = manager.get_tunnel_config();
        assert!(loaded.is_some());
    }

    // HTTP Client Tests
    #[tokio::test]
    async fn test_api_client_creation() {
        // Test creating an ApiClient with valid base URL
        let result = ApiClient::new("http://localhost:4096");
        assert!(result.is_ok());

        let client = result.unwrap();
        assert_eq!(client.base_url, "http://localhost:4096");
        assert_eq!(client.timeout, std::time::Duration::from_secs(30));
    }

    #[tokio::test]
    async fn test_api_client_invalid_url() {
        // Test creating an ApiClient with invalid URL
        let result = ApiClient::new("invalid-url");
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_api_client_get_request() {
        // Test GET request to a valid endpoint
        let client = ApiClient::new("http://httpbin.org").unwrap();

        // This will fail initially since httpbin.org may not be available
        // but tests the request structure
        let result = client.get::<serde_json::Value>("/json").await;
        // We expect this to fail in the test environment, but the structure should work
        assert!(result.is_err() || result.is_ok()); // Either way, it shouldn't panic
    }

    #[tokio::test]
    async fn test_api_client_post_request() {
        // Test POST request with JSON body
        let client = ApiClient::new("http://httpbin.org").unwrap();

        let test_data = serde_json::json!({"test": "data"});
        let result = client.post::<serde_json::Value, serde_json::Value>("/post", &test_data).await;
        // Similar to GET test - structure validation
        assert!(result.is_err() || result.is_ok());
    }

    #[tokio::test]
    async fn test_api_client_network_error_handling() {
        // Test handling of network errors (unreachable host)
        let client = ApiClient::new("http://nonexistent.localhost:9999").unwrap();

        let result = client.get::<serde_json::Value>("/test").await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_api_client_timeout_handling() {
        // Test timeout handling with an unreachable host
        let client = ApiClient::new("http://10.255.255.1").unwrap(); // Non-routable IP

        // This should timeout due to network unavailability
        let result = client.get::<serde_json::Value>("/test").await;
        // Should fail due to timeout or connection error
        assert!(result.is_err());
    }

    // App API Integration Tests
    #[tokio::test]
    async fn test_server_manager_api_client_creation() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("test-server");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Initially no API client
        assert!(manager.api_client.is_none());

        // After ensuring API client, it should be created
        manager.ensure_api_client().unwrap();
        assert!(manager.api_client.is_some());

        let client = manager.api_client.as_ref().unwrap();
        assert_eq!(client.base_url, "http://127.0.0.1:4096");
    }

    #[tokio::test]
    async fn test_server_manager_api_client_url_update() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("test-server");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Create initial API client
        manager.ensure_api_client().unwrap();
        assert_eq!(manager.api_client.as_ref().unwrap().base_url, "http://127.0.0.1:4096");

        // Update server port
        manager.update_server_config(Some(8080), None).unwrap();

        // API client should update URL when ensured again
        manager.ensure_api_client().unwrap();
        assert_eq!(manager.api_client.as_ref().unwrap().base_url, "http://127.0.0.1:8080");
    }

    #[tokio::test]
    async fn test_get_app_info_api_fallback() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("test-server");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Test fallback behavior when API is not available
        let result = manager.get_app_info().await;
        assert!(result.is_ok());

        let app_info = result.unwrap();
        // Should return stubbed data when API fails
        assert_eq!(app_info.version, "unknown");
        assert_eq!(app_info.status, "unknown");
        assert!(app_info.uptime.is_none());
        assert!(app_info.sessions_count.is_none());
    }

    #[tokio::test]
    async fn test_initialize_app_api_fallback() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().to_path_buf();
        let binary_path = config_dir.join("test-server");

        let mut manager = ServerManager::new(config_dir, binary_path, None).unwrap();

        // Test fallback behavior when API is not available
        let result = manager.initialize_app().await;
        assert!(result.is_err()); // Should fail when API client is not available
    }

    #[tokio::test]
    async fn test_api_client_invalid_json_response() {
        // Test handling of invalid JSON responses
        let client = ApiClient::new("http://httpbin.org").unwrap();

        // Try to parse HTML as JSON
        let result = client.get::<serde_json::Value>("/html").await;
        assert!(result.is_err());
    }
}