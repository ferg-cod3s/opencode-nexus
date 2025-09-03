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
1. **Read Implementation Plan**: Check `thoughts/plans/` for current phase requirements
2. **Write Tests First**: Create failing tests before any implementation
3. **Implement Feature**: Write minimal code to pass tests
4. **Update TODO.md**: Mark completed tasks and add new ones discovered
5. **Commit Completed Work**: Make commits for each completed feature
6. **Document Changes**: Update relevant documentation

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

### ✅ Completed Features
- Onboarding system with cross-platform system detection
- Password authentication with Argon2 hashing and account lockout
- Dashboard UI with server status display
- Accessibility compliance (WCAG 2.2 AA)
- Test-driven development workflow with comprehensive test suites

### 🔄 In Progress
- OpenCode server process management (fixing async safety issues)
- Server lifecycle controls (start/stop/restart)
- Health monitoring and metrics collection

### ⏳ Upcoming
- Cloudflared tunnel integration
- Real-time server status updates
- Log viewing and system monitoring

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

**Remember**: Security and accessibility are non-negotiable. Always follow TDD principles and maintain comprehensive test coverage. Update TODO.md and commit completed work promptly.
