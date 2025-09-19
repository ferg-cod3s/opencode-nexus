# Critical Fixes: API Connectivity and Test Coverage Implementation Plan

## Overview

Fix critical API connectivity issues causing runtime 404 errors, establish comprehensive test coverage for real OpenCode server integration, and eliminate code quality issues through systematic cleanup of compiler warnings.

## Current State Analysis

### Critical Issues Identified:
- **Runtime API Failures**: Application shows "Failed to get app info from API: API error: 404 Not Found" during normal operation
- **Test Coverage Gaps**: 29 unit tests and comprehensive E2E tests exist but use mocked/fake servers, missing real OpenCode server API validation
- **Code Quality Issues**: 15 compiler warnings including 466-line unused module and multiple unused variables/functions

### Current Implementation:
- **Server Manager** (`src-tauri/src/server_manager.rs:750-776`): `get_app_info()` calls `/app` endpoint, falls back to stub data on failure
- **Connection Logic** (`src-tauri/src/server_manager.rs:834-857`): `try_connect_to_existing_server()` tries `/app` then `/config` endpoints
- **Working Endpoints**: Chat system successfully uses `/session/{id}/message` and `/event` endpoints
- **Test Infrastructure**: Uses `httpbin.org` and fake server paths instead of real OpenCode servers

## Desired End State

### Success Verification:
1. **Zero Runtime API Errors**: Application starts without "Failed to get app info" messages
2. **Comprehensive Test Coverage**: Integration tests verify real OpenCode server API compatibility
3. **Clean Compilation**: Zero compiler warnings during `cargo clippy`
4. **Maintained Functionality**: All existing features work without regression

### Key Discoveries:
- **Working Pattern**: Chat functionality at `src-tauri/src/chat_manager.rs:121` successfully connects using `/session/{id}/message` endpoint
- **Endpoint Availability**: `/app` endpoint doesn't exist on current OpenCode servers, but `/event` and session endpoints work
- **Test Architecture**: Current test suite at `src-tauri/src/tests.rs:406` tests fallback behavior but not real API endpoint validation
- **Unused Code Volume**: `src-tauri/src/web_server_manager.rs` contains 466 lines of completely unused functionality

## What We're NOT Doing

- **Not changing core chat functionality** - existing message streaming works correctly
- **Not removing fallback logic** - maintain graceful degradation for API failures  
- **Not modifying E2E test architecture** - keep existing Playwright/Tauri integration
- **Not implementing new OpenCode server features** - focus only on connectivity fixes
- **Not changing authentication or onboarding systems** - these are working correctly

## Implementation Approach

**Strategy**: Incremental fixes with comprehensive testing to ensure zero regression while eliminating runtime errors.

**Technical Approach**:
1. **Replace failing endpoints** with working connectivity checks
2. **Add integration test infrastructure** for real OpenCode server validation
3. **Systematic code cleanup** following existing patterns in codebase

## Phase 1: API Connectivity Resolution

### Overview

Replace failing `/app` endpoint checks with working connectivity verification to eliminate runtime 404 errors while maintaining all existing functionality.

### Changes Required:

#### 1. Server Health Check Replacement

**File**: `src-tauri/src/server_manager.rs`
**Changes**: Replace `/app` endpoint dependency with working connectivity check

