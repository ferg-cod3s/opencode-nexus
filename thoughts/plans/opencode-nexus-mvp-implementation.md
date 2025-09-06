# OpenCode Nexus MVP – Implementation Plan

## Overview

Complete the OpenCode Nexus MVP by implementing the **critical missing web-based chat interface** alongside Cloudflared tunnel integration, streaming metrics with comprehensive logging, auto-restart functionality, and advanced features. This plan builds on the completed onboarding and authentication systems to deliver a fully functional system that provides secure remote access to a local OpenCode AI chat interface.

**CRITICAL MVP GAP IDENTIFIED:** The current implementation provides excellent server management but lacks the core web-based chat interface that enables users to interact with their local OpenCode AI from any device/browser via the secure tunnel. This is a blocking issue for MVP completion.

**KEY ARCHITECTURAL CLARIFICATION:** The chat interface is a **web application** served by the local OpenCode server and made accessible remotely via Cloudflared tunnel, enabling users to chat with their local AI from any device.

## Current State Analysis

### ✅ Completed (Phase 1)
- Onboarding & Setup Wizard: 6-step wizard with system detection, server setup, and security configuration
- Password Authentication: Argon2 hashing, account lockout protection, secure IPC
- Testing Infrastructure: TDD approach with 29 tests covering onboarding and authentication
- Accessibility: WCAG 2.2 AA compliance verified
- Documentation: Comprehensive docs for onboarding, security, and user flows

### 🔄 Current Implementation Status
- **Server Process Management**: ✅ Complete - Full lifecycle management with monitoring
- **Dashboard UI**: ✅ Complete - Real-time status monitoring and controls
- **Chat Interface**: ✅ **FULLY IMPLEMENTED** - Complete chat UI with session management and real-time messaging
- **Tunnel Integration**: ✅ Complete - Full Cloudflared process management with monitoring
- **Metrics**: ✅ Complete - Real-time system metrics collection
- **Logging**: ✅ Complete - Comprehensive application logging with rotation

### Key Constraints
- **Security First**: All features must meet security standards (Argon2, no plaintext secrets)
- **TDD Required**: Write failing tests before implementation
- **Accessibility**: WCAG 2.2 AA compliance mandatory
- **Cloudflared Only**: No alternative tunnel providers for MVP
- **User-Supplied Server**: Application doesn't bundle OpenCode server binary

## Desired End State

After completing this plan, OpenCode Nexus will be a production-ready system that:

- **Provides Web-Based AI Chat**: Browser-accessible chat interface for OpenCode AI conversations
- **Enables Cross-Device Access**: Chat with local OpenCode AI from any device via secure tunnel
- **Streams AI Responses**: Server-Sent Events for real-time message streaming
- **Manages Conversations**: Session-based chat history and multi-conversation support
- **Manages OpenCode servers**: Start/stop/restart with monitoring and auto-recovery
- **Provides secure remote access**: Cloudflared tunnel integration with custom domains
- **Offers real-time monitoring**: Streaming metrics and comprehensive logging
- **Ensures reliability**: Auto-restart with user notifications and graceful error handling
- **Maintains security**: No sensitive data exposure, secure logging, audit trails
- **Delivers accessibility**: Full WCAG 2.2 AA compliance across all features

### Verification Criteria
- All automated tests pass (unit, integration, accessibility)
- Manual testing covers edge cases (interruptions, concurrency, OS failures)
- Performance benchmarks meet requirements (<3s startup, <1MB bundle)
- Security audit passes (no secrets in logs, secure IPC, input validation)
- Accessibility audit passes (keyboard navigation, screen reader support)

## What We're NOT Doing

- **Multi-user support**: Single-user authentication only
- **OAuth integration**: Password-based authentication only
- **Alternative tunnel providers**: Cloudflared only for MVP
- **Server bundling**: User must provide OpenCode server binary
- **Advanced user management**: No user roles, permissions, or multi-tenancy
- **External integrations**: No cloud storage, third-party APIs, or external monitoring
- **Mobile/desktop sync**: Desktop-only application
- **Plugin system**: Core functionality only

