# CLAUDE.md – OpenCode Nexus Development Guide

This file provides guidance to Claude Code (claude.ai/code) when working with the OpenCode Nexus codebase.

## Project Overview

OpenCode Nexus is a cross-platform desktop application for managing OpenCode servers with secure remote access, built with Tauri (Rust backend) + Astro/Svelte 5 (frontend) + Bun runtime.

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
# From project root or src-tauri directory
cargo build              # Build Rust backend
cargo test               # Run unit tests
cargo clippy             # Linting
cargo fmt                # Code formatting
cargo tauri dev          # Run Tauri app in development
cargo tauri build        # Build production app
```

### Full Stack Development
```bash
# Run complete application
cargo tauri dev          # Starts both Rust backend and frontend

# Test entire stack
cargo test               # Backend tests
cd frontend && bun test  # Frontend tests
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

The `/docs` directory contains detailed documentation covering all aspects of the project:

### Core Documentation
- **[/docs/PRD.md](docs/PRD.md)** - Product Requirements Document and feature specifications
- **[/docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture, technology choices, and design decisions
- **[/docs/SECURITY.md](docs/SECURITY.md)** - Security model, authentication, and threat assessment
- **[/docs/USER-FLOWS.md](docs/USER-FLOWS.md)** - User experience flows and interaction design

### Development Documentation
- **[/docs/TESTING.md](docs/TESTING.md)** - Testing strategy, TDD approach, and quality assurance
- **[/docs/DEVOPS.md](docs/DEVOPS.md)** - CI/CD pipelines, deployment, and infrastructure
- **[/docs/ONBOARDING.md](docs/ONBOARDING.md)** - Developer onboarding and setup procedures

### Implementation Planning
- **[thoughts/plans/opencode-nexus-mvp-implementation.md](thoughts/plans/opencode-nexus-mvp-implementation.md)** - Current implementation plan with TDD requirements
- **[TODO.md](TODO.md)** - Current task tracking and progress status

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

## File Structure

```
opencode-nexus/
├── docs/                 # Comprehensive project documentation
├── thoughts/             # Research and implementation planning
├── src-tauri/           # Rust backend (Tauri application)
│   ├── src/
│   │   ├── lib.rs       # Tauri command handlers
│   │   ├── auth.rs      # Authentication system
│   │   ├── onboarding.rs # System detection and setup
│   │   └── server_manager.rs # OpenCode server lifecycle
├── frontend/            # Astro + Svelte frontend
│   ├── src/pages/       # Route pages (onboarding, dashboard, login)
│   ├── src/layouts/     # Shared layouts with accessibility
│   ├── src/components/  # Reusable Svelte components
│   └── src/tests/       # Frontend test suites
├── TODO.md              # Current task tracking
├── CLAUDE.md            # This file
└── AGENTS.md            # Agent-specific guidelines
```

## Development Workflow

### 1. Planning Phase
- Read implementation plan in `thoughts/plans/`
- Review relevant documentation in `docs/`
- Update TODO.md with specific tasks

### 2. TDD Implementation
- Write failing tests first (MANDATORY)
- Implement minimal code to pass tests
- Refactor while keeping tests green
- Update TODO.md with completed tasks

### 3. Quality Assurance
- Run all tests (`cargo test` + `cd frontend && bun test`)
- Check compilation (`cargo clippy` + `bun run typecheck`)
- Verify accessibility (WCAG 2.2 AA compliance)
- Ensure security requirements are met

### 4. Documentation & Commit
- Update TODO.md with progress
- Commit completed features with descriptive messages
- Update relevant documentation if needed

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

### ✅ Completed Features
- Cross-platform onboarding system with system requirements checking
- Password authentication with Argon2 hashing and account lockout
- Dashboard UI with server status display
- Accessibility compliance (WCAG 2.2 AA verified)
- Test-driven development workflow (29 tests implemented)

### 🔄 In Progress  
- OpenCode server process management (async safety issues resolved)
- Server lifecycle controls (start/stop/restart commands)

### ⏳ Upcoming
- Cloudflared tunnel integration
- Real-time server metrics and monitoring
- Log viewing and system administration features

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
- Always follow TDD principles (tests first)
- Security and accessibility are non-negotiable
- Reference comprehensive documentation in `/docs` for detailed guidance
- Update TODO.md and commit completed work promptly
- Maintain WCAG 2.2 AA accessibility compliance

For detailed technical specifications, architecture decisions, and implementation guidelines, refer to the comprehensive documentation in the `/docs` directory.