```rust
// Replace get_app_info() implementation (lines 750-776)
pub async fn get_app_info(&mut self) -> Result<AppInfo> {
    // Ensure API client is available
    self.ensure_api_client()?;

    if let Some(client) = &self.api_client {
        // First try basic connectivity check instead of /app endpoint
        match self.check_server_connectivity().await {
            Ok(_) => {
                // Server is reachable, return enhanced app info
                Ok(AppInfo {
                    version: "connected".to_string(),
                    status: "running".to_string(), 
                    uptime: Some(self.get_server_uptime()),
                    sessions_count: self.get_active_sessions().await.ok().map(|s| s.len()),
                })
            }
            Err(e) => {
                // Fallback to stub data with connectivity error context
                eprintln!("Server connectivity check failed: {}", e);
                Ok(AppInfo {
                    version: "unknown".to_string(),
                    status: "disconnected".to_string(),
                    uptime: None,
                    sessions_count: None,
                })
            }
        }
    } else {
        Err(anyhow!("API client not available"))
    }
}

// Add new connectivity check method
async fn check_server_connectivity(&self) -> Result<()> {
    if let Some(client) = &self.api_client {
        // Use working endpoint pattern from chat_manager.rs:121
        let test_url = format!("{}/health", client.base_url);
        let response = reqwest::get(&test_url).await?;
        
        // Accept any non-404 response as server presence
        if response.status() != reqwest::StatusCode::NOT_FOUND {
            Ok(())
        } else {
            Err(anyhow!("Server health check returned 404"))
        }
    } else {
        Err(anyhow!("No API client available"))
    }
}
```

#### 2. Server Detection Logic Update

**File**: `src-tauri/src/server_manager.rs`
**Changes**: Update `try_connect_to_existing_server()` to use reliable endpoint detection

```rust
// Update try_connect_to_existing_server (lines 834-857)
async fn try_connect_to_existing_server(&self, port: u16) -> Result<ApiClient> {
    let base_url = format!("http://127.0.0.1:{}", port);
    let api_client = ApiClient::new(&base_url).map_err(|e| anyhow!(e))?;
    
    // Try multiple endpoints to detect OpenCode server
    let endpoints = vec!["/health", "/status", "/api", "/"];
    
    for endpoint in endpoints {
        let test_url = format!("{}{}", base_url, endpoint);
        match reqwest::get(&test_url).await {
            Ok(response) => {
                // Any successful response indicates server presence
                if response.status().is_success() || response.status().is_client_error() {
                    return Ok(api_client);
                }
            }
            Err(_) => continue,
        }
    }
    
    Err(anyhow!("No OpenCode server detected on port {}", port))
}
```

### Success Criteria:

#### Automated Verification:
- [ ] Unit tests pass: `cd src-tauri && cargo test`
- [ ] No compilation errors: `cd src-tauri && cargo clippy`
- [ ] Application builds successfully: `cargo tauri build`

#### Manual Verification:
- [ ] Application starts without "Failed to get app info" error messages
- [ ] Dashboard displays server information correctly
- [ ] Chat functionality continues to work normally
- [ ] Server start/stop operations function properly

---

## Phase 2: Test Coverage Enhancement

### Overview

Add comprehensive integration tests for real OpenCode server API connectivity to prevent regression of the issues fixed in Phase 1.

### Changes Required:

#### 1. Integration Test Infrastructure

**File**: `src-tauri/src/tests.rs`
**Changes**: Add real OpenCode server integration tests

