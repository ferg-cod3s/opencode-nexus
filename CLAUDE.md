# CLAUDE.md – OpenCode Nexus Development Guide

This file provides guidance to Claude Code (claude.ai/code) when working with the OpenCode Nexus codebase.

## Project Overview

OpenCode Nexus is a **cross-platform client application** for connecting to OpenCode servers started with `opencode serve`. Built with **Tauri** (Rust backend) + **Astro/Svelte 5** (frontend) + **Bun** runtime, it provides a mobile-first interface for AI-powered coding conversations with real-time streaming.

**Key Features:**
- **Native OpenCode Client** - Connect to OpenCode servers with a beautiful native interface
- **Real-Time Chat Interface** - AI conversation experience with instant message streaming
- **Cross-Platform Support** - iOS (TestFlight ready), Android (prepared), Desktop (macOS, Windows, Linux)
- **Secure Authentication** - Argon2 password hashing, account lockout protection, encrypted local storage
- **Session Management** - Persistent conversation history with search and context preservation
- **Accessibility First** - WCAG 2.2 AA compliant with full screen reader and keyboard navigation support

## Quick Start Commands

### Frontend Development (Astro + Svelte)
```bash
cd frontend
bun install              # Install dependencies
bun run dev              # Development server (http://localhost:4321)
bun run build            # Production build
bun test                 # Run unit tests with Bun
bun run test:e2e         # Run end-to-end tests with Playwright
bun run test:e2e:ui      # Run E2E tests with UI
bun run lint             # ESLint with accessibility checks
bun run typecheck        # TypeScript checking
bun run format           # Format code with Prettier
```

### Backend Development (Rust + Tauri)
```bash
# Core Tauri development (from project root)
cargo tauri dev          # Run full application (backend + frontend)
cargo tauri build        # Build production application

# Rust backend only (from src-tauri/ directory)
cargo build              # Build Rust backend
cargo test               # Run unit tests
cargo clippy             # Linting and code analysis
cargo fmt                # Code formatting

# Connection and chat testing
cargo test connection_manager  # Test server connection management
cargo test auth                # Test authentication system
cargo test chat_client         # Test chat client functionality
```

### Full Stack Development
```bash
# Complete development workflow
cargo tauri dev          # Starts both Rust backend and frontend with hot reload

# Comprehensive testing
cargo test               # Backend tests (auth, connection management, chat client)
cd frontend && bun test  # Frontend tests (UI components, accessibility)

# Quality assurance
cargo clippy && cd frontend && bun run lint && bun run typecheck
```

## Development Standards & Requirements

### Core Principles
- **Test-Driven Development (TDD)**: Write failing tests before implementation - MANDATORY
- **Security First**: All user inputs validated, secure server connections, secure password storage (Argon2)
- **Accessibility**: WCAG 2.2 AA compliance required for all UI components
- **Cross-Platform**: Support iOS, Android, macOS, Linux, and Windows
- **Mobile-First**: UI/UX optimized for mobile touch interactions

### Code Quality Requirements
- **Function Size**: Target 10-30 lines, max 50 before refactoring
- **TypeScript**: Strict mode enabled - no `any` types allowed
- **Rust**: Use Result<T, E> and Option<T> for error handling
- **Testing**: 80-90% coverage target for critical paths
- **Documentation**: Keep status_docs/TODO.md updated with progress

## Comprehensive Documentation

The `/docs` directory contains detailed documentation covering all aspects of the project. **Always consult these docs before making architectural decisions.**

### Essential Reading
- **[docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md)** - Client-only system architecture and design decisions
- **[docs/client/SECURITY.md](docs/client/SECURITY.md)** - Client connection security and data protection
- **[docs/client/TESTING.md](docs/client/TESTING.md)** - **TDD approach (mandatory)**, mobile testing strategies
- **[docs/client/PRD.md](docs/client/PRD.md)** - Mobile-first client goals, features, and requirements

### Development Workflow
- **[docs/client/USER-FLOWS.md](docs/client/USER-FLOWS.md)** - Mobile touch interactions and offline user flows
- **[docs/client/README.md](docs/client/README.md)** - Complete client documentation guide

### Current Implementation Status
- **[status_docs/TODO.md](status_docs/TODO.md)** - **Current progress (15% complete - client pivot in progress)**, task tracking, and next priorities
- **[status_docs/CURRENT_STATUS.md](status_docs/CURRENT_STATUS.md)** - Detailed status of client pivot implementation
- **[thoughts/plans/opencode-client-pivot-implementation-plan.md](thoughts/plans/opencode-client-pivot-implementation-plan.md)** - Client pivot implementation plan

## Technology Stack Details

