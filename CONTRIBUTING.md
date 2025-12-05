# Contributing to OpenCode Nexus

Thank you for your interest in contributing to OpenCode Nexus! This document provides guidelines for contributing code, documentation, and improvements to the project.

## Code of Conduct

- Be respectful and inclusive
- Focus on code quality and project goals
- Provide constructive feedback
- Ask questions if something is unclear

## Before You Start

1. **Read [AGENTS.md](AGENTS.md)** - Quick reference for code standards and commands
2. **Read [CLAUDE.md](CLAUDE.md)** - Comprehensive development guide (essential)
3. **Check [status_docs/TODO.md](status_docs/TODO.md)** - Current tasks and progress
4. **Review [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md)** - System design

## Development Setup

### Prerequisites
- Rust 1.70+ (see [rustup.rs](https://rustup.rs))
- Bun 1.0+ (see [bun.sh](https://bun.sh))
- Node.js 18+ (for some build tools)
- macOS/Linux/Windows (for development; iOS/Android for testing)

### Initial Setup
```bash
# Clone repository
git clone https://github.com/v1truv1us/opencode-nexus.git
cd opencode-nexus

# Install dependencies
cd frontend && bun install && cd ..
cargo build  # Rust dependencies

# Start development
cargo tauri dev
```

## Making Changes

### 1. Plan Your Work
- Check [status_docs/TODO.md](status_docs/TODO.md) for task list
- Discuss major changes in issues before coding
- Reference [docs/client/](docs/client/) for architectural decisions

### 2. Follow Test-Driven Development (TDD)

**This is MANDATORY** - see [docs/client/TESTING.md](docs/client/TESTING.md)

```bash
# 1. Write a failing test first
# (Add test to test file)

# 2. Run tests to confirm failure
cargo test                  # Rust backend
cd frontend && bun test     # TypeScript frontend

# 3. Implement minimal code to pass test
# (Write implementation)

# 4. Run tests again to confirm pass
cargo test && cd frontend && bun test

# 5. Refactor while keeping tests green
# (Improve code quality)
```

### 3. Code Style

Follow the standards in [AGENTS.md](AGENTS.md#code-style-guidelines):

**TypeScript/Svelte:**
- `camelCase` for variables/functions
- `PascalCase` for types/components
- Single quotes, 2-space indentation
- No `any` types (strict mode)
- Group imports: stdlib → external → local

**Rust:**
- `snake_case` for functions/variables
- `PascalCase` for types/structs
- Use `Result<T, E>` + `?` operator for errors
- Use `Arc<Mutex<T>>` for shared state

**General:**
- Keep functions 10-30 lines (max 50)
- Self-documenting code (minimal comments)
- WCAG 2.2 AA accessibility compliance
- 44px touch targets for mobile UI

### 4. Quality Checks Before Committing

```bash
# Format code
cargo fmt && cd frontend && bun run format

# Run linting
cd frontend && bun run lint

# Type checking
cd frontend && bun run typecheck

# Run tests
cargo test && cd frontend && bun test

# Run clippy analysis
cargo clippy

# Full quality check (recommended)
cargo clippy && cargo test && cd frontend && bun run lint && bun run typecheck && bun test
```

### 5. Write Clear Commit Messages

Use conventional commit format with detailed description:

```bash
git commit -m "$(cat <<'EOFF'
feat: implement user authentication

TDD implementation complete:
- ✅ Added auth command handlers
- ✅ Implemented Argon2 password hashing
- ✅ Added unit tests (95% coverage)

Files modified:
- src-tauri/src/auth.rs (150 lines) - Authentication logic
- src-tauri/src/lib.rs (25 lines) - Command registration
- frontend/src/tests/auth.test.ts (200 lines) - Test coverage

Security: All user inputs validated, no plaintext passwords stored.
Tests passing. Ready for code review.

Co-Authored-By: Your Name <your.email@example.com>
EOFF
)"
```

**Commit types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code restructuring (no behavior change)
- `test:` - Test additions/modifications
- `docs:` - Documentation updates
- `chore:` - Build, dependencies, configuration
- `perf:` - Performance improvements
- `sec:` - Security fixes

### 6. Update Documentation

After completing features:

1. **Update [status_docs/TODO.md](status_docs/TODO.md)**
   - Mark completed tasks ✅
   - Add new discovered tasks
   - Update progress percentage

2. **Update relevant architecture docs**
   - [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md) - System design changes
   - [docs/client/TESTING.md](docs/client/TESTING.md) - Testing approach updates
   - [docs/client/SECURITY.md](docs/client/SECURITY.md) - Security changes

3. **Update [AGENTS.md](AGENTS.md)** if standards change

## Security Considerations

### Security Standards
- **Password Storage:** Use Argon2 with salt (never plaintext)
- **API Security:** TLS 1.3 for all connections
- **Input Validation:** Sanitize ALL user inputs
- **Secrets Management:** Use environment variables, never commit secrets
- **Data Encryption:** AES-256 for sensitive local data
- **Lockout:** Account lockout after 5 failed auth attempts

See [docs/client/SECURITY.md](docs/client/SECURITY.md) for detailed security implementation.

### Security Checklist
- [ ] No hardcoded secrets or API keys
- [ ] All user inputs validated
- [ ] Error messages don't leak sensitive information
- [ ] Dependencies audited (`cargo audit`, `npm audit`)
- [ ] Security tests included with feature

## Accessibility Requirements

All UI changes must meet **WCAG 2.2 AA compliance**:

- **Keyboard Navigation:** All interactive elements keyboard-accessible
- **Screen Readers:** Semantic HTML, proper ARIA labels
- **Touch Targets:** 44px minimum for mobile
- **Color Contrast:** 4.5:1 for text (AA standard)
- **Focus Management:** Clear focus indicators
- **Responsive Design:** Works on all screen sizes

Test with:
```bash
# Browser DevTools accessibility inspector
# Lighthouse audits (Chrome DevTools)
# Screen readers (NVDA, JAWS, VoiceOver)
```

## Testing Requirements

### Test Coverage
- **Target:** 80-90% for critical paths
- **Required:** All public APIs have tests
- **Types:** Unit tests + E2E tests for features

### Frontend Tests (Bun)
```typescript
import { describe, test, expect } from 'bun:test';

describe('FeatureName', () => {
  test('should do something', () => {
    // Implementation
  });
});
```

### Backend Tests (Rust)
```rust
#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn test_function() {
    // Implementation
  }
}
```

### E2E Tests (Playwright)
```typescript
import { test, expect } from '@playwright/test';

test('user flow', async ({ page }) => {
  await page.goto('/');
  // Interaction and assertions
});
```

## Git Workflow

### Branch Naming
- Feature: `feat/description` or `feature/description`
- Bug fix: `fix/description`
- Documentation: `docs/description`
- Example: `feat/user-authentication`

### Before Pushing
1. Create a feature branch
2. Make changes following TDD
3. Run full quality checks
4. Update documentation
5. Write clear commit messages
6. Push to your branch

### Pull Requests
1. **Title:** Clear, concise description
2. **Description:** Include:
   - What changed and why
   - Related tasks from [status_docs/TODO.md](status_docs/TODO.md)
   - Testing done
   - Any breaking changes
3. **Checklist:**
   - [ ] Tests written and passing
   - [ ] Code follows style guidelines
   - [ ] Documentation updated
   - [ ] No new warnings (linting)
   - [ ] Security reviewed
   - [ ] Accessibility verified

## Project Structure

Understanding the codebase organization:

```
opencode-nexus/
├── frontend/                 # Astro + Svelte frontend
│   ├── src/pages/           # Routes (file-based)
│   ├── src/components/      # Reusable components
│   ├── src/stores/          # State management
│   ├── src/lib/             # Business logic
│   ├── src/utils/           # Helper functions
│   └── e2e/                 # E2E tests
│
├── src-tauri/               # Rust backend (Tauri)
│   ├── src/lib.rs           # Main handlers
│   ├── src/connection_manager.rs  # Server connections
│   └── src/auth.rs          # Authentication
│
├── docs/client/             # Architecture & design
├── status_docs/             # Progress tracking
└── AGENTS.md, CLAUDE.md     # Development guides
```

## Common Workflows

### Adding a New Feature
1. Create task in [status_docs/TODO.md](status_docs/TODO.md)
2. Create feature branch (`feat/my-feature`)
3. Read [docs/client/TESTING.md](docs/client/TESTING.md)
4. Write failing test
5. Implement feature (TDD)
6. Run quality checks
7. Update documentation
8. Create pull request

### Fixing a Bug
1. Create minimal failing test that reproduces bug
2. Implement fix
3. Verify test passes
4. Add regression test if needed
5. Run quality checks
6. Document in commit message
7. Create pull request

### Updating Documentation
1. Edit relevant file in `docs/` or `status_docs/`
2. Run any automated checks (`bun run lint`, `cargo clippy`)
3. Commit with `docs:` prefix
4. Create pull request

## Need Help?

- **Development questions:** Check [CLAUDE.md](CLAUDE.md)
- **Architecture questions:** See [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md)
- **Testing guidance:** See [docs/client/TESTING.md](docs/client/TESTING.md)
- **Security concerns:** See [docs/client/SECURITY.md](docs/client/SECURITY.md)
- **Current tasks:** Check [status_docs/TODO.md](status_docs/TODO.md)

## Reporting Issues

When reporting issues, include:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment (OS, Rust version, Bun version)
- Error messages/logs (if applicable)
- Screenshots for UI issues

## Code Review Process

All PRs require:
1. **Functionality Review** - Does it work as intended?
2. **Code Quality Review** - Style, patterns, best practices?
3. **Security Review** - No vulnerabilities or data leaks?
4. **Testing Review** - Adequate coverage and test quality?
5. **Documentation Review** - Is it clear and complete?
6. **Accessibility Review** - WCAG 2.2 AA compliance?

Reviewers will provide constructive feedback. Be responsive to comments and iterate until approval.

## Continuous Integration

The project uses GitHub Actions for:
- Running tests (`cargo test`, `bun test`)
- Linting and type checking
- Building frontend and backend
- Security scanning
- Accessibility checks

All checks must pass before merging.

## Recognition

Contributors will be:
- Added to [CHANGELOG.md](CHANGELOG.md)
- Listed in project documentation
- Credited in release notes

## Questions or Suggestions?

- Open a GitHub issue for discussion
- Reference relevant documentation
- Be specific and provide context
- Check existing issues first

---

**Thank you for contributing to OpenCode Nexus!** Your efforts help make this project better for everyone.

For questions about these guidelines, please open an issue on GitHub.
