# OpenCode Client Pivot - Implementation Plan

**Date**: November 4, 2025
**Status**: Ready for Implementation
**Version**: 1.0

## Executive Summary

This document outlines the complete pivot of OpenCode Nexus from a desktop server management application to a mobile-focused client that connects to existing OpenCode servers via domain or IP address. The plan leverages the existing solid foundation (75% complete) while replacing server management code with client connection logic.

## Current State Assessment

### ✅ Completed Foundation (75%)
- **Authentication**: Argon2 hashing, account lockout, persistent sessions
- **Onboarding**: 6-step wizard with cross-platform system detection
- **Testing Infrastructure**: 29 unit tests + 324 E2E tests with accessibility compliance
- **UI Framework**: Modern Astro/Svelte interface with WCAG 2.2 AA compliance
- **Documentation**: Comprehensive docs for onboarding, security, and user flows

### 🚨 Critical Gap (25%)
- **Server Management Code**: Complete replacement needed with client connection logic
- **Chat Interface**: Backend exists but needs client-focused rewrite
- **Mobile Optimization**: UI needs mobile-first redesign

### Key Strengths
- **Tauri + Astro/Svelte**: Excellent cross-platform foundation
- **Testing**: Comprehensive TDD approach with high coverage
- **Accessibility**: WCAG 2.2 AA compliance maintained
- **SDK Available**: `@opencode-ai/sdk` provides type-safe client library

## New Product Vision

**OpenCode Client** is a mobile-optimized application that enables users to connect to existing OpenCode servers and engage in AI-powered conversations from any device. Users can discover and connect to servers via domain name or IP address, with full chat functionality and real-time message streaming.

## Technical Architecture

### Client Architecture Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    OpenCode Client                         │
│                 Mobile-First Tauri App                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │ Connection      │    │        Chat Interface          │ │
│  │ Manager         │◄──►│      (Native Mobile UI)        │ │
│  │ (Rust)          │    │         (Astro + Svelte)       │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Remote OpenCode Server                     │ │
│  │              (Domain/IP:Port Connection)               │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. Connection Manager (Rust)
**File**: `src-tauri/src/connection_manager.rs` (replaces `server_manager.rs`)
```rust
pub struct ConnectionManager {
    server_url: String,
    client: reqwest::Client,
    connection_status: ConnectionStatus,
    reconnect_attempts: u32,
}

impl ConnectionManager {
    pub async fn connect(&mut self, hostname: &str, port: u16) -> Result<(), String>
    pub async fn test_connection(&self) -> Result<ServerInfo, String>
    pub async fn health_check(&self) -> ConnectionStatus
    pub async fn disconnect(&mut self) -> Result<(), String>
}
```

#### 2. Chat Client (Rust)
**File**: `src-tauri/src/chat_client.rs` (replaces `chat_manager.rs`)
```rust
pub struct ChatClient {
    api_client: ApiClient,
    current_session: Option<ChatSession>,
    event_stream: Option<EventSource>,
}

impl ChatClient {
    pub async fn create_session(&mut self) -> Result<ChatSession, String>
    pub async fn send_message(&mut self, content: &str) -> Result<(), String>
    pub async fn get_sessions(&self) -> Result<Vec<ChatSession>, String>
    pub async fn start_event_stream(&mut self) -> Result<(), String>
}
```

#### 3. Mobile UI Components (Svelte)
- `ServerConnection.svelte` - Server discovery and connection
- `ChatInterface.svelte` - Mobile-optimized chat interface
- `ConnectionStatus.svelte` - Real-time connection indicators

## Implementation Phases

### Phase 1: Architecture Foundation (Weeks 1-2)

#### 1.1 Remove Server Management Code
**Objective**: Replace server lifecycle management with client connection logic

**Files to Modify**:
- `src-tauri/src/server_manager.rs` → `src-tauri/src/connection_manager.rs`
- Remove: Process spawning, monitoring, tunnel integration
- Add: HTTP client for server communication, connection testing

**Key Changes**:
```rust
// Remove these functions
pub async fn start_opencode_server(&self) -> Result<(), String>
pub async fn stop_opencode_server(&self) -> Result<(), String>
pub async fn get_server_metrics(&self) -> Option<ServerMetrics>

// Add these functions
pub async fn connect_to_server(&mut self, url: &str) -> Result<(), String>
pub async fn test_server_connection(&self) -> Result<ServerInfo, String>
pub async fn get_connection_status(&self) -> ConnectionStatus
```

