#!/bin/bash
# iOS Development Script
# Enables iOS simulator support with hot-reload for cargo tauri dev

set -e

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

# Default values
SIMULATOR_NAME="iPhone 15"
SIMULATOR_OS="latest"
DEV_MODE="dev"
HOT_RELOAD=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --simulator)
            SIMULATOR_NAME="$2"
            shift 2
            ;;
        --os)
            SIMULATOR_OS="$2"
            shift 2
            ;;
        --release)
            DEV_MODE="release"
            shift
            ;;
        --no-hot-reload)
            HOT_RELOAD=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --simulator NAME    Simulator device name (default: iPhone 15)"
            echo "  --os VERSION       iOS version (default: latest)"
            echo "  --release          Build in release mode instead of debug"
            echo "  --no-hot-reload    Disable hot-reload"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Use defaults"
            echo "  $0 --simulator 'iPhone 14'   # Use specific simulator"
            echo "  $0 --release                 # Build in release mode"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_status "Starting iOS development with simulator..."
echo "=================================="
echo "Simulator: $SIMULATOR_NAME"
echo "iOS Version: $SIMULATOR_OS"
echo "Build Mode: $DEV_MODE"
echo "Hot Reload: $HOT_RELOAD"
echo ""

# Check prerequisites
print_status "Checking prerequisites..."

# Check if on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "iOS development requires macOS"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode not found. Please install Xcode."
    exit 1
fi

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    print_error "Cargo not found. Please install Rust."
    exit 1
fi

# Check if Tauri CLI is available
if ! cargo tauri --help &> /dev/null; then
    print_error "Tauri CLI not found. Install with: cargo install tauri-cli"
    exit 1
fi

print_success "Prerequisites check passed"

# Setup environment variables
print_status "Setting up iOS development environment..."
export IPHONEOS_DEPLOYMENT_TARGET=14.0
export CFLAGS="-miphoneos-version-min=14.0"
export CXXFLAGS="-miphoneos-version-min=14.0"
export RUST_BACKTRACE=1
export RUST_LOG=debug

# Set iOS simulator target
export TAURI_IOS_TARGET="aarch64-apple-ios-sim"

print_success "Environment configured"

# Check and create iOS simulator
print_status "Setting up iOS simulator..."

# Get available simulators
AVAILABLE_SIMULATORS=$(xcrun simctl list devices available | grep "iOS" | grep -E "iPhone|iPad" | head -10)

if [[ -z "$AVAILABLE_SIMULATORS" ]]; then
    print_error "No iOS simulators available"
    exit 1
fi

print_status "Available simulators:"
echo "$AVAILABLE_SIMULATORS"

# Find or create simulator
SIMULATOR_ID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | grep -oE '\([A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\)' | head -1)

if [[ -z "$SIMULATOR_ID" ]]; then
    print_warning "Simulator '$SIMULATOR_NAME' not found. Creating..."
    
    # Get runtime for latest iOS
    RUNTIME=$(xcrun simctl list runtimes | grep "iOS" | tail -1 | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9]+' | head -1)
    
    if [[ -z "$RUNTIME" ]]; then
        print_error "No iOS runtime found"
        exit 1
    fi
    
    # Create device
    SIMULATOR_ID=$(xcrun simctl create "$SIMULATOR_NAME" "com.apple.CoreSimulator.SimDeviceType.$(echo $SIMULATOR_NAME | tr ' ' '-')" "$RUNTIME")
    print_success "Created simulator: $SIMULATOR_ID"
else
    print_success "Found simulator: $SIMULATOR_ID"
fi

# Boot simulator if not already running
SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -oE '(Booted|Shutdown)' | head -1)

if [[ "$SIMULATOR_STATE" != "Booted" ]]; then
    print_status "Booting simulator..."
    xcrun simctl boot "$SIMULATOR_ID"
    print_success "Simulator booted"
    
    # Wait a moment for simulator to fully boot
    sleep 3
else
    print_success "Simulator already running"
fi

# Open Simulator app
open -a Simulator

# Initialize iOS project if needed
print_status "Checking iOS project initialization..."
cd src-tauri

if [[ ! -d "gen/apple/src-tauri.xcodeproj" ]]; then
    print_status "Initializing iOS project..."
    cargo tauri ios init
    print_success "iOS project initialized"
fi

# Install CocoaPods dependencies
print_status "Installing CocoaPods dependencies..."
cd gen/apple
if [[ -f "Podfile" ]]; then
    pod install --repo-update || pod install
    print_success "CocoaPods dependencies installed"
else
    print_warning "Podfile not found"
fi
cd ../../..

# Build frontend
print_status "Building frontend..."
cd frontend
bun install --frozen-lockfile
bun run build
cd ..
print_success "Frontend built"

# Build Rust for iOS simulator
print_status "Building Rust for iOS simulator..."
cd src-tauri

if [[ "$DEV_MODE" == "release" ]]; then
    cargo build --target aarch64-apple-ios-sim --release
    BUILD_PROFILE="release"
else
    cargo build --target aarch64-apple-ios-sim
    BUILD_PROFILE="debug"
fi

print_success "Rust build completed"

# Configure Tauri for iOS development
print_status "Configuring Tauri for iOS development..."