### Backend (Rust + Tauri)
- **Framework**: Tauri 2.x for cross-platform client applications (iOS, Android, Desktop)
- **Runtime**: Tokio for async operations and HTTP client connections
- **HTTP Client**: Reqwest for RESTful API communication with OpenCode servers
- **Security**: Argon2 for password hashing, TLS 1.3 for server connections, encrypted local storage
- **Storage**: JSON-based configuration and conversation caching
- **Testing**: Built-in Rust testing with comprehensive unit tests

### Frontend (TypeScript + Astro + Svelte)
- **Framework**: Astro for static site generation with islands architecture
- **Components**: Svelte 5 for reactive UI components
- **Runtime**: Bun for package management and testing
- **Styling**: CSS with HSLA colors and REM sizing for accessibility
- **Testing**: Bun test runner with accessibility testing integration

## Project Structure

```
opencode-nexus/
├── docs/                           # Comprehensive project documentation
│   └── client/                    # Client-specific documentation
│       ├── ARCHITECTURE.md        # Client-only system architecture
│       ├── SECURITY.md            # Client connection security
│       ├── TESTING.md             # TDD approach and mobile testing
│       ├── PRD.md                 # Mobile-first client requirements
│       ├── USER-FLOWS.md          # Mobile touch interactions
│       └── README.md              # Client documentation guide
├── src-tauri/                     # Rust backend (Tauri client application)
│   ├── src/
│   │   ├── lib.rs                 # Tauri command handlers
│   │   ├── connection_manager.rs  # OpenCode server connection management
│   │   ├── auth.rs                # Authentication with Argon2 hashing
│   │   ├── api_client.rs          # OpenCode server API integration
│   │   ├── chat_client.rs         # Chat client and session management
│   │   └── message_stream.rs      # Real-time SSE message streaming
│   ├── Cargo.toml                 # Dependencies (Tauri, reqwest, tokio, etc.)
│   └── tests/                     # Rust unit tests (TDD approach)
├── frontend/                      # Astro + Svelte 5 frontend (mobile-first)
│   ├── src/pages/
│   │   ├── index.astro           # Entry point with routing logic
│   │   ├── chat.astro            # Main chat interface
│   │   └── login.astro           # Authentication interface
│   ├── src/components/           # Svelte components (touch-optimized)
│   ├── src/layouts/Layout.astro  # Base layout with WCAG 2.2 AA compliance
│   └── src/tests/                # Frontend tests with accessibility checks
├── thoughts/                      # Research and planning documentation
│   └── plans/                    # Client pivot implementation plan
├── status_docs/                   # Project status and tracking
│   ├── TODO.md                   # Current progress (15% complete - client pivot in progress)
│   └── CURRENT_STATUS.md         # Detailed status of client pivot
├── CLAUDE.md                     # This file - Claude Code guidance
└── AGENTS.md                     # Multi-AI system configuration (see [AGENTS.md](AGENTS.md))
```

### Key Files for Development
- **[src-tauri/src/lib.rs](src-tauri/src/lib.rs)** - Tauri command handlers and main entry point
- **[src-tauri/src/connection_manager.rs](src-tauri/src/connection_manager.rs)** - OpenCode server connection management (replaces server_manager.rs)
- **[src-tauri/src/auth.rs](src-tauri/src/auth.rs)** - Authentication system with Argon2
- **[src-tauri/src/chat_client.rs](src-tauri/src/chat_client.rs)** - Chat client and session management (replaces chat_manager.rs)
- **[src-tauri/src/api_client.rs](src-tauri/src/api_client.rs)** - OpenCode API integration with RESTful client
- **[src-tauri/src/message_stream.rs](src-tauri/src/message_stream.rs)** - Real-time SSE message streaming
- **[frontend/src/pages/chat.astro](frontend/src/pages/chat.astro)** - Main chat interface (mobile-optimized)
- **[frontend/src/pages/login.astro](frontend/src/pages/login.astro)** - Authentication interface
- **[src-tauri/Cargo.toml](src-tauri/Cargo.toml)** - Backend dependencies (Tauri, reqwest, tokio, etc.)

## Development Workflow

### 1. Planning Phase
- Read implementation plan in `thoughts/plans/`
- Review relevant documentation in `docs/`
- Update status_docs/TODO.md with specific tasks using TodoWrite tool

### 2. TDD Implementation
- Write failing tests first (MANDATORY)
- Implement minimal code to pass tests
- Refactor while keeping tests green
- Update status_docs/TODO.md with completed tasks immediately after completion

### 2.1 Test Maintenance (100% Pass Rate Required)

**All tests must pass at all times.** When changing code that breaks existing tests:

1. **Understand the Test First:** Read the failing test to understand what behavior it expects
2. **Determine Intent:** Is the test outdated, or is your change incorrect?
3. **Update the Test:** If the change is intentional, update the test to reflect new behavior
4. **Never Skip Tests:** Do not use `.skip()`, `#[ignore]`, or comment out tests
5. **Remove Obsolete Tests:** If functionality is removed, delete related tests entirely

