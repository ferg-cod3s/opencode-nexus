#!/bin/bash
# iOS CI/CD Pipeline Testing Script
# 
# This script tests the iOS CI/CD pipeline components locally
# to ensure they work before deploying to CI environments.

set -e

echo "🧪 iOS CI/CD Pipeline Testing Suite"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass_test() {
    echo -e "${GREEN}✅ PASS: $1${NC}"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}❌ FAIL: $1${NC}"
    ((TESTS_FAILED++))
}

warn_test() {
    echo -e "${YELLOW}⚠️  WARN: $1${NC}"
}

# Test 1: Environment Setup
test_environment() {
    echo ""
    echo "🔍 Test 1: Environment Setup"
    echo "----------------------------"
    
    # Check if we're on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        pass_test "Running on macOS"
    else
        fail_test "Not running on macOS (current: $OSTYPE)"
        return
    fi
    
    # Check Rust installation
    if command -v rustc &> /dev/null; then
        RUST_VERSION=$(rustc --version)
        pass_test "Rust installed: $RUST_VERSION"
    else
        fail_test "Rust not installed"
        return
    fi
    
    # Check Cargo
    if command -v cargo &> /dev/null; then
        pass_test "Cargo available"
    else
        fail_test "Cargo not available"
        return
    fi
    
    # Check iOS target
    if rustup target list --installed | grep -q "aarch64-apple-ios"; then
        pass_test "iOS target (aarch64-apple-ios) installed"
    else
        warn_test "iOS target not installed, installing..."
        rustup target add aarch64-apple-ios
        if rustup target list --installed | grep -q "aarch64-apple-ios"; then
            pass_test "iOS target installed successfully"
        else
            fail_test "Failed to install iOS target"
        fi
    fi
    
    # Check Xcode
    if command -v xcodebuild &> /dev/null; then
        XCODE_VERSION=$(xcodebuild -version | head -1)
        pass_test "Xcode available: $XCODE_VERSION"
    else
        fail_test "Xcode not available"
    fi
    
    # Check iOS SDK
    if xcrun --sdk iphoneos --show-sdk-path &> /dev/null; then
        IOS_SDK_VERSION=$(xcrun --sdk iphoneos --show-sdk-version)
        pass_test "iOS SDK available: $IOS_SDK_VERSION"
    else
        fail_test "iOS SDK not available"
    fi
}

# Test 2: Rust Library Build
test_rust_build() {
    echo ""
    echo "🦀 Test 2: Rust Library Build"
    echo "-----------------------------"
    
    if [ ! -d "src-tauri" ]; then
        fail_test "src-tauri directory not found"
        return
    fi
    
    cd src-tauri
    
    # Check Cargo.toml exists
    if [ ! -f "Cargo.toml" ]; then
        fail_test "Cargo.toml not found"
        cd ..
        return
    fi
    
    # Extract library name from Cargo.toml
    LIB_NAME=$(grep -E '^name = ' Cargo.toml | head -1 | sed 's/name = "//;s/"//')
    if [ -z "$LIB_NAME" ]; then
        fail_test "Could not extract library name from Cargo.toml"
        cd ..
        return
    fi
    
    EXPECTED_LIB_NAME="lib${LIB_NAME}.a"
    pass_test "Library name from Cargo.toml: $LIB_NAME ($EXPECTED_LIB_NAME)"
    
    # Check if frontend is built (required for Tauri build)
    if [ ! -d "../frontend" ]; then
        warn_test "Frontend directory not found, building may fail"
    else
        cd ../frontend
        if command -v bun &> /dev/null; then
            if [ ! -d "node_modules" ]; then
                echo "Installing frontend dependencies..."
                bun install
            fi
            echo "Building frontend..."
            bun run build
            pass_test "Frontend built successfully"
        else
            warn_test "Bun not available, frontend may not be built"
        fi
        cd ../src-tauri
    fi
    
    # Build the Rust library
    echo "Building Rust library for iOS..."
    if cargo build --target aarch64-apple-ios --release --lib; then
        pass_test "Rust library build succeeded"
    else
        fail_test "Rust library build failed"
        cd ..
        return
    fi
    
    # Check if library was created
    RUST_LIB_PATH="target/aarch64-apple-ios/release/$EXPECTED_LIB_NAME"
    if [ -f "$RUST_LIB_PATH" ]; then
        pass_test "Library found at: $RUST_LIB_PATH"
        
        # Check library format
        if file "$RUST_LIB_PATH" | grep -q "ar archive"; then
            pass_test "Library is valid ar archive"
        else
            fail_test "Library is not a valid ar archive"
        fi
        
        # Check library architecture
        if lipo -info "$RUST_LIB_PATH" 2>/dev/null | grep -q "arm64"; then
            pass_test "Library contains arm64 architecture"
        else
            fail_test "Library does not contain arm64 architecture"
        fi
        
        # Check library size
        LIB_SIZE=$(du -k "$RUST_LIB_PATH" | cut -f1)
        if [ "$LIB_SIZE" -gt 100 ]; then
            pass_test "Library size reasonable: ${LIB_SIZE}KB"
        else
            warn_test "Library seems small: ${LIB_SIZE}KB"
        fi
    else
        fail_test "Library not found at expected path: $RUST_LIB_PATH"
        echo "Available files:"
        find target/aarch64-apple-ios/release -name "*.a" -type f 2>/dev/null || echo "No .a files found"
    fi
    
    cd ..
}

