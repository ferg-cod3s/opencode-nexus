# GitHub Actions Testing Setup

This directory contains the complete GitHub Actions testing infrastructure for OpenCode Nexus, enabling local testing, CI/CD automation, and comprehensive mobile testing.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Act CLI for local GitHub Actions testing
brew install act

# Or on Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Install Docker (required for Act)
# Start Docker Desktop or service
```

### 2. Setup Local Secrets

```bash
# Run the setup script
./scripts/setup-local-secrets.sh

# Or manually copy and configure
cp .secrets.local.example .secrets.local
# Edit .secrets.local with your actual secrets
```

### 3. Test Workflows Locally

```bash
# List available workflows
act -l

# Run default workflow
act

# Run specific workflow
act -j test-frontend

# Run with specific secrets file
act -s .secrets.local
```

## 📁 File Structure

```
.github/
├── workflows/
│   ├── test-frontend.yml      # Frontend unit/integration tests
│   ├── test-backend.yml       # Backend Rust tests
│   ├── test-integration.yml   # Cross-component integration
│   ├── test-mobile-e2e.yml    # Mobile E2E testing
│   └── ios-release-optimized.yml  # iOS build (existing)
├── hooks/
│   ├── pre-commit            # Pre-commit validation
│   └── pre-push             # Pre-push testing
└── scripts/
    ├── setup-local-secrets.sh    # Secrets setup
    └── validate-workflows.sh     # Quick validation

frontend/
├── e2e/
│   └── mobile/
│       └── chat-mobile.spec.ts   # Mobile E2E tests
├── playwright.mobile.config.ts     # Mobile testing config
├── playwright.ios.config.ts       # iOS testing config
├── playwright.android.config.ts    # Android testing config
└── Dockerfile.test               # Frontend test container

src-tauri/
└── Dockerfile.test               # Backend test container

tests/
├── integration/
│   ├── init-test-db.sql         # Test database setup
│   └── Dockerfile.mock-server  # Mock server for testing
└── ...

docker-compose.test.yml          # Full testing environment
.actrc                         # Act CLI configuration
.secrets.local.example          # Secrets template
```

## 🔧 Configuration

### Act CLI Configuration (.actrc)

```bash
# Use official act images
-P ubuntu-latest=nektos/act-ubuntu-latest:latest
-P macos-14=nektos/act-macos-latest:latest

# Use local secrets
-s .secrets.local
```

### Local Secrets (.secrets.local)

```bash
# GitHub Token for API access
GITHUB_TOKEN=your_github_token_here

# Database for integration testing
DATABASE_URL=postgresql://test:test@localhost:5432/test_db
REDIS_URL=redis://localhost:6379

# Environment variables
NODE_ENV=test
RUST_LOG=debug
```

## 🧪 Testing Workflows

### Frontend Tests (`test-frontend.yml`)

- **Unit Tests**: Bun test runner with Vitest
- **Type Checking**: TypeScript strict mode
- **Linting**: ESLint with comprehensive rules
- **E2E Tests**: Playwright with multiple browsers
- **Accessibility**: Axe-core for WCAG compliance

### Backend Tests (`test-backend.yml`)

- **Unit Tests**: Cargo test runner
- **Integration Tests**: Database and API testing
- **Security Audit**: Cargo audit for vulnerabilities
- **Code Coverage**: LLVM coverage reporting
- **Cross-Platform**: Multiple target builds

### Integration Tests (`test-integration.yml`)

- **Docker Compose**: Full stack testing
- **Database Integration**: PostgreSQL with test data
- **API Integration**: Mock OpenCode server
- **Cross-Component**: Frontend + backend integration

### Mobile E2E Tests (`test-mobile-e2e.yml`)

- **Mobile Viewports**: iPhone, Android, iPad testing
- **Touch Interactions**: Mobile gesture testing
- **Native Apps**: iOS Simulator and Android Emulator
- **Performance**: Lighthouse CI integration

## 📱 Mobile Testing

### iOS Testing

```bash
# Run iOS-specific tests
act -j ios-native-e2e

# Local testing with Playwright
cd frontend
bunx playwright test --config=playwright.ios.config.ts
```

### Android Testing

```bash
# Run Android-specific tests
act -j android-native-e2e

# Local testing with Playwright
cd frontend
bunx playwright test --config=playwright.android.config.ts
```

### Mobile Web Testing

```bash
# Test mobile web browsers
act -j mobile-e2e

