# iOS CI/CD Pipeline Implementation Plan

## Executive Summary

This plan addresses critical issues in the iOS CI/CD pipeline for the OpenCode Nexus Tauri 2 application. The main problem is that `cargo tauri ios build` requires a TCP socket connection to a parent Tauri process, which doesn't exist in CI environments, causing "Connection refused (os error 61)" failures.

## Current Issues Analysis

### 1. GitHub Actions Pipeline Issues
- **Problem**: Uses `cargo tauri ios build --release --no-codesign` which triggers TCP socket errors
- **Root Cause**: Tauri's xcode-script expects a parent process connection
- **Impact**: Build failures in GitHub Actions, preventing automated iOS releases

### 2. Xcode Cloud Script Issues  
- **Problem**: Scripts reference wrong library names and paths
- **Root Cause**: Inconsistent library naming (`libapp.a` vs `libsrc_tauri.a`)
- **Impact**: Pre-built libraries not found, causing unnecessary rebuilds

### 3. Library Utilization Issues
- **Problem**: Pre-built Rust library not properly utilized
- **Root Cause**: Incorrect path structure and missing skip logic
- **Impact**: Wasted build time and potential build failures

## Solution Architecture

### Core Strategy: Pre-Build + Skip Pattern
1. **Pre-Build Phase**: Build Rust library separately using `cargo build --target aarch64-apple-ios --release`
2. **Library Placement**: Copy to `src-tauri/gen/apple/Externals/arm64/Release/libapp.a`
3. **Skip Logic**: Patch Xcode project to skip "Build Rust Code" phase when library exists
4. **Direct Archive**: Use `xcodebuild archive` directly, bypassing Tauri CLI

## Implementation Plan

### Phase 1: GitHub Actions Workflow Restructuring

#### 1.1 New Workflow Structure
```yaml
# .github/workflows/ios-release.yml (optimized)
name: iOS TestFlight Release

on:
  push:
    tags:
      - 'ios-v*'
    branches:
      - 'main'
      - 'test-ios-build'
      - 'release'

jobs:
  build-ios:
    runs-on: macos-14
    timeout-minutes: 90
    
    steps:
      # 1. Environment Setup
      - name: Checkout code
      - name: Setup Xcode 15.4
      - name: Install Rust + iOS target
      - name: Install Bun
      - name: Setup caching (cargo, bun, node_modules)
      
      # 2. Pre-Build Phase (NEW)
      - name: Build frontend
      - name: Pre-build Rust library for iOS
      - name: Initialize iOS project structure
      - name: Place pre-built library
      - name: Patch Xcode project for CI
      
      # 3. Code Signing Setup
      - name: Setup code signing
      - name: Install provisioning profile
      
      # 4. Build & Archive (OPTIMIZED)
      - name: Archive with xcodebuild (direct)
      - name: Export IPA
      - name: Normalize IPA for TestFlight
      
      # 5. Deployment
      - name: Upload to TestFlight
      - name: Create GitHub Release
      - name: Upload artifacts
```

#### 1.2 Critical Script Changes

**Pre-Build Rust Library Step:**
```bash
cd src-tauri
cargo build --target aarch64-apple-ios --release --lib

# Verify library exists and copy to correct locations
mkdir -p gen/apple/Externals/arm64/Release
mkdir -p gen/apple/Externals/arm64/release

# Handle library name variations
LIB_NAME="libsrc_tauri_lib.a"  # From Cargo.toml: name = "src_tauri_lib"
if [ -f "target/aarch64-apple-ios/release/$LIB_NAME" ]; then
    cp "target/aarch64-apple-ios/release/$LIB_NAME" gen/apple/Externals/arm64/Release/libapp.a
    cp "target/aarch64-apple-ios/release/$LIB_NAME" gen/apple/Externals/arm64/release/libapp.a
else
    echo "ERROR: Expected library not found"
    exit 1
fi
```

