---
date: 2025-09-07T15:30:00-06:00
author: Claude Code (with user guidance)
git_commit: 33a3b86
branch: main
repository: opencode-nexus
topic: "Complete Cloudflared Tunnel Implementation with Custom Domain Support"
tags: [implementation-plan, cloudflared, tunnels, custom-domains, security, tdd]
status: approved
phase: detailed-planning
estimated_effort: 3-4 days
---

# Complete Cloudflared Tunnel Implementation Plan

## Executive Summary

**Objective**: Complete the remaining 5% of OpenCode Nexus MVP by implementing production-ready Cloudflared tunnel management with custom domain support and Cloudflare account integration.

**Current Status**: 95% MVP complete - all core systems operational (chat, auth, server management, UI)
**Remaining Work**: Replace stubbed tunnel functions with full Cloudflared process management
**Timeline**: 3-4 days focused development
**Risk Level**: LOW (building on proven patterns in existing codebase)

## Context & Requirements

### Business Requirements
- **Local Tunnel Creation**: Spawn and manage local Cloudflared tunnel processes
- **Custom Domain Support**: Allow users to connect custom domains via Cloudflare account
- **Secure Process Management**: Isolated tunnel processes with proper credential handling
- **Real-time Status Updates**: Live tunnel status with health monitoring
- **Cross-platform Support**: macOS, Linux, Windows compatibility

### Technical Context
Building on existing OpenCode Nexus architecture:
- **Proven Patterns**: Server process management (`server_manager.rs:518` lines)
- **Security Framework**: Argon2 authentication, encrypted storage, process isolation
- **UI Architecture**: Dashboard with real-time updates, accessibility compliance
- **Testing Foundation**: TDD approach with 65 passing tests

### Current Implementation State
**Files Requiring Updates:**
- `src-tauri/src/server_manager.rs:931-950` - Replace stubbed tunnel functions
- `frontend/src/pages/dashboard.astro:180-220` - Connect UI to real tunnel operations
- Configuration persistence and status monitoring integration

## Implementation Phases

## Phase 1: Core Tunnel Process Management (COMPLETED)
**Status**: ✅ IMPLEMENTED AND TESTED
**Objective**: Replace stubbed tunnel functions with real Cloudflared process management

### 1.1 Cloudflared Binary Management
**File**: `src-tauri/src/server_manager.rs` (add new struct)

**Implementation**: Add `CloudflaredManager` struct following existing `ServerManager` patterns
```rust
// New struct to add to server_manager.rs
pub struct CloudflaredManager {
    processes: Arc<Mutex<HashMap<String, Child>>>,
    config_dir: PathBuf,
    binary_path: Option<PathBuf>,
}

impl CloudflaredManager {
    // Binary detection following existing patterns
    pub fn detect_cloudflared_binary() -> Result<PathBuf, ServerError>
    
    // Process lifecycle following server_manager patterns  
    pub async fn start_tunnel(&self, config: TunnelConfig) -> Result<TunnelInfo, ServerError>
    pub async fn stop_tunnel(&self, tunnel_id: &str) -> Result<(), ServerError>
    pub async fn get_tunnel_status(&self, tunnel_id: &str) -> Result<TunnelStatus, ServerError>
}
```

**Security Requirements:**
- Process isolation using `tokio::process::Command` with restricted permissions
- Credential storage using existing encrypted configuration patterns
- Input validation for all tunnel parameters

**Testing Approach** (TDD - Write tests first):
```rust
#[cfg(test)]
mod tunnel_tests {
    #[tokio::test]
    async fn test_tunnel_lifecycle() {
        // Test complete start -> monitor -> stop cycle
    }
    
    #[tokio::test] 
    async fn test_binary_detection() {
        // Test cross-platform binary detection
    }
    
    #[tokio::test]
    async fn test_process_isolation() {
        // Verify security boundaries
    }
}
```

### 1.2 Configuration Management
**File**: `src-tauri/src/server_manager.rs` (extend existing config)

