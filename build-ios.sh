#!/bin/bash
# iOS Build Script for OpenCode Nexus
# Optimized for reliable TestFlight builds

set -e

echo "🚀 OpenCode Nexus iOS Build Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Start timing
START_TIME=$(date +%s)
print_status "Build started at $(date)"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode command line tools not found. Please install Xcode."
    exit 1
fi

# Check Rust
if ! command -v cargo &> /dev/null; then
    print_error "Cargo not found. Please install Rust."
    exit 1
fi

# Check Bun
if ! command -v bun &> /dev/null; then
    print_error "Bun not found. Please install Bun."
    exit 1
fi

print_success "Prerequisites check passed"

# Ensure iOS targets are installed
print_status "Ensuring iOS targets are installed..."
rustup target add aarch64-apple-ios 2>/dev/null || true
rustup target add aarch64-apple-ios-sim 2>/dev/null || true
rustup target add x86_64-apple-ios 2>/dev/null || true

# Set iOS-specific environment variables
export IPHONEOS_DEPLOYMENT_TARGET=14.0
export CFLAGS="-miphoneos-version-min=14.0"
export CXXFLAGS="-miphoneos-version-min=14.0"
export RUST_BACKTRACE=0

# Pre-warm dependencies
print_status "Pre-warming Rust dependencies..."
cd src-tauri
cargo fetch --target aarch64-apple-ios
cargo check --target aarch64-apple-ios
cd ..
print_success "Dependencies pre-warmed"

# Build frontend
print_status "Building frontend..."
cd frontend
bun install --frozen-lockfile
bun run build
cd ..
print_success "Frontend built"

# Build iOS app
print_status "Building iOS app..."
cd src-tauri

# Time the Rust build
RUST_START_TIME=$(date +%s)
print_status "Compiling Rust code for iOS..."
cargo build --target aarch64-apple-ios --release
RUST_BUILD_TIME=$(($(date +%s) - RUST_START_TIME))
print_success "Rust compilation completed in ${RUST_BUILD_TIME}s"

# Time the Tauri iOS build
TAURI_START_TIME=$(date +%s)
print_status "Running Tauri iOS build process..."
cargo tauri ios build --release
TAURI_BUILD_TIME=$(($(date +%s) - TAURI_START_TIME))
print_success "Tauri iOS build completed in ${TAURI_BUILD_TIME}s"

cd ..
TOTAL_TIME=$(($(date +%s) - START_TIME))

print_success "iOS build completed successfully in ${TOTAL_TIME}s!"
echo ""
echo "📊 Build Timing Summary:"
echo "  - Total time: ${TOTAL_TIME}s"
echo "  - Rust compilation: ${RUST_BUILD_TIME}s"
echo "  - Tauri + Xcode: ${TAURI_BUILD_TIME}s"
echo ""

# Check if Xcode project and workspace were generated
if [ -d "src-tauri/gen/apple/src-tauri.xcodeproj" ] && [ -f "src-tauri/gen/apple/src-tauri.xcworkspace/contents.xcworkspacedata" ]; then
    print_success "Xcode project and workspace generated successfully"
    echo ""
    echo "🍎 Next Steps for TestFlight:"
    echo "  1. Open Xcode workspace (recommended):"
    echo "     open src-tauri/gen/apple/src-tauri.xcworkspace"
    echo "     OR open project:"
    echo "     open src-tauri/gen/apple/src-tauri.xcodeproj"
    echo ""
    echo "  2. In Xcode:"
    echo "     - Select 'src-tauri_iOS' scheme"
    echo "     - Set target to 'Any iOS Device'"
    echo "     - Go to Project Settings → Signing & Capabilities"
    echo "     - Set your Apple Developer Team"
    echo "     - Verify bundle identifier: com.agentic-codeflow.opencode-nexus"
    echo ""
    echo "  3. Build and Archive:"
    echo "     - Product → Archive"
    echo "     - Wait for archive to complete"
    echo ""
    echo "  4. Distribute to TestFlight:"
    echo "     - In Organizer window, select the archive"
    echo "     - Click 'Distribute App' → 'App Store Connect'"
    echo "     - Follow the prompts to upload to TestFlight"
    echo ""
    echo "  5. Monitor upload:"
    echo "     - Check App Store Connect → TestFlight"
    echo "     - Build should appear within 5-10 minutes"
    echo ""
else
    if [ ! -d "src-tauri/gen/apple/src-tauri.xcodeproj" ]; then
        print_error "Xcode project was not generated."
    fi
    if [ ! -f "src-tauri/gen/apple/src-tauri.xcworkspace/contents.xcworkspacedata" ]; then
        print_error "Xcode workspace was not generated."
    fi
    echo "Check the build logs above for errors."
    exit 1
fi

print_success "Build script completed successfully!"