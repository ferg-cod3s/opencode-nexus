---
date: 2025-12-03
researcher: Assistant
topic: 'GitHub Actions Testing Best Practices: Local, Docker, and CI Strategies'
tags: [research, github-actions, testing, ci-cd, docker, best-practices]
status: complete
---

# GitHub Actions Testing Best Practices: Local, Docker, and CI Strategies

## Executive Summary

This research document provides a comprehensive analysis of the best ways to test GitHub Actions workflows, covering local testing with `act`, Docker-based strategies, and modern CI/CD testing approaches for 2024-2025. Based on analysis of the OpenCode Nexus codebase and current industry best practices, we present actionable strategies for efficient, reliable workflow testing.

## Research Scope

- **Codebase Analysis**: Examined existing GitHub Actions workflows in OpenCode Nexus
- **Industry Research**: Analyzed 2024-2025 best practices from multiple sources
- **Tool Evaluation**: Compared local testing approaches, Docker integration, and CI strategies
- **Practical Application**: Focused on mobile-first development with iOS/Android deployment

## Key Findings

### 1. Current State Analysis

**OpenCode Nexus Current Workflows:**
- `ios-release-optimized.yml` - Complex iOS build workflow (533 lines)
- `license-check.yml` - License compliance automation
- No dedicated testing workflows identified
- Heavy reliance on manual testing and deployment verification

**Testing Gaps Identified:**
- No automated unit/integration test workflows
- Missing local development testing setup
- No workflow testing infrastructure
- Limited test coverage for mobile-specific scenarios

### 2. Local Testing Strategies

#### 2.1 Act CLI Tool (Primary Recommendation)

**What it is:** Open-source tool that runs GitHub Actions workflows locally using Docker containers.

**Key Benefits:**
- **Fast Feedback Loop**: Test changes without committing/pushing
- **Docker-based**: Simulates GitHub Actions runner environment accurately
- **Cost Effective**: No GitHub Actions minutes consumption
- **Debugging Friendly**: Full access to logs and container state

**Installation:**
```bash
# macOS
brew install act

# Windows
winget install nektos.act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

**Usage Patterns:**
```bash
# List workflows
act -l

# Run default push workflow
act

# Run specific event
act pull_request

# Run specific job
act -j build-ios

# Use custom secrets file
act -s GITHUB_TOKEN=your_token
```

**Best Practices:**
- Use `.actrc` file for default configuration
- Create dedicated secrets file for local testing
- Integrate with pre-commit hooks
- Use for workflow development and debugging

#### 2.2 Docker Compose Integration

**Use Case**: Testing workflows that require multiple services (databases, APIs)

**Implementation Pattern:**
```yaml
# docker-compose.test.yml
version: '3.8'
services:
  app:
    build: .
    environment:
      - NODE_ENV=test
    depends_on:
      - postgres
      - redis
  
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: test_db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 5
  
  redis:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5
```

**GitHub Actions Integration:**
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
```

### 3. Testing Framework Integration

#### 3.1 Multi-Level Testing Strategy

**Testing Pyramid for GitHub Actions:**
```
    E2E Workflow Tests (Critical paths)
         ↑
    Integration Tests (Service interactions)
         ↑
    Unit Tests (Individual actions/steps)
```

#### 3.2 Framework-Specific Implementations

**JavaScript/TypeScript (Vitest + Playwright):**
```yaml
# .github/workflows/test-js.yml
name: JavaScript Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20]
    
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      
      - run: npm ci
      - run: npm run test:unit
      - run: npm run test:integration
      - run: npm run test:e2e
```

**Rust (Cargo + Tauri):**
```yaml
# .github/workflows/test-rust.yml
name: Rust Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      
      - name: Cache cargo
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            target
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
      
      - run: cargo test --verbose
      - run: cargo clippy -- -D warnings
```

#### 3.3 Mobile-Specific Testing

**iOS Testing Workflow:**
```yaml
# .github/workflows/ios-test.yml
name: iOS Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.4'
      
      - name: Install dependencies
        run: |
          cd frontend
          bun install --frozen-lockfile
      
      - name: Run unit tests
        run: |
          cd frontend
          bun test
      
      - name: Run E2E tests
        run: |
          npx playwright test --config=playwright.ios.config.ts
```