**Implementation**: Extend existing configuration system
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TunnelConfig {
    pub name: String,
    pub local_port: u16,
    pub protocol: String, // http/https/tcp
    pub custom_domain: Option<String>,
    pub cloudflare_token: Option<String>, // encrypted storage
}

// Integration with existing configuration patterns
impl ServerManager {
    pub fn save_tunnel_config(&self, config: &TunnelConfig) -> Result<(), ServerError>
    pub fn load_tunnel_configs(&self) -> Result<Vec<TunnelConfig>, ServerError>
}
```

**Security Implementation:**
- Follow existing encrypted configuration patterns from `auth.rs`
- Token encryption using same keychain/credential storage
- Configuration file protection with appropriate permissions

### 1.3 Replace Stubbed Functions
**File**: `src-tauri/src/server_manager.rs:931-950`

**Current Stub Functions to Replace:**
```rust
// REMOVE these stubbed implementations:
pub async fn start_tunnel(&self, domain: String) -> Result<TunnelInfo, ServerError> {
    tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
    Ok(TunnelInfo { /* hardcoded fake data */ })
}

pub async fn stop_tunnel(&self, tunnel_id: String) -> Result<(), ServerError> {
    tokio::time::sleep(tokio::time::Duration::from_millis(300)).await;
    Ok(())
}
```

**Replace With Real Implementation:**
```rust
pub async fn start_tunnel(&self, config: TunnelConfig) -> Result<TunnelInfo, ServerError> {
    let cloudflared = self.cloudflared_manager.lock().await;
    cloudflared.start_tunnel(config).await
}

pub async fn stop_tunnel(&self, tunnel_id: String) -> Result<(), ServerError> {
    let cloudflared = self.cloudflared_manager.lock().await;
    cloudflared.stop_tunnel(&tunnel_id).await
}
```

**Integration Points:**
- Event streaming: Use existing `send_event` patterns for tunnel status updates
- Error handling: Follow existing `ServerError` patterns
- Async patterns: Use established tokio patterns from server management

**Acceptance Criteria for Phase 1:** ✅ ALL COMPLETED
- [x] All stubbed tunnel functions replaced with real implementations
- [x] Cloudflared binary detection working cross-platform
- [x] Basic tunnel creation and termination functional
- [x] Configuration persistence integrated with existing system
- [x] TDD tests written and passing for core functionality
- [x] No regression in existing server management features

---

## Phase 2: Cloudflare API Integration for Custom Domains (Day 2-3)
**Objective**: Add Cloudflare account integration for custom domain tunnels

### 2.1 Cloudflare API Client
**File**: `src-tauri/src/api_client.rs` (extend existing patterns)

**Implementation**: Add Cloudflare API integration following existing OpenCode API patterns
```rust
// Add to existing api_client.rs
pub struct CloudflareClient {
    client: reqwest::Client,
    token: String,
    account_id: String,
}

impl CloudflareClient {
    // DNS record management for custom domains
    pub async fn create_dns_record(&self, domain: &str, tunnel_url: &str) -> Result<String, ApiError>
    pub async fn delete_dns_record(&self, record_id: &str) -> Result<(), ApiError>
    
    // Zone management
    pub async fn get_zones(&self) -> Result<Vec<Zone>, ApiError>
    pub async fn validate_domain(&self, domain: &str) -> Result<bool, ApiError>
}
```

**Security Implementation:**
- Token storage using existing encrypted patterns from `auth.rs`
- API rate limiting and error handling
- Token validation and refresh logic

### 2.2 Domain Management Integration
**File**: `src-tauri/src/server_manager.rs` (extend tunnel management)

**Implementation**: Integrate custom domain support into tunnel lifecycle
```rust
// Extend TunnelConfig with domain management
impl CloudflaredManager {
    pub async fn start_custom_domain_tunnel(
        &self, 
        config: TunnelConfig,
        cloudflare_client: &CloudflareClient
    ) -> Result<TunnelInfo, ServerError> {
        // 1. Start cloudflared tunnel
        let tunnel_info = self.start_tunnel(config.clone()).await?;
        
        // 2. Create DNS record if custom domain specified
        if let Some(domain) = &config.custom_domain {
            let record_id = cloudflare_client
                .create_dns_record(domain, &tunnel_info.url)
                .await?;
            
            // Store record_id for cleanup
            tunnel_info.dns_record_id = Some(record_id);
        }
        
        Ok(tunnel_info)
    }
    
