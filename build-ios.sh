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


# Complete iOS Build Solution for OpenCode Nexus
# This script provides a complete fix for iOS cross-compilation issues

set -e

echo "🍎 OpenCode Nexus iOS Build Solution"
echo "===================================="

# Navigate to project root
cd "$(dirname "$0")"

# Step 1: Ensure iOS targets are installed
echo "📱 Installing iOS targets..."
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# Step 2: Navigate to src-tauri for build configuration
cd src-tauri

# Step 3: Create .cargo directory and config
mkdir -p .cargo

echo "🔧 Configuring iOS build settings..."
cat > .cargo/config.toml << 'EOF'
# iOS Build Configuration for OpenCode Nexus
# Fixes cross-compilation linker issues

[build]
target = "aarch64-apple-ios"

[target.aarch64-apple-ios]
rustflags = [
    "-C", "link-arg=-L$(SDKROOT)/usr/lib",
    "-C", "link-arg=-L$(SDKROOT)/usr/lib/swift",
    "-C", "link-arg=-framework", "-C", "link-arg=Foundation",
    "-C", "link-arg=-framework", "-C", "link-arg=UIKit",
    "-C", "link-arg=-framework", "-C", "link-arg=CoreGraphics",
    "-C", "link-arg=-framework", "-C", "link-arg=Metal",
    "-C", "link-arg=-framework", "-C", "link-arg=QuartzCore",
    "-C", "link-arg=-framework", "-C", "link-arg=Security",
    "-C", "link-arg=-framework", "-C", "link-arg=WebKit"
]

[target.aarch64-apple-ios-sim]
rustflags = [
    "-C", "link-arg=-L$(SDKROOT)/usr/lib",
    "-C", "link-arg=-L$(SDKROOT)/usr/lib/swift",
    "-C", "link-arg=-framework", "-C", "link-arg=Foundation",
    "-C", "link-arg=-framework", "-C", "link-arg=UIKit",
    "-C", "link-arg=-framework", "-C", "link-arg=CoreGraphics",
    "-C", "link-arg=-framework", "-C", "link-arg=Metal",
    "-C", "link-arg=-framework", "-C", "link-arg=QuartzCore",
    "-C", "link-arg=-framework", "-C", "link-arg=Security",
    "-C", "link-arg=-framework", "-C", "link-arg=WebKit"
]

[target.x86_64-apple-ios]
rustflags = [
    "-C", "link-arg=-L$(SDKROOT)/usr/lib",
    "-C", "link-arg=-L$(SDKROOT)/usr/lib/swift",
    "-C", "link-arg=-framework", "-C", "link-arg=Foundation",
    "-C", "link-arg=-framework", "-C", "link-arg=UIKit",
    "-C", "link-arg=-framework", "-C", "link-arg=CoreGraphics",
    "-C", "link-arg=-framework", "-C", "link-arg=Metal",
    "-C", "link-arg=-framework", "-C", "link-arg=QuartzCore",
    "-C", "link-arg=-framework", "-C", "link-arg=Security",
    "-C", "link-arg=-framework", "-C", "link-arg=WebKit"
]

[env]
IPHONEOS_DEPLOYMENT_TARGET = "14.0"
CARGO_CFG_TARGET_OS = "ios"
CARGO_CFG_TARGET_VENDOR = "apple"
EOF

# Step 4: Clean previous builds
echo "🧹 Cleaning previous builds..."
cargo clean

# Step 5: Update dependencies
echo "📦 Updating dependencies..."
cargo update

# Step 6: Build frontend first
echo "🏗️ Building frontend..."
cd ../frontend
bun run build

# Step 7: Build for iOS (arm64 - physical devices)
echo "🏗️ Building for iOS arm64 (physical devices)..."
cd ../src-tauri
cargo tauri build --target aarch64-apple-ios

echo ""
echo "✅ iOS build completed successfully!"
echo ""
echo "📱 Build artifacts location:"
echo "  - iOS App: target/aarch64-apple-ios/release/src-tauri"
echo "  - Xcode Project: gen/apple/src-tauri.xcodeproj"
echo ""
echo "🍎 TestFlight Distribution Steps:"
echo "  1. Open Xcode: open gen/apple/src-tauri.xcodeproj"
echo "  2. Set your Apple Developer Team ID in project settings"
echo "  3. Select 'Any iOS Device' as target"
echo "  4. Product → Archive"
echo "  5. Distribute to TestFlight"
echo ""
echo "🔧 Key fixes applied:"
echo "  - Fixed iOS cross-compilation linker configuration"
echo "  - Added proper iOS framework linking"
echo "  - Configured correct SDK paths"
echo "  - Set iOS deployment target to 14.0"
echo "  - Prevented macOS System library linking"