#!/bin/bash
# iOS Build Verification Script
# Verifies that all necessary iOS project files are present

set -e

echo "🔍 iOS Build Verification"
echo "=========================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# Check if we're in the right directory
if [ ! -d "src-tauri" ]; then
    print_error "src-tauri directory not found. Please run from project root."
    exit 1
fi

cd src-tauri

# Check core iOS generated files
echo "Checking iOS project structure..."

FILES_TO_CHECK=(
    "gen/apple/src-tauri.xcworkspace/contents.xcworkspacedata:Workspace file"
    "gen/apple/src-tauri.xcodeproj/project.pbxproj:Project file"
    "gen/apple/src-tauri.xcodeproj/xcshareddata/xcschemes/src-tauri_iOS.xcscheme:iOS scheme"
    "gen/apple/Podfile:CocoaPods file"
    "gen/apple/ExportOptions.plist:Export options"
    "gen/apple/project.yml:XcodeGen configuration"
    "gen/apple/src-tauri_iOS/Info.plist:iOS Info.plist"
    "gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements:iOS entitlements"
    "gen/apple/Sources/src-tauri/main.mm:iOS main file"
    "gen/apple/Assets.xcassets/AppIcon.appiconset:App icons"
)

ALL_GOOD=true

for file_check in "${FILES_TO_CHECK[@]}"; do
    file_path="${file_check%%:*}"
    description="${file_check##*:}"
    
    if [ -f "$file_path" ] || [ -d "$file_path" ]; then
        print_success "$description"
    else
        print_error "$description missing: $file_path"
        ALL_GOOD=false
    fi
done

# Check Tauri configuration
echo ""
echo "Checking Tauri configuration..."

if [ -f "tauri.conf.json" ]; then
    print_success "Main Tauri config"
else
    print_error "Main Tauri config missing"
    ALL_GOOD=false
fi

if [ -f "tauri.ios.conf.json" ]; then
    print_success "iOS-specific Tauri config"
else
    print_warning "iOS-specific Tauri config missing (using main config)"
fi

# Check Rust configuration
echo ""
echo "Checking Rust configuration..."

if [ -f "Cargo.toml" ]; then
    print_success "Cargo.toml"
else
    print_error "Cargo.toml missing"
    ALL_GOOD=false
fi

# Check if iOS targets are available
echo ""
echo "Checking Rust iOS targets..."

if command -v rustup &> /dev/null; then
    if rustup target list --installed | grep -q "aarch64-apple-ios"; then
        print_success "aarch64-apple-ios target installed"
    else
        print_warning "aarch64-apple-ios target not installed"
        echo "  Run: rustup target add aarch64-apple-ios"
    fi
else
    print_warning "Rustup not available to check targets"
fi

# Summary
echo ""
if [ "$ALL_GOOD" = true ]; then
    echo "🎉 All iOS project files are present!"
    echo ""
    echo "Next steps:"
    echo "1. Open workspace: open gen/apple/src-tauri.xcworkspace"
    echo "2. Or open project: open gen/apple/src-tauri.xcodeproj"
    echo "3. Build in Xcode or run: cargo tauri ios build"
    exit 0
else
    echo "❌ Some iOS project files are missing."
    echo ""
    echo "To regenerate iOS project:"
    echo "1. Run: cargo tauri ios init"
    echo "2. Or manually create missing files"
    exit 1
fi