#!/bin/bash

# Xcode Cloud Pre-Build Script
# This script runs before Xcode builds the iOS app to initialize the workspace

set -e

echo "🔨 Starting Xcode Cloud pre-build setup..."

# Verify Rust toolchain is available
if ! command -v rustup &> /dev/null; then
    echo "❌ Error: rustup not found. Please ensure Rust is installed in the Xcode Cloud environment."
    exit 1
fi
if ! command -v cargo &> /dev/null; then
    echo "❌ Error: cargo not found. Please ensure Rust is installed in the Xcode Cloud environment."
    exit 1
fi

# Change to src-tauri directory
cd "$CI_PRIMARY_REPOSITORY_PATH/src-tauri" || { echo "❌ Error: Failed to change to src-tauri directory"; exit 1; }

echo "📦 Installing Rust iOS target..."
rustup target add aarch64-apple-ios

echo "🔧 Initializing iOS Tauri workspace..."
cargo tauri ios init

echo "📋 Copying ExportOptions.plist configuration..."
if [ -f "ios-config/ExportOptions.plist" ]; then
  cp ios-config/ExportOptions.plist gen/apple/ExportOptions.plist
  echo "✅ ExportOptions.plist copied"
else
  echo "⚠️  Warning: ios-config/ExportOptions.plist not found"
fi

echo "📦 Installing CocoaPods dependencies..."
cd gen/apple || exit 1

# Remove macOS target from Podfile since we're only building for iOS
if [ -f "Podfile" ]; then
  sed -i.bak '/^target.*macOS.*do$/,/^end$/d' Podfile
  sed -i.bak '/MACOSX_DEPLOYMENT_TARGET/d' Podfile
  rm -f Podfile.bak
fi

# Install CocoaPods dependencies for iOS target
pod install --repo-update || pod install

echo "✅ Xcode Cloud pre-build setup completed successfully"
