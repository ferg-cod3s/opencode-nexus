#!/bin/bash
# Enhanced Xcode Cloud Pre-Build Script
# Runs before Xcode builds the iOS app
#
# This script validates that the post-clone setup completed successfully
# and that the pre-built Rust library is ready for Xcode to use.

set -e
echo "🔨 Enhanced Xcode Cloud pre-build validation..."

# Navigate to the project root
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

# Navigate to src-tauri
cd src-tauri || exit 1

echo "🔍 Validating pre-build setup..."

# 1. Verify pre-built library exists
LIB_PATH="gen/apple/Externals/arm64/Release/libapp.a"
if [ ! -f "$LIB_PATH" ]; then
    echo "❌ ERROR: Pre-built library not found at $LIB_PATH"
    echo "   This indicates the post-clone script failed"
    echo "   Available files in Externals directory:"
    find gen/apple/Externals -type f 2>/dev/null || echo "   No files found"
    exit 1
fi

# 2. Verify library is a valid static library
if ! file "$LIB_PATH" | grep -q -E "(ar archive|current ar archive)"; then
    echo "❌ ERROR: Library is not a valid ar archive"
    echo "   File type: $(file "$LIB_PATH")"
    exit 1
fi

# 3. Verify library contains arm64 code
if ! lipo -info "$LIB_PATH" 2>/dev/null | grep -q "arm64"; then
    echo "❌ ERROR: Library does not contain arm64 code"
    echo "   Architecture info: $(lipo -info "$LIB_PATH" 2>/dev/null || echo "Unable to read architecture")"
    exit 1
fi

# 4. Verify Xcode project was patched
if [ ! -f "gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
    echo "❌ ERROR: Xcode project file not found"
    exit 1
fi

if ! grep -q "CI-Compatible: Skip if pre-built libapp.a exists" gen/apple/src-tauri.xcodeproj/project.pbxproj; then
    echo "❌ ERROR: Xcode project not properly patched"
    echo "   The CI-compatible build script was not injected"
    exit 1
fi

# 5. Verify Xcode workspace exists
if [ ! -f "gen/apple/src-tauri.xcworkspace/contents.xcworkspacedata" ]; then
    echo "❌ ERROR: Xcode workspace not found"
    echo "   CocoaPods may not have run successfully"
    exit 1
fi

# 6. Verify ExportOptions.plist exists
if [ ! -f "gen/apple/ExportOptions.plist" ]; then
    echo "⚠️ WARNING: ExportOptions.plist not found"
    echo "   This may cause issues during IPA export"
else
    echo "✅ ExportOptions.plist found"
fi

# 7. Check library size (should be reasonable for a release build)
LIB_SIZE=$(du -k "$LIB_PATH" | cut -f1)
if [ "$LIB_SIZE" -lt 100 ]; then
    echo "⚠️ WARNING: Library seems unusually small (${LIB_SIZE}KB)"
elif [ "$LIB_SIZE" -gt 50000 ]; then
    echo "⚠️ WARNING: Library seems unusually large (${LIB_SIZE}KB)"
else
    echo "✅ Library size looks reasonable (${LIB_SIZE}KB)"
fi

# 8. Verify Rust toolchain is still available
if ! command -v cargo &> /dev/null; then
    echo "❌ ERROR: cargo not found in PATH"
    echo "   PATH: $PATH"
    exit 1
fi

if ! cargo tauri --version &> /dev/null 2>&1; then
    echo "⚠️ WARNING: Tauri CLI not found, but this may not be needed"
else
    echo "✅ Tauri CLI available: $(cargo tauri --version)"
fi

echo "✅ All pre-build validations passed"
echo "📱 Ready for Xcode to build the iOS app"
echo ""
echo "📊 Summary:"
echo "   - Library: $LIB_PATH (${LIB_SIZE}KB)"
echo "   - Architecture: arm64"
echo "   - Xcode Project: Patched for CI"
echo "   - Workspace: Ready"
echo "   - Rust Toolchain: Available"