### 4. Advanced Testing Strategies

#### 4.1 Matrix Testing for Cross-Platform

**Multi-Platform Matrix:**
```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-14, windows-latest]
        node-version: [18, 20]
        include:
          - os: macos-14
            platform: ios
          - os: ubuntu-latest
            platform: android
    
    steps:
      - uses: actions/checkout@v4
      - name: Setup platform-specific environment
        run: |
          if [ "${{ matrix.platform }}" = "ios" ]; then
            # iOS-specific setup
          elif [ "${{ matrix.platform }}" = "android" ]; then
            # Android-specific setup
          fi
```

#### 4.2 Performance Testing Integration

**Performance Regression Testing:**
```yaml
jobs:
  performance-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run performance tests
        run: |
          npm run test:performance
          
      - name: Compare with baseline
        run: |
          # Compare metrics with baseline
          if performance_degraded; then
            echo "Performance regression detected"
            exit 1
          fi
```

#### 4.3 Security Testing

**Security Scan Integration:**
```yaml
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run security audit
        run: |
          npm audit --audit-level moderate
          cargo audit
          
      - name: Scan for secrets
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: main
          head: HEAD
```

### 5. Best Practices for 2024-2025

#### 5.1 Workflow Structure

**Separate Concerns:**
```yaml
# Separate workflows for different concerns
name: Unit Tests
on: [push, pull_request]
jobs:
  unit-test: # Only unit tests

---
name: Integration Tests  
on: [push, pull_request]
jobs:
  integration-test: # Only integration tests

---
name: E2E Tests
on: [push, pull_request]
jobs:
  e2e-test: # Only E2E tests
```

#### 5.2 Caching Strategies

**Advanced Caching:**
```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      ~/.cargo
      target/
    key: ${{ runner.os }}-${{ hashFiles('**/lockfiles') }}
    restore-keys: |
      ${{ runner.os }}-
```

#### 5.3 Parallel Execution

**Test Sharding:**
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    
    steps:
      - name: Run tests shard
        run: |
          npm test -- --shard=${{ matrix.shard }} --shard-count=4
```

### 6. Local Development Setup

#### 6.1 Complete Local Testing Environment

**Docker Compose for Local Testing:**
```yaml
# docker-compose.local.yml
version: '3.8'
services:
  github-runner:
    image: nektos/act:latest
    volumes:
      - .:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    working_dir: /workspace
    command: act -s GITHUB_TOKEN=local_token
```

**Pre-commit Hook Integration:**
```bash
#!/bin/sh
# .git/hooks/pre-commit

echo "Running GitHub Actions locally..."
act -j test

if [ $? -eq 0 ]; then
  echo "✅ GitHub Actions tests passed"
  exit 0
else
  echo "❌ GitHub Actions tests failed"
  exit 1
fi
```

#### 6.2 Development Workflow

**Recommended Development Process:**
1. **Local Development**: Write code and tests
2. **Local Testing**: Run `act` to test workflows locally
3. **Pre-commit**: Automated workflow validation
4. **Push**: Trigger CI/CD pipeline
5. **Review**: Monitor GitHub Actions results
6. **Merge**: Only after all tests pass

### 7. Implementation Recommendations for OpenCode Nexus

#### 7.1 Immediate Actions

**1. Implement Local Testing Setup:**
```bash
# Install act
brew install act

# Create .actrc
echo "-P ubuntu-latest=nektos/act-ubuntu-latest:latest" > .actrc
echo "-P macos-14=nektos/act-macos-latest:latest" >> .actrc
```

**2. Create Testing Workflows:**
- Unit test workflow for frontend (Vitest)
- Integration test workflow for API connections
- E2E test workflow for mobile scenarios
- Performance regression tests

**3. Add Docker Compose Support:**
```yaml
# docker-compose.test.yml
version: '3.8'
services:
  app:
    build: .
    environment:
      - NODE_ENV=test
    volumes:
      - .:/app
    command: npm test
```

#### 7.2 Advanced Implementation

**1. Test Sharding for Performance:**
```yaml
strategy:
  matrix:
    shard: [1/4, 2/4, 3/4, 4/4]