**Example Workflow:**
```bash
# 1. Make your code change
# 2. Run tests
cargo test && cd frontend && bun test

# 3. If tests fail, investigate:
#    - Is the test correct and my change wrong? → Fix my change
#    - Is the test outdated? → Update the test to reflect new behavior
#    - Is the feature removed? → Delete the test

# 4. Run tests again to confirm 100% pass
cargo test && cd frontend && bun test

# 5. Commit only when all tests pass
git commit -m "feat: implement feature with updated tests"
```

### 3. Quality Assurance
- Run all tests (`cargo test` + `cd frontend && bun test`)
- Check compilation (`cargo clippy` + `bun run typecheck`)
- Verify accessibility (WCAG 2.2 AA compliance)
- Ensure security requirements are met

### 4. Documentation & Commit (MANDATORY)
**After completing each major feature or component:**

**A. Validate Implementation:**
- Verify all tests pass (`cargo test` + `cd frontend && bun test`)
- Run quality checks (`cargo clippy` + `bun run lint` + `bun run typecheck`)
- Confirm accessibility compliance for UI changes
- Validate security requirements (no secrets exposed, input validation, etc.)

**B. Update Documentation:**
- Mark completed tasks in [status_docs/TODO.md](status_docs/TODO.md) immediately
- Add newly discovered tasks or requirements
- Update progress metrics and milestone status
- Document any architectural decisions or patterns

**C. Create Descriptive Commit:**
Use conventional commit format with comprehensive details:
```bash
git commit -m "$(cat <<'EOF'
feat: implement [specific feature]

TDD implementation complete:
- ✅ [Specific functionality implemented]
- ✅ [Test coverage and validation]
- ✅ [Integration with existing systems]

Files modified:
- [file.rs] (XXX lines) - [purpose and changes]
- [file.astro] - [UI/UX changes and accessibility]
- [config files] - [dependency or configuration changes]

[Any critical issues resolved or patterns established]
Tests passing. [Current status and next steps]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**D. Progress Communication:**
Provide clear status including:
- Completed phase/feature with reference to implementation plan
- Current progress percentage vs [status_docs/TODO.md](status_docs/TODO.md) targets
- Next development priorities from [thoughts/plans/](thoughts/plans/)
- Any blockers or decisions needed to proceed

### Event Streaming (SSE)
**Pattern**: Real-time updates from backend to frontend
```rust
// Backend: Send events via event emitter
app.emit("event_name", &payload)?;
```

```typescript
// Frontend: Listen for events
import { listen } from '@tauri-apps/api/event';
await listen('event_name', (event) => {
    // Handle event.payload
});
```

### State Management in Rust
**Pattern**: Use Arc<Mutex<T>> for shared state
```rust
use std::sync::Arc;
use tokio::sync::Mutex;

// Create shared state
let state = Arc::new(Mutex::new(ServerManager::new()));