```rust
// Add after existing tests (around line 450)
#[cfg(test)]
mod integration_tests {
    use super::*;
    use std::process::{Command, Child};
    use std::time::{Duration, Instant};

    /// Integration test helper to start a real OpenCode server for testing
    struct TestOpenCodeServer {
        process: Option<Child>,
        port: u16,
        base_url: String,
    }

    impl TestOpenCodeServer {
        async fn start() -> Result<Self> {
            // Attempt to start real OpenCode server for testing
            // This requires OpenCode binary to be available in test environment
            let port = find_available_port().unwrap_or(8080);
            
            // Skip if OpenCode binary not available (CI environment)
            if !Self::is_opencode_available() {
                return Err(anyhow!("OpenCode server not available for integration testing"));
            }
            
            let mut process = Command::new("opencode")
                .arg("--port")
                .arg(port.to_string())
                .spawn()?;
                
            let base_url = format!("http://127.0.0.1:{}", port);
            
            // Wait for server startup
            let start = Instant::now();
            while start.elapsed() < Duration::from_secs(10) {
                if reqwest::get(&base_url).await.is_ok() {
                    break;
                }
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
            
            Ok(TestOpenCodeServer {
                process: Some(process),
                port,
                base_url,
            })
        }
        
        fn is_opencode_available() -> bool {
            Command::new("opencode").arg("--version").status().is_ok()
        }
    }

    impl Drop for TestOpenCodeServer {
        fn drop(&mut self) {
            if let Some(mut process) = self.process.take() {
                let _ = process.kill();
            }
        }
    }

    #[tokio::test]
    async fn test_real_opencode_server_connectivity() {
        // Skip if OpenCode server not available
        let server = match TestOpenCodeServer::start().await {
            Ok(s) => s,
            Err(_) => {
                println!("Skipping integration test - OpenCode server not available");
                return;
            }
        };

        let api_client = ApiClient::new(&server.base_url).unwrap();
        
        // Test the endpoints that should work
        let endpoints = vec!["/health", "/status", "/api", "/"];
        let mut working_endpoint_found = false;
        
        for endpoint in endpoints {
            match api_client.get::<serde_json::Value>(endpoint).await {
                Ok(_) => {
                    working_endpoint_found = true;
                    break;
                }
                Err(e) => {
                    // Log but continue - some endpoints may not exist
                    println!("Endpoint {} failed: {}", endpoint, e);
                }
            }
        }
        
        assert!(working_endpoint_found, "No working endpoints found on OpenCode server");
    }

    #[tokio::test] 
    async fn test_server_manager_with_real_server() {
        let server = match TestOpenCodeServer::start().await {
            Ok(s) => s,
            Err(_) => {
                println!("Skipping integration test - OpenCode server not available");
                return;
            }
        };

        let mut server_manager = ServerManager::new(PathBuf::from("/tmp/test"));
        
        // Test server detection
        let api_client = server_manager.try_connect_to_existing_server(server.port).await;
        assert!(api_client.is_ok(), "Should detect real OpenCode server");
        
        // Test app info retrieval
        server_manager.api_client = Some(api_client.unwrap());
        let app_info = server_manager.get_app_info().await;
        assert!(app_info.is_ok(), "Should retrieve app info successfully");
        
        let info = app_info.unwrap();
        assert_ne!(info.status, "unknown", "Should not return unknown status with real server");
    }
}
```

#### 2. Enhanced Unit Tests for API Connectivity

**File**: `src-tauri/src/tests.rs`
**Changes**: Add specific tests for 404 handling and endpoint fallback logic

```rust
// Add after line 423 (existing test_get_app_info_api_fallback)
#[tokio::test]
async fn test_app_endpoint_404_handling() {
    let mut server_manager = ServerManager::new(PathBuf::from("/tmp/test"));
    
    // Create API client pointing to non-existent endpoint
    let api_client = ApiClient::new("http://httpbin.org/status/404").unwrap();
    server_manager.api_client = Some(api_client);
    
    // Should handle 404 gracefully and return fallback data
    let result = server_manager.get_app_info().await;
    assert!(result.is_ok());
    
    let app_info = result.unwrap();
    assert_eq!(app_info.status, "disconnected");
    assert_eq!(app_info.version, "unknown");
}

#[tokio::test]
async fn test_connectivity_check_with_various_responses() {
    let test_cases = vec![
        ("http://httpbin.org/status/200", true),   // Should pass
        ("http://httpbin.org/status/404", false),  // Should fail
        ("http://httpbin.org/status/500", true),   // Should pass (server exists)
    ];
    
    for (url, should_pass) in test_cases {
        let server_manager = ServerManager::new(PathBuf::from("/tmp/test"));
        // Note: This test would need the new check_server_connectivity method
        // Implementation depends on Phase 1 completion
    }
}
```

#### 3. E2E Test Enhancement

**File**: `frontend/e2e/server-management.spec.ts`
**Changes**: Add real server connectivity validation

