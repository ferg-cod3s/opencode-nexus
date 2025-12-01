#!/bin/bash
# MIT License
# Copyright (c) 2025 OpenCode Nexus Contributors
#
# CI-Compatible Rust Build Script for Tauri iOS
# 
# This script replaces the default "Build Rust Code" phase in Xcode to support
# both local development and CI/CD environments (including Xcode Cloud).
#
# PROBLEM THIS SOLVES:
# Tauri's `cargo tauri ios xcode-script` command requires a TCP socket connection
# to a parent Tauri process. In CI environments (like Xcode Cloud), this parent
# process doesn't exist, causing "Connection refused (os error 61)" errors.
#
# SOLUTION:
# 1. In CI: Check for pre-built library, or build directly with cargo
# 2. Locally: Use the standard Tauri xcode-script for hot reload support
#
# USAGE:
# Replace the "Build Rust Code" shell script in your Xcode project with:
#   ${CI_PRIMARY_REPOSITORY_PATH}/ci_scripts/build_rust_code.sh
# Or use this script content directly in the build phase.

set -e

echo "=== Tauri iOS Rust Build Script ==="
echo "Configuration: ${CONFIGURATION:-Release}"
echo "Platform: ${PLATFORM_DISPLAY_NAME:-iOS}"
echo "Archs: ${ARCHS:-arm64}"
echo "SRCROOT: ${SRCROOT:-unknown}"

# Determine output directory based on Xcode build settings
ARCH="arm64"
CONFIG="${CONFIGURATION:-Release}"
CONFIG_LOWER=$(echo "$CONFIG" | tr '[:upper:]' '[:lower:]')
OUTPUT_DIR="${SRCROOT}/Externals/${ARCH}/${CONFIG_LOWER}"
LIBAPP_PATH="${OUTPUT_DIR}/libapp.a"

# Alternative path structure (some Tauri versions use this)
ALT_OUTPUT_DIR="${SRCROOT}/Externals/${ARCH}/${CONFIG}"
ALT_LIBAPP_PATH="${ALT_OUTPUT_DIR}/libapp.a"

echo "Expected library path: $LIBAPP_PATH"

# Detect CI environment (Xcode Cloud sets CI_PRIMARY_REPOSITORY_PATH)
IS_CI="false"
if [ -n "$CI_PRIMARY_REPOSITORY_PATH" ] || [ "$CI" = "true" ] || [ -n "$GITHUB_ACTIONS" ]; then
    IS_CI="true"
    echo "✅ CI environment detected"
fi

# Function to check if libapp.a is valid for arm64
check_libapp() {
    local path="$1"
    if [ -f "$path" ]; then
        # Verify it's a valid static library
        if file "$path" | grep -q -E "(ar archive|current ar archive)"; then
            # Verify it contains arm64 code
            if lipo -info "$path" 2>/dev/null | grep -q "arm64"; then
                echo "✅ Valid arm64 libapp.a found at: $path"
                return 0
            elif file "$path" | grep -q "arm64"; then
                echo "✅ Valid arm64 libapp.a found at: $path"
                return 0
            fi
            # Accept if it's an archive (might be universal or arm64-only)
            echo "✅ Valid archive libapp.a found at: $path"
            return 0
        fi
    fi
    return 1
}

# First, check if libapp.a already exists (pre-built by CI or previous build)
if check_libapp "$LIBAPP_PATH"; then
    echo "Pre-built libapp.a found, skipping Rust compilation"
    exit 0
fi

if check_libapp "$ALT_LIBAPP_PATH"; then
    echo "Pre-built libapp.a found at alternate path, copying..."
    mkdir -p "$OUTPUT_DIR"
    cp "$ALT_LIBAPP_PATH" "$LIBAPP_PATH"
    exit 0
fi

# Check for CI marker file
if [ -f "${SRCROOT}/Externals/.rust_prebuilt" ]; then
    echo "⚠️ CI prebuilt marker found but libapp.a is missing"
    echo "   This indicates the pre-build step failed. Attempting rebuild..."
fi

