#!/bin/bash
# iOS Build Environment Validation Script
# Validates that all required tools and dependencies are properly installed for iOS builds

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

# Validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

print_status "Starting iOS build environment validation..."
echo "=============================================="

# 1. Check macOS version
print_status "Checking macOS version..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    MACOS_VERSION=$(sw_vers -productVersion)
    MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
    MACOS_MINOR=$(echo "$MACOS_VERSION" | cut -d. -f2)
    
    if [[ $MACOS_MAJOR -gt 13 ]] || [[ $MACOS_MAJOR -eq 13 && $MACOS_MINOR -ge 0 ]]; then
        print_success "macOS $MACOS_VERSION (meets minimum requirement 13.0+)"
    else
        print_error "macOS $MACOS_VERSION (below minimum requirement 13.0+)"
        ((VALIDATION_ERRORS++))
    fi
else
    print_error "Not running on macOS (current: $OSTYPE)"
    ((VALIDATION_ERRORS++))
fi

# 2. Check Xcode installation
print_status "Checking Xcode installation..."
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -n1 | awk '{print $2}')
    XCODE_MAJOR=$(echo "$XCODE_VERSION" | cut -d. -f1)
    XCODE_MINOR=$(echo "$XCODE_VERSION" | cut -d. -f2)
    
    if [[ $XCODE_MAJOR -gt 15 ]] || [[ $XCODE_MAJOR -eq 15 && $XCODE_MINOR -ge 4 ]]; then
        print_success "Xcode $XCODE_VERSION (meets minimum requirement 15.4+)"
    else
        print_warning "Xcode $XCODE_VERSION (below recommended 15.4+)"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check Xcode Command Line Tools
    if xcode-select -p &> /dev/null; then
        print_success "Xcode Command Line Tools installed"
    else
        print_error "Xcode Command Line Tools not installed"
        ((VALIDATION_ERRORS++))
    fi
else
    print_error "Xcode not found"
    ((VALIDATION_ERRORS++))
fi

# 3. Check Rust installation
print_status "Checking Rust installation..."
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version | awk '{print $2}')
    print_success "Rust $RUST_VERSION installed"
    
    # Check Rustup
    if command -v rustup &> /dev/null; then
        print_success "Rustup available"
        
        # Check iOS targets
        print_status "Checking iOS targets..."
        IOS_TARGETS=("aarch64-apple-ios" "aarch64-apple-ios-sim" "x86_64-apple-ios")
        MISSING_TARGETS=()
        
        for target in "${IOS_TARGETS[@]}"; do
            if rustup target list --installed | grep -q "$target"; then
                print_success "Target $target installed"
            else
                print_warning "Target $target not installed"
                MISSING_TARGETS+=("$target")
                ((VALIDATION_WARNINGS++))
            fi
        done
        
        # Install missing targets if requested
        if [[ ${#MISSING_TARGETS[@]} -gt 0 ]]; then
            print_status "To install missing targets, run:"
            for target in "${MISSING_TARGETS[@]}"; do
                echo "  rustup target add $target"
            done
        fi
    else
        print_warning "Rustup not found (using system Rust)"
    fi
else
    print_error "Rust not installed"
    ((VALIDATION_ERRORS++))
fi

# 4. Check Bun installation
print_status "Checking Bun installation..."
if command -v bun &> /dev/null; then
    BUN_VERSION=$(bun --version)
    print_success "Bun $BUN_VERSION installed"
else
    print_error "Bun not installed"
    ((VALIDATION_ERRORS++))
fi

# 5. Check CocoaPods installation
print_status "Checking CocoaPods installation..."
if command -v pod &> /dev/null; then
    POD_VERSION=$(pod --version)
    print_success "CocoaPods $POD_VERSION installed"
else
    print_error "CocoaPods not installed"
    ((VALIDATION_ERRORS++))
fi

# 6. Check project structure
print_status "Checking project structure..."
REQUIRED_DIRS=("src-tauri" "frontend" "src-tauri/ios-config")
REQUIRED_FILES=("src-tauri/Cargo.toml" "src-tauri/tauri.ios.conf.json" "frontend/package.json")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        print_success "Directory $dir exists"
    else
        print_error "Directory $dir missing"
        ((VALIDATION_ERRORS++))
    fi
done

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "File $file exists"
    else
        print_error "File $file missing"
        ((VALIDATION_ERRORS++))
    fi
done

# 7. Check iOS configuration files
print_status "Checking iOS configuration files..."
IOS_CONFIG_FILES=("src-tauri/ios-config/src-tauri_iOS.entitlements" "src-tauri/ios-config/ExportOptions.plist" "src-tauri/ios-config/Podfile")

for file in "${IOS_CONFIG_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "iOS config $file exists"
    else
        print_warning "iOS config $file missing (will be generated)"
        ((VALIDATION_WARNINGS++))
    fi
done

# 8. Check generated Xcode project
print_status "Checking generated Xcode project..."
if [[ -d "src-tauri/gen/apple/src-tauri.xcodeproj" ]] && [[ -f "src-tauri/gen/apple/src-tauri.xcworkspace/contents.xcworkspacedata" ]]; then
    print_success "Xcode project and workspace generated"
else
    print_warning "Xcode project not generated (run 'cargo tauri ios init' first)"
    ((VALIDATION_WARNINGS++))
fi

# 9. Check environment variables
print_status "Checking environment variables..."
REQUIRED_VARS=("IPHONEOS_DEPLOYMENT_TARGET" "CFLAGS" "CXXFLAGS")

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -n "${!var}" ]]; then
        print_success "$var is set"
    else
        print_warning "$var not set (will be set by build scripts)"
    fi
done

# 10. Check available simulators
print_status "Checking iOS simulators..."
if command -v xcrun &> /dev/null; then
    SIMULATOR_COUNT=$(xcrun simctl list devices available | grep -c "iOS" || echo "0")
    if [[ $SIMULATOR_COUNT -gt 0 ]]; then
        print_success "$SIMULATOR_COUNT iOS simulators available"
    else
        print_warning "No iOS simulators available"
        ((VALIDATION_WARNINGS++))
    fi
else
    print_warning "xcrun not available (cannot check simulators)"
    ((VALIDATION_WARNINGS++))
fi

# Summary
echo "=============================================="
print_status "Validation Summary:"
echo "  Errors: $VALIDATION_ERRORS"
echo "  Warnings: $VALIDATION_WARNINGS"

if [[ $VALIDATION_ERRORS -eq 0 ]]; then
    if [[ $VALIDATION_WARNINGS -eq 0 ]]; then
        print_success "Environment validation passed with no issues!"
        exit 0
    else
        print_warning "Environment validation passed with $VALIDATION_WARNINGS warning(s)"
        exit 0
    fi
else
    print_error "Environment validation failed with $VALIDATION_ERRORS error(s)"
    echo ""
    print_status "To fix errors:"
    echo "1. Install missing tools (Xcode, Rust, Bun, CocoaPods)"
    echo "2. Install missing Rust targets: rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios"
    echo "3. Ensure project structure is complete"
    echo "4. Run 'cargo tauri ios init' to generate Xcode project"
    exit 1
fi