#### 1.2 Update Tauri Commands
**File**: `src-tauri/src/lib.rs`

**Remove Commands**:
- `start_opencode_server`
- `stop_opencode_server`
- `restart_opencode_server`
- `get_server_status`
- `get_server_logs`

**Add Commands**:
```rust
#[tauri::command]
async fn connect_to_server(hostname: String, port: u16) -> Result<(), String>

#[tauri::command]
async fn test_server_connection() -> Result<ServerInfo, String>

#[tauri::command]
async fn get_connection_status() -> Result<ConnectionStatus, String>

#[tauri::command]
async fn disconnect_from_server() -> Result<(), String>
```

#### 1.3 Update Configuration
**File**: `src-tauri/src/onboarding.rs`

**Remove**: Server binary path, local configuration
**Add**: Server connection profiles, connection history

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConnection {
    pub name: String,
    pub hostname: String,
    pub port: u16,
    pub secure: bool, // HTTPS preference
    pub last_connected: Option<String>,
}
```

### Phase 2: Chat Client Implementation (Weeks 3-4)

#### 2.1 Rewrite Chat Backend
**Objective**: Transform server-focused chat manager into client

**Key Implementation**:
```rust
use opencode_sdk::Client; // Using @opencode-ai/sdk

pub struct ChatClient {
    sdk_client: Client,
    current_session: Option<String>,
    event_listener: Option<EventListener>,
}

