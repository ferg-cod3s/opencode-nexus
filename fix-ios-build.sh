#!/bin/bash
# MIT License
#
# Copyright (c) 2025 OpenCode Nexus Contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# iOS Build Fix Script for OpenCode Nexus
# This script fixes common iOS cross-compilation issues

set -e

echo "🔧 Fixing iOS build configuration..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
cargo clean
rm -rf src-tauri/target

# Ensure iOS targets are installed
echo "📱 Installing iOS targets..."
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# Update dependencies
echo "📦 Updating dependencies..."
cargo update

# Set iOS-specific environment variables
export IPHONEOS_DEPLOYMENT_TARGET=14.0
export CFLAGS="-miphoneos-version-min=14.0"
export CXXFLAGS="-miphoneos-version-min=14.0"

# Build for iOS (arm64 - physical devices)
echo "🏗️ Building for iOS arm64 (physical devices)..."
cargo tauri build --target aarch64-apple-ios

# Build for iOS simulator (optional)
echo "🏗️ Building for iOS simulator (arm64)..."
cargo tauri build --target aarch64-apple-ios-sim

echo "✅ iOS build completed successfully!"
echo ""
echo "📱 Build artifacts:"
echo "  - Physical devices: src-tauri/target/aarch64-apple-ios/release/src-tauri"
echo "  - Simulator (arm64): src-tauri/target/aarch64-apple-ios-sim/release/src-tauri"
echo ""
echo "🍎 Next steps for TestFlight:"
echo "  1. Open src-tauri/gen/apple/src-tauri.xcodeproj in Xcode"
echo "  2. Set your development team in project settings"
echo "  3. Build and archive the app"
echo "  4. Distribute to TestFlight"