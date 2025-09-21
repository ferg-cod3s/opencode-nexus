# AGENTS.md – OpenCode Nexus Agent Guidelines

This file provides guidance to AI agents when working with the OpenCode Nexus codebase. OpenCode Nexus is a cross-platform desktop application for managing OpenCode servers with secure remote access.

## Project Architecture

### Technology Stack
- **Desktop Framework**: Tauri (Rust backend + web frontend)
- **Frontend**: Astro + Svelte 5 + TypeScript
- **Runtime**: Bun (package manager and test runner)
- **Backend**: Rust with tokio for async operations
- **Database**: JSON file-based configuration storage
- **Security**: Argon2 password hashing, account lockout protection

### Development Philosophy
- **Test-Driven Development (TDD)**: Write failing tests before implementation
- **Security First**: All user inputs validated, secure password storage
- **Accessibility**: WCAG 2.2 AA compliance mandatory
- **Cross-Platform**: Support macOS, Linux, and Windows

## Common Commands

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
cargo build              # Build Rust backend
cargo test               # Run unit tests
cargo clippy             # Linting
cargo fmt                # Code formatting
cargo tauri dev          # Run Tauri app in development
cargo tauri build        # Build production app
```

### Full Stack Development
```bash
# Run both frontend and backend in development
cargo tauri dev          # Starts both Rust backend and frontend

# Test entire application
cargo test               # Backend tests
cd frontend && bun test  # Frontend tests
```

## Code Style Guidelines

### TypeScript/JavaScript (Frontend)
- Use **2 spaces** for indentation
- **Strict TypeScript** mode enabled - no `any` types
- Group imports: stdlib, external, then local
- **camelCase** for variables and functions
- **PascalCase** for types, classes, and interfaces
- Use **const** over **let**, avoid **var**
- Prefer **async/await** over promises
- Early returns to reduce nesting

### Rust (Backend)
- Follow **rustfmt** formatting (use `cargo fmt`)
- **snake_case** for variables and functions
- **PascalCase** for types and structs
- Use **Result<T, E>** and **Option<T>** for error handling
- Prefer **&str** over **String** for function parameters
- Use **Arc<Mutex<T>>** for shared state across async boundaries
- Always handle **unwrap()** and **expect()** carefully

### Error Handling Requirements
- **Rust**: Use `Result<T, E>` and `?` operator, convert to Tauri errors with `.map_err(|e| e.to_string())`
- **TypeScript**: Use try/catch blocks, provide user-friendly error messages
- **Never** expose stack traces or internal errors to users
- **Always** validate user inputs before processing

## File Structure and Patterns

### Backend Structure (`src-tauri/src/`)
```
src/
├── main.rs              # Tauri application entry point
├── lib.rs               # Tauri command handlers and exports
├── onboarding.rs        # System detection and onboarding logic
├── auth.rs              # Authentication and password management
├── server_manager.rs    # OpenCode server lifecycle management
└── tests/               # Rust unit tests
```

### Frontend Structure (`frontend/src/`)
```
src/
├── pages/
│   ├── index.astro      # Entry point with routing logic
│   ├── onboarding.astro # 6-step onboarding wizard
│   ├── dashboard.astro  # Main dashboard UI
│   └── login.astro      # Authentication page
├── layouts/
│   └── Layout.astro     # Base layout with accessibility
├── components/          # Reusable Svelte components
└── tests/               # Frontend test suites
```

## Development Standards

### Test-Driven Development (TDD)
1. **Write failing tests first** - This is mandatory
2. **Implement minimal code** to make tests pass
3. **Refactor** while keeping tests green
4. **Coverage target**: 80-90% for critical paths

### Security Requirements (Critical)
- **Password Storage**: Use Argon2 hashing with salt
- **Account Protection**: Implement lockout after 5 failed attempts
- **Input Validation**: Sanitize ALL user inputs
- **Secret Management**: Never commit secrets, use environment variables
- **Secure IPC**: Validate all Tauri command parameters

### Accessibility Requirements (WCAG 2.2 AA)
- **Keyboard Navigation**: All interactive elements accessible via keyboard
- **Screen Reader Support**: Proper ARIA labels and semantic HTML
- **Color Contrast**: Minimum 4.5:1 ratio for text
- **Focus Management**: Visible focus indicators and logical tab order
- **Error Handling**: Clear, actionable error messages

### Performance Standards
- **Bundle Size**: Keep frontend bundles under 1MB
- **Startup Time**: Application should start in under 3 seconds
- **Memory Usage**: Monitor Rust memory usage, use Arc for shared data
- **Async Operations**: Use tokio properly, avoid blocking the UI thread

## Task Management and Workflow

### Development Process
1. **Read Implementation Plan**: Check [thoughts/plans/opencode-nexus-mvp-implementation.md](thoughts/plans/opencode-nexus-mvp-implementation.md) for current phase requirements
2. **Consult Architecture Docs**: Review [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/SECURITY.md](docs/SECURITY.md), and [docs/TESTING.md](docs/TESTING.md)
3. **Write Tests First**: Create failing tests before any implementation (TDD mandatory per [docs/TESTING.md](docs/TESTING.md))
4. **Implement Feature**: Write minimal code to pass tests following established patterns in [src-tauri/src/](src-tauri/src/)
5. **Update Progress**: Mark completed tasks in [TODO.md](TODO.md) and add new ones discovered using TodoWrite tool
6. **Document & Commit**: Follow comprehensive documentation and commit workflow (see below)
7. **Validate Quality**: Run accessibility checks, security validation, and cross-platform testing

### MANDATORY Documentation & Commit Workflow
**This process MUST be followed after completing each major feature or phase:**

#### Step 1: Document Current Progress
Write detailed progress summary including:
- ✅ **What was completed**: Specific features, functions, files modified
- 📊 **Metrics**: Line counts, test coverage, files changed
- 📍 **Current vs Plan**: Implementation status against original plan
- 🔄 **Issues Resolved**: Compilation errors, async safety issues, etc.
- ➡️ **Next Requirements**: What's needed for the next phase

#### Step 2: Update TODO.md
- Mark all completed tasks as finished immediately
- Add newly discovered tasks that emerged during implementation
- Update project progress percentages and milestones
- Note any scope or timeline changes

#### Step 3: Create Comprehensive Commit
**Use this exact format:**

```bash
git add .
git commit -m "$(cat <<'EOF'
[type]: [concise description]