```

**2. Cross-Platform Testing:**
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-14]
    platform: [web, ios, android]
```

**3. Automated Performance Monitoring:**
```yaml
- name: Performance benchmarks
  run: |
    npm run test:performance
    # Upload results to monitoring service
```

### 8. Tool Comparison

| Tool | Use Case | Pros | Cons | Recommendation |
|------|----------|------|------|---------------|
| **act** | Local workflow testing | Fast, accurate simulation | Docker required | ⭐⭐⭐⭐⭐ Primary choice |
| **Docker Compose** | Multi-service testing | Production-like environment | Complex setup | ⭐⭐⭐⭐ For integration tests |
| **GitHub Actions** | CI/CD production | Native, scalable | Slower feedback | ⭐⭐⭐⭐⭐ Production CI/CD |
| **Local Scripts** | Simple testing | No dependencies | Limited simulation | ⭐⭐ Basic testing only |

### 9. Security Considerations

#### 9.1 Secret Management

**Local Testing:**
```bash
# .secrets.local
GITHUB_TOKEN=ghp_your_token_here
IOS_CERTIFICATE_P12=base64_cert_here
```

**CI/CD:**
```yaml
- name: Use secrets
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    IOS_CERTIFICATE: ${{ secrets.IOS_CERTIFICATE }}
```

#### 9.2 Security Testing

**Automated Security Scans:**
```yaml
- name: Security audit
  run: |
    npm audit --audit-level moderate
    cargo audit
    trufflehog filesystem ./
```

### 10. Monitoring and Reporting

#### 10.1 Test Results Reporting

**JUnit XML Integration:**
```yaml
- name: Publish test results
  uses: dorny/test-reporter@v1
  if: success() || failure()
  with:
    name: Test Results
    path: junit.xml
    reporter: java-junit
```

#### 10.2 Performance Monitoring

**Metrics Collection:**
```yaml
- name: Collect metrics
  run: |
    # Collect test execution time
    # Collect memory usage
    # Upload to monitoring service
```

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- [ ] Install and configure `act` for local testing
- [ ] Create basic unit test workflows
- [ ] Set up Docker Compose for integration testing
- [ ] Implement pre-commit hooks

### Phase 2: Expansion (Week 3-4)
- [ ] Add E2E testing workflows
- [ ] Implement test sharding for performance
- [ ] Set up cross-platform matrix testing
- [ ] Add security scanning workflows

### Phase 3: Optimization (Week 5-6)
- [ ] Implement advanced caching strategies
- [ ] Add performance regression testing
- [ ] Set up comprehensive reporting
- [ ] Optimize for mobile-specific scenarios

### Phase 4: Production (Week 7-8)
- [ ] Full integration with existing iOS build workflow
- [ ] Automated performance monitoring
- [ ] Complete test coverage reporting
- [ ] Documentation and team training

## Conclusion

The best approach to testing GitHub Actions combines multiple strategies:

1. **Local Testing with `act`** for fast feedback during development
2. **Docker Compose** for complex integration scenarios
3. **GitHub Actions CI/CD** for production testing
4. **Comprehensive monitoring** for quality assurance

For OpenCode Nexus specifically, implementing this multi-layered approach will significantly improve development velocity, reduce bugs, and ensure reliable mobile app deployments.

## References

1. [nektos/act - GitHub Actions local runner](https://github.com/nektos/act)
2. [GitHub Actions Best Practices 2025](https://suzuki-shashuke.github.io/slides/github-actions-best-practice-2025)
3. [Docker Compose with GitHub Actions](https://spin.atomicobject.com/docker-compose-github-actions/)
4. [Advanced Testing Strategies 2024](https://augmentcode.com/guides/12-faster-testing-strategies)
5. [Mobile Testing with Playwright](https://www.testmo.com/guides/github-actions-selenium/)

---

**Research Confidence**: 0.9/1.0
**Evidence Quality**: High (multiple industry sources, codebase analysis)
**Implementation Feasibility**: High (tools are mature and well-documented)
**ROI Estimate**: High (significant time savings and quality improvements)