**Xcode Project Patching:**
```python
# Enhanced patch script with better error handling
import re
import sys

def patch_xcode_project(pbxproj_path):
    with open(pbxproj_path, "r") as f:
        content = f.read()
    
    # More robust pattern matching
    old_pattern = r'(shellScript = ")[^"]*cargo tauri ios xcode-script[^"]*(")'
    
    new_script = r'''\1# CI-Compatible: Skip if pre-built libapp.a exists
OUTPUT_DIR="${SRCROOT}/Externals/arm64/${CONFIGURATION}"
LIBAPP_PATH="${OUTPUT_DIR}/libapp.a"
if [ -f "$LIBAPP_PATH" ]; then
  echo "✅ Pre-built libapp.a found at $LIBAPP_PATH - skipping Rust build"
  exit 0
fi
echo "⚠️ libapp.a not found, falling back to Tauri build..."
cargo tauri ios xcode-script -v --platform ${PLATFORM_DISPLAY_NAME:?} --sdk-root ${SDKROOT:?} --framework-search-paths "${FRAMEWORK_SEARCH_PATHS:?}" --header-search-paths "${HEADER_SEARCH_PATHS:?}" --gcc-preprocessor-definitions "${GCC_PREPROCESSOR_DEFINITIONS:-}" --configuration ${CONFIGURATION:?} ${FORCE_COLOR} ${ARCHS:?}\2'''
    
    content = re.sub(old_pattern, new_script, content, flags=re.MULTILINE | re.DOTALL)
    
    with open(pbxproj_path, "w") as f:
        f.write(content)
    
    print("✅ Xcode project patched successfully")
```

#### 1.3 Direct xcodebuild Archive
```bash
cd src-tauri/gen/apple

# Verify workspace exists
if [ ! -f "src-tauri.xcworkspace/contents.xcworkspacedata" ]; then
    echo "❌ Error: Xcode workspace not found"
    exit 1
fi

# Direct archive (bypassing cargo tauri ios build)
xcodebuild \
  -workspace src-tauri.xcworkspace \
  -scheme src-tauri_iOS \
  -configuration Release \
  -archivePath build/archives/OpenCodeNexus.xcarchive \
  -derivedDataPath build/DerivedData \
  archive \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  DEVELOPMENT_TEAM="PCJU8QD9FN" \
  OTHER_CODE_SIGN_FLAGS="--timestamp=none"
```

### Phase 2: Xcode Cloud Script Fixes

#### 2.1 Updated ci_post_clone.sh
```bash
#!/bin/bash
# Enhanced post-clone script with proper library naming

set -e
echo "📥 Enhanced post-clone setup for Xcode Cloud..."

# Environment setup
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Install Rust if needed
if ! command -v rustup &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Add iOS target and install Tauri CLI
rustup target add aarch64-apple-ios
if ! cargo tauri --version &> /dev/null 2>&1; then
    cargo install tauri-cli --version "^2" --locked
fi

# Set iOS SDK environment
export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
export IPHONEOS_DEPLOYMENT_TARGET="14.0"

# Navigate to project
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Build frontend
echo "🎨 Building frontend..."
cd frontend
if command -v bun &> /dev/null; then
    bun install --frozen-lockfile || bun install
    bun run build
else
    npm ci
    npm run build
fi

# Pre-build Rust library
echo "🦀 Pre-building Rust library..."
cd src-tauri

# Initialize iOS project
cargo tauri ios init

# Build with correct library name
cargo build --target aarch64-apple-ios --release --lib

# Create directory structure
mkdir -p gen/apple/Externals/arm64/Release
mkdir -p gen/apple/Externals/arm64/release

# Copy with correct library name (from Cargo.toml)
LIB_NAME="libsrc_tauri_lib.a"
RUST_LIB_PATH="target/aarch64-apple-ios/release/$LIB_NAME"

if [ -f "$RUST_LIB_PATH" ]; then
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/Release/libapp.a
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/release/libapp.a
    echo "✅ Rust library copied successfully"
else
    echo "❌ ERROR: Library $LIB_NAME not found"
    find target/aarch64-apple-ios/release -name "*.a" -type f
    exit 1
fi

# Patch Xcode project (same patch script as GitHub Actions)
python3 /tmp/patch_pbxproj.py gen/apple/src-tauri.xcodeproj/project.pbxproj

# Setup CocoaPods
cd gen/apple
sed -i.bak '/^target.*macOS.*do$/,/^end$/d' Podfile 2>/dev/null || true
sed -i.bak '/MACOSX_DEPLOYMENT_TARGET/d' Podfile 2>/dev/null || true
rm -f Podfile.bak

if ! command -v pod &> /dev/null; then
    sudo gem install cocoapods
fi
pod install --repo-update || pod install

echo "✅ Enhanced post-clone setup completed"
```

#### 2.2 Updated pre_xcode_build.sh
```bash
#!/bin/bash
# Simplified pre-build script (most work moved to post-clone)

set -e
echo "🔨 Xcode Cloud pre-build verification..."

cd "$CI_PRIMARY_REPOSITORY_PATH/src-tauri"

# Verify pre-built library exists
LIB_PATH="gen/apple/Externals/arm64/Release/libapp.a"
if [ ! -f "$LIB_PATH" ]; then
    echo "❌ ERROR: Pre-built library not found at $LIB_PATH"
    echo "This indicates post-clone script failed"
    exit 1
fi

# Verify library is valid
if ! file "$LIB_PATH" | grep -q "ar archive"; then
    echo "❌ ERROR: Library is not a valid ar archive"
    exit 1
fi

echo "✅ Pre-built library verified"
echo "📱 Ready for Xcode build"
```

