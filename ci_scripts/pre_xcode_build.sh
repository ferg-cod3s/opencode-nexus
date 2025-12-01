#!/bin/bash
# Xcode Cloud Pre-Build Script
# Runs before Xcode builds the iOS app
#
# This script initializes the Tauri iOS project and pre-builds the Rust library
# so that the Xcode "Build Rust Code" phase can skip the rebuild.

set -e

echo "🔨 Starting Xcode Cloud pre-build setup..."

# Navigate to the project root
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

# Verify Rust toolchain is available (should be installed in post_clone)
if ! command -v rustup &> /dev/null; then
    echo "❌ Error: rustup not found. Please ensure Rust is installed."
    exit 1
fi

if ! command -v cargo &> /dev/null; then
    echo "❌ Error: cargo not found. Please ensure Rust is installed."
    exit 1
fi

# Ensure Tauri CLI is available
if ! cargo tauri --version &> /dev/null; then
    echo "📦 Installing Tauri CLI..."
    cargo install tauri-cli --version "^2" --locked
fi

# Add iOS target
echo "📦 Adding Rust iOS target..."
rustup target add aarch64-apple-ios

# Navigate to src-tauri
cd src-tauri || exit 1

# Build the frontend first (if needed)
if [ -d "../frontend" ]; then
    echo "🎨 Building frontend..."
    cd ../frontend
    if command -v bun &> /dev/null; then
        bun install --frozen-lockfile 2>/dev/null || bun install
        bun run build
    elif command -v npm &> /dev/null; then
        npm ci
        npm run build
    fi
    cd ../src-tauri
fi

# Pre-build Rust library for iOS
echo "🦀 Pre-building Rust library for iOS..."
cargo build --target aarch64-apple-ios --release

# Initialize Tauri iOS project
echo "🔧 Initializing iOS Tauri workspace..."
cargo tauri ios init

# Create Externals directories
mkdir -p gen/apple/Externals/arm64/Release
mkdir -p gen/apple/Externals/arm64/release

# Copy pre-built libapp.a to where Xcode expects it
if [ -f "target/aarch64-apple-ios/release/libapp.a" ]; then
    cp target/aarch64-apple-ios/release/libapp.a gen/apple/Externals/arm64/Release/libapp.a
    cp target/aarch64-apple-ios/release/libapp.a gen/apple/Externals/arm64/release/libapp.a
    echo "✅ Copied pre-built libapp.a to Externals"
else
    echo "❌ ERROR: libapp.a not found after build"
    exit 1
fi

# Patch the Xcode project to skip Rust build phase when libapp.a exists
echo "🔧 Patching Xcode project for CI compatibility..."
cat > /tmp/patch_pbxproj.py << 'PYEOF'
import re
import sys

pbxproj_path = sys.argv[1]

with open(pbxproj_path, "r") as f:
    content = f.read()

# Find the shellScript line for "Build Rust Code" phase and replace it
old_pattern = r'(shellScript = ")cargo tauri ios xcode-script[^"]*(")'

# CI-compatible script that checks for pre-built library first
new_script = r'''\1# CI-Compatible: Skip if pre-built libapp.a exists
OUTPUT_DIR="${SRCROOT}/Externals/arm64/${CONFIGURATION}"
LIBAPP_PATH="${OUTPUT_DIR}/libapp.a"
if [ -f "$LIBAPP_PATH" ]; then
  echo "Pre-built libapp.a found at $LIBAPP_PATH - skipping Rust build"
  exit 0
fi
echo "libapp.a not found, running Tauri build..."
cargo tauri ios xcode-script -v --platform ${PLATFORM_DISPLAY_NAME:?} --sdk-root ${SDKROOT:?} --framework-search-paths "${FRAMEWORK_SEARCH_PATHS:?}" --header-search-paths "${HEADER_SEARCH_PATHS:?}" --gcc-preprocessor-definitions "${GCC_PREPROCESSOR_DEFINITIONS:-}" --configuration ${CONFIGURATION:?} ${FORCE_COLOR} ${ARCHS:?}\2'''

content = re.sub(old_pattern, new_script, content)

with open(pbxproj_path, "w") as f:
    f.write(content)

print("Updated project.pbxproj with CI-compatible build script")
PYEOF

python3 /tmp/patch_pbxproj.py gen/apple/src-tauri.xcodeproj/project.pbxproj

# Copy ExportOptions.plist if available
if [ -f "ios-config/ExportOptions.plist" ]; then
    cp ios-config/ExportOptions.plist gen/apple/ExportOptions.plist
    echo "✅ ExportOptions.plist copied"
fi

# Setup CocoaPods
echo "📦 Installing CocoaPods dependencies..."
cd gen/apple || exit 1

# Remove macOS target from Podfile
if [ -f "Podfile" ]; then
    sed -i.bak '/target.*macOS/,/^end$/d' Podfile 2>/dev/null || true
    sed -i.bak '/MACOSX_DEPLOYMENT_TARGET/d' Podfile 2>/dev/null || true
    rm -f Podfile.bak
fi

# Install pods
if ! command -v pod &> /dev/null; then
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
fi
pod install --repo-update || pod install

echo "✅ Xcode Cloud pre-build setup completed successfully"
echo "📱 Ready for Xcode to build the iOS app"
