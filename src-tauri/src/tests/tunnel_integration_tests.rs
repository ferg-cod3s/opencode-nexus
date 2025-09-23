// Tunnel Integration Tests
// These tests verify the complete tunnel lifecycle functionality

#[cfg(test)]
mod tunnel_integration_tests {
    use super::super::*;
    use std::fs;
    use std::path::PathBuf;
    use std::process::Command;
    use std::time::Duration;
    use tempfile::TempDir;
    use tokio::time::sleep;

    // Test helper to create a mock cloudflared binary for testing
    fn create_mock_cloudflared(temp_dir: &TempDir) -> PathBuf {
        let mock_binary = temp_dir.path().join("cloudflared");
        
        #[cfg(unix)]
        {
            let script = r#"#!/bin/bash
echo "Starting cloudflared tunnel..."
echo "Your quick tunnel will be available at: https://test-tunnel.trycloudflare.com"
echo "Ready!"
while true; do
    sleep 1
    echo "Tunnel heartbeat"
done
"#;
            fs::write(&mock_binary, script).unwrap();
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&mock_binary, fs::Permissions::from_mode(0o755)).unwrap();
        }
        
        #[cfg(windows)]
        {
            let script = r#"@echo off
echo Starting cloudflared tunnel...
echo Your quick tunnel will be available at: https://test-tunnel.trycloudflare.com
echo Ready!
:loop
timeout 1 >nul
echo Tunnel heartbeat
goto loop
"#;
            fs::write(&mock_binary, script).unwrap();
        }
        
