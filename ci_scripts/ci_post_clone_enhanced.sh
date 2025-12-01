#!/bin/bash
# Enhanced Xcode Cloud Post-Clone Script
# Runs after repository is cloned, before Xcode builds
#
# CRITICAL: This script pre-builds the Rust library so Xcode's "Build Rust Code"
# script phase can be skipped. This avoids the TCP socket error that occurs when
# Tauri's xcode-script tries to connect to a non-existent parent process.

set -e
echo "📥 Enhanced post-clone setup for Xcode Cloud..."

# Source cargo env if it exists
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Install Rust if not present
if ! command -v rustup &> /dev/null; then
    echo "🦀 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Add iOS target
echo "📱 Adding iOS target..."
rustup target add aarch64-apple-ios

# Install Tauri CLI
if ! cargo tauri --version &> /dev/null 2>&1; then
    echo "📦 Installing Tauri CLI..."
    cargo install tauri-cli --version "^2" --locked
fi

# Set iOS SDK environment variables for Rust cross-compilation
export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
export IPHONEOS_DEPLOYMENT_TARGET="14.0"

echo "🔧 SDK Root: $SDKROOT"
echo "🔧 Deployment Target: $IPHONEOS_DEPLOYMENT_TARGET"

# Navigate to project root
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Build frontend first (required for Tauri build)
echo "🎨 Building frontend..."
cd frontend
if command -v bun &> /dev/null; then
    bun install --frozen-lockfile || bun install
    bun run build
else
    npm ci
    npm run build
fi

# Return to src-tauri
cd "$CI_PRIMARY_REPOSITORY_PATH/src-tauri"

# Initialize iOS project (creates gen/apple directory)
echo "📱 Initializing iOS project..."
cargo tauri ios init

# PRE-BUILD THE RUST LIBRARY
# This is the critical step that allows us to skip Tauri's xcode-script
echo "🦀 Pre-building Rust library for iOS (aarch64-apple-ios)..."

# Create the Externals directory structure that Xcode expects
# Note: Xcode configuration names can be "Release" or "release" depending on context
mkdir -p gen/apple/Externals/arm64/Release
mkdir -p gen/apple/Externals/arm64/release

# Build the Rust library for iOS release with correct library name
echo "🔨 Building with library name: libsrc_tauri_lib.a"
RUST_BACKTRACE=1 cargo build \
    --target aarch64-apple-ios \
    --release \
    --lib

# Copy the built library to where Xcode expects it
LIB_NAME="libsrc_tauri_lib.a"
RUST_LIB_PATH="target/aarch64-apple-ios/release/$LIB_NAME"

if [ -f "$RUST_LIB_PATH" ]; then
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/Release/libapp.a
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/release/libapp.a
    echo "✅ Rust library copied to Externals directory"
    echo "   Source: $RUST_LIB_PATH"
    echo "   Target: gen/apple/Externals/arm64/Release/libapp.a"
    ls -la gen/apple/Externals/arm64/Release/
else
    echo "❌ ERROR: Expected library not found at $RUST_LIB_PATH"
    echo "   Available files in target directory:"
    find target/aarch64-apple-ios/release -name "*.a" -type f 2>/dev/null || echo "   No .a files found"
    exit 1
fi

# CRITICAL: Patch the Xcode project to skip Rust build when libapp.a exists
echo "🔧 Patching Xcode project for CI compatibility..."
cat > /tmp/patch_pbxproj.py << 'PYEOF'
import re
import sys

def patch_xcode_project(pbxproj_path):
    with open(pbxproj_path, "r") as f:
        content = f.read()
    
    # Find the shellScript line for "Build Rust Code" phase and replace it
    old_pattern = r'(shellScript = ")[^"]*cargo tauri ios xcode-script[^"]*(")'
    
    # CI-compatible script that checks for pre-built library first
    new_script = r'''\1# CI-Compatible: Skip if pre-built libapp.a exists
OUTPUT_DIR="${SRCROOT}/Externals/arm64/${CONFIGURATION}"
LIBAPP_PATH="${OUTPUT_DIR}/libapp.a"
if [ -f "$LIBAPP_PATH" ]; then
  echo "✅ Pre-built libapp.a found at $LIBAPP_PATH - skipping Rust build"
  exit 0
fi
echo "⚠️ libapp.a not found, running Tauri build..."
cargo tauri ios xcode-script -v --platform ${PLATFORM_DISPLAY_NAME:?} --sdk-root ${SDKROOT:?} --framework-search-paths "${FRAMEWORK_SEARCH_PATHS:?}" --header-search-paths "${HEADER_SEARCH_PATHS:?}" --gcc-preprocessor-definitions "${GCC_PREPROCESSOR_DEFINITIONS:-}" --configuration ${CONFIGURATION:?} ${FORCE_COLOR} ${ARCHS:?}\2'''
    
    content = re.sub(old_pattern, new_script, content, flags=re.MULTILINE | re.DOTALL)
    
    with open(pbxproj_path, "w") as f:
        f.write(content)
    
    print("✅ Xcode project patched successfully")
    return True

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 patch_pbxproj.py <path_to_project.pbxproj>")
        sys.exit(1)
    
    pbxproj_path = sys.argv[1]
    if patch_xcode_project(pbxproj_path):
        sys.exit(0)
    else:
        sys.exit(1)
PYEOF

python3 /tmp/patch_pbxproj.py gen/apple/src-tauri.xcodeproj/project.pbxproj

# Setup CocoaPods
echo "📦 Setting up CocoaPods..."
cd gen/apple

# Remove macOS target from Podfile (iOS only)
if [ -f "Podfile" ]; then
    sed -i.bak '/^target.*macOS.*do$/,/^end$/d' Podfile 2>/dev/null || true
    sed -i.bak '/MACOSX_DEPLOYMENT_TARGET/d' Podfile 2>/dev/null || true
    rm -f Podfile.bak
fi

# Install CocoaPods
if ! command -v pod &> /dev/null; then
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
fi
pod install --repo-update || pod install

# Copy ExportOptions.plist
if [ -f "$CI_PRIMARY_REPOSITORY_PATH/src-tauri/ios-config/ExportOptions.plist" ]; then
    cp "$CI_PRIMARY_REPOSITORY_PATH/src-tauri/ios-config/ExportOptions.plist" ExportOptions.plist
    echo "✅ ExportOptions.plist copied"
fi

# Validation step
echo "🔍 Validating setup..."
LIB_PATH="Externals/arm64/Release/libapp.a"
if [ ! -f "$LIB_PATH" ]; then
    echo "❌ ERROR: Library not found at $LIB_PATH"
    exit 1
fi

if ! file "$LIB_PATH" | grep -q "ar archive"; then
    echo "❌ ERROR: Library is not a valid ar archive"
    exit 1
fi

if ! lipo -info "$LIB_PATH" 2>/dev/null | grep -q "arm64"; then
    echo "❌ ERROR: Library not built for arm64"
    exit 1
fi

echo "✅ Enhanced post-clone setup completed"
echo "   - Rust library pre-built for iOS (libsrc_tauri_lib.a → libapp.a)"
echo "   - Xcode project patched to skip rebuild"
echo "   - CocoaPods installed"
echo "   - All validations passed"