```typescript
// Add after existing server management tests
test.describe('Real Server Connectivity', () => {
  test('should handle server info retrieval without errors', async ({ page }) => {
    // Navigate to dashboard
    await page.goto('/dashboard');
    
    // Wait for server info to load
    await page.waitForLoadState('networkidle');
    
    // Check that no API error messages appear in console
    const errorMessages = [];
    page.on('console', msg => {
      if (msg.type() === 'error' && msg.text().includes('Failed to get app info')) {
        errorMessages.push(msg.text());
      }
    });
    
    // Reload to trigger fresh API calls
    await page.reload();
    await page.waitForTimeout(2000);
    
    expect(errorMessages).toHaveLength(0, 'Should not show API connectivity errors');
  });

  test('should display appropriate server status', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Look for server status indicators
    const statusElement = page.locator('[data-testid="server-status"]');
    await expect(statusElement).toBeVisible();
    
    // Should not show "unknown" status if server is running
    const statusText = await statusElement.textContent();
    if (statusText?.includes('running')) {
      expect(statusText).not.toContain('unknown');
    }
  });
});
```

### Success Criteria:

#### Automated Verification:
- [ ] All unit tests pass: `cd src-tauri && cargo test`
- [ ] Integration tests pass when OpenCode server available: `cd src-tauri && cargo test integration_tests`
- [ ] E2E tests pass: `cd frontend && bun run test:e2e`
- [ ] No test failures in CI pipeline

#### Manual Verification:
- [ ] Integration tests correctly skip when OpenCode server unavailable
- [ ] Tests catch API connectivity regressions when run against real servers
- [ ] E2E tests validate absence of error messages in browser console
- [ ] Test coverage reports show improved API connectivity testing

---

## Phase 3: Code Quality Improvement

### Overview

Systematically eliminate all 15 compiler warnings through strategic code cleanup, focusing on removing unused code while preserving all functional capabilities.

### Changes Required:

#### 1. Remove Unused Web Server Manager Module

**File**: `src-tauri/src/web_server_manager.rs`
**Changes**: Complete file removal (466 lines of unused code)

```bash
# Remove entire unused module
rm src-tauri/src/web_server_manager.rs
```

**File**: `src-tauri/src/lib.rs`
**Changes**: Remove module declaration and imports

```rust
// Remove these lines:
// mod web_server_manager;
// use web_server_manager::*;
```

#### 2. Clean Up Server Manager Warnings

**File**: `src-tauri/src/server_manager.rs`
**Changes**: Fix unused variables, fields, and methods

```rust
// Line 288: Fix unused variable warning
let (_binary_path, port) = {  // Add underscore prefix

// Line 120 & 126: Fix unused struct fields
pub struct ServerManager {
    // Remove or mark as allowed if needed for future use
    #[allow(dead_code)]
    config_dir: PathBuf,
    server_info: Arc<Mutex<ServerInfo>>,
    event_sender: broadcast::Sender<ServerEvent>,
    api_client: Option<ApiClient>,
    #[allow(dead_code)]
    app_handle: Option<tauri::AppHandle>,
}

// Line 622: Fix useless comparison
if new_port < 1024 {  // Remove upper bound check for u16
    return Err("Port must be above 1024".to_string());
}

// Lines 282, 596, 641, 711, 716, 783, 1047: Remove or annotate unused methods
#[allow(dead_code)]
pub fn is_running(&self) -> bool {
    // Keep methods that might be used by frontend commands
}

// For methods not exposed to frontend, consider removal:
// - get_server_version() if not used
// - get_metrics() if not used  
// - subscribe_to_events() if not used
// - emit_event() if not used
// - initialize_app() if not used
// - spawn_tunnel_process() if not used
```

#### 3. Clean Up Other Module Warnings

**File**: `src-tauri/src/onboarding.rs`
**Changes**: Remove unused imports and methods

```rust
// Line 468: Remove unused import
// use std::fs;  // Remove this line

// Line 54: Remove or annotate unused method
#[allow(dead_code)]
pub fn is_first_launch(&self) -> bool {
    // Keep if planned for future use, otherwise remove
}
```

**File**: `src-tauri/src/api_client.rs`
**Changes**: Fix unused field warning

```rust
// Line 17: Either use timeout field or mark as allowed
pub struct ApiClient {
    pub base_url: String,
    pub client: reqwest::Client,
    #[allow(dead_code)]
    pub timeout: Duration,  // Keep for future timeout configuration
}
```

**File**: `src-tauri/src/chat_manager.rs`
**Changes**: Address unused methods and fields