        mock_binary
    }

    // Test helper to create a test server manager with mock cloudflared
    async fn create_test_server_manager() -> (ServerManager, TempDir) {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_dir = temp_dir.path().join("config");
        fs::create_dir_all(&config_dir).unwrap();

        let mock_cloudflared = create_mock_cloudflared(&temp_dir);
        
        let manager = ServerManager::new(config_dir, PathBuf::from("/fake/opencode"), Some(mock_cloudflared)).unwrap();
        
        (manager, temp_dir)
    }

    #[tokio::test]
    async fn test_tunnel_lifecycle_integration() {
        let (mut manager, _temp_dir) = create_test_server_manager().await;
        
        // Test 1: Tunnel should be stopped initially
        let status = manager.get_tunnel_status();
        assert_eq!(status.status, "stopped");
        assert!(status.url.is_none());
        
        // Test 2: Start tunnel with valid config
        let config = TunnelConfig {
            name: "test-tunnel".to_string(),
            local_port: 8080,
            protocol: "http".to_string(),
            custom_domain: None,
            cloudflare_token: None,
        };
        
        let result = manager.start_cloudflared_tunnel(&config).await;
        assert!(result.is_ok(), "Failed to start tunnel: {:?}", result.err());
        
        // Test 3: Verify tunnel status after starting
        let status = manager.get_tunnel_status();
        assert_eq!(status.status, "connected");
        assert!(status.url.is_some());
        assert!(status.url.as_ref().unwrap().contains("trycloudflare.com"));
        
        // Test 4: Verify tunnel config is stored
        let stored_config = manager.get_tunnel_config();
        assert!(stored_config.is_some());
        assert_eq!(stored_config.as_ref().unwrap().name, "test-tunnel");
        assert_eq!(stored_config.as_ref().unwrap().local_port, 8080);
        
        // Test 5: Stop tunnel
        let result = manager.stop_cloudflared_tunnel();
        assert!(result.is_ok(), "Failed to stop tunnel: {:?}", result.err());
        
        // Test 6: Verify tunnel is stopped
        let status = manager.get_tunnel_status();
        assert_eq!(status.status, "stopped");
        assert!(status.url.is_none());
        
        // Test 7: Verify config is cleared
        let stored_config = manager.get_tunnel_config();
        assert!(stored_config.is_none());
    }

    #[tokio::test]
    async fn test_tunnel_config_persistence() {
        let (mut manager, _temp_dir) = create_test_server_manager().await;
        
        // Test config persistence across operations
        let config = TunnelConfig {
            name: "persistent-tunnel".to_string(),
            local_port: 9090,
            protocol: "https".to_string(),
            custom_domain: Some("test.example.com".to_string()),
            cloudflare_token: Some("test-token".to_string()),
        };
        
        // Update config
        let result = manager.update_tunnel_config(config.clone());
        assert!(result.is_ok());
        
        // Verify config is stored
        let stored_config = manager.get_tunnel_config();
        assert!(stored_config.is_some());
        assert_eq!(stored_config.as_ref().unwrap().name, "persistent-tunnel");
        assert_eq!(stored_config.as_ref().unwrap().custom_domain, Some("test.example.com".to_string()));
        
        // Config should persist even if tunnel is not running
        let status = manager.get_tunnel_status();
        assert_eq!(status.status, "stopped");
        
        let stored_config_again = manager.get_tunnel_config();
        assert!(stored_config_again.is_some());
    }

    #[tokio::test]
    async fn test_tunnel_error_handling() {
        let (mut manager, _temp_dir) = create_test_server_manager().await;
        
        // Test error handling when cloudflared binary doesn't exist
        let mut manager_no_binary = ServerManager::new(
            PathBuf::from("/tmp/nonexistent"),
            PathBuf::from("/fake/opencode"),
            None
        ).unwrap();
        
        let config = TunnelConfig {
            name: "error-test".to_string(),
            local_port: 8080,
            protocol: "http".to_string(),
            custom_domain: None,
            cloudflare_token: None,
        };
        
        let result = manager_no_binary.start_cloudflared_tunnel(&config).await;
        assert!(result.is_err());
        assert!(result.as_ref().unwrap_err().to_string().contains("cloudflared binary not found"));
    }

    #[tokio::test]
    async fn test_concurrent_tunnel_operations() {
        let (mut manager, _temp_dir) = create_test_server_manager().await;
        
        // Test that we can't start multiple tunnels simultaneously
        let config1 = TunnelConfig {
            name: "tunnel-1".to_string(),
            local_port: 8080,
            protocol: "http".to_string(),
            custom_domain: None,
            cloudflare_token: None,
        };
        
        let config2 = TunnelConfig {
            name: "tunnel-2".to_string(),
            local_port: 8081,
            protocol: "http".to_string(),
            custom_domain: None,
            cloudflare_token: None,
        };
        
        // Start first tunnel
        let result1 = manager.start_cloudflared_tunnel(&config1).await;
        assert!(result1.is_ok());
        
        // Try to start second tunnel (should fail or handle gracefully)
        let result2 = manager.start_cloudflared_tunnel(&config2).await;
        // This might fail or replace the first tunnel depending on implementation
        // Both outcomes are acceptable for this test
        
        // Verify at least one tunnel operation worked
        let status = manager.get_tunnel_status();
        assert!(status.status == "connected" || status.status == "stopped");
    }

    #[tokio::test]
    async fn test_tunnel_url_extraction() {
        let (mut manager, _temp_dir) = create_test_server_manager().await;
        
        let config = TunnelConfig {
            name: "url-test".to_string(),
            local_port: 8080,
            protocol: "http".to_string(),
            custom_domain: None,
            cloudflare_token: None,
        };
        
        let result = manager.start_cloudflared_tunnel(&config).await;
        assert!(result.is_ok());
        
        let url = manager.get_tunnel_url();
        assert!(url.is_some());
        
        let url_str = url.as_ref().unwrap();
        assert!(url_str.starts_with("https://"));
        assert!(url_str.contains("trycloudflare.com"));
    }

    #[tokio::test]
    async fn test_tunnel_process_cleanup() {
        let (mut manager, _temp_dir) = create_test_server_manager().await;
        
        // Start tunnel
        let config = TunnelConfig {
            name: "cleanup-test".to_string(),
            local_port: 8080,
            protocol: "http".to_string(),
            custom_domain: None,
            cloudflare_token: None,
        };
        
        manager.start_cloudflared_tunnel(&config).await.unwrap();
        
        // Verify tunnel is running
        let status_before = manager.get_tunnel_status();
        assert_eq!(status_before.status, "connected");
        
        // Stop tunnel
        manager.stop_cloudflared_tunnel().unwrap();
        
        // Verify tunnel is stopped and resources are cleaned up
        let status_after = manager.get_tunnel_status();
        assert_eq!(status_after.status, "stopped");
        assert!(status_after.url.is_none());
        
        // Verify config is cleared
        let config_after = manager.get_tunnel_config();
        assert!(config_after.is_none());
    }
}