# === CI BUILD PATH ===
if [ "$IS_CI" = "true" ]; then
    echo "🦀 CI Build: Using direct cargo build (bypassing Tauri xcode-script)"
    
    # Set up cargo environment
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    # Verify cargo is available
    if ! command -v cargo &> /dev/null; then
        echo "❌ Error: cargo not found"
        echo "   PATH: $PATH"
        
        # Try to find cargo
        for CARGO_BIN in "$HOME/.cargo/bin" "/usr/local/bin" "/opt/homebrew/bin"; do
            if [ -x "$CARGO_BIN/cargo" ]; then
                export PATH="$CARGO_BIN:$PATH"
                echo "   Found cargo at: $CARGO_BIN/cargo"
                break
            fi
        done
        
        if ! command -v cargo &> /dev/null; then
            echo "❌ Fatal: cargo is not available. Ensure Rust is installed in ci_post_clone.sh"
            exit 1
        fi
    fi
    
    # Navigate to src-tauri directory
    # SRCROOT is typically gen/apple, so src-tauri is ../..
    PROJECT_ROOT="${SRCROOT}/../.."
    
    if [ -n "$CI_PRIMARY_REPOSITORY_PATH" ]; then
        PROJECT_ROOT="$CI_PRIMARY_REPOSITORY_PATH/src-tauri"
    fi
    
    cd "$PROJECT_ROOT"
    echo "   Project root: $(pwd)"
    
    # Set iOS SDK environment
    export SDKROOT="${SDKROOT:-$(xcrun --sdk iphoneos --show-sdk-path)}"
    export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-14.0}"
    
    echo "   SDKROOT: $SDKROOT"
    echo "   Deployment target: $IPHONEOS_DEPLOYMENT_TARGET"
    
    # Determine Rust profile
    if [ "$CONFIG_LOWER" = "release" ]; then
        RUST_PROFILE="release"
        CARGO_FLAGS="--release"
    else
        RUST_PROFILE="debug"
        CARGO_FLAGS=""
    fi
    
    # Build the Rust library
    echo "🔨 Building: cargo build --target aarch64-apple-ios $CARGO_FLAGS --lib"
    cargo build --target aarch64-apple-ios $CARGO_FLAGS --lib
    
    # Find and copy the built library
    RUST_TARGET_DIR="target/aarch64-apple-ios/${RUST_PROFILE}"
    
# Try different possible library names, starting with correct one from Cargo.toml
FOUND_LIB=""
for LIB_NAME in "libsrc_tauri_lib.a" "libapp.a" "libsrc_tauri.a" "libopencode_nexus.a"; do
    if [ -f "${RUST_TARGET_DIR}/${LIB_NAME}" ]; then
        FOUND_LIB="${RUST_TARGET_DIR}/${LIB_NAME}"
        break
    fi
done
    
    if [ -z "$FOUND_LIB" ]; then
        echo "⚠️ Standard library names not found, searching..."
        FOUND_LIB=$(find "$RUST_TARGET_DIR" -maxdepth 1 -name "lib*.a" -type f | head -1)
    fi
    
    if [ -n "$FOUND_LIB" ] && [ -f "$FOUND_LIB" ]; then
        mkdir -p "$OUTPUT_DIR"
        mkdir -p "$ALT_OUTPUT_DIR"
        cp "$FOUND_LIB" "$LIBAPP_PATH"
        cp "$FOUND_LIB" "$ALT_LIBAPP_PATH"
        echo "✅ Copied $(basename $FOUND_LIB) to $LIBAPP_PATH"
        exit 0
    else
        echo "❌ Error: Rust build succeeded but no .a library found"
        echo "   Searched in: $RUST_TARGET_DIR"
        echo "   Available files:"
        ls -la "$RUST_TARGET_DIR" 2>/dev/null || echo "   Directory not found"
        exit 1
    fi
fi

# === LOCAL DEVELOPMENT PATH ===
echo "🔧 Local development mode - using cargo tauri ios xcode-script"
echo "   This requires the Tauri dev server to be running"

# Ensure cargo and tauri-cli are available
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

if ! command -v cargo &> /dev/null; then
    echo "❌ Error: cargo not found. Please install Rust."
    exit 1
fi

if ! cargo tauri --version &> /dev/null 2>&1; then
    echo "⚠️ Tauri CLI not found, attempting to install..."
    cargo install tauri-cli --version "^2" --locked
fi

# Execute the standard Tauri xcode-script
exec cargo tauri ios xcode-script -v \
    --platform "${PLATFORM_DISPLAY_NAME:?}" \
    --sdk-root "${SDKROOT:?}" \
    --framework-search-paths "${FRAMEWORK_SEARCH_PATHS:?}" \
    --header-search-paths "${HEADER_SEARCH_PATHS:?}" \
    --gcc-preprocessor-definitions "${GCC_PREPROCESSOR_DEFINITIONS:-}" \
    --configuration "${CONFIGURATION:?}" \
    ${FORCE_COLOR} \
    ${ARCHS:?}