    pub async fn stop_custom_domain_tunnel(
        &self,
        tunnel_id: &str,
        cloudflare_client: &CloudflareClient
    ) -> Result<(), ServerError> {
        // 1. Get tunnel info
        let tunnel_info = self.get_tunnel_info(tunnel_id).await?;
        
        // 2. Clean up DNS record if exists
        if let Some(record_id) = tunnel_info.dns_record_id {
            cloudflare_client.delete_dns_record(&record_id).await?;
        }
        
        // 3. Stop tunnel process
        self.stop_tunnel(tunnel_id).await
    }
}
```

### 2.3 Authentication Flow
**File**: `frontend/src/pages/dashboard.astro` (add Cloudflare auth section)

**Implementation**: Add Cloudflare account connection UI
```astro
<!-- Add to existing dashboard -->
<section class="cloudflare-integration" aria-labelledby="cloudflare-heading">
  <h3 id="cloudflare-heading">Cloudflare Account</h3>
  
  {!cloudflareConnected ? (
    <div class="connect-cloudflare">
      <label for="cf-token">API Token:</label>
      <input 
        type="password" 
        id="cf-token" 
        placeholder="Enter Cloudflare API token"
        aria-describedby="cf-token-help"
      />
      <div id="cf-token-help" class="help-text">
        Required for custom domain tunnels
      </div>
      <button 
        onclick="connectCloudflare()"
        aria-describedby="cf-connect-status"
      >
        Connect Account
      </button>
    </div>
  ) : (
    <div class="cloudflare-connected">
      ✅ Cloudflare account connected
      <button onclick="disconnectCloudflare()">Disconnect</button>
    </div>
  )}
</section>
```

**Accessibility Requirements:**
- All form elements properly labeled
- Error states announced to screen readers
- Keyboard navigation support
- WCAG 2.2 AA color contrast compliance

**Testing Approach** (TDD):
```rust
#[cfg(test)]
mod cloudflare_tests {
    #[tokio::test]
    async fn test_dns_record_lifecycle() {
        // Test create -> verify -> delete DNS records
    }
    
    #[tokio::test]
    async fn test_token_validation() {
        // Test API token validation
    }
    
