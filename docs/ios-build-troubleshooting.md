# iOS Build Troubleshooting Guide

**Last Updated**: 2025-12-01  
**Version**: 1.0  

This guide provides comprehensive troubleshooting steps for iOS build issues in OpenCode Nexus.

## Table of Contents

1. [Quick Diagnosis](#quick-diagnosis)
2. [Common Issues](#common-issues)
3. [Environment Problems](#environment-problems)
4. [Build Failures](#build-failures)
5. [Code Signing Issues](#code-signing-issues)
6. [Performance Problems](#performance-problems)
7. [CI/CD Issues](#cicd-issues)
8. [Advanced Troubleshooting](#advanced-troubleshooting)

## Quick Diagnosis

### Step 1: Run Environment Validation
```bash
./scripts/validate-ios-env.sh
```

This will check:
- ✅ macOS version and Xcode installation
- ✅ Rust toolchain and iOS targets
- ✅ Bun package manager
- ✅ CocoaPods installation
- ✅ Project structure integrity
- ✅ iOS configuration files

### Step 2: Run Build Tests
```bash
./scripts/test-ios-build.sh all
```

This will validate:
- ✅ All dependencies are available
- ✅ Project structure is correct
- ✅ iOS configuration is valid
- ✅ Scripts are functional
- ✅ Build process works

### Step 3: Check Recent Logs
```bash
# View recent build logs
ls -la logs/ | tail -5

# View latest error log
cat logs/ios-errors-*.log | tail -20

# View latest timing log
cat logs/ios-timing-*.log
```

## Common Issues

### Issue: "Rust not found"
**Symptoms**: `command not found: cargo` or `command not found: rustc`

**Causes**:
- Rust not installed
- Rust not in PATH
- Corrupted Rust installation

**Solutions**:
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add to PATH (add to ~/.zshrc or ~/.bashrc)
source "$HOME/.cargo/env"

# Verify installation
rustc --version
cargo --version
```

### Issue: "iOS targets not installed"
**Symptoms**: `error: couldn't find target aarch64-apple-ios`

**Causes**:
- iOS targets not installed
- Rust targets corrupted

**Solutions**:
```bash
# Install all iOS targets
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# Verify installation
rustup target list --installed | grep ios
```

### Issue: "Bun not found"
**Symptoms**: `command not found: bun`

**Causes**:
- Bun not installed
- Bun not in PATH

**Solutions**:
```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Add to PATH (add to ~/.zshrc or ~/.bashrc)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Verify installation
bun --version
```

### Issue: "CocoaPods not found"
**Symptoms**: `command not found: pod`

**Causes**:
- CocoaPods not installed
- Ruby gems not updated

**Solutions**:
```bash
# Install CocoaPods
sudo gem install cocoapods

# Update gem system first (if needed)
sudo gem update --system

# Verify installation
pod --version
```

## Environment Problems

### Issue: Xcode Command Line Tools Not Found
**Symptoms**: `xcode-select: error: tool 'xcodebuild' requires Xcode`

**Solutions**:
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Set Xcode path (if Xcode is installed)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Verify installation
xcodebuild -version
```

### Issue: iOS Simulator Not Available
**Symptoms**: `No iOS simulators available` or simulator fails to boot

**Solutions**:
```bash
# List available simulators
xcrun simctl list devices available

# Create iOS simulator (if needed)
xcrun simctl create "iPhone 15" "com.apple.CoreSimulator.SimDeviceType.iPhone-15" "com.apple.CoreSimulator.SimRuntime.iOS-17-0"

# Boot simulator
xcrun simctl boot <SIMULATOR_ID>

# Open Simulator app
open -a Simulator
```

### Issue: Permission Denied Errors
**Symptoms**: `Permission denied` when accessing files or directories

**Solutions**:
```bash
# Fix script permissions
chmod +x scripts/*.sh

# Fix directory permissions
chmod -R 755 src-tauri/
chmod -R 755 frontend/

# Fix ownership (if needed)
sudo chown -R $(whoami):$(whoami) .
```

## Build Failures

### Issue: Frontend Build Fails
**Symptoms**: Frontend compilation errors during `bun run build`

**Diagnosis**:
```bash
# Check frontend dependencies
cd frontend
bun install --frozen-lockfile

# Test frontend build
bun run build

# Check for specific errors
bun run build 2>&1 | grep -i error
```

**Solutions**:
```bash
# Clear frontend cache
rm -rf node_modules
rm -rf .bun
rm -rf dist

# Reinstall dependencies
bun install --frozen-lockfile

# Update dependencies
bun update
```

### Issue: Rust Compilation Fails
**Symptoms**: Rust compiler errors during `cargo build`

**Diagnosis**:
```bash
# Check Rust code
cd src-tauri
cargo check --target aarch64-apple-ios

# Check for specific errors
cargo check --target aarch64-apple-ios 2>&1 | grep -i error

# Update dependencies
cargo update
```

**Solutions**:
```bash
# Clean Rust build
cargo clean

# Rebuild with verbose output
RUST_LOG=debug cargo build --target aarch64-apple-ios --verbose

# Check for dependency conflicts
cargo tree | grep -E "(red|yellow)"
```

### Issue: Tauri iOS Build Fails
**Symptoms**: `cargo tauri ios build` fails

**Diagnosis**:
```bash
# Check iOS project initialization
cd src-tauri
ls -la gen/apple/

# Reinitialize iOS project
cargo tauri ios init

# Check CocoaPods
cd gen/apple
pod install --verbose
```

**Solutions**:
```bash
# Clean and rebuild
rm -rf gen/apple/
cargo tauri ios init

# Update Tauri CLI
cargo install tauri-cli@2.0.0 --force

# Check iOS configuration
cat tauri.ios.conf.json | python3 -m json.tool
```

## Code Signing Issues

### Issue: Code Signing Certificate Not Found
**Symptoms**: `No signing certificate found` or `Code signing failed`

**Diagnosis**:
```bash
# List available certificates
security find-identity -v -p codesigning

# Check provisioning profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```

**Solutions**:
```bash
# Import certificate (if needed)
security import /path/to/certificate.p12 -k ~/Library/Keychains/login.keychain -P <password>

# Set default keychain
security default-keychain -s ~/Library/Keychains/login.keychain

# Verify certificate
security find-identity -v -p codesigning
```

### Issue: Provisioning Profile Issues
**Symptoms**: `Provisioning profile doesn't match bundle identifier`

**Solutions**:
```bash
# Check bundle identifier
grep -A1 "CFBundleIdentifier" src-tauri/gen/apple/Info.plist

# Update provisioning profile
cp /path/to/profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

# Rescan provisioning profiles
xcrun simctl list devices
```

## Performance Problems

### Issue: Slow Build Times
**Symptoms**: Builds taking longer than expected (>10 minutes)

**Diagnosis**:
```bash
# Measure build performance
./scripts/measure-build-performance.sh measure

# Check system resources
top -l 1 | head -10

# Check disk space
df -h
```

**Solutions**:
```bash
# Pre-warm dependencies
./scripts/pre-warm-deps.sh

# Clean build cache
cargo clean

# Optimize build settings
export RUSTC_WRAPPER=sccache  # if sccache is installed
export CARGO_INCREMENTAL=1
```

### Issue: Memory Issues During Build
**Symptoms**: Build fails with out-of-memory errors

**Solutions**:
```bash
# Limit parallel jobs
export CARGO_BUILD_JOBS=2

# Use less memory-intensive settings
export RUSTFLAGS="-C opt-level=0"

# Close other applications
# Add more RAM or use machine with more memory
```

## CI/CD Issues

### Issue: GitHub Actions Build Fails
**Symptoms**: CI/CD pipeline fails on iOS build step

**Diagnosis**:
```bash
# Check workflow syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ios-release-enhanced.yml'))"

# Check secrets configuration
gh secret list
```

**Solutions**:
```bash
# Update workflow with enhanced version
cp .github/workflows/ios-release-enhanced.yml .github/workflows/ios-release.yml

# Add missing secrets
gh secret set APP_STORE_CONNECT_API_KEY_ID --body "your-key-id"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "your-issuer-id"
gh secret set APP_STORE_CONNECT_API_PRIVATE_KEY --body "your-private-key"

# Test workflow locally
act -j build-ios
```

### Issue: Xcode Cloud Build Fails
**Symptoms**: Xcode Cloud builds fail with configuration errors

**Solutions**:
```bash
# Run Xcode Cloud setup
./scripts/setup-xcode-cloud.sh

# Check Xcode Cloud configuration
cat .xcodecloud/ci_cd.xcconfig

# Update workflow
cat .xcodecloud/workflows/ios-build.yml
```

## Advanced Troubleshooting

### Issue: Intermittent Build Failures
**Symptoms**: Builds sometimes pass, sometimes fail

**Diagnosis**:
```bash
# Run multiple builds and check patterns
for i in {1..5}; do
    echo "Build attempt $i:"
    ./scripts/build-with-error-handling.sh --debug
    echo "---"
done

# Check system logs
console | tail -50
```

**Solutions**:
```bash
# Check for race conditions
export CARGO_BUILD_JOBS=1

# Use stable Rust toolchain
rustup default stable

# Check for hardware issues
system_profiler SPHardwareDataType
```

### Issue: Dependency Conflicts
**Symptoms**: Build fails with dependency version conflicts

**Diagnosis**:
```bash
# Check dependency tree
cd src-tauri
cargo tree | grep -E "(red|yellow)"

# Check for duplicate dependencies
cargo tree --duplicate

# Check for outdated dependencies
cargo outdated
```

**Solutions**:
```bash
# Update specific dependencies
cargo update some_crate

# Use exact versions
cargo update --precise some_crate@1.2.3

# Clean and rebuild
cargo clean
cargo build
```

## Getting Help

### Automated Diagnosis
Run the automated diagnosis script:
```bash
./scripts/test-ios-build.sh all
```

### Manual Information Collection
If you need to request help, collect this information:

```bash
# System information
uname -a > system-info.txt
sw_vers >> system-info.txt
xcodebuild -version >> system-info.txt

# Tool versions
rustc --version >> system-info.txt
cargo --version >> system-info.txt
bun --version >> system-info.txt
pod --version >> system-info.txt

# Build logs
cat logs/ios-build-*.log >> system-info.txt
cat logs/ios-errors-*.log >> system-info.txt

# Project state
git status >> system-info.txt
git log --oneline -5 >> system-info.txt
```

### Common Commands Reference

| Purpose | Command |
|---------|---------|
| Validate environment | `./scripts/validate-ios-env.sh` |
| Pre-warm dependencies | `./scripts/pre-warm-deps.sh` |
| iOS development | `./scripts/ios-dev.sh` |
| Build with error handling | `./scripts/build-with-error-handling.sh` |
| Measure performance | `./scripts/measure-build-performance.sh` |
| Run tests | `./scripts/test-ios-build.sh` |
| Setup Xcode Cloud | `./scripts/setup-xcode-cloud.sh` |

## Prevention Tips

1. **Regular Updates**: Keep Rust, Bun, Xcode, and CocoaPods updated
2. **Clean Builds**: Regularly clean build directories to prevent corruption
3. **Monitor Performance**: Use performance monitoring to detect regressions
4. **Test Changes**: Run tests after making changes to build configuration
5. **Backup Configuration**: Keep backups of working configurations
6. **Document Issues**: Track recurring issues and their solutions

---

**Still having issues?** 

1. Check the [GitHub Issues](https://github.com/your-repo/issues) for known problems
2. Run the automated test suite for detailed diagnosis
3. Collect system information using the commands above
4. Create a new issue with all collected information

---

*This guide is maintained as part of the iOS Build Reliability Implementation Plan*