## Implementation Approach

### Guiding Principles
- **TDD-First**: Write failing tests before any implementation
- **Incremental Delivery**: Each phase delivers working, tested functionality
- **Security by Design**: Security considerations in every feature
- **Accessibility First**: WCAG compliance built into UI/UX from start
- **Comprehensive Logging**: Secure, structured logging for troubleshooting
- **Real-time Updates**: Event-driven architecture for live dashboard

### Technical Strategy
- **Backend**: Extend existing Rust patterns (async process management, event broadcasting)
- **Frontend**: Leverage existing Tauri integration and Astro/Svelte patterns
- **Testing**: Expand automated test coverage, add comprehensive manual test scenarios
- **Logging**: Structured logging with rotation, secure viewer, and export functionality
- **Configuration**: User-configurable settings with validation and persistence

---

## Phase 0: Chat Interface & AI Conversation System (CRITICAL MVP COMPONENT)

### Overview
Implement the core chat interface and AI conversation system that enables users to interact with OpenCode AI in real-time. This is the **missing MVP component** that transforms the application from server management tool to functional AI coding assistant.

### Changes Required

#### 1. Chat Session Management (`src-tauri/src/chat_manager.rs` - New File)
**Current**: No chat functionality
**Changes**:
- Implement session creation and management using `/session/*` endpoints
- Add message sending/receiving with OpenCode AI
- Handle conversation history and context
- Integrate with existing server manager for API access

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatSession {
    pub id: String,
    pub title: Option<String>,
    pub created_at: String,
    pub messages: Vec<ChatMessage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id: String,
    pub role: MessageRole, // "user" or "assistant"
    pub content: String,
    pub timestamp: String,
}

pub struct ChatManager {
    api_client: ApiClient,
    current_session: Option<ChatSession>,
}

impl ChatManager {
    pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
        // Create new chat session via API
    }

    pub async fn send_message(&mut self, content: &str) -> Result<ChatMessage, String> {
        // Send message to OpenCode AI and get response
    }

    pub async fn get_session_history(&self, session_id: &str) -> Result<Vec<ChatMessage>, String> {
        // Retrieve conversation history
    }
}
```

#### 2. Real-time Message Streaming (`src-tauri/src/message_stream.rs` - New File)
**Current**: No message streaming
**Changes**:
- Implement SSE client for real-time message streaming from `/event` endpoint
- Parse incoming AI responses and emit to frontend
- Handle streaming tokens for smooth UI updates
- Manage connection state and reconnection logic

```rust
pub struct MessageStream {
    api_client: ApiClient,
    event_sender: broadcast::Sender<ChatEvent>,
}

#[derive(Debug, Clone, Serialize)]
pub enum ChatEvent {
    MessageReceived { session_id: String, message: ChatMessage },
    MessageChunk { session_id: String, chunk: String },
    SessionCreated { session: ChatSession },
    Error { message: String },
}