# Test 3: iOS Project Initialization
test_ios_init() {
    echo ""
    echo "📱 Test 3: iOS Project Initialization"
    echo "--------------------------------------"
    
    if [ ! -d "src-tauri" ]; then
        fail_test "src-tauri directory not found"
        return
    fi
    
    cd src-tauri
    
    # Check if Tauri CLI is available
    if ! cargo tauri --version &> /dev/null; then
        warn_test "Tauri CLI not available, installing..."
        cargo install tauri-cli --version "^2" --locked
    fi
    
    # Initialize iOS project
    echo "Initializing iOS project..."
    if cargo tauri ios init; then
        pass_test "iOS project initialization succeeded"
    else
        fail_test "iOS project initialization failed"
        cd ..
        return
    fi
    
    # Check if gen/apple directory was created
    if [ -d "gen/apple" ]; then
        pass_test "gen/apple directory created"
    else
        fail_test "gen/apple directory not created"
        cd ..
        return
    fi
    
    # Check Xcode project
    if [ -f "gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        pass_test "Xcode project file created"
    else
        fail_test "Xcode project file not found"
        cd ..
        return
    fi
    
    # Check for Build Rust Code phase
    if grep -q "Build Rust Code" gen/apple/src-tauri.xcodeproj/project.pbxproj; then
        pass_test "Build Rust Code phase found in Xcode project"
    else
        warn_test "Build Rust Code phase not found (may be different in this version)"
    fi
    
    cd ..
}

# Test 4: Library Placement
test_library_placement() {
    echo ""
    echo "📦 Test 4: Library Placement"
    echo "----------------------------"
    
    if [ ! -d "src-tauri" ]; then
        fail_test "src-tauri directory not found"
        return
    fi
    
    cd src-tauri
    
    # Get library name
    LIB_NAME=$(grep -E '^name = ' Cargo.toml | head -1 | sed 's/name = "//;s/"//')
    EXPECTED_LIB_NAME="lib${LIB_NAME}.a"
    RUST_LIB_PATH="target/aarch64-apple-ios/release/$EXPECTED_LIB_NAME"
    
    if [ ! -f "$RUST_LIB_PATH" ]; then
        fail_test "Source library not found: $RUST_LIB_PATH"
        cd ..
        return
    fi
    
    # Create Externals directory structure
    mkdir -p gen/apple/Externals/arm64/Release
    mkdir -p gen/apple/Externals/arm64/release
    
    # Copy library
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/Release/libapp.a
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/release/libapp.a
    
    # Verify copies
    if [ -f "gen/apple/Externals/arm64/Release/libapp.a" ]; then
        pass_test "Library copied to Release directory"
    else
        fail_test "Library copy to Release directory failed"
    fi
    
    if [ -f "gen/apple/Externals/arm64/release/libapp.a" ]; then
        pass_test "Library copied to release directory"
    else
        fail_test "Library copy to release directory failed"
    fi
    
    # Validate copied libraries
    for CONFIG in Release release; do
        LIB_PATH="gen/apple/Externals/arm64/$CONFIG/libapp.a"
        if file "$LIB_PATH" | grep -q "ar archive"; then
            pass_test "Copied library ($CONFIG) is valid ar archive"
        else
            fail_test "Copied library ($CONFIG) is not valid ar archive"
        fi
        
        if lipo -info "$LIB_PATH" 2>/dev/null | grep -q "arm64"; then
            pass_test "Copied library ($CONFIG) contains arm64"
        else
            fail_test "Copied library ($CONFIG) does not contain arm64"
        fi
    done
    
    cd ..
}

# Test 5: Xcode Project Patching
test_xcode_patching() {
    echo ""
    echo "🔧 Test 5: Xcode Project Patching"
    echo "--------------------------------"
    
    if [ ! -d "src-tauri" ]; then
        fail_test "src-tauri directory not found"
        return
    fi
    
    cd src-tauri
    
    if [ ! -f "gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        fail_test "Xcode project file not found"
        cd ..
        return
    fi
    
    # Create patch script
    cat > /tmp/test_patch_pbxproj.py << 'PYEOF'
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
    
    return True

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(1)
    
    pbxproj_path = sys.argv[1]
    if patch_xcode_project(pbxproj_path):
        sys.exit(0)
    else:
        sys.exit(1)
PYEOF
    
    # Apply patch
    if python3 /tmp/test_patch_pbxproj.py gen/apple/src-tauri.xcodeproj/project.pbxproj; then
        pass_test "Xcode project patching succeeded"
    else
        fail_test "Xcode project patching failed"
        cd ..
        return
    fi
    
    # Verify patch was applied
    if grep -q "CI-Compatible: Skip if pre-built libapp.a exists" gen/apple/src-tauri.xcodeproj/project.pbxproj; then
        pass_test "CI-compatible script injected into Xcode project"
    else
        fail_test "CI-compatible script not found in Xcode project"
    fi
    
    # Verify original cargo tauri command is still there (as fallback)
    if grep -q "cargo tauri ios xcode-script" gen/apple/src-tauri.xcodeproj/project.pbxproj; then
        pass_test "Fallback Tauri command preserved"
    else
        warn_test "Fallback Tauri command not found"
    fi
    
    cd ..
}

# Test 6: CocoaPods Setup
test_cocoapods() {
    echo ""
    echo "📚 Test 6: CocoaPods Setup"
    echo "--------------------------"
    
    if [ ! -d "src-tauri/gen/apple" ]; then
        fail_test "gen/apple directory not found"
        return
    fi
    
    cd src-tauri/gen/apple
    
    # Check if Podfile exists
    if [ -f "Podfile" ]; then
        pass_test "Podfile found"
    else
        warn_test "Podfile not found (may not be needed)"
        cd ../..
        return
    fi
    
    # Check if CocoaPods is available
    if command -v pod &> /dev/null; then
        pass_test "CocoaPods available"
    else
        warn_test "CocoaPods not available, installing..."
        if command -v gem &> /dev/null; then
            sudo gem install cocoapods
            if command -v pod &> /dev/null; then
                pass_test "CocoaPods installed successfully"
            else
                fail_test "Failed to install CocoaPods"
                cd ../..
                return
            fi
        else
            fail_test "Gem not available, cannot install CocoaPods"
            cd ../..
            return
        fi
    fi
    
    # Try to install pods
    echo "Installing CocoaPods dependencies..."
    if pod install --repo-update || pod install; then
        pass_test "CocoaPods installation succeeded"
    else
        fail_test "CocoaPods installation failed"
        cd ../..
        return
    fi
    
    # Check if workspace was created
    if [ -f "src-tauri.xcworkspace/contents.xcworkspacedata" ]; then
        pass_test "Xcode workspace created"
    else
        fail_test "Xcode workspace not created"
    fi
    
    cd ../..
}

# Test 7: Build Script Validation
test_build_scripts() {
    echo ""
    echo "📜 Test 7: Build Script Validation"
    echo "---------------------------------"
    
    # Check if enhanced scripts exist
    SCRIPTS=(
        "ci_scripts/ci_post_clone_enhanced.sh"
        "ci_scripts/pre_xcode_build_enhanced.sh"
        "ci_scripts/build_rust_code_enhanced.sh"
    )
    
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            pass_test "Script found: $script"
            
            # Check if script is executable
            if [ -x "$script" ]; then
                pass_test "Script is executable: $script"
            else
                warn_test "Script is not executable: $script"
            fi
            
            # Check script syntax
            if bash -n "$script"; then
                pass_test "Script syntax valid: $script"
            else
                fail_test "Script syntax invalid: $script"
            fi
        else
            fail_test "Script not found: $script"
        fi
    done
}

# Test 8: Integration Test
test_integration() {
    echo ""
    echo "🔗 Test 8: Integration Test"
    echo "---------------------------"
    
    if [ ! -d "src-tauri" ]; then
        fail_test "src-tauri directory not found"
        return
    fi
    
    cd src-tauri
    
    # Check if all components are in place
    COMPONENTS_OK=true
    
    # Check Rust library
    LIB_NAME=$(grep -E '^name = ' Cargo.toml | head -1 | sed 's/name = "//;s/"//')
    EXPECTED_LIB_NAME="lib${LIB_NAME}.a"
    RUST_LIB_PATH="target/aarch64-apple-ios/release/$EXPECTED_LIB_NAME"
    
    if [ ! -f "$RUST_LIB_PATH" ]; then
        fail_test "Rust library missing for integration test"
        COMPONENTS_OK=false
    fi
    
    # Check iOS project
    if [ ! -f "gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        fail_test "Xcode project missing for integration test"
        COMPONENTS_OK=false
    fi
    
    # Check library placement
    if [ ! -f "gen/apple/Externals/arm64/Release/libapp.a" ]; then
        fail_test "Placed library missing for integration test"
        COMPONENTS_OK=false
    fi
    
    # Check Xcode patch
    if ! grep -q "CI-Compatible: Skip if pre-built libapp.a exists" gen/apple/src-tauri.xcodeproj/project.pbxproj; then
        fail_test "Xcode project patch missing for integration test"
        COMPONENTS_OK=false
    fi
    
    if [ "$COMPONENTS_OK" = true ]; then
        pass_test "All components in place for integration test"
        
        # Test the enhanced build script
        echo "Testing enhanced build script..."
        export SRCROOT="$(pwd)/gen/apple"
        export CONFIGURATION="Release"
        export PLATFORM_DISPLAY_NAME="iOS"
        export ARCHS="arm64"
        export CI="true"
        export CI_PRIMARY_REPOSITORY_PATH="$(pwd)/.."
        
        if bash ../../ci_scripts/build_rust_code_enhanced.sh; then
            pass_test "Enhanced build script test succeeded"
        else
            fail_test "Enhanced build script test failed"
        fi
        
        # Clean up environment variables
        unset SRCROOT CONFIGURATION PLATFORM_DISPLAY_NAME ARCHS CI CI_PRIMARY_REPOSITORY_PATH
    else
        fail_test "Integration test prerequisites not met"
    fi
    
    cd ..
}

# Main execution
main() {
    echo "Starting iOS CI/CD Pipeline Testing..."
    echo "This will test all components of the iOS build pipeline locally."
    echo ""
    
    # Run all tests
    test_environment
    test_rust_build
    test_ios_init
    test_library_placement
    test_xcode_patching
    test_cocoapods
    test_build_scripts
    test_integration
    
    # Print summary
    echo ""
    echo "===================================="
    echo "🏁 Test Summary"
    echo "===================================="
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Total Tests: $((TESTS_PASSED + TESTS_FAILED))${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 All tests passed! The iOS CI/CD pipeline should work correctly.${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Commit the enhanced scripts and workflow"
        echo "2. Test in a GitHub Actions run"
        echo "3. Test in Xcode Cloud if applicable"
        exit 0
    else
        echo ""
        echo -e "${RED}❌ Some tests failed. Please fix the issues before deploying.${NC}"
        echo ""
        echo "Common fixes:"
        echo "1. Install missing tools (Rust, Xcode, CocoaPods)"
        echo "2. Fix library name mismatches in scripts"
        echo "3. Ensure frontend builds successfully"
        echo "4. Check network connectivity for dependency downloads"
        exit 1
    fi
}

# Check if we're in the right directory
if [ ! -f "package.json" ] && [ ! -f "src-tauri/Cargo.toml" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    echo "   (where package.json and src-tauri/Cargo.toml should be located)"
    exit 1
fi

# Run main function
main "$@"