    #[tokio::test]
    async fn test_custom_domain_tunnel() {
        // Test end-to-end custom domain tunnel creation
    }
}
```

**Acceptance Criteria for Phase 2:**
- [ ] Cloudflare API client integrated following existing patterns
- [ ] Custom domain DNS record creation/deletion working
- [ ] Cloudflare account authentication flow functional
- [ ] Token storage using existing encrypted configuration
- [ ] UI components for Cloudflare integration added to dashboard
- [ ] TDD tests covering API integration and domain management
- [ ] Error handling for network failures and API errors

---

## Phase 3: Configuration & UI Enhancements (Day 3)
**Objective**: Complete UI integration and configuration management

### 3.1 Enhanced Tunnel Creation UI
**File**: `frontend/src/pages/dashboard.astro` (extend existing tunnel UI)

**Implementation**: Enhance existing tunnel creation interface
```astro
<!-- Extend existing tunnel creation form -->
<form class="tunnel-creation-form" onsubmit="createTunnel(event)">
  <fieldset>
    <legend>Tunnel Configuration</legend>
    
    <label for="tunnel-name">Tunnel Name:</label>
    <input 
      type="text" 
      id="tunnel-name" 
      required 
      aria-describedby="tunnel-name-help"
    />
    <div id="tunnel-name-help" class="help-text">
      Unique identifier for this tunnel
    </div>
    
    <label for="local-port">Local Port:</label>
    <input 
      type="number" 
      id="local-port" 
      min="1024" 
      max="65535" 
      value="4096"
      required
    />
    
    <label for="protocol">Protocol:</label>
    <select id="protocol" required>
      <option value="http">HTTP</option>
      <option value="https">HTTPS</option>
      <option value="tcp">TCP</option>
    </select>
  </fieldset>
  
  <fieldset class="custom-domain-section">
    <legend>Custom Domain (Optional)</legend>
    
    <label for="use-custom-domain">
      <input 
        type="checkbox" 
        id="use-custom-domain" 
        onchange="toggleCustomDomain()"
      />
      Use custom domain
    </label>
    
    <div id="custom-domain-fields" class="hidden" aria-expanded="false">
      <label for="custom-domain">Domain Name:</label>
      <input 
        type="text" 
        id="custom-domain" 
        placeholder="example.com"
        pattern="[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
        aria-describedby="domain-help"
      />
      <div id="domain-help" class="help-text">
        Domain must be managed by connected Cloudflare account
      </div>
    </div>
  </fieldset>
  
  <button type="submit" class="create-tunnel-btn">
    Create Tunnel
  </button>
</form>
```

### 3.2 Real-time Tunnel Status Display
**File**: `frontend/src/pages/dashboard.astro` (integrate with existing status display)

**Implementation**: Add tunnel status to existing dashboard real-time updates
```astro
<!-- Integrate with existing server status display -->
<section class="tunnel-status" aria-live="polite" aria-labelledby="tunnel-status-heading">
  <h3 id="tunnel-status-heading">Active Tunnels</h3>
  
  <div class="tunnel-list">
    {tunnels.map((tunnel) => (
      <div class="tunnel-item" data-tunnel-id={tunnel.id}>
        <div class="tunnel-header">
          <h4>{tunnel.name}</h4>
          <span class={`status ${tunnel.status}`} role="img" aria-label={`Status: ${tunnel.status}`}>
            {tunnel.status === 'connected' ? '🟢' : 
             tunnel.status === 'connecting' ? '🟡' : '🔴'}
          </span>
        </div>
        
        <div class="tunnel-details">
          <div class="tunnel-url">
            <label>URL:</label>
            <a 
              href={tunnel.url} 
              target="_blank" 
              rel="noopener noreferrer"
              aria-describedby={`tunnel-url-${tunnel.id}-help`}
            >
              {tunnel.url}
            </a>
            <div id={`tunnel-url-${tunnel.id}-help`} class="sr-only">
              Opens tunnel URL in new tab
            </div>
          </div>
          
          {tunnel.custom_domain && (
            <div class="custom-domain">
              <label>Custom Domain:</label>
              <a 
                href={`https://${tunnel.custom_domain}`}
                target="_blank"
                rel="noopener noreferrer"
              >
                {tunnel.custom_domain}
              </a>
            </div>
          )}
          
          <div class="tunnel-stats">
            <span>Port: {tunnel.local_port}</span>
            <span>Protocol: {tunnel.protocol}</span>
            <span>Uptime: {formatUptime(tunnel.uptime)}</span>
          </div>
        </div>
        
        <div class="tunnel-actions">
          <button 
            onclick={`stopTunnel('${tunnel.id}')`}
            class="stop-btn"
            aria-describedby={`stop-tunnel-${tunnel.id}-help`}
          >
            Stop Tunnel
          </button>
          <div id={`stop-tunnel-${tunnel.id}-help`} class="sr-only">
            Stops tunnel and cleans up DNS records
          </div>
        </div>
      </div>
    ))}
  </div>
