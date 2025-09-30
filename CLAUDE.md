# CLAUDE.md – OpenCode Nexus Development Guide

This file provides guidance to Claude Code (claude.ai/code) when working with the OpenCode Nexus codebase.

## Project Overview

OpenCode Nexus is a **cross-platform desktop application** for managing OpenCode servers with secure remote access. Built with **Tauri** (Rust backend) + **Astro/Svelte 5** (frontend) + **Bun** runtime, it provides a comprehensive solution for OpenCode server lifecycle management, authentication, and secure tunneling.

**Key Features:**
- Server process management (start/stop/restart with monitoring)
- User authentication with Argon2 hashing and session management
- Real-time metrics and event streaming
- Cloudflared tunnel integration for secure remote access
- Cross-platform system requirements detection
- Comprehensive accessibility support (WCAG 2.2 AA compliant)

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

# Server management testing
cargo test server_manager  # Test server lifecycle management
cargo test auth            # Test authentication system
```

### Full Stack Development
```bash
# Complete development workflow
cargo tauri dev          # Starts both Rust backend and frontend with hot reload

# Comprehensive testing
cargo test               # Backend tests (auth, server management, onboarding)
cd frontend && bun test  # Frontend tests (UI components, accessibility)

# Quality assurance
cargo clippy && cd frontend && bun run lint && bun run typecheck
```

## Development Standards & Requirements

### Core Principles
- **Test-Driven Development (TDD)**: Write failing tests before implementation - MANDATORY
- **Security First**: All user inputs validated, secure password storage (Argon2)
- **Accessibility**: WCAG 2.2 AA compliance required for all UI components
- **Cross-Platform**: Support macOS, Linux, and Windows

### Code Quality Requirements
- **Function Size**: Target 10-30 lines, max 50 before refactoring
- **TypeScript**: Strict mode enabled - no `any` types allowed
- **Rust**: Use Result<T, E> and Option<T> for error handling
- **Testing**: 80-90% coverage target for critical paths
- **Documentation**: Keep TODO.md updated with progress

## Comprehensive Documentation

The `/docs` directory contains detailed documentation covering all aspects of the project. **Always consult these docs before making architectural decisions.**

### Essential Reading
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture, Tauri patterns, and design decisions
- **[docs/SECURITY.md](docs/SECURITY.md)** - Security model, Argon2 authentication, and threat assessment
- **[docs/TESTING.md](docs/TESTING.md)** - **TDD approach (mandatory)**, test patterns, and quality assurance
- **[docs/PRD.md](docs/PRD.md)** - Product requirements, feature specifications, and acceptance criteria

### Development Workflow
- **[docs/ONBOARDING.md](docs/ONBOARDING.md)** - Developer setup, system requirements, and configuration
- **[docs/DEVOPS.md](docs/DEVOPS.md)** - CI/CD pipelines, deployment, and release processes
- **[docs/USER-FLOWS.md](docs/USER-FLOWS.md)** - UX patterns, accessibility requirements, and user journeys

### Current Implementation Status
- **[TODO.md](TODO.md)** - **Current progress (100% MVP complete - all core functionality operational)**, task tracking, and next priorities
- **[CURRENT_STATUS.md](CURRENT_STATUS.md)** - Detailed status of all implemented features
- **[thoughts/plans/opencode-nexus-mvp-implementation.md](thoughts/plans/opencode-nexus-mvp-implementation.md)** - Implementation plan with TDD requirements
- **[thoughts/research/2025-09-03_claude-agents-documentation-best-practices.md](thoughts/research/2025-09-03_claude-agents-documentation-best-practices.md)** - Documentation standards and best practices

## Technology Stack Details

### Backend (Rust + Tauri)
- **Framework**: Tauri 2.x for cross-platform desktop applications
- **Runtime**: Tokio for async operations and process management
- **Security**: Argon2 for password hashing, account lockout protection
- **Storage**: JSON-based configuration in user config directory
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
│   ├── ARCHITECTURE.md            # System design and Tauri patterns  
│   ├── SECURITY.md                # Authentication and security model
│   ├── TESTING.md                 # TDD approach and test patterns
│   └── [OTHER_DOCS]               # PRD, DevOps, User Flows, Onboarding
├── src-tauri/                     # Rust backend (Tauri application)
│   ├── src/
│   │   ├── lib.rs                 # Tauri command handlers (400+ lines)
│   │   ├── server_manager.rs      # OpenCode server lifecycle (518 lines)
│   │   ├── auth.rs                # Authentication with Argon2 hashing
│   │   ├── onboarding.rs          # Cross-platform system detection
│   │   ├── api_client.rs          # OpenCode server API integration
│   │   ├── chat_manager.rs        # Chat session and message management
│   │   ├── message_stream.rs      # Real-time SSE message streaming
│   │   ├── web_server_manager.rs  # Web server for tunnel access
│   │   └── tunnel_manager.rs      # Cloudflared tunnel management
│   ├── Cargo.toml                 # Dependencies (Tauri, tokio, sentry, etc.)
│   └── tests/                     # Rust unit tests (TDD approach)
├── frontend/                      # Astro + Svelte 5 frontend
│   ├── src/pages/
│   │   ├── index.astro           # Entry point with routing logic
│   │   ├── onboarding.astro      # 6-step wizard with system detection
│   │   ├── dashboard.astro       # Main UI with real-time updates
│   │   └── login.astro           # Authentication interface
│   ├── src/layouts/Layout.astro  # Base layout with WCAG 2.2 AA compliance
│   └── src/tests/                # Frontend tests with accessibility checks
├── thoughts/                      # Research and planning documentation
│   ├── plans/                    # Implementation plans and TDD requirements
│   └── research/                 # Best practices and architecture research
├── TODO.md                       # Current progress (90% complete - core functionality operational)
├── CLAUDE.md                     # This file - Claude Code guidance
└── AGENTS.md                     # Multi-AI system configuration
```