[Detailed implementation summary with checkmarks:]

- ✅ [Major feature 1 implemented]
- ✅ [Major feature 2 implemented]
- ✅ [Testing/security/accessibility completed]

Files changed:
- [file1.rs (XXX lines)] - [purpose/functionality]
- [file2.astro] - [purpose/functionality]  
- [config files] - [dependencies/setup changes]

[Any critical issues resolved]
[Test status and coverage info]
[What's ready for next phase]

Next: [Upcoming phase/feature]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

#### Step 4: Status Communication
After commit, provide user with:
- Clear summary of what phase/feature was completed
- Current progress percentage vs overall plan  
- What's ready for next development phase
- Any blockers or user input needed

### Quality Gates (Pre-Commit)
- [ ] All tests passing (`cargo test` + `bun test`)
- [ ] No compilation errors (`cargo clippy` + `bun run typecheck`)
- [ ] Code formatted (`cargo fmt` + proper formatting)
- [ ] No security vulnerabilities (input validation checked)
- [ ] Accessibility verified (keyboard navigation + screen reader)
- [ ] TODO.md updated with progress

## Tauri-Specific Patterns

### Command Handlers (lib.rs)
```rust
#[tauri::command]
async fn example_command(param: String) -> Result<ResponseType, String> {
    // Always validate inputs
    if param.is_empty() {
        return Err("Parameter cannot be empty".to_string());
    }
    
    // Use proper error handling
    some_operation(&param).map_err(|e| e.to_string())
}
```

### Frontend Integration (TypeScript)
```typescript
import { invoke } from '@tauri-apps/api/core';

try {
    const result = await invoke<ResponseType>('example_command', {
        param: validatedInput
    });
    // Handle success
} catch (error) {
    // Handle error - provide user-friendly message
    console.error('Operation failed:', error);
}
```

## Security Patterns

### Password Handling
```rust
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier};
use argon2::password_hash::{rand_core::OsRng, SaltString};

// Hash password
let salt = SaltString::generate(&mut OsRng);
let argon2 = Argon2::default();
let password_hash = argon2.hash_password(password.as_bytes(), &salt)
    .map_err(|e| format!("Failed to hash password: {}", e))?
    .to_string();
```

### Input Validation
```rust
fn validate_username(username: &str) -> Result<(), String> {
    if username.is_empty() || username.len() < 3 {
        return Err("Username must be at least 3 characters".to_string());
    }
    if !username.chars().all(|c| c.is_alphanumeric() || c == '_' || c == '-') {
        return Err("Username can only contain alphanumeric characters, underscore, and dash".to_string());
    }
    Ok(())
}
```

## Common Issues and Solutions

### Async/Await in Rust
- **Issue**: MutexGuard not Send-safe across await boundaries
- **Solution**: Extract data from mutex before await, don't hold locks across async calls
```rust
// Bad - holds lock across await
let guard = mutex.lock().unwrap();
some_async_operation().await;

// Good - extract data first
let data = {
    let guard = mutex.lock().unwrap();
    guard.clone() // or extract needed fields
};
some_async_operation().await;
```

### Cross-Platform Path Handling
```rust
use std::path::PathBuf;
use dirs::config_dir;

let config_path = config_dir()
    .ok_or("Could not determine config directory")?
    .join("opencode-nexus");
```

## Current Implementation Status

### ✅ Completed Features (60% Complete)
- **Onboarding System**: 6-step wizard with cross-platform detection ([src-tauri/src/onboarding.rs](src-tauri/src/onboarding.rs))
- **Authentication**: Argon2 hashing, session management, account lockout ([src-tauri/src/auth.rs](src-tauri/src/auth.rs))
- **Server Management**: Complete lifecycle with real-time event streaming ([src-tauri/src/server_manager.rs](src-tauri/src/server_manager.rs))
- **Dashboard UI**: Responsive interface with WCAG 2.2 AA compliance ([frontend/src/pages/dashboard.astro](frontend/src/pages/dashboard.astro))
- **API Integration**: OpenCode server communication ([src-tauri/src/api_client.rs](src-tauri/src/api_client.rs))
- **Testing**: TDD approach with 29 comprehensive tests

### 🚨 CRITICAL MVP GAP
- **Chat Interface**: **COMPLETELY MISSING** - No AI conversation functionality
- **Message Streaming**: No real-time message streaming from AI
- **Session Management**: No chat session creation or history
- **File Context Sharing**: No code context sharing with AI

### 🔄 Ready for Implementation  
- **Cloudflared Integration**: Tunnel management system (complete and functional)
- **Advanced Features**: Real-time metrics, logging, auto-restart (planned)

**Current Status**: Core infrastructure complete but missing primary chat functionality that defines the product's value proposition. See [thoughts/plans/opencode-nexus-mvp-implementation.md](thoughts/plans/opencode-nexus-mvp-implementation.md) for chat interface implementation plan.

## Emergency Procedures

### Security Issues
1. **Immediate**: Revoke any compromised credentials
2. **Assess**: Determine scope of potential breach
3. **Fix**: Patch vulnerability and update affected systems
4. **Document**: Record incident and prevention measures

### Critical Bugs
1. **Reproduce**: Create failing test that demonstrates bug
2. **Isolate**: Identify root cause and affected components
3. **Fix**: Implement minimal fix to resolve issue
4. **Test**: Verify fix works and doesn't introduce regressions
5. **Deploy**: Release hotfix if production-critical

## Reference Links

- **Tauri Documentation**: https://tauri.app/
- **Astro Documentation**: https://docs.astro.build/
- **Svelte 5 Documentation**: https://svelte-5-preview.vercel.app/
- **WCAG 2.2 Guidelines**: https://www.w3.org/WAI/WCAG22/Understanding/
- **OpenCode Server API**: https://opencode.ai/docs/server/

## Development Environment

### Required Tools
- **Rust**: Latest stable (1.70+)
- **Node.js**: Not used (Bun replaces Node.js)
- **Bun**: Latest stable (package manager and runtime)
- **System Dependencies**: Build tools for native compilation

### IDE Setup
- **VS Code Extensions**: rust-analyzer, Astro, Svelte, ESLint
- **Settings**: Enable format on save, strict TypeScript mode
- **Debug Configuration**: Tauri debugging support enabled

---

## Documentation References

### Essential Reading (Required)
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture and Tauri patterns
- **[docs/SECURITY.md](docs/SECURITY.md)** - Security model, Argon2 authentication, threat assessment  
- **[docs/TESTING.md](docs/TESTING.md)** - TDD approach (mandatory), test patterns, quality assurance
- **[docs/PRD.md](docs/PRD.md)** - Product requirements and feature specifications

### Current Implementation Status
- **[TODO.md](TODO.md)** - Current progress (60% complete), task tracking, critical chat interface gap
- **[thoughts/plans/opencode-nexus-mvp-implementation.md](thoughts/plans/opencode-nexus-mvp-implementation.md)** - Phase 0 chat interface implementation plan
- **[thoughts/research/2025-09-03_claude-agents-documentation-best-practices.md](thoughts/research/2025-09-03_claude-agents-documentation-best-practices.md)** - Documentation standards

### Key Implementation Files
- **[src-tauri/src/server_manager.rs](src-tauri/src/server_manager.rs)** - Server lifecycle management patterns
- **[src-tauri/src/auth.rs](src-tauri/src/auth.rs)** - Authentication system implementation
- **[frontend/src/pages/dashboard.astro](frontend/src/pages/dashboard.astro)** - UI patterns and accessibility implementation

---

**Critical Reminders**: 
- 🚨 **Chat interface implementation is highest priority** - blocks MVP completion
- Security and accessibility are non-negotiable (WCAG 2.2 AA compliance verified)
- Always follow TDD principles per [docs/TESTING.md](docs/TESTING.md) 
- Update [TODO.md](TODO.md) and commit completed work following documentation workflow
- Consult [docs/](docs/) for all architectural and security decisions