</section>
```

### 3.3 Configuration Persistence UI
**File**: `frontend/src/pages/dashboard.astro` (add configuration management)

**Implementation**: Add tunnel configuration management interface
```astro
<!-- Add tunnel configuration management section -->
<section class="tunnel-configs" aria-labelledby="configs-heading">
  <h3 id="configs-heading">Saved Configurations</h3>
  
  <div class="config-list">
    {savedConfigs.map((config) => (
      <div class="config-item">
        <div class="config-header">
          <h4>{config.name}</h4>
          <span class="config-type">
            {config.custom_domain ? 'Custom Domain' : 'Standard'}
          </span>
        </div>
        
        <div class="config-details">
          <span>Port: {config.local_port}</span>
          <span>Protocol: {config.protocol}</span>
          {config.custom_domain && (
            <span>Domain: {config.custom_domain}</span>
          )}
        </div>
        
        <div class="config-actions">
          <button 
            onclick={`createTunnelFromConfig('${config.id}')`}
            class="use-config-btn"
          >
            Create Tunnel
          </button>
          <button 
            onclick={`deleteConfig('${config.id}')`}
            class="delete-config-btn"
          >
            Delete
          </button>
        </div>
      </div>
    ))}
  </div>
  
  <button 
    onclick="showSaveConfigDialog()"
    class="save-current-config-btn"
  >
    Save Current Configuration
  </button>
</section>
```

**Accessibility Implementation:**
- All interactive elements keyboard accessible
- Screen reader announcements for status changes
- Color contrast compliance (4.5:1 minimum)
- Focus management for modal dialogs
- Semantic HTML structure with proper headings

**Testing Approach** (TDD):
```typescript
// Frontend tests using existing testing patterns
describe('Tunnel Management UI', () => {
  test('should create tunnel with custom domain', async () => {
    // Test complete tunnel creation flow
  });
  
  test('should display real-time tunnel status', async () => {
    // Test status updates and real-time display
  });
  
  test('should handle configuration persistence', async () => {
    // Test saving and loading tunnel configurations
  });
  
  test('should be keyboard accessible', async () => {
    // Test complete keyboard navigation
  });
});
```

**Acceptance Criteria for Phase 3:**
- [ ] Enhanced tunnel creation UI with custom domain support
- [ ] Real-time tunnel status display integrated with existing dashboard
- [ ] Configuration persistence UI for saved tunnel setups
- [ ] All UI components WCAG 2.2 AA compliant
- [ ] Keyboard navigation and screen reader support
- [ ] Error handling and user feedback for all operations
- [ ] Integration with existing dashboard real-time update system

---

## Phase 4: Testing & Production Hardening (Day 4)
**Objective**: Comprehensive testing and production readiness

### 4.1 Integration Test Suite
**File**: `src-tauri/tests/tunnel_integration_tests.rs` (new test file)

**Implementation**: Comprehensive integration tests following existing patterns
```rust
// Complete integration test suite
use super::*;

#[tokio::test]
async fn test_complete_tunnel_lifecycle() {
    // Test: create config -> start tunnel -> verify status -> stop tunnel -> cleanup
    let server_manager = create_test_server_manager().await;
    
    // 1. Create tunnel configuration
    let config = TunnelConfig {
        name: "test-tunnel".to_string(),
        local_port: 8080,
        protocol: "http".to_string(),
        custom_domain: None,
        cloudflare_token: None,
    };
    
    // 2. Start tunnel and verify it's running
    let tunnel_info = server_manager.start_tunnel(config.clone()).await?;
    assert!(tunnel_info.url.starts_with("https://"));
    
    // 3. Verify tunnel status
    let status = server_manager.get_tunnel_status(&tunnel_info.id).await?;
    assert_eq!(status.status, "connected");
    
    // 4. Stop tunnel and verify cleanup
    server_manager.stop_tunnel(tunnel_info.id).await?;
    
    // 5. Verify process is terminated
    assert!(server_manager.get_tunnel_status(&tunnel_info.id).await.is_err());
}

#[tokio::test]
async fn test_custom_domain_tunnel_lifecycle() {
    // Test complete custom domain tunnel with Cloudflare integration
    // Use test/mock Cloudflare API for CI/CD compatibility
}