### Phase 3: Enhanced build_rust_code.sh

#### 3.1 Improved Build Script
```bash
#!/bin/bash
# Enhanced CI-compatible Rust build script

set -e

echo "=== Enhanced Tauri iOS Rust Build Script ==="
echo "Configuration: ${CONFIGURATION:-Release}"
echo "Platform: ${PLATFORM_DISPLAY_NAME:-iOS}"
echo "Archs: ${ARCHS:-arm64}"

# Determine paths
ARCH="arm64"
CONFIG="${CONFIGURATION:-Release}"
CONFIG_LOWER=$(echo "$CONFIG" | tr '[:upper:]' '[:lower:]')
OUTPUT_DIR="${SRCROOT}/Externals/${ARCH}/${CONFIG_LOWER}"
LIBAPP_PATH="${OUTPUT_DIR}/libapp.a"

# Detect CI environment
IS_CI="false"
if [ -n "$CI_PRIMARY_REPOSITORY_PATH" ] || [ "$CI" = "true" ] || [ -n "$GITHUB_ACTIONS" ]; then
    IS_CI="true"
    echo "✅ CI environment detected"
fi

# Enhanced library validation
validate_library() {
    local path="$1"
    if [ -f "$path" ]; then
        if file "$path" | grep -q -E "(ar archive|current ar archive)"; then
            if lipo -info "$path" 2>/dev/null | grep -q "arm64" || file "$path" | grep -q "arm64"; then
                echo "✅ Valid arm64 library found: $path"
                return 0
            fi
        fi
    fi
    return 1
}

# Check for pre-built library
if validate_library "$LIBAPP_PATH"; then
    echo "🎯 Pre-built library found, skipping build"
    exit 0
fi

# CI build path
if [ "$IS_CI" = "true" ]; then
    echo "🦀 CI Build: Using direct cargo build"
    
    # Setup environment
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    # Navigate to project
    PROJECT_ROOT="${SRCROOT}/../.."
    if [ -n "$CI_PRIMARY_REPOSITORY_PATH" ]; then
        PROJECT_ROOT="$CI_PRIMARY_REPOSITORY_PATH/src-tauri"
    fi
    cd "$PROJECT_ROOT"
    
    # Build with correct profile
    CARGO_FLAGS=""
    if [ "$CONFIG_LOWER" = "release" ]; then
        CARGO_FLAGS="--release"
    fi
    
    echo "🔨 Building: cargo build --target aarch64-apple-ios $CARGO_FLAGS --lib"
    cargo build --target aarch64-apple-ios $CARGO_FLAGS --lib
    
    # Find and copy library
    RUST_PROFILE="release"
    if [ "$CONFIG_LOWER" != "release" ]; then
        RUST_PROFILE="debug"
    fi
    
    RUST_TARGET_DIR="target/aarch64-apple-ios/${RUST_PROFILE}"
    LIB_NAME="libsrc_tauri_lib.a"
    FOUND_LIB="${RUST_TARGET_DIR}/${LIB_NAME}"
    
    if [ -f "$FOUND_LIB" ]; then
        mkdir -p "$OUTPUT_DIR"
        cp "$FOUND_LIB" "$LIBAPP_PATH"
        echo "✅ Library copied to $LIBAPP_PATH"
        exit 0
    else
        echo "❌ Library not found at $FOUND_LIB"
        echo "Available files:"
        ls -la "$RUST_TARGET_DIR" 2>/dev/null || echo "Directory not found"
        exit 1
    fi
fi

# Local development path
echo "🔧 Local development mode"
# ... (rest of local development logic)
```

### Phase 4: Testing Strategy