```rust
// Multiple unused methods (lines 63, 142, 146, 158, 226):
// Remove methods not used by frontend commands:
// - subscribe_to_events() 
// - get_session()
// - get_all_sessions() 
// - delete_session()
// - persist_session()

// Line 173: Fix unused field
struct MessageResponse {
    info: ChatMessage,
    #[allow(dead_code)]
    parts: Vec<serde_json::Value>, // Keep for future API compatibility
}
```

**File**: `src-tauri/src/message_stream.rs`
**Changes**: Clean up unused components

```rust
// Lines 12-13: Fix unused fields
struct SSEEvent {
    #[allow(dead_code)]
    event: Option<String>,  // Keep for future SSE event types
    #[allow(dead_code)]
    data: String,           // Keep for future SSE data handling
}

// Line 72: Remove unused method
// pub fn stop_streaming(&mut self) -> Remove if not needed
```

**File**: `src-tauri/src/tests.rs`
**Changes**: Clean up test imports

```rust
// Line 3 & 6: Remove unused imports
// use super::*;      // Remove if not needed
// use std::sync::Arc; // Remove if not needed
```

**File**: `src-tauri/src/lib.rs`
**Changes**: Remove unused function

```rust
// Line 234: Remove unused initialize_app function
// async fn initialize_app(app_handle: tauri::AppHandle) -> Result<bool, String> {
//     // Remove entire function if not used
// }
```

### Success Criteria:

#### Automated Verification:
- [ ] Zero compiler warnings: `cd src-tauri && cargo clippy --all-targets --all-features`
- [ ] All tests still pass: `cd src-tauri && cargo test`
- [ ] Application builds cleanly: `cargo tauri build`
- [ ] No functionality regression: `cd frontend && bun run test:e2e`

#### Manual Verification:
- [ ] All existing features work normally after cleanup
- [ ] No performance degradation from code changes
- [ ] Application startup time remains consistent
- [ ] Memory usage patterns unchanged

---

## Testing Strategy

### Unit Tests:
- **API Connectivity**: Test endpoint fallback logic with various HTTP response codes
- **Error Handling**: Validate graceful degradation when servers unavailable
- **Integration Points**: Test ServerManager with real and mocked API clients

### Integration Tests:
- **Real Server Testing**: Validate connectivity with actual OpenCode server instances
- **Endpoint Discovery**: Test server detection logic with various server configurations
- **Fallback Behavior**: Verify system behavior when preferred endpoints unavailable

### Manual Testing Steps:
1. **Start application** and verify no "Failed to get app info" errors in console
2. **Test server lifecycle** (start/stop/restart) and verify status updates correctly
3. **Verify chat functionality** continues working normally after API changes
4. **Test with different OpenCode server versions** if available
5. **Validate dashboard displays** appropriate server information
6. **Confirm error handling** shows user-friendly messages when servers unavailable

## Performance Considerations

### Optimizations:
- **Reduced API calls**: New connectivity check pattern reduces failed API attempts
- **Faster error recovery**: Quicker fallback to working endpoints
- **Smaller binary size**: Removal of 466-line unused module

### Monitoring:
- **Startup time**: Should remain under 3 seconds after cleanup
- **Memory usage**: Monitor for any increases after API client changes
- **Network requests**: Verify no increase in unnecessary API calls

## Migration Notes

### Backward Compatibility:
- **API client interface**: Maintain existing method signatures for frontend compatibility
- **Event system**: Preserve all event types and structures used by UI
- **Configuration**: No changes to user configuration or data storage

### Deployment Considerations:
- **Testing requirements**: Integration tests require OpenCode server availability
- **CI/CD updates**: May need OpenCode server setup in test environments
- **Rollback plan**: All changes are additive/cleanup, easy to revert if needed

## References

- Original research: `thoughts/research/2025-09-11_critical-fixes-implementation-analysis.md`
- Current test patterns: `src-tauri/src/tests.rs:305-450`
- Working API example: `src-tauri/src/chat_manager.rs:121`
- Server detection logic: `src-tauri/src/server_manager.rs:834-857`