### Key Files for Development
- **[src-tauri/src/lib.rs](src-tauri/src/lib.rs)** - Tauri command handlers and main entry point
- **[src-tauri/src/server_manager.rs](src-tauri/src/server_manager.rs)** - Core server lifecycle management
- **[src-tauri/src/auth.rs](src-tauri/src/auth.rs)** - Authentication system with Argon2
- **[src-tauri/src/chat_manager.rs](src-tauri/src/chat_manager.rs)** - Chat session management
- **[src-tauri/src/api_client.rs](src-tauri/src/api_client.rs)** - OpenCode API integration
- **[src-tauri/src/tunnel_manager.rs](src-tauri/src/tunnel_manager.rs)** - Cloudflared tunnel management
- **[frontend/src/pages/dashboard.astro](frontend/src/pages/dashboard.astro)** - Main dashboard UI
- **[frontend/src/pages/chat.astro](frontend/src/pages/chat.astro)** - Chat interface
- **[src-tauri/Cargo.toml](src-tauri/Cargo.toml)** - Backend dependencies and configuration

## Development Workflow

### 1. Planning Phase
- Read implementation plan in `thoughts/plans/`
- Review relevant documentation in `docs/`
- Update TODO.md with specific tasks using TodoWrite tool

### 2. TDD Implementation
- Write failing tests first (MANDATORY)
- Implement minimal code to pass tests
- Refactor while keeping tests green
- Update TODO.md with completed tasks immediately after completion

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
- Mark completed tasks in [TODO.md](TODO.md) immediately
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
- Current progress percentage vs [TODO.md](TODO.md) targets
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
- **Process Security**: Secure OpenCode server process management

## Performance Standards

- **Startup Time**: Application should start in under 3 seconds
- **Bundle Size**: Keep frontend bundles under 1MB
- **Memory Usage**: Monitor Rust memory usage with Arc for shared data
- **Responsiveness**: UI should remain responsive during server operations

## Current Implementation Status

### ✅ MVP Complete - All Core Features Operational (100%)

**Phase 1-3: Core Infrastructure** ✅
- **Onboarding System**: 6-step wizard with cross-platform system detection ([src-tauri/src/onboarding.rs](src-tauri/src/onboarding.rs))
- **Authentication**: Argon2 hashing, account lockout, persistent sessions ([src-tauri/src/auth.rs](src-tauri/src/auth.rs))
- **Server Management**: Complete lifecycle management with real-time event streaming ([src-tauri/src/server_manager.rs](src-tauri/src/server_manager.rs))
- **Dashboard UI**: Reactive interface with accessibility compliance ([frontend/src/pages/dashboard.astro](frontend/src/pages/dashboard.astro))
- **Session Tracking**: OpenCode server session management with API integration

**Phase 4: Chat & Remote Access** ✅
- **Chat Interface**: Full AI conversation system with real OpenCode API integration ([frontend/src/pages/chat.astro](frontend/src/pages/chat.astro))
- **Message Streaming**: Real-time SSE message streaming ([src-tauri/src/message_stream.rs](src-tauri/src/message_stream.rs))
- **Tunnel Management**: Cloudflared integration for secure remote access ([src-tauri/src/tunnel_manager.rs](src-tauri/src/tunnel_manager.rs))
- **Web Server**: HTTP server for tunnel access ([src-tauri/src/web_server_manager.rs](src-tauri/src/web_server_manager.rs))

**Testing & Quality** ✅
- **Test Coverage**: 29+ tests covering all critical paths (TDD approach)
- **Accessibility**: WCAG 2.2 AA compliance verified
- **Security**: Comprehensive security audit completed

### ⏳ Future Enhancements (Post-MVP)
- Advanced tunnel configuration options (Tailscale, VPN)
- Log viewing and export functionality
- Multi-instance management
- Performance optimization and monitoring
- Plugin system architecture

**Status**: Production-ready MVP complete
**Next Phase**: User testing, feedback collection, and refinement

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
- Always follow TDD principles (tests first) - see [docs/TESTING.md](docs/TESTING.md)
- Security and accessibility are non-negotiable - see [docs/SECURITY.md](docs/SECURITY.md) and WCAG 2.2 AA
- Reference comprehensive documentation in [docs/](docs/) for all architectural decisions
- Update [TODO.md](TODO.md) and commit completed work following [documentation workflow](#4-documentation--commit-mandatory)
- Current status: MVP complete - all core functionality operational and production-ready

## Essential Context for AI Development
- **Project Type**: Tauri 2.x desktop application (NOT web app or monorepo)
- **Current Status**: MVP Complete (100%) - All core features operational
- **Architecture**: See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for Tauri-specific patterns
- **Runtime**: Bun for frontend, Tokio for backend async operations
- **Next Phase**: User testing, feedback collection, and post-MVP enhancements
- **Test Coverage**: 29+ tests covering all major functionality

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
- **Process issues**: Check server logs in config directory