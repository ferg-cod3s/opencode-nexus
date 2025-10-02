# Contributing to OpenCode Nexus

Thank you for your interest in contributing to OpenCode Nexus! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [CI/CD Pipeline](#cicd-pipeline)
- [Pull Request Process](#pull-request-process)
- [Security Guidelines](#security-guidelines)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please be respectful, professional, and constructive in all interactions.

### Our Standards

- **Be Respectful:** Treat all community members with respect
- **Be Collaborative:** Work together toward common goals
- **Be Professional:** Maintain professional conduct
- **Be Constructive:** Provide helpful, actionable feedback

## Getting Started

### Prerequisites

- **Rust:** Latest stable (1.70+)
- **Bun:** Latest stable version
- **Git:** Version control
- **System Dependencies:** See [README.md](README.md) for platform-specific requirements

### Setting Up Development Environment

1. **Fork the Repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/opencode-nexus.git
   cd opencode-nexus
   ```

2. **Install Dependencies**
   ```bash
   cd frontend
   bun install
   cd ../src-tauri
   cargo build
   ```

3. **Run Development Server**
   ```bash
   cargo tauri dev
   ```

4. **Verify Setup**
   ```bash
   cd frontend
   bun test
   cd ../src-tauri
   cargo test
   ```

## Development Workflow

### Branching Strategy

- **main:** Stable production-ready code
- **develop:** Integration branch for features
- **feature/*:** New features and enhancements
- **fix/*:** Bug fixes
- **docs/*:** Documentation updates

### Creating a Branch

```bash
git checkout -b feature/your-feature-name develop
```

### Commit Message Format

Use conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process or tooling changes
- `perf`: Performance improvements
- `security`: Security fixes

**Example:**
```
feat(auth): add multi-factor authentication support

Implement TOTP-based MFA for enhanced security. Users can now
enable MFA in their account settings.

Closes #123
```

## Coding Standards

### TypeScript/JavaScript (Frontend)

- **Indentation:** 2 spaces
- **Style Guide:** Follow ESLint configuration
- **Type Safety:** Strict TypeScript mode (no `any` types)
- **Imports:** Group by stdlib, external, then local
- **Naming:**
  - `camelCase` for variables and functions
  - `PascalCase` for types, classes, interfaces
  - `UPPER_SNAKE_CASE` for constants

**Example:**
```typescript
interface UserConfig {
  username: string;
  enableMFA: boolean;
}

function validateUser(config: UserConfig): boolean {
  if (!config.username || config.username.length < 3) {
    return false;
  }
  return true;
}
```

### Rust (Backend)

- **Formatting:** Use `cargo fmt`
- **Linting:** Pass `cargo clippy`
- **Naming:**
  - `snake_case` for variables and functions
  - `PascalCase` for types and structs
  - `SCREAMING_SNAKE_CASE` for constants
- **Error Handling:** Use `Result<T, E>` and `?` operator

**Example:**
```rust
pub struct ServerConfig {
    pub port: u16,
    pub host: String,
}

pub fn validate_config(config: &ServerConfig) -> Result<(), String> {
    if config.port == 0 {
        return Err("Port cannot be zero".to_string());
    }
    Ok(())
}
```

## Testing Guidelines

### Test-Driven Development (TDD)

**We follow TDD principles:**

1. **Write failing test first**
2. **Implement minimal code to pass**
3. **Refactor while keeping tests green**

### Frontend Tests

```bash
cd frontend
bun test                    # Run unit tests
bun test --coverage         # Run with coverage
bun run test:e2e            # Run E2E tests
```

### Backend Tests

```bash
cd src-tauri
cargo test                  # Run all tests
cargo test --test auth      # Run specific test
cargo tarpaulin             # Coverage report
```

### Test Coverage Requirements

- **Minimum Coverage:** 80% for new code
- **Critical Paths:** 90% coverage required
- **Security Features:** 100% coverage mandatory

### Writing Good Tests

**Frontend Example:**
```typescript
import { describe, it, expect } from 'vitest';
import { validateUser } from './auth';

describe('validateUser', () => {
  it('should return true for valid user', () => {
    const config = { username: 'testuser', enableMFA: false };
    expect(validateUser(config)).toBe(true);
  });

  it('should return false for short username', () => {
    const config = { username: 'ab', enableMFA: false };
    expect(validateUser(config)).toBe(false);
  });
});
```

**Backend Example:**
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_config_success() {
        let config = ServerConfig {
            port: 8080,
            host: "localhost".to_string(),
        };
        assert!(validate_config(&config).is_ok());
    }

    #[test]
    fn test_validate_config_invalid_port() {
        let config = ServerConfig {
            port: 0,
            host: "localhost".to_string(),
        };
        assert!(validate_config(&config).is_err());
    }
}
```

## CI/CD Pipeline

Our CI/CD pipeline automatically runs on all pull requests and commits to main/develop branches.

### Pipeline Stages

#### 1. **Comprehensive Testing** (Automatic)
- Frontend unit tests (Bun + TypeScript)
- Backend unit tests (Rust + Cargo)
- E2E tests (Playwright)
- Linting (ESLint + Clippy)
- Type checking (TypeScript + Rust)
- Code formatting (Prettier + rustfmt)

#### 2. **Security Scanning** (Automatic)
- Trivy filesystem scan
- Trivy configuration scan
- NPM audit (dependency vulnerabilities)
- Cargo audit (Rust dependency vulnerabilities)
- CodeQL analysis (JavaScript/TypeScript)
- Secret scanning (TruffleHog)

#### 3. **Quality Gate** (Pull Requests)
- Code quality checks (linting + formatting)
- Test coverage analysis
- Build verification (all platforms)
- Quality summary report

#### 4. **License Check** (Automatic)
- License header validation
- Dependency license scanning (Rust + NPM)
- SBOM (Software Bill of Materials) generation

#### 5. **Release** (Tags Only)
- Cross-platform builds (Linux, macOS, Windows)
- Asset generation (.deb, .dmg, .msi, .AppImage, .exe)
- GitHub Release creation
- Automated distribution

### Viewing CI/CD Results

- **GitHub Actions:** Check the "Actions" tab
- **Security:** Check the "Security" tab for vulnerability reports
- **Quality:** View summary in PR comments

### Running CI Checks Locally

**Frontend:**
```bash
cd frontend
bun run lint                # ESLint
bun run typecheck           # TypeScript
bun test                    # Unit tests
bun run test:e2e            # E2E tests
```

**Backend:**
```bash
cd src-tauri
cargo fmt -- --check        # Format check
cargo clippy                # Linting
cargo test                  # Tests
cargo audit                 # Security audit
```

## Pull Request Process

### Before Submitting

- [ ] Branch created from `develop`
- [ ] Tests written and passing locally
- [ ] Code follows style guidelines
- [ ] Documentation updated (if needed)
- [ ] Commit messages follow convention
- [ ] No merge conflicts with target branch

### Submitting a Pull Request

1. **Push Your Branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**
   - Navigate to GitHub repository
   - Click "New Pull Request"
   - Select `develop` as base branch
   - Provide clear title and description

3. **PR Description Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## Testing
   - [ ] Unit tests added/updated
   - [ ] E2E tests added/updated
   - [ ] Manual testing performed

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] No new warnings introduced
   - [ ] Tests pass locally
   - [ ] Security considerations addressed

   ## Related Issues
   Closes #issue_number
   ```

### Review Process

1. **Automated Checks:** CI/CD pipeline runs automatically
2. **Code Review:** Maintainers review code and provide feedback
3. **Revisions:** Address feedback and update PR
4. **Approval:** At least one maintainer approval required
5. **Merge:** Maintainer merges after all checks pass

### After Merge

- Branch will be automatically deleted
- Changes will be included in next release
- Contributors will be credited in release notes

## Security Guidelines

### Security-First Mindset

- **Validate All Inputs:** Never trust user input
- **Use Parameterized Queries:** Prevent SQL injection
- **Avoid Eval:** Never use `eval()` or similar functions
- **Sanitize Output:** Prevent XSS attacks
- **Secure Secrets:** Never commit secrets or API keys
- **Follow Principle of Least Privilege:** Minimal permissions

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities.

Instead:
- Use [GitHub Security Advisories](https://github.com/YOUR_REPO/security/advisories)
- Email: security@opencode-nexus.example.com
- See [SECURITY.md](docs/SECURITY.md) for details

### Security Review Checklist

- [ ] Input validation implemented
- [ ] Authentication and authorization checked
- [ ] Sensitive data encrypted
- [ ] No secrets in code
- [ ] Error messages don't leak information
- [ ] Dependencies updated and audited
- [ ] Security best practices followed

## Documentation

### Documentation Requirements

- **Code Comments:** Explain "why" not "what"
- **API Documentation:** Document all public APIs
- **README Updates:** Update README for new features
- **Architecture Docs:** Update architecture documentation for major changes
- **Security Docs:** Update security documentation for security-related changes

### Documentation Standards

**TypeScript/JavaScript:**
```typescript
/**
 * Validates user configuration
 * 
 * @param config - User configuration object
 * @returns True if valid, false otherwise
 * @throws Error if configuration is malformed
 */
function validateUser(config: UserConfig): boolean {
  // Implementation
}
```

**Rust:**
```rust
/// Validates server configuration
///
/// # Arguments
///
/// * `config` - Reference to server configuration
///
/// # Returns
///
/// * `Result<(), String>` - Ok if valid, Err with message if invalid
///
/// # Examples
///
/// ```
/// let config = ServerConfig { port: 8080, host: "localhost".to_string() };
/// assert!(validate_config(&config).is_ok());
/// ```
pub fn validate_config(config: &ServerConfig) -> Result<(), String> {
    // Implementation
}
```

## Community

### Getting Help

- **GitHub Discussions:** Ask questions and share ideas
- **GitHub Issues:** Report bugs and request features
- **Documentation:** Check docs/ directory

### Contributing to Discussions

- Search existing discussions before creating new ones
- Provide context and details
- Be respectful and constructive
- Help others when possible

### Recognition

We recognize contributors through:
- **CHANGELOG.md:** Credits in release notes
- **Contributors Page:** Listed on GitHub
- **Security Hall of Fame:** For security researchers

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR:** Breaking changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes (backward compatible)

### Release Workflow

1. **Prepare Release Branch**
   ```bash
   git checkout -b release/v1.2.0 develop
   ```

2. **Update Version Numbers**
   - `src-tauri/Cargo.toml`
   - `frontend/package.json`
   - `CHANGELOG.md`

3. **Create Release Tag**
   ```bash
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin v1.2.0
   ```

4. **Automated Build:** CI/CD pipeline builds and releases automatically

5. **Merge to Main**
   ```bash
   git checkout main
   git merge release/v1.2.0
   git push origin main
   ```

## Questions?

If you have questions not covered here:
- Check [README.md](README.md)
- Check [docs/](docs/) directory
- Open a GitHub Discussion
- Contact maintainers

---

**Thank you for contributing to OpenCode Nexus!**

We appreciate your time and effort in making this project better. Every contribution, no matter how small, helps make OpenCode Nexus more secure, reliable, and useful for everyone.