# Local testing
cd frontend
bunx playwright test --project="Mobile Chrome"
```

## 🐳 Docker Testing

### Full Stack Testing

```bash
# Run complete integration test suite
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Run specific services
docker-compose -f docker-compose.test.yml up postgres redis
```

### Test Services

- **PostgreSQL**: Test database with sample data
- **Redis**: Caching and session storage
- **Mock Server**: OpenCode API simulation
- **Frontend Test**: Bun + Playwright testing
- **Backend Test**: Cargo testing environment

## 🔍 Pre-commit Hooks

### Pre-commit Validation

- **YAML Syntax**: Validate workflow files
- **Workflow Testing**: Act CLI dry-run validation
- **Source Testing**: Unit tests and linting
- **Security Checks**: Secret detection and console.log warnings

### Pre-push Testing

- **Full Workflow Testing**: Complete Act CLI execution
- **Integration Tests**: Cross-component validation
- **Security Audit**: Vulnerability scanning
- **Performance Checks**: Basic performance validation

## 📊 Monitoring & Reporting

### Test Reports

- **JUnit XML**: Standardized test results
- **HTML Reports**: Playwright visual reports
- **Coverage Reports**: Code coverage tracking
- **Performance Reports**: Lighthouse scores

### Artifacts

- **Test Screenshots**: Failure screenshots
- **Test Videos**: Execution recordings
- **Logs**: Detailed execution logs
- **Coverage Data**: Coverage information

## 🛠️ Development Workflow

### 1. Local Development

```bash
# Make changes to code
# Run tests locally
cd frontend && bun test
cd src-tauri && cargo test

# Validate workflows
./scripts/validate-workflows.sh
```

### 2. Pre-commit Validation

```bash
# Git hooks automatically run
git add .
git commit -m "feat: add new feature"
# Hooks validate and test automatically
```

### 3. Pre-push Testing

```bash
# Full test suite before push
git push origin feature-branch
# Pre-push hook runs comprehensive tests
```

### 4. CI/CD Pipeline

```bash
# GitHub Actions runs automatically
# All workflows execute in parallel
# Results available in PR checks
```

## 🚨 Troubleshooting

### Common Issues

1. **Act CLI not found**
   ```bash
   brew install act
   # or
   curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
   ```

2. **Docker not running**
   ```bash
   # Start Docker Desktop
   # or start Docker service
   sudo systemctl start docker
   ```

3. **Secrets not configured**
   ```bash
   ./scripts/setup-local-secrets.sh
   # or manually create .secrets.local
   ```

4. **Workflow validation fails**
   ```bash
   # Check YAML syntax
   yamllint .github/workflows/*.yml
   
   # Test with Act
   act --dryrun
   ```

### Debug Mode

```bash
# Enable verbose logging
act -v

# Debug specific workflow
act -j test-frontend -v

# Use specific secrets
act -s GITHUB_TOKEN=your_token -v
```

## 📚 Best Practices

### Workflow Design

- **Separate Concerns**: Different workflows for different test types
- **Parallel Execution**: Run tests in parallel where possible
- **Caching**: Use GitHub Actions caching for dependencies
- **Fail Fast**: Use `fail-fast: false` for comprehensive testing

### Testing Strategy

- **Test Pyramid**: Unit → Integration → E2E
- **Mobile First**: Test mobile viewports and interactions
- **Cross-Platform**: Test on multiple operating systems
- **Performance**: Include performance regression tests

### Security

- **Secret Management**: Never commit secrets
- **Dependency Scanning**: Regular security audits
- **Container Security**: Use trusted base images
- **Access Control**: Principle of least privilege

## 🔄 Continuous Improvement

### Metrics to Track

- **Test Execution Time**: Optimize for speed
- **Test Coverage**: Aim for 80%+ coverage
- **Flaky Tests**: Identify and fix flaky tests
- **Resource Usage**: Monitor CI/CD resource consumption

### Regular Updates

- **Dependencies**: Keep dependencies up to date
- **Base Images**: Update Docker base images regularly
- **Actions**: Use latest GitHub Actions versions
- **Tools**: Keep testing tools current

## 📞 Support

### Documentation

- **GitHub Actions**: [Official Documentation](https://docs.github.com/en/actions)
- **Act CLI**: [Act Documentation](https://github.com/nektos/act)
- **Playwright**: [Playwright Documentation](https://playwright.dev/)
- **Docker**: [Docker Documentation](https://docs.docker.com/)

### Issues

- **GitHub Issues**: Report issues in the repository
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check existing documentation first

---

**Last Updated**: 2025-12-03
**Version**: 1.0.0
**Maintainer**: OpenCode Nexus Team