# Create development configuration
cat > tauri.ios.dev.json << EOF
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "OpenCode Nexus",
  "version": "0.1.30",
  "identifier": "com.agentic-codeflow.opencode-nexus",
  "build": {
    "beforeDevCommand": "cd frontend && bun run dev",
    "devUrl": "http://localhost:1420",
    "beforeBuildCommand": "cd frontend && bun run build",
    "frontendDist": "../frontend/dist"
  },
  "app": {
    "withGlobalTauri": true,
    "windows": [
      {
        "title": "OpenCode Nexus",
        "width": 800,
        "height": 600,
        "label": "main"
      }
    ],
    "security": {
      "csp": "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'inline-speculation-rules' tauri:; style-src 'self'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' https: http: ws: tauri: ipc: http://ipc.localhost; media-src 'self' data: blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'; worker-src 'self' blob:",
      "devCsp": "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline' 'wasm-unsafe-eval' http: https: tauri:; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; font-src 'self' data:; connect-src 'self' ws: http: https: tauri: ipc:; media-src 'self' data: blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'; worker-src 'self' blob:"
    }
  },
  "bundle": {
    "active": true,
    "targets": "all",
    "iOS": {
      "developmentTeam": "PCJU8QD9FN",
      "minimumSystemVersion": "14.0",
      "capabilities": [],
      "entitlements": "ios-config/src-tauri_iOS.entitlements",
      "infoPlist": {
        "NSAppTransportSecurity": {
          "NSAllowsArbitraryLoads": false,
          "NSExceptionDomains": {
            "api.opencode.ai": {
              "NSExceptionAllowsInsecureHTTPLoads": false,
              "NSExceptionMinimumTLSVersion": "TLSv1.2",
              "NSExceptionRequiresForwardSecrecy": true
            },
            "opencode.ai": {
              "NSExceptionAllowsInsecureHTTPLoads": false,
              "NSExceptionMinimumTLSVersion": "TLSv1.2",
              "NSExceptionRequiresForwardSecrecy": true
            }
          }
        },
        "ITSAppUsesNonExemptEncryption": true,
        "NSCameraUsageDescription": "This app may use the camera for scanning QR codes and other features.",
        "NSMicrophoneUsageDescription": "This app may access the microphone for voice input features.",
        "CFBundleDisplayName": "OpenCode Nexus",
        "CFBundleName": "OpenCodeNexus",
        "LSRequiresIPhoneOS": true,
        "UIRequiredDeviceCapabilities": ["armv7"],
        "UISupportedInterfaceOrientations": [
          "UIInterfaceOrientationPortrait",
          "UIInterfaceOrientationLandscapeLeft",
          "UIInterfaceOrientationLandscapeRight"
        ],
        "UISupportedInterfaceOrientations~ipad": [
          "UIInterfaceOrientationPortrait",
          "UIInterfaceOrientationPortraitUpsideDown",
          "UIInterfaceOrientationLandscapeLeft",
          "UIInterfaceOrientationLandscapeRight"
        ]
      }
    }
  }
}
EOF

print_success "Development configuration created"

# Start development server
print_status "Starting iOS development server..."

if [[ "$HOT_RELOAD" == "true" ]]; then
    print_status "Starting with hot-reload enabled..."
    print_status "Frontend dev server will start automatically"
    print_status "Changes will be reflected in the simulator"
    
    # Start frontend dev server in background
    cd frontend
    bun run dev &
    FRONTEND_PID=$!
    cd ..
    
    # Wait a moment for dev server to start
    sleep 5
    
    # Start Tauri development
    cd src-tauri
    print_status "Installing and running app on simulator..."
    
    # Build and install app
    if [[ "$DEV_MODE" == "release" ]]; then
        cargo tauri ios build --release --target aarch64-apple-ios-sim
    else
        cargo tauri ios build --target aarch64-apple-ios-sim
    fi
    
    # Install and run on simulator
    APP_PATH="gen/apple/build/Build/Products/Debug-iphonesimulator/src-tauri_iOS.app"
    if [[ "$DEV_MODE" == "release" ]]; then
        APP_PATH="gen/apple/build/Build/Products/Release-iphonesimulator/src-tauri_iOS.app"
    fi
    
    if [[ -d "$APP_PATH" ]]; then
        xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
        xcrun simctl launch "$SIMULATOR_ID" com.agentic-codeflow.opencode-nexus
        print_success "App installed and launched on simulator"
    else
        print_error "App not found at expected path: $APP_PATH"
    fi
    
    # Keep the script running to monitor for changes
    print_status "Development server running. Press Ctrl+C to stop."
    print_status "Hot-reload is active - changes will be reflected in simulator."
    
    # Wait for interrupt
    trap 'kill $FRONTEND_PID; print_status "Stopping development servers..."; exit 0' INT
    wait $FRONTEND_PID
else
    print_status "Starting without hot-reload..."
    cd src-tauri
    cargo tauri ios build --target aarch64-apple-ios-sim
    
    # Install and run
    APP_PATH="gen/apple/build/Build/Products/Debug-iphonesimulator/src-tauri_iOS.app"
    if [[ -d "$APP_PATH" ]]; then
        xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
        xcrun simctl launch "$SIMULATOR_ID" com.agentic-codeflow.opencode-nexus
        print_success "App installed and launched on simulator"
    else
        print_error "App not found at expected path: $APP_PATH"
    fi
fi

print_success "iOS development environment ready!"
echo ""
echo "📱 Development Tips:"
echo "  - Simulator: $SIMULATOR_NAME ($SIMULATOR_ID)"
echo "  - Hot-reload: $HOT_RELOAD"
echo "  - Build mode: $DEV_MODE"
echo "  - Frontend URL: http://localhost:1420"
echo "  - Use Xcode for debugging: open src-tauri/gen/apple/src-tauri.xcworkspace"
echo ""
echo "🔧 Development Commands:"
echo "  - Rebuild: cargo tauri ios build --target aarch64-apple-ios-sim"
echo "  - Install: xcrun simctl install $SIMULATOR_ID <app-path>"
echo "  - Launch: xcrun simctl launch $SIMULATOR_ID com.agentic-codeflow.opencode-nexus"
echo "  - Logs: xcrun simctl spawn $SIMULATOR_ID log stream --predicate 'process == \"OpenCodeNexus\"'"