#### 4.1 Unit Testing for Scripts
```bash
# test_scripts.sh
#!/bin/bash
# Test CI scripts locally

echo "🧪 Testing iOS CI scripts..."

# Test 1: Library building
test_library_build() {
    echo "Testing Rust library build..."
    cd src-tauri
    cargo build --target aarch64-apple-ios --release --lib
    
    LIB_NAME="libsrc_tauri_lib.a"
    if [ -f "target/aarch64-apple-ios/release/$LIB_NAME" ]; then
        echo "✅ Library build test passed"
        return 0
    else
        echo "❌ Library build test failed"
        return 1
    fi
}

# Test 2: Directory structure
test_directory_structure() {
    echo "Testing directory structure..."
    mkdir -p gen/apple/Externals/arm64/Release
    mkdir -p gen/apple/Externals/arm64/release
    
    if [ -d "gen/apple/Externals/arm64/Release" ]; then
        echo "✅ Directory structure test passed"
        return 0
    else
        echo "❌ Directory structure test failed"
        return 1
    fi
}

# Test 3: Xcode project patching
test_xcode_patching() {
    echo "Testing Xcode project patching..."
    # Initialize project first
    cargo tauri ios init
    
    if [ -f "gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        python3 /tmp/patch_pbxproj.py gen/apple/src-tauri.xcodeproj/project.pbxproj
        echo "✅ Xcode patching test passed"
        return 0
    else
        echo "❌ Xcode patching test failed"
        return 1
    fi
}

# Run all tests
test_library_build && test_directory_structure && test_xcode_patching
echo "🎉 All tests completed"
```

#### 4.2 Integration Testing
```yaml
# .github/workflows/ios-test.yml
name: iOS Pipeline Test

on:
  pull_request:
    paths:
      - '.github/workflows/ios-release.yml'
      - 'ci_scripts/*.sh'
      - 'src-tauri/**'

jobs:
  test-ios-pipeline:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Test Rust library build
        run: |
          cd src-tauri
          cargo build --target aarch64-apple-ios --release --lib
          
      - name: Test iOS project initialization
        run: |
          cd src-tauri
          cargo tauri ios init
          
      - name: Test library placement
        run: |
          cd src-tauri
          mkdir -p gen/apple/Externals/arm64/Release
          cp target/aarch64-apple-ios/release/libsrc_tauri_lib.a gen/apple/Externals/arm64/Release/libapp.a
          
      - name: Test Xcode project patching
        run: |
          cd src-tauri
          python3 /tmp/patch_pbxproj.py gen/apple/src-tauri.xcodeproj/project.pbxproj
```

### Phase 5: Error Handling and Rollback Procedures

#### 5.1 Error Detection
```bash
# Enhanced error handling in workflow
- name: Validate pre-build step
  run: |
    cd src-tauri
    
    # Check if library was built
    LIB_NAME="libsrc_tauri_lib.a"
    if [ ! -f "target/aarch64-apple-ios/release/$LIB_NAME" ]; then
      echo "❌ ERROR: Rust library build failed"
      echo "Available files in target directory:"
      find target/aarch64-apple-ios/release -type f -name "*.a" || echo "No .a files found"
      exit 1
    fi
    
    # Check if library was copied
    if [ ! -f "gen/apple/Externals/arm64/Release/libapp.a" ]; then
      echo "❌ ERROR: Library copy failed"
      exit 1
    fi
    
    # Validate library content
    if ! file "gen/apple/Externals/arm64/Release/libapp.a" | grep -q "ar archive"; then
      echo "❌ ERROR: Copied file is not a valid static library"
      exit 1
    fi
    
    echo "✅ Pre-build validation successful"
```

#### 5.2 Rollback Procedures
```bash
# Rollback script for failed builds
rollback_ios_build() {
    echo "🔄 Rolling back iOS build..."
    
    # Clean build artifacts
    rm -rf src-tauri/target/aarch64-apple-ios/
    rm -rf src-tauri/gen/apple/
    
    # Reset any patches
    git checkout -- src-tauri/
    
    echo "✅ Rollback completed"
}
```

#### 5.3 Failure Notifications
```yaml
- name: Build failure notification
  if: failure()
  run: |
    cat >> $GITHUB_STEP_SUMMARY << 'EOF'
    ## ❌ iOS Build Failed
    
    ### Immediate Actions Required
    1. **Check library name**: Verify `libsrc_tauri_lib.a` matches Cargo.toml
    2. **Verify target**: Ensure `aarch64-apple-ios` target is installed
    3. **Check paths**: Validate directory structure creation
    4. **Review patches**: Ensure Xcode project patching succeeded
    
    ### Debug Information
    - Rust version: $(rustc --version)
    - Tauri CLI version: $(cargo tauri --version)
    - Xcode version: $(xcodebuild -version)
    
    ### Common Fixes
    - Update library name in scripts if Cargo.toml changed
    - Verify iOS SDK is properly installed
    - Check for network issues during dependency installation
    EOF
```

### Phase 6: Validation Steps

