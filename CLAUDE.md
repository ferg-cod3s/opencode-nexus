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
bun run dev              # Development server
bun run build            # Production build
bun test                 # Run tests with Bun
bun run lint             # ESLint with accessibility checks
bun run typecheck        # TypeScript checking
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
- **[TODO.md](TODO.md)** - **Current progress (90% complete - core functionality operational)**, task tracking, and next priorities
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
│   │   └── api_client.rs          # OpenCode server API integration
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
- **[src-tauri/src/server_manager.rs](src-tauri/src/server_manager.rs)** - Core server management logic
- **[src-tauri/src/auth.rs](src-tauri/src/auth.rs)** - Authentication system patterns  
- **[frontend/src/pages/dashboard.astro](frontend/src/pages/dashboard.astro)** - Main UI implementation
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

## Common Issues & Solutions

### Async/Await in Rust
- **Issue**: MutexGuard not Send-safe across await boundaries
- **Solution**: Extract data from mutex before await, don't hold locks across async calls

### Cross-Platform Compatibility
- **Issue**: Platform-specific system detection
- **Solution**: Use conditional compilation and platform-specific dependencies

### Accessibility Compliance
- **Issue**: Missing keyboard navigation or screen reader support
- **Solution**: Use proper ARIA labels, semantic HTML, and test with accessibility tools

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

### ✅ Completed Features (Phase 1-3)
- **Onboarding System**: 6-step wizard with cross-platform system detection ([src-tauri/src/onboarding.rs](src-tauri/src/onboarding.rs))
- **Authentication**: Argon2 hashing, account lockout, persistent sessions ([src-tauri/src/auth.rs](src-tauri/src/auth.rs))
- **Server Management**: Complete lifecycle management with real-time event streaming ([src-tauri/src/server_manager.rs](src-tauri/src/server_manager.rs))
- **Dashboard UI**: Reactive interface with accessibility compliance ([frontend/src/pages/dashboard.astro](frontend/src/pages/dashboard.astro))
- **Session Tracking**: OpenCode server session management with API integration
- **Testing**: TDD approach with 29 tests covering critical paths

### 🔄 Current Phase: Production Hardening (90% Complete)  
- **Chat Interface**: Full AI conversation system with real OpenCode API integration (implemented)
- **Real-time Metrics**: Event-driven architecture with live updates (implemented)
- **API Integration**: Full OpenCode server API client with chat system integration (implemented)

### ⏳ Remaining Work
- Cloudflared tunnel implementation (Phase 4 from implementation plan)
- Advanced tunnel configuration options
- Log viewing and export functionality
- Performance optimization and production hardening

**Progress**: 90% complete - All core functionality operational
**Next Priority**: Cloudflared tunnel implementation and production hardening

## ✅ Core MVP Complete

**All primary functionality is implemented and operational. Chat interface, server management, and authentication systems are fully functional.**

### Implemented Core Functionality
- **Chat Interface**: Full conversational interface with OpenCode AI integration
- **Message Streaming**: Real-time SSE message streaming from AI responses implemented
- **Session Management**: Complete chat session creation and conversation history
- **Server Management**: Full OpenCode server lifecycle management
- **Authentication**: Secure user authentication with Argon2 hashing

### Production-Ready Components
**Fully Implemented Files:**
- `src-tauri/src/chat_manager.rs` - Complete chat session and message management
- `src-tauri/src/message_stream.rs` - Real-time SSE message streaming implementation
- `frontend/src/pages/chat.astro` - Functional chat interface
- `src-tauri/src/api_client.rs` - Production OpenCode API client

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
- Current progress: 90% complete - core functionality operational, tunnel integration remaining

## Essential Context for AI Development
- **Project Type**: Tauri desktop application (NOT web app or monorepo)
- **Current Status**: All core functionality operational - chat, server management, authentication complete
- **Architecture**: See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for Tauri-specific patterns
- **Next Phase**: Cloudflared tunnel implementation and production hardening
- **Test Coverage**: 29 tests established covering all major functionality