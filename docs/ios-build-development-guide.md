# iOS Build Development Guide

**Last Updated**: 2025-12-01  
**Version**: 1.0  

This guide covers iOS development workflow and best practices for OpenCode Nexus.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Development Workflow](#development-workflow)
3. [Local Development](#local-development)
4. [Testing](#testing)
5. [Performance Optimization](#performance-optimization)
6. [Best Practices](#best-practices)

## Quick Start

### Prerequisites
- macOS 14.0+ with Xcode 15.4+
- Rust 1.70+ with iOS targets installed
- Bun package manager
- CocoaPods (for iOS dependencies)

### Initial Setup
```bash
# 1. Clone and navigate to project
git clone <repository-url>
cd opencode-nexus

# 2. Install Rust and iOS targets
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# 3. Install Bun
curl -fsSL https://bun.sh/install | bash

# 4. Install CocoaPods
sudo gem install cocoapods

# 5. Validate environment
./scripts/validate-ios-env.sh

# 6. Pre-warm dependencies
./scripts/pre-warm-deps.sh
```

## Development Workflow

### Daily Development Routine
```bash
# 1. Pull latest changes
git pull origin main

# 2. Validate environment (quick check)
./scripts/validate-ios-env.sh

# 3. Start iOS development
./scripts/ios-dev.sh
```

### Making Changes
```bash
# 1. Make your changes
# Edit source code in src-tauri/ or frontend/

# 2. Test changes locally
./scripts/ios-dev.sh --simulator "iPhone 15"

# 3. Run tests
./scripts/test-ios-build.sh all

# 4. Measure performance
./scripts/measure-build-performance.sh measure

# 5. Commit changes
git add .
git commit -m "feat: your change description"
git push
```

## Local Development

### iOS Simulator Development
```bash
# Start development with default simulator
./scripts/ios-dev.sh

# Start with specific simulator
./scripts/ios-dev.sh --simulator "iPhone 14"

# Start with debug mode
./scripts/ios-dev.sh --debug

# Start without hot-reload
./scripts/ios-dev.sh --no-hot-reload
```

### Available Options
| Option | Description | Example |
|--------|-------------|---------|
| `--simulator NAME` | Specify simulator device | `--simulator "iPad Pro"` |
| `--os VERSION` | iOS version for simulator | `--os "17.0"` |
| `--debug` | Build in debug mode | `--debug` |
| `--no-hot-reload` | Disable hot-reload | `--no-hot-reload` |
| `--help` | Show help message | `--help` |

### Development Features

#### Hot Reload
- Frontend changes automatically reload in simulator
- Rust changes require rebuild (automatic with hot-reload enabled)
- Configuration changes require restart

#### Logging
- Development logs shown in terminal
- Rust logs: Set `RUST_LOG=debug`
- iOS logs: Use Xcode Console app

#### Debugging
- Use Xcode for debugging: `open src-tauri/gen/apple/src-tauri.xcworkspace`
- Set breakpoints in Xcode
- Use Console app for iOS logs

## Testing

### Running Tests
```bash
# Run all tests
./scripts/test-ios-build.sh all

# Run specific test categories
./scripts/test-ios-build.sh env          # Environment tests
./scripts/test-ios-build.sh rust         # Rust tests
./scripts/test-ios-build.sh frontend     # Frontend tests
./scripts/test-ios-build.sh ios          # iOS configuration tests
```

### Test Categories

#### Environment Tests
- ✅ macOS version check
- ✅ Xcode installation
- ✅ Rust toolchain
- ✅ iOS targets
- ✅ Bun installation
- ✅ CocoaPods installation

#### Build Tests
- ✅ Frontend dependency installation
- ✅ Frontend build
- ✅ Rust compilation for iOS targets
- ✅ iOS project generation
- ✅ Tauri iOS build

#### Configuration Tests
- ✅ Project structure validation
- ✅ iOS configuration files
- ✅ Tauri configuration syntax
- ✅ Script functionality

### Test Results
```bash
# View latest test report
./scripts/test-ios-build.sh report

# View test history
ls -la tests/build/results/
```

## Performance Optimization

### Measuring Performance
```bash
# Measure build performance
./scripts/measure-build-performance.sh measure

# View performance history
./scripts/measure-build-performance.sh history

# Generate performance summary
./scripts/measure-build-performance.sh summary
```

### Optimization Techniques

#### 1. Dependency Caching
```bash
# Pre-warm dependencies
./scripts/pre-warm-deps.sh

# Use incremental builds
export CARGO_INCREMENTAL=1

# Use sccache for Rust compilation
export RUSTC_WRAPPER=sccache
```

#### 2. Build Optimization
```bash
# Optimize for size
cargo build --target aarch64-apple-ios --profile release-ios

# Use parallel builds
cargo build -j $(nproc) --target aarch64-apple-ios

# Clean builds periodically
cargo clean
```

#### 3. System Optimization
```bash
# Close unnecessary applications
# Use SSD storage
# Ensure sufficient RAM (16GB+ recommended)
# Keep macOS updated
```

### Performance Targets
| Metric | Target | Good | Excellent |
|--------|--------|-------|------------|
| Total Build Time | <5m | <3m | <2m |
| Rust Build Time | <2m | <1m | <30s |
| Frontend Build Time | <1m | <30s | <15s |
| Tauri Build Time | <2m | <1m | <30s |
| Artifact Size | <50MB | <30MB | <20MB |

## Best Practices

### Code Organization

#### Rust Code
```rust
// Use conditional compilation for iOS-specific code
#[cfg(target_os = "ios")]
fn ios_specific_function() {
    // iOS-specific implementation
}

// Use proper error handling
use anyhow::Result;
fn ios_operation() -> Result<()> {
    // Implementation with proper error handling
}
```

#### Frontend Code
```typescript
// Use platform-specific imports
import { invoke } from '@tauri-apps/api/core';

// Handle iOS-specific behavior
if (window.__TAURI__) {
    // Tauri-specific code
}
```

### Build Configuration

#### Cargo.toml
```toml
# Use iOS-specific dependencies
[target.'cfg(target_os = "ios")'.dependencies]
tauri-plugin-ios = "2.0"
mobile-entry-point = "1.0"
```

#### Tauri Configuration
```json
{
  "bundle": {
    "iOS": {
      "developmentTeam": "YOUR_TEAM_ID",
      "minimumSystemVersion": "14.0",
      "capabilities": [],
      "entitlements": "ios-config/src-tauri_iOS.entitlements"
    }
  }
}
```

### Git Workflow

#### Branch Strategy
```bash
# Main branch for production
main

# Feature branches for development
feature/ios-build-improvements
feature/ios-simulator-support

# Release branches for stabilization
release/ios-v1.0.0
```

#### Commit Messages
```bash
# Use conventional commits
feat: add iOS simulator support
fix: resolve iOS code signing issue
docs: update iOS build guide
test: add iOS build validation tests
```

### Security Practices

#### Code Signing
```bash
# Use environment variables for sensitive data
export DEVELOPMENT_TEAM="PCJU8QD9FN"

# Never commit certificates or provisioning profiles
# Add to .gitignore
*.p12
*.mobileprovision
```

#### API Keys
```bash
# Use GitHub secrets for CI/CD
# Use environment variables for local development
export API_KEY="your-api-key"
```

## Troubleshooting

### Common Issues

#### Build Failures
1. **Check environment**: `./scripts/validate-ios-env.sh`
2. **Clean build**: `cargo clean && rm -rf src-tauri/gen/apple/`
3. **Update dependencies**: `cargo update && bun update`
4. **Restart tools**: Restart Xcode, Terminal

#### Simulator Issues
1. **Reset simulator**: `xcrun simctl erase all`
2. **Restart simulator**: `killall Simulator && open -a Simulator`
3. **Check iOS version**: Ensure simulator iOS matches deployment target

#### Performance Issues
1. **Measure performance**: `./scripts/measure-build-performance.sh measure`
2. **Check system resources**: Activity Monitor
3. **Optimize build**: Use caching and incremental builds

### Getting Help

#### Automated Help
```bash
# Run comprehensive diagnosis
./scripts/test-ios-build.sh all

# Generate troubleshooting report
./scripts/build-with-error-handling.sh 2>&1 | tee build.log
```

#### Manual Help
1. Check logs: `logs/` directory
2. Review documentation: `docs/` directory
3. Search issues: GitHub repository issues
4. Create new issue with system information

## Advanced Topics

### Custom Build Scripts
```bash
#!/bin/bash
# Custom build script example
export RUST_LOG=debug
export CARGO_INCREMENTAL=1

./scripts/build-with-error-handling.sh --release
./scripts/measure-build-performance.sh measure
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Build iOS
  run: |
    ./scripts/validate-ios-env.sh
    ./scripts/pre-warm-deps.sh
    ./scripts/build-with-error-handling.sh
```

### Performance Monitoring
```bash
# Continuous monitoring
while true; do
    ./scripts/measure-build-performance.sh measure
    sleep 3600  # Every hour
done
```

## Resources

### Documentation
- [iOS Build Troubleshooting Guide](ios-build-troubleshooting.md)
- [Xcode Cloud Setup Guide](xcode-cloud-setup.md)
- [Tauri iOS Documentation](https://tauri.app/v1/guides/building/ios/)

### Tools
- [Rust Documentation](https://doc.rust-lang.org/)
- [Bun Documentation](https://bun.sh/docs)
- [Xcode Documentation](https://developer.apple.com/xcode/)

### Community
- [Tauri Discord](https://discord.gg/tauri)
- [Rust Users Forum](https://users.rust-lang.org/)
- [Apple Developer Forums](https://developer.apple.com/forums/)

---

## Quick Reference

### Essential Commands
```bash
# Environment validation
./scripts/validate-ios-env.sh

# Development
./scripts/ios-dev.sh

# Build with error handling
./scripts/build-with-error-handling.sh

# Performance measurement
./scripts/measure-build-performance.sh measure

# Testing
./scripts/test-ios-build.sh all

# Troubleshooting
./scripts/build-with-error-handling.sh 2>&1 | tee build.log
```

### File Locations
- **Scripts**: `scripts/`
- **Configuration**: `src-tauri/ios-config/`
- **Logs**: `logs/`
- **Performance Data**: `performance/`
- **Test Results**: `tests/build/results/`

### Environment Variables
```bash
export RUST_LOG=info          # Logging level
export CARGO_INCREMENTAL=1   # Incremental builds
export IPHONEOS_DEPLOYMENT_TARGET=14.0  # iOS minimum version
```

---

*This guide is part of the iOS Build Reliability Implementation Plan*