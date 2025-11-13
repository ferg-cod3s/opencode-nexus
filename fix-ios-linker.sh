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


# iOS Linker Fix Script for OpenCode Nexus
# Addresses the "library 'System' not found" linker error

set -e

echo "🔧 Fixing iOS linker configuration..."

# Navigate to src-tauri directory
cd "$(dirname "$0")/src-tauri"

# Create .cargo directory if it doesn't exist
mkdir -p .cargo

# Create iOS-specific cargo config
cat > .cargo/config.toml << 'EOF'
# iOS Build Configuration for OpenCode Nexus
# Fixes cross-compilation linker issues

[build]
# Default target for iOS builds
target = "aarch64-apple-ios"

# iOS-specific configuration
[target.aarch64-apple-ios]
# Use iOS SDK instead of macOS
rustflags = [
    "-C", "link-arg=-L$(SDKROOT)/usr/lib",
    "-C", "link-arg=-L$(SDKROOT)/usr/lib/swift",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Foundation",
    "-C", "link-arg=-framework",
    "-C", "link-arg=UIKit",
    "-C", "link-arg=-framework",
    "-C", "link-arg=CoreGraphics",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Metal",
    "-C", "link-arg=-framework",
    "-C", "link-arg=QuartzCore",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Security",
    "-C", "link-arg=-framework",
    "-C", "link-arg=WebKit"
]

# iOS Simulator configuration
[target.aarch64-apple-ios-sim]
rustflags = [
    "-C", "link-arg=-L$(SDKROOT)/usr/lib",
    "-C", "link-arg=-L$(SDKROOT)/usr/lib/swift",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Foundation",
    "-C", "link-arg=-framework",
    "-C", "link-arg=UIKit",
    "-C", "link-arg=-framework",
    "-C", "link-arg=CoreGraphics",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Metal",
    "-C", "link-arg=-framework",
    "-C", "link-arg=QuartzCore",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Security",
    "-C", "link-arg=-framework",
    "-C", "link-arg=WebKit"
]

# x86_64 iOS Simulator configuration
[target.x86_64-apple-ios]
rustflags = [
    "-C", "link-arg=-L$(SDKROOT)/usr/lib",
    "-C", "link-arg=-L$(SDKROOT)/usr/lib/swift",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Foundation",
    "-C", "link-arg=-framework",
    "-C", "link-arg=UIKit",
    "-C", "link-arg=-framework",
    "-C", "link-arg=CoreGraphics",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Metal",
    "-C", "link-arg=-framework",
    "-C", "link-arg=QuartzCore",
    "-C", "link-arg=-framework",
    "-C", "link-arg=Security",
    "-C", "link-arg=-framework",
    "-C", "link-arg=WebKit"
]

[env]
# iOS deployment target
IPHONEOS_DEPLOYMENT_TARGET = "14.0"

# Prevent linking with macOS System library
CARGO_CFG_TARGET_OS = "ios"
CARGO_CFG_TARGET_VENDOR = "apple"
EOF

echo "✅ iOS linker configuration fixed!"

# Clean and rebuild
echo "🧹 Cleaning previous builds..."
cargo clean

echo "📦 Updating dependencies..."
cargo update

echo "🏗️ Testing iOS build..."
# Test build with verbose output to see if linker issues are resolved
cargo build --target aarch64-apple-ios --release --verbose

echo "✅ iOS build successful!"
echo ""
echo "🍎 Ready for TestFlight distribution:"
echo "  1. Open Xcode project: src-tauri/gen/apple/src-tauri.xcodeproj"
echo "  2. Set your Apple Developer Team ID"
echo "  3. Build and Archive"
echo "  4. Distribute to TestFlight"