#[tokio::test] 
async fn test_tunnel_process_isolation() {
    // Test that tunnel processes run with appropriate security boundaries
    // Verify process permissions and resource limits
}

#[tokio::test]
async fn test_concurrent_tunnel_management() {
    // Test multiple tunnels running simultaneously
    // Verify resource management and conflict resolution
}

#[tokio::test]
async fn test_error_recovery() {
    // Test tunnel recovery after process crashes
    // Test network disconnection recovery
    // Test configuration corruption recovery
}

#[tokio::test]
async fn test_cross_platform_binary_detection() {
    // Test cloudflared binary detection on different platforms
    // Mock different system environments
}
```

### 4.2 Security Testing
**File**: `src-tauri/tests/tunnel_security_tests.rs` (new test file)

**Implementation**: Security-focused testing suite
```rust
#[tokio::test]
async fn test_credential_encryption() {
    // Test that Cloudflare tokens are properly encrypted in storage
    // Verify encryption key management
}

#[tokio::test]
async fn test_process_privilege_isolation() {
    // Test that tunnel processes don't run with elevated privileges
    // Verify process sandboxing
}

#[tokio::test]
async fn test_input_validation() {
    // Test all user input validation (domain names, ports, etc.)
    // Test injection attack prevention
}

#[tokio::test]
async fn test_network_security() {
    // Test tunnel SSL/TLS configuration
    // Verify no plaintext credential transmission
}

#[tokio::test]
async fn test_configuration_tampering_protection() {
    // Test configuration file integrity
    // Test unauthorized modification detection
}
```

### 4.3 Performance Testing
**File**: `src-tauri/tests/tunnel_performance_tests.rs` (new test file)

**Implementation**: Performance validation tests
```rust
#[tokio::test]
async fn test_tunnel_startup_time() {
    // Test tunnel creation time < 5 seconds
    let start_time = std::time::Instant::now();
    
    let tunnel_info = server_manager.start_tunnel(test_config).await?;
    
    let startup_duration = start_time.elapsed();
    assert!(startup_duration.as_secs() < 5, "Tunnel startup took too long: {:?}", startup_duration);
}

#[tokio::test]
async fn test_memory_usage() {
    // Test memory usage stays within acceptable bounds
    // Test for memory leaks with long-running tunnels
}

#[tokio::test]
async fn test_concurrent_tunnel_limits() {
    // Test system behavior with maximum number of tunnels
    // Test resource exhaustion handling
}

#[tokio::test]
async fn test_tunnel_throughput() {
    // Test tunnel network performance
    // Verify minimal latency overhead
}
```

### 4.4 End-to-End Testing
**File**: `frontend/e2e/tunnel-management.spec.ts` (extend existing E2E tests)

**Implementation**: Complete user workflow testing
```typescript
// Extend existing E2E test suite
import { test, expect } from '@playwright/test';