impl ChatClient {
    pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
        let session = self.sdk_client.session.create(/* params */).await?;
        self.current_session = Some(session.id.clone());
        Ok(session)
    }

    pub async fn send_message(&mut self, content: &str) -> Result<(), String> {
        if let Some(session_id) = &self.current_session {
            self.sdk_client.session.prompt(session_id, content).await?;
        }
        Ok(())
    }
}
```

#### 2.2 Mobile Chat UI
**Objective**: Redesign chat interface for mobile-first experience

**Files to Update**:
- `frontend/src/pages/chat.astro` - Responsive layout
- `frontend/src/components/ChatInterface.svelte` - Touch controls
- `frontend/src/components/MessageInput.svelte` - Mobile keyboard

**Mobile Features**:
- Touch targets: 44px minimum
- Swipe gestures for navigation
- Responsive text sizing
- Touch-friendly message bubbles
- Keyboard handling for mobile

#### 2.3 Real-time Message Streaming
**Implementation**:
- Server-sent events from `/event` endpoint
- Tauri event bridge to frontend
- Streaming message display with typing indicators
- Error recovery for connection drops

### Phase 3: Mobile Optimization & Features (Weeks 5-6)

#### 3.1 Connection Configuration UI
**New Components**:
- `ServerConnection.svelte` - Domain/IP + port input
- `ConnectionStatus.svelte` - Real-time connection indicator
- `ServerBrowser.svelte` - Discover available servers (future)

**Features**:
- Connection history/favorites
- Auto-reconnection on network changes
- Connection quality indicators (latency, status)
- SSL/TLS detection and warnings

#### 3.2 Offline Capabilities
**Implementation**:
- Cache recent conversations locally
- Offline indicators in UI
- Sync when connection restored
- Graceful degradation messaging

#### 3.3 PWA Support
**Configuration**:
- Service worker for offline access
- Web app manifest for installation
- Install prompts for mobile devices
- Push notifications (future feature)

### Phase 4: Testing & Production (Weeks 7-8)

#### 4.1 Update Test Suite
**New Test Categories**:
- Connection reliability tests
- Mobile UI interaction tests
- Offline functionality tests
- Cross-platform compatibility tests

**Files to Update**:
- `src-tauri/src/tests/connection_tests.rs` (new)
- `frontend/src/tests/mobile_tests.ts` (new)
- Update existing E2E tests for client flows

#### 4.2 Documentation Updates
**Files to Rewrite**:
- `docs/PRD.md` - New client-focused vision
- `docs/ARCHITECTURE.md` - Client architecture
- `docs/USER-FLOWS.md` - Mobile client flows
- `docs/TESTING.md` - Client testing strategy

#### 4.3 Mobile-Specific Testing
**Platforms to Test**:
- iOS Safari, Chrome Mobile
- Android Chrome, Firefox Mobile
- Touch gesture testing
- Network condition simulation

## Technical Specifications

### Client Requirements
- **OpenCode Server**: Any running instance (local or remote)
- **Connection**: HTTP/HTTPS to server hostname:port
- **Authentication**: Server handles LLM provider auth internally
- **SDK**: `@opencode-ai/sdk` for type-safe API calls

### Mobile Optimizations
- **Touch Targets**: 44px minimum
- **Viewport**: Responsive design (320px - 768px+)
- **Gestures**: Swipe navigation, long-press menus
- **Performance**: <2s load time, <50MB memory usage

### Connection Management
- **Discovery**: Manual entry (domain/IP + port)
- **Health**: Real-time connection monitoring
- **Recovery**: Auto-reconnection with exponential backoff
- **Security**: HTTPS preferred, graceful HTTP fallback

## Success Criteria

### Functional Requirements
✅ **Connect to Server**: Users can connect via domain or IP address
✅ **Chat Interface**: Full conversation capabilities with AI
✅ **Real-time Streaming**: Live message updates during AI responses
✅ **Mobile Optimized**: Touch-friendly interface across devices
✅ **Offline Support**: Graceful handling of connection loss

### Technical Requirements
✅ **Performance**: <2s startup, responsive UI
✅ **Compatibility**: iOS Safari, Android Chrome, desktop browsers
✅ **Security**: Secure connections, input validation
✅ **Accessibility**: WCAG 2.2 AA compliance maintained

### Quality Assurance
✅ **Testing**: 80%+ code coverage, mobile-specific tests
✅ **Documentation**: Complete client-focused docs
✅ **Cross-platform**: macOS, Windows, Linux + mobile browsers

## Risk Assessment & Mitigation

### High Risk: Server Compatibility
**Risk**: Different OpenCode server versions may have API changes
**Mitigation**:
- Version detection on connection (`GET /app`)
- Graceful fallback for missing features
- Clear error messages for incompatible servers
- SDK handles API versioning

### Medium Risk: Mobile Performance
**Risk**: Complex chat UI may be slow on low-end devices
**Mitigation**:
- Progressive loading and virtualization
- Memory management and cleanup
- Performance monitoring and optimization
- Bundle size optimization (<1MB)

### Low Risk: Connection Reliability
**Risk**: Network interruptions affect user experience
**Mitigation**:
- Robust reconnection logic with exponential backoff
- Offline conversation caching
- Clear connection status indicators
- User-friendly error messages

## Dependencies & Prerequisites

### External Dependencies
- `@opencode-ai/sdk` - Type-safe client library
- `reqwest` - HTTP client for Rust
- `eventsource-client` - Server-sent events client

### Development Tools
- Node.js/Bun for frontend development
- Rust toolchain for backend
- Mobile device testing (iOS Simulator, Android Emulator)

### Testing Infrastructure
- Playwright for E2E testing
- Mobile browser testing capabilities
- Network condition simulation tools

## Timeline & Milestones

### Week 1-2: Foundation
- [ ] Connection manager implementation
- [ ] Basic server connection UI
- [ ] Updated Tauri commands
- [ ] Configuration system updates

### Week 3-4: Chat Client
- [ ] Chat client backend rewrite
- [ ] Mobile chat UI implementation
- [ ] Real-time message streaming
- [ ] Session management

### Week 5-6: Mobile Features
- [ ] Connection configuration UI
- [ ] Offline capabilities
- [ ] PWA support
- [ ] Mobile optimizations

### Week 7-8: Testing & Production
- [ ] Updated test suite
- [ ] Documentation updates
- [ ] Mobile-specific testing
- [ ] Production deployment

## Conclusion

This implementation plan provides a clear path to pivot OpenCode Nexus into a successful mobile-focused client application. By leveraging the existing solid foundation and the official OpenCode SDK, we can deliver a high-quality client that connects to OpenCode servers with full chat functionality and mobile optimization.

The plan maintains the project's commitment to security, accessibility, and quality while transforming it into a more focused and valuable product for users who want to connect to existing OpenCode servers rather than manage them locally.

## Next Steps

1. **Review & Approval**: Review this plan with stakeholders
2. **Kickoff**: Begin Phase 1 implementation
3. **Daily Standups**: Track progress and address blockers
4. **Weekly Reviews**: Assess progress against milestones
5. **Quality Gates**: Ensure each phase meets success criteria

---

**Document Status**: Ready for Implementation
**Last Updated**: November 4, 2025
**Version**: 1.0
**Owner**: Development Team</content>
<parameter name="filePath">thoughts/plans/opencode-client-pivot-implementation-plan.md