// Clone Arc for each task (cheap reference counting)
let state_clone = state.clone();
tokio::spawn(async move {
    let mut manager = state_clone.lock().await;
    // Use manager
});
```

## Security Requirements (Critical)

- **Password Storage**: Argon2 hashing with salt (implemented)
- **Account Protection**: Lockout after 5 failed attempts (implemented)
- **Input Validation**: Sanitize ALL user inputs before processing
- **Secret Management**: Never commit secrets - use environment variables
- **Connection Security**: TLS 1.3 for all OpenCode server connections
- **Data Encryption**: AES-256 for local conversation storage

## Performance Standards

- **Startup Time**: Application should start in under 2 seconds (mobile target)
- **Bundle Size**: Keep frontend bundles under 1MB for mobile networks
- **Memory Usage**: Monitor Rust memory usage with Arc for shared data
- **Responsiveness**: UI should remain responsive during API calls and streaming
- **Mobile Optimization**: Touch targets 44px minimum, responsive layouts

## Current Implementation Status

### 🔄 Client Pivot In Progress (15% Complete)

**Status**: Project has pivoted from desktop server management to mobile-first client architecture.

**✅ Phase 0: Foundation & Security (COMPLETED)**
- **Dependency Updates**: All dependencies updated to latest secure versions (Nov 6, 2025)
- **Security Vulnerabilities**: All 6 frontend vulnerabilities resolved (0 vulnerabilities)
- **Authentication**: Argon2 hashing, account lockout, persistent sessions ([src-tauri/src/auth.rs](src-tauri/src/auth.rs))
- **Build System**: Frontend and backend compilation validated
- **iOS Deployment**: TestFlight build ready (IPA generated at 3.2MB)

**🔴 Phase 1: Architecture Foundation (IN PROGRESS - HIGH PRIORITY)**
- [ ] **Replace Server Manager with Connection Manager** - CRITICAL
- [ ] **Update Tauri Commands** - Remove server lifecycle commands, add connection commands
- [ ] **Rewrite Chat Backend** - Replace local server integration with OpenCode SDK
- [ ] **Update Configuration System** - Server connection profiles instead of server binary config

**🟡 Phase 2: Chat Client Implementation (PENDING - BLOCKED BY PHASE 1)**
- [ ] **Mobile Chat UI** - Touch-optimized interface (44px targets)
- [ ] **Real-time Streaming** - SSE client for `/event` endpoint
- [ ] **Offline Capabilities** - Conversation caching (✅ localStorage implemented, needs testing)
- [ ] **Session Management** - HTTP API for session CRUD operations

**⚠️ Critical Blockers**
- **Chat Interface**: UI scaffolding exists but NO backend integration (E2E: 2/14 tests passing)
- **E2E Test Status**: 46/121 passing (38%) - 75 tests blocked by missing chat backend
- **Connection Manager**: Must replace server_manager.rs with connection_manager.rs

**Next Immediate Priority**: Implement Connection Manager to unblock chat functionality

See [status_docs/TODO.md](status_docs/TODO.md) for complete task breakdown and [docs/client/](docs/client/) for architecture details.

## Common Patterns and Gotchas

### Tauri IPC Communication
**Pattern**: Frontend ↔ Backend communication via Tauri commands
```typescript
// Frontend: Invoke Rust command
import { invoke } from '@tauri-apps/api/core';
const result = await invoke('command_name', { arg: value });
```

```rust
// Backend: Define command handler
#[tauri::command]
async fn command_name(arg: String) -> Result<Response, String> {
    // Implementation
}
```

### Async Rust with Tokio
**Issue**: MutexGuard not Send-safe across await boundaries
**Solution**: Extract data before await, don't hold locks across async calls
```rust
// ❌ Bad: Holding lock across await
let guard = mutex.lock().await;
some_async_fn().await; // Error!

// ✅ Good: Release lock before await
let data = {
    let guard = mutex.lock().await;
    guard.clone() // Extract data
};
some_async_fn().await; // OK!
```

## Emergency Procedures

### Security Incident
1. Immediately revoke compromised credentials
2. Assess scope and impact
3. Patch vulnerability
4. Document and implement prevention measures

### Critical Bug
1. Reproduce with failing test
2. Identify root cause
3. Implement minimal fix
4. Verify fix and test for regressions

---

**Key Reminders:**
- Always follow TDD principles (tests first) - see [docs/client/TESTING.md](docs/client/TESTING.md)
- Security and accessibility are non-negotiable - see [docs/client/SECURITY.md](docs/client/SECURITY.md) and WCAG 2.2 AA
- Reference comprehensive documentation in [docs/client/](docs/client/) for all architectural decisions
- Update [status_docs/TODO.md](status_docs/TODO.md) and commit completed work following [documentation workflow](#4-documentation--commit-mandatory)
- Current status: 15% complete - client pivot in progress, connection manager needed to unblock chat functionality
- **AGENTS.md Reference**: For quick build/lint/test commands, see [AGENTS.md](AGENTS.md)

## Essential Context for AI Development
- **Project Type**: Tauri 2.x client application (iOS, Android, Desktop) - NOT a web app or server management tool
- **Current Status**: Client Pivot In Progress (15% complete) - Foundation secure, connection manager needed
- **Architecture**: See [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md) for client-only architecture
- **Runtime**: Bun for frontend, Tokio for backend async HTTP client operations
- **Critical Path**: Replace server_manager.rs → connection_manager.rs to unblock chat functionality
- **Test Coverage**: Backend secure (29+ tests), E2E 38% passing (46/121) - blocked by missing chat backend
- **Mobile-First**: All UI/UX decisions prioritize mobile touch interactions (44px targets)

## Quick Reference

### Running the Application
```bash
# Development mode (hot reload)
cargo tauri dev

# Production build
cd frontend && bun run build && cd .. && cargo tauri build
```

### Common Tasks
```bash
# Run all tests
cargo test && cd frontend && bun test

# Code quality checks
cargo clippy && cd frontend && bun run lint && bun run typecheck

# Format code
cargo fmt && cd frontend && bun run format
```

### Debugging
- **Backend logs**: Check stdout from `cargo tauri dev`
- **Frontend logs**: Browser DevTools Console (F12)
- **Tauri IPC**: Enable debug logging in `tauri.conf.json`
- **Connection issues**: Check OpenCode server connectivity and API responses
- **Chat streaming**: Monitor SSE events in Network tab (DevTools)