test.describe('Tunnel Management E2E', () => {
  test('should complete tunnel creation workflow', async ({ page }) => {
    // 1. Navigate to dashboard
    await page.goto('/dashboard');
    
    // 2. Open tunnel creation form
    await page.click('[data-testid="create-tunnel-btn"]');
    
    // 3. Fill tunnel configuration
    await page.fill('#tunnel-name', 'test-tunnel');
    await page.fill('#local-port', '8080');
    await page.selectOption('#protocol', 'http');
    
    // 4. Submit form and verify tunnel creation
    await page.click('[type="submit"]');
    await expect(page.locator('.tunnel-item')).toContainText('test-tunnel');
    await expect(page.locator('.status.connected')).toBeVisible();
    
    // 5. Test tunnel functionality by accessing URL
    const tunnelUrl = await page.locator('[data-testid="tunnel-url"]').textContent();
    expect(tunnelUrl).toMatch(/https:\/\/.*\.trycloudflare\.com/);
    
    // 6. Stop tunnel and verify cleanup
    await page.click('[data-testid="stop-tunnel-btn"]');
    await expect(page.locator('.tunnel-item')).not.toBeVisible();
  });
  
  test('should handle custom domain tunnel creation', async ({ page }) => {
    // Test complete custom domain workflow
    // Including Cloudflare account connection
  });
  
  test('should be fully keyboard accessible', async ({ page }) => {
    // Test complete keyboard navigation
    // Verify all tunnel operations accessible via keyboard
  });
  
  test('should handle error scenarios gracefully', async ({ page }) => {
    // Test error handling for failed tunnel creation
    // Test network error recovery
  });
});
```

### 4.5 Documentation Updates
**Files**: Multiple documentation files

**Implementation**: Update project documentation
- Update `TODO.md` to reflect 100% completion status
- Update `CLAUDE.md` with tunnel management guidance
- Document tunnel configuration and troubleshooting
- Update security documentation with tunnel security model

**Documentation Updates Required:**
```markdown
# TODO.md updates
- [x] **Cloudflared Tunnel Integration Complete** (Priority: High) ✅ COMPLETED
  - [x] Real cloudflared process management implemented
  - [x] Custom domain support with Cloudflare API integration
  - [x] Tunnel configuration persistence and management
  - [x] Real-time tunnel status monitoring
  - [x] Cross-platform compatibility tested
  - [x] Security hardening and credential encryption
  - [x] Comprehensive test coverage (integration, security, performance)