impl MessageStream {
    pub async fn start_streaming(&self) -> Result<(), String> {
        // Connect to /event SSE endpoint
        // Parse streaming messages
        // Emit events to frontend
    }
}
```

#### 3. Chat UI Components (`frontend/src/components/` - New Files)
**Current**: No chat interface
**Changes**:
- Create `ChatInterface.svelte` - Main chat component
- Create `MessageBubble.svelte` - Individual message display
- Create `MessageInput.svelte` - Message composition
- Create `SessionSidebar.svelte` - Conversation management
- Implement syntax highlighting for code blocks
- Add file attachment/sharing capabilities

#### 4. Chat Page (`frontend/src/pages/chat.astro` - New File)
**Current**: No dedicated chat page
**Changes**:
- Create full-page chat interface
- Integrate with existing layout and navigation
- Add keyboard shortcuts and accessibility features
- Implement responsive design for mobile/desktop

#### 5. Tauri Commands for Chat (`src-tauri/src/lib.rs`)
**Current**: No chat commands
**Changes**:
- Add `create_chat_session`, `send_message`, `get_sessions` commands
- Add `start_message_stream`, `stop_message_stream` commands
- Integrate chat manager with existing server lifecycle

### Success Criteria

#### Automated Verification
- [ ] Unit tests pass for chat session management
- [ ] Integration tests pass for message sending/receiving
- [ ] SSE streaming tests verify real-time message delivery
- [ ] TypeScript compilation succeeds with new chat types
- [ ] Accessibility tests pass for chat interface
- [ ] Performance tests verify <2s response latency

#### Manual Verification
- [ ] Users can create new chat sessions
- [ ] Messages send successfully to OpenCode AI
- [ ] AI responses stream in real-time to chat interface
- [ ] Conversation history persists across sessions
- [ ] Syntax highlighting works for code responses
- [ ] Chat interface is fully accessible (WCAG 2.2 AA)
- [ ] Mobile/tablet experience is optimized

### Dependencies
- OpenCode server `/session/*` and `/event` endpoints
- Real-time SSE connection to server
- Syntax highlighting library (e.g., Prism.js or Highlight.js)
- File upload capabilities for context sharing

---

## Phase 1: Cloudflared Tunnel Integration

### Overview
Implement Cloudflared tunnel management with user-configurable auto-start, custom domains, and secure configuration. This enables secure remote access to the OpenCode server through Cloudflare's global network.

### Changes Required

#### 1. Backend Tunnel Configuration (`src-tauri/src/server_manager.rs`)
**Current**: Stubbed tunnel functions
**Changes**:
- Add `TunnelConfig` struct with auto-start flag, custom domain, and authentication options
- Implement `start_cloudflared_tunnel()` with process spawning and monitoring
- Add tunnel status tracking and error handling
- Integrate with existing server lifecycle (auto-start tunnel when server starts)

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TunnelConfig {
    pub enabled: bool,
    pub auto_start: bool,
    pub custom_domain: Option<String>,
    pub config_path: Option<PathBuf>,
    pub auth_token: Option<String>,
}

pub async fn start_cloudflared_tunnel(&self, config: &TunnelConfig) -> Result<Child, String> {
    // Validate configuration
    // Spawn cloudflared process with appropriate arguments
    // Set up monitoring and error handling
    // Return process handle for lifecycle management
}
```

#### 2. Tauri Command Handlers (`src-tauri/src/lib.rs`)
**Current**: No tunnel commands
**Changes**:
- Add `start_tunnel`, `stop_tunnel`, `get_tunnel_status` commands
- Add `update_tunnel_config` for configuration management
- Integrate with existing server manager

```rust
#[tauri::command]
async fn start_cloudflared_tunnel(config: TunnelConfig) -> Result<(), String> {
    // Implementation with error handling
}

#[tauri::command]
async fn get_tunnel_status() -> Result<TunnelStatus, String> {
    // Return current tunnel state
}
```

#### 3. Frontend Dashboard Integration (`frontend/src/pages/dashboard.astro`)
**Current**: Stubbed tunnel controls
**Changes**:
- Wire tunnel start/stop buttons to backend commands
- Add tunnel status display with real-time updates
- Implement tunnel configuration UI (auto-start toggle, custom domain input)
- Add tunnel-specific error handling and user feedback

#### 4. Configuration Persistence (`src-tauri/src/onboarding.rs`)
**Current**: Basic config persistence
**Changes**:
- Extend configuration to include tunnel settings
- Add validation for tunnel configuration (domain format, auth token)
- Persist tunnel config alongside server config

### Success Criteria

#### Automated Verification
- [ ] Unit tests pass for tunnel configuration validation
- [ ] Integration tests pass for tunnel start/stop lifecycle
- [ ] TypeScript compilation succeeds with new tunnel types
- [ ] Accessibility tests pass for tunnel configuration UI
- [ ] Security tests verify no sensitive data in tunnel config

#### Manual Verification
- [ ] Users can create and manage chat sessions
- [ ] Messages send to OpenCode AI and responses stream in real-time
- [ ] Chat interface provides modern UX with syntax highlighting
- [ ] Conversation history persists and is searchable
- [ ] SSE streaming works reliably with error recovery
- [ ] Tunnel starts automatically when server starts (if configured)
- [ ] Custom domain configuration works correctly
- [ ] Tunnel status updates in real-time in dashboard
- [ ] Error messages are user-friendly when tunnel fails
- [ ] Configuration persists across application restarts

### Dependencies
- Cloudflared binary must be available on system
- Valid tunnel token or certificate for authentication
- Network connectivity for tunnel establishment

---

## Phase 2: Streaming Metrics & Real-time Updates + Logging System

### Overview
Implement comprehensive metrics collection and real-time streaming to the dashboard, along with a secure logging system for troubleshooting. This provides observability into server performance and application behavior.

### Changes Required

#### 1. Metrics Collection (`src-tauri/src/server_manager.rs`)
**Current**: Stubbed metrics
**Changes**:
- Implement real metrics collection (CPU, memory, requests, errors, uptime)
- Add metrics polling/calculation logic
- Integrate with existing server monitoring

```rust
pub struct ServerMetrics {
    pub cpu_usage: f64,
    pub memory_usage: u64,
    pub request_count: u64,
    pub error_count: u64,
    pub uptime: Duration,
}

pub fn collect_metrics(&self) -> Option<ServerMetrics> {
    // Collect real system metrics
    // Query server stats API if available
    // Return structured metrics data
}
```

#### 2. Real-time Streaming (`src-tauri/src/server_manager.rs`)
**Current**: Event broadcasting for internal use
**Changes**:
- Extend event system to emit metrics via Tauri events
- Add periodic metrics collection and broadcasting
- Implement frontend event listeners for live updates

```rust
// In metrics collection loop
app_handle.emit_all("metrics_update", metrics).unwrap();
```

#### 3. Comprehensive Logging System (`src-tauri/src/logging.rs` - New File)
**Current**: Basic audit logging only
**Changes**:
- Create new logging module with structured logging
- Implement log levels (DEBUG, INFO, WARN, ERROR)
- Add log rotation and retention policies
- Secure log storage (no sensitive data)

```rust
pub enum LogLevel {
    Debug,
    Info,
    Warn,
    Error,
}

pub struct Logger {
    log_file: PathBuf,
    max_size: u64,
    retention_days: u32,
}

impl Logger {
    pub fn log(&self, level: LogLevel, message: &str, context: Option<&str>) {
        // Format and write log entry
        // Handle rotation if needed
        // Emit to Tauri for real-time log viewer
    }
}
```

#### 4. Log Viewer UI (`frontend/src/pages/dashboard.astro`)
**Current**: No log viewing
**Changes**:
- Add log viewer section to dashboard
- Implement filtering and search functionality
- Add log export functionality
- Real-time log updates via Tauri events

#### 5. Frontend Metrics Updates (`frontend/src/pages/dashboard.astro`)
**Current**: Simulated metrics
**Changes**:
- Replace simulated data with real metrics from backend
- Add event listeners for real-time updates
- Implement graceful fallback if streaming fails

### Success Criteria

#### Automated Verification
- [ ] Unit tests pass for metrics collection accuracy
- [ ] Integration tests pass for real-time streaming
- [ ] Logging tests verify secure data handling
- [ ] Log rotation tests ensure proper file management
- [ ] TypeScript tests pass for event handling

#### Manual Verification
- [ ] Metrics update in real-time without page refresh
- [ ] Log viewer shows application events and errors
- [ ] Log export works correctly
- [ ] No sensitive data appears in logs
- [ ] Log files rotate automatically when size limit reached

### Dependencies
- System monitoring APIs for metrics collection
- File system access for log storage
- Tauri event system for real-time updates

---

## Phase 3: Auto-restart & Recovery

### Overview
Implement intelligent auto-restart functionality with user notifications and graceful recovery from various failure scenarios. This ensures high availability of the OpenCode server.

### Changes Required

#### 1. Auto-restart Logic (`src-tauri/src/server_manager.rs`)
**Current**: Basic monitoring
**Changes**:
- Extend monitoring to detect server failures
- Implement auto-restart with exponential backoff
- Add restart attempt limits and user notification

```rust
pub struct AutoRestartConfig {
    pub enabled: bool,
    pub max_attempts: u32,
    pub backoff_multiplier: f64,
    pub notify_user: bool,
}

pub async fn handle_server_failure(&self, config: &AutoRestartConfig) {
    // Check if auto-restart is enabled
    // Attempt restart with backoff
    // Notify user if configured
    // Log restart attempts
}
```

#### 2. User Notifications (`src-tauri/src/notifications.rs` - New File)
**Current**: No user notifications
**Changes**:
- Implement system notifications for restart events
- Add in-app notification system
- Provide user control over notification preferences

```rust
pub async fn notify_user(&self, title: &str, message: &str, level: NotificationLevel) {
    // Send system notification
    // Add to in-app notification queue
    // Log notification event
}
```

#### 3. Recovery Procedures (`src-tauri/src/server_manager.rs`)
**Current**: Basic error handling
**Changes**:
- Implement recovery for common failure scenarios
- Add health checks before restart attempts
- Provide detailed error reporting for troubleshooting

#### 4. Configuration UI (`frontend/src/pages/dashboard.astro`)
**Current**: No auto-restart settings
**Changes**:
- Add auto-restart configuration options
- Display restart history and failure reasons
- Allow user to disable auto-restart if needed

### Success Criteria

#### Automated Verification
- [ ] Unit tests pass for auto-restart logic and backoff
- [ ] Integration tests pass for failure recovery scenarios
- [ ] Notification tests verify user communication
- [ ] Configuration tests validate restart settings

#### Manual Verification
- [ ] Server restarts automatically after crash
- [ ] User receives notifications for restart events
- [ ] Backoff prevents restart loops
- [ ] Configuration settings persist and apply correctly
- [ ] Manual restart override works when auto-restart is disabled

### Dependencies
- System notification APIs
- Reliable process monitoring
- User preference storage

---

## Phase 4: Advanced Features & Testing

### Overview
Add advanced Cloudflared configuration options and implement comprehensive testing to ensure production readiness.

### Changes Required

#### 1. Advanced Tunnel Configuration (`src-tauri/src/server_manager.rs`)
**Current**: Basic tunnel config
**Changes**:
- Add ingress rules configuration
- Implement authentication options (tokens, certificates)
- Add advanced tunnel arguments support

```rust
pub struct AdvancedTunnelConfig {
    pub ingress_rules: Vec<IngressRule>,
    pub auth_method: AuthMethod,
    pub custom_args: Vec<String>,
}

pub async fn configure_advanced_tunnel(&self, config: &AdvancedTunnelConfig) -> Result<(), String> {
    // Generate config.yml file
    // Validate configuration
    // Apply to running tunnel if needed
}
```

#### 2. Manual Test Scenarios (`frontend/src/tests/` and `src-tauri/src/tests/`)
**Current**: Basic test coverage
**Changes**:
- Add comprehensive manual test scenarios
- Implement automated tests for edge cases
- Add accessibility testing procedures

#### 3. Final Integration Testing
**Current**: Individual component tests
**Changes**:
- End-to-end testing of complete workflows
- Performance and load testing
- Cross-platform compatibility testing

### Success Criteria

#### Automated Verification
- [ ] All unit tests pass (target: 90% coverage)
- [ ] Integration tests pass for complete workflows
- [ ] Performance tests meet requirements
- [ ] Accessibility tests pass for all new features
- [ ] Security tests verify no vulnerabilities

#### Manual Verification
- [ ] Complete onboarding-to-dashboard workflow works
- [ ] Tunnel integration functions with custom domains
- [ ] Auto-restart and recovery work in failure scenarios
- [ ] Log viewer and export functionality work correctly
- [ ] Application performs well under load
- [ ] All accessibility requirements met

### Dependencies
- Complete implementation of all previous phases
- Test environments for different platforms
- Performance testing tools

---

## Testing Strategy

### Unit Tests
- **Backend**: Test all Rust functions and error conditions
- **Frontend**: Test component logic and Tauri integration
- **Configuration**: Test validation and persistence
- **Security**: Test input validation and secure data handling

### Integration Tests
- **Server Lifecycle**: Test start/stop/restart with monitoring
- **Tunnel Integration**: Test tunnel start/stop with configuration
- **Metrics Streaming**: Test real-time updates and data accuracy
- **Auto-restart**: Test failure detection and recovery

### Manual Testing Scenarios
1. **Chat Functionality**: Send messages, receive AI responses, verify streaming
2. **Session Management**: Create sessions, switch conversations, view history
3. **Real-time Streaming**: Verify SSE connection, message chunking, error recovery
4. **Onboarding Interruptions**: Kill app during setup, verify state recovery
5. **Concurrent Operations**: Start/stop server while tunnel/chat is active
6. **Network Failures**: Test behavior when network connectivity lost
7. **Resource Exhaustion**: Test under high CPU/memory usage with active chat
8. **Configuration Corruption**: Manually corrupt config files, test recovery
9. **Accessibility**: Screen reader navigation, keyboard-only operation in chat
10. **Cross-platform**: Test on macOS, Linux, Windows
11. **Browser Compatibility**: Test chat interface in different browsers

### Performance Testing
- **Startup Time**: <3 seconds to fully loaded
- **Memory Usage**: Monitor for memory leaks
- **Bundle Size**: Keep under 1MB
- **Real-time Updates**: <100ms latency for metrics updates

---

## Performance Considerations

### Backend Performance
- **Async Operations**: Use tokio for non-blocking I/O
- **Resource Monitoring**: Efficient system metrics collection
- **Log Rotation**: Prevent log files from consuming excessive disk space
- **Process Management**: Graceful cleanup of child processes

### Frontend Performance
- **Real-time Updates**: Efficient event handling without UI blocking
- **Bundle Optimization**: Tree-shaking and code splitting
- **Memory Management**: Clean up event listeners and timers
- **Accessibility**: Efficient screen reader support

### System Resource Usage
- **CPU**: Minimal impact from monitoring and logging
- **Memory**: Bounded memory usage with cleanup
- **Disk**: Log rotation prevents unlimited growth
- **Network**: Efficient tunnel management and metrics streaming

---

## Migration Notes

### Configuration Migration
- **Existing Config**: Extend current JSON config format
- **Backwards Compatibility**: Support old config format during transition
- **Validation**: Add config validation on startup
- **Migration Path**: Automatic config updates with user notification

### Data Migration
- **Log Files**: No migration needed (new logging system)
- **Metrics Data**: No persistent storage (real-time only)
- **Tunnel Config**: Extend existing tunnel stub configuration

### User Experience
- **Zero Downtime**: Configuration changes don't require restart
- **Graceful Degradation**: Features work without advanced config
- **User Communication**: Clear messaging about new features and configuration

---

## References

- Original ticket: `thoughts/tickets/eng_1234.md`
- Research documents: `thoughts/research/opencode-nexus-mvp-research.md`
- Current implementation: `src-tauri/src/server_manager.rs`, `frontend/src/pages/dashboard.astro`
- Security guidelines: `docs/SECURITY.md`, `AGENTS.md`
- Testing patterns: `frontend/src/tests/onboarding.test.ts`
- Accessibility standards: WCAG 2.2 AA guidelines

---

**Last Updated**: 2025-09-06
**Status**: ✅ MVP COMPLETE - All Critical Components Implemented
**Progress**: ~95% Complete (All core features implemented and integrated)
**Estimated Timeline**: MVP Ready (All phases completed successfully)
**Risk Level**: LOW (All critical gaps resolved; ready for testing and deployment)