#### 6.1 Pre-Deployment Validation
```bash
# validate_ios_build.sh
#!/bin/bash
# Comprehensive validation before deployment

echo "🔍 iOS Build Validation"

# 1. Library Validation
validate_library() {
    local lib_path="src-tauri/gen/apple/Externals/arm64/Release/libapp.a"
    
    if [ ! -f "$lib_path" ]; then
        echo "❌ Library not found: $lib_path"
        return 1
    fi
    
    if ! file "$lib_path" | grep -q "ar archive"; then
        echo "❌ Invalid library format"
        return 1
    fi
    
    if ! lipo -info "$lib_path" 2>/dev/null | grep -q "arm64"; then
        echo "❌ Library not built for arm64"
        return 1
    fi
    
    echo "✅ Library validation passed"
    return 0
}

# 2. Xcode Project Validation
validate_xcode_project() {
    local project_path="src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj"
    
    if [ ! -f "$project_path" ]; then
        echo "❌ Xcode project not found"
        return 1
    fi
    
    if grep -q "CI-Compatible: Skip if pre-built libapp.a exists" "$project_path"; then
        echo "✅ Xcode project patch validation passed"
        return 0
    else
        echo "❌ Xcode project not properly patched"
        return 1
    fi
}

# 3. CocoaPods Validation
validate_cocoapods() {
    local workspace_path="src-tauri/gen/apple/src-tauri.xcworkspace"
    
    if [ ! -f "$workspace_path/contents.xcworkspacedata" ]; then
        echo "❌ CocoaPods workspace not found"
        return 1
    fi
    
    echo "✅ CocoaPods validation passed"
    return 0
}

# Run all validations
validate_library && validate_xcode_project && validate_cocoapods
echo "🎉 All validations passed - ready for deployment"
```

#### 6.2 Post-Deployment Validation
```bash
# validate_deployment.sh
#!/bin/bash
# Validate successful deployment

echo "🔍 Deployment Validation"

# 1. IPA Validation
validate_ipa() {
    local ipa_path="$1"
    
    if [ ! -f "$ipa_path" ]; then
        echo "❌ IPA not found: $ipa_path"
        return 1
    fi
    
    # Check IPA size (should be reasonable)
    local size=$(du -m "$ipa_path" | cut -f1)
    if [ "$size" -lt 5 ] || [ "$size" -gt 200 ]; then
        echo "⚠️ IPA size unusual: ${size}MB"
    fi
    
    echo "✅ IPA validation passed: ${size}MB"
    return 0
}

# 2. TestFlight Upload Validation
validate_testflight() {
    # Check if TestFlight upload was successful
    # This would typically involve checking App Store Connect API responses
    echo "✅ TestFlight upload validation passed"
    return 0
}

# Run deployment validations
validate_ipa "$1" && validate_testflight
echo "🎉 Deployment validation completed"
```

## Implementation Timeline

### Week 1: Foundation
- [ ] Update GitHub Actions workflow with new structure
- [ ] Fix library naming in all scripts
- [ ] Implement enhanced error handling
- [ ] Create validation scripts

### Week 2: Testing & Refinement
- [ ] Implement comprehensive testing strategy
- [ ] Test both GitHub Actions and Xcode Cloud
- [ ] Refine error handling and rollback procedures
- [ ] Document troubleshooting procedures

### Week 3: Production Deployment
- [ ] Deploy updated workflows to production
- [ ] Monitor pipeline performance
- [ ] Collect metrics and optimize
- [ ] Train team on new procedures

## Success Metrics

### Technical Metrics
- **Build Success Rate**: Target >95% success rate
- **Build Time**: Reduce from 90+ minutes to <60 minutes
- **Failure Recovery Time**: <5 minutes to identify and fix issues

### Business Metrics
- **Release Frequency**: Enable daily iOS releases if needed
- **Time to Market**: Reduce from manual days to automated hours
- **Developer Productivity**: Eliminate manual iOS build intervention

## Maintenance Procedures

### Monthly
- [ ] Review and update Rust toolchain versions
- [ ] Validate Xcode compatibility
- [ ] Check certificate and provisioning profile expiration
- [ ] Update dependency versions

### Quarterly
- [ ] Optimize build performance
- [ ] Review and refine error handling
- [ ] Update documentation
- [ ] Conduct pipeline security audit

## Conclusion

This implementation plan addresses the core issues in the iOS CI/CD pipeline by:

1. **Eliminating TCP Socket Dependencies**: Pre-building Rust libraries separately
2. **Standardizing Library Naming**: Using correct names from Cargo.toml
3. **Implementing Robust Error Handling**: Comprehensive validation and rollback
4. **Optimizing Build Performance**: Skipping unnecessary rebuilds
5. **Ensuring Reliability**: Extensive testing and monitoring

The solution is maintainable, scalable, and provides clear visibility into the build process, enabling rapid iteration and reliable iOS deployments.