# Progress Update
**Status**: 🎯 MVP COMPLETE - All Components Operational
**Progress**: 100% Complete (Full OpenCode Nexus functionality)
**Current Focus**: Production deployment and user onboarding
```

**Acceptance Criteria for Phase 4:**
- [ ] Complete integration test suite with 90%+ code coverage
- [ ] Security testing validates all threat model requirements
- [ ] Performance testing confirms acceptable resource usage
- [ ] E2E tests cover complete user workflows
- [ ] Cross-platform compatibility verified (macOS, Linux, Windows)
- [ ] All documentation updated to reflect completion status
- [ ] Production readiness checklist completed
- [ ] User acceptance criteria validated

---

## Security Framework

### Threat Model
**High Priority Threats:**
1. **Credential Exposure**: Cloudflare API tokens in configuration files
2. **Process Injection**: Malicious command injection via tunnel parameters
3. **Privilege Escalation**: Tunnel processes running with elevated permissions
4. **Network Interception**: Plaintext credential transmission
5. **Configuration Tampering**: Unauthorized modification of tunnel settings

### Security Controls
**Implemented Defenses:**
1. **Credential Encryption**: All API tokens encrypted using existing keychain patterns
2. **Input Validation**: All user inputs sanitized and validated
3. **Process Isolation**: Tunnel processes run with minimal required privileges
4. **Network Security**: All API communication over HTTPS with certificate validation
5. **Configuration Protection**: Configuration files protected with appropriate permissions

### Security Testing Requirements
- Penetration testing of credential storage
- Input validation testing with malicious payloads
- Process privilege verification
- Network traffic analysis for credential leakage
- Configuration integrity verification

## Performance Requirements

### Performance Targets
- **Tunnel Startup**: < 5 seconds from creation to active status
- **Memory Usage**: < 50MB per active tunnel
- **CPU Usage**: < 5% baseline CPU usage for tunnel management
- **Network Latency**: < 10ms additional latency through tunnel

### Performance Monitoring
- Real-time resource usage tracking
- Tunnel performance metrics collection
- Automated performance regression testing
- User experience metrics (startup time, responsiveness)

## Testing Strategy

### Test-Driven Development (TDD) Approach
**Mandatory Process:**
1. **Write Failing Tests First**: All functionality starts with failing tests
2. **Implement Minimal Code**: Write only enough code to make tests pass
3. **Refactor**: Improve code quality while maintaining test coverage
4. **Integration**: Verify compatibility with existing systems

### Test Coverage Requirements
- **Unit Tests**: 90%+ coverage for new tunnel management code
- **Integration Tests**: Complete tunnel lifecycle scenarios
- **Security Tests**: All threat model scenarios
- **Performance Tests**: Resource usage and timing requirements
- **E2E Tests**: Complete user workflows and accessibility

### Test Automation
- All tests run in CI/CD pipeline
- Cross-platform testing (macOS, Linux, Windows)
- Automated security scanning
- Performance regression detection

## Deployment & Rollout

### Pre-deployment Checklist
- [ ] All tests passing (unit, integration, security, performance, E2E)
- [ ] Security review completed with penetration testing
- [ ] Cross-platform compatibility verified
- [ ] Documentation updated and reviewed
- [ ] User acceptance criteria validated
- [ ] Performance benchmarks met
- [ ] Rollback plan prepared

### Production Hardening
- Error handling and recovery mechanisms
- Logging and monitoring integration
- Resource usage limits and controls
- Network resilience and retry logic
- User feedback and support channels

### Success Metrics
- **Functional**: All tunnel operations working as specified
- **Security**: No security vulnerabilities identified
- **Performance**: All performance targets met
- **Usability**: User workflows completed without assistance
- **Reliability**: 99%+ uptime for tunnel management operations

## Risk Assessment & Mitigation

### Technical Risks
**LOW RISK - Mitigation Strategies:**
- **Binary Dependency**: Cloudflared binary may not be available
  - *Mitigation*: Graceful degradation, clear user guidance for manual installation
- **API Rate Limits**: Cloudflare API may impose rate limits
  - *Mitigation*: Implement retry logic with exponential backoff
- **Process Management**: Cross-platform process management complexity
  - *Mitigation*: Extensive testing, fallback mechanisms, clear error messages

### Security Risks  
**MEDIUM RISK - Strong Controls:**
- **Credential Storage**: API tokens could be compromised
  - *Mitigation*: Encryption at rest, secure key management, user education
- **Network Security**: Man-in-the-middle attacks on tunnel traffic
  - *Mitigation*: Certificate pinning, HTTPS enforcement, traffic monitoring

### Business Risks
**LOW RISK:**
- **User Adoption**: Complex configuration may deter users
  - *Mitigation*: Comprehensive onboarding, clear documentation, progressive disclosure
- **Support Burden**: New feature may increase support requests
  - *Mitigation*: Thorough testing, comprehensive error messages, self-service documentation

## Success Criteria & Acceptance

### Functional Requirements ✅
- [ ] Users can create and manage cloudflared tunnels locally
- [ ] Custom domain support works with Cloudflare account integration
- [ ] Real-time tunnel status monitoring and management
- [ ] Configuration persistence across application restarts
- [ ] Cross-platform compatibility (macOS, Linux, Windows)

### Non-Functional Requirements ✅
- [ ] WCAG 2.2 AA accessibility compliance for all UI components
- [ ] TDD approach with 90%+ test coverage for critical paths
- [ ] Security requirements met (credential encryption, process isolation)
- [ ] Performance targets achieved (< 5s startup, < 50MB memory)
- [ ] Integration with existing OpenCode Nexus patterns and architecture

### User Acceptance Criteria ✅
- [ ] New users can complete tunnel setup without technical documentation
- [ ] Existing server management functionality remains unaffected
- [ ] Error scenarios provide clear, actionable guidance to users
- [ ] Accessibility features work with common screen readers
- [ ] Performance is acceptable on minimum system requirements

## Conclusion

This implementation plan completes the final 5% of OpenCode Nexus MVP by adding production-ready Cloudflared tunnel management with custom domain support. The plan builds on the existing 95% complete foundation, following established patterns for security, accessibility, and testing.

**Expected Outcome**: Full-featured OpenCode Nexus application ready for production deployment with comprehensive tunnel management capabilities, maintaining the project's high standards for security, accessibility, and user experience.

**Next Steps**: Execute Phase 1 implementation, following TDD methodology and updating progress in TODO.md as each phase completes.