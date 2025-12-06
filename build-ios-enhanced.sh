#!/bin/bash
# Enhanced iOS Build Script for OpenCode Nexus
# Addresses TCP socket errors, library naming, and build reliability issues
# Implements pre-build strategy to avoid xcodebuild Rust compilation

set -euo pipefail

# Enhanced error handling
error_handler() {
    local line_number=$1
    local error_code=$2
    echo -e "\033[0;31m❌ ERROR: Failed at line $line_number with exit code $error_code\033[0m" >&2
    echo -e "\033[1;33m🔍 Common causes:\033[0m" >&2
    echo "  - Missing iOS targets: rustup target add aarch64-apple-ios" >&2
    echo "  - Network connectivity issues" >&2
    echo "  - Xcode command line tools not installed" >&2
    echo "  - Insufficient disk space" >&2
    exit $error_code
}

trap 'error_handler ${LINENO} $?' ERR

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}${BOLD}[STEP]${NC} $1"; }

# Configuration
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SRC_TAUDIR="${PROJECT_ROOT}/src-tauri"
readonly FRONTEND_DIR="${PROJECT_ROOT}/frontend"
readonly BUILD_START_TIME=$(date +%s)

# Build metrics
declare -A BUILD_METRICS=(
    ["frontend"]=0
    ["rust_prebuild"]=0
    ["xcode_setup"]=0
    ["archive"]=0
    ["export"]=0
)

log_step "🚀 Enhanced iOS Build for OpenCode Nexus"
echo "=========================================="
log_info "Build started at $(date '+%Y-%m-%d %H:%M:%S')"
log_info "Project root: ${PROJECT_ROOT}"

# Step 1: Environment Validation
log_step "1️⃣ Environment Validation"

validate_environment() {
    local validation_failed=false
    
    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode command line tools not found"
        log_info "Install with: xcode-select --install"
        validation_failed=true
    else
        local xcode_version=$(xcodebuild -version | head -1)
        log_success "Xcode: ${xcode_version}"
    fi
    
    # Check Rust
    if ! command -v cargo &> /dev/null; then
        log_error "Cargo not found"
        log_info "Install from: https://rustup.rs/"
        validation_failed=true
    else
        local rust_version=$(rustc --version)
        log_success "Rust: ${rust_version}"
    fi
    
    # Check Bun
    if ! command -v bun &> /dev/null; then
        log_error "Bun not found"
        log_info "Install with: curl -fsSL https://bun.sh/install | bash"
        validation_failed=true
    else
        local bun_version=$(bun --version)
        log_success "Bun: ${bun_version}"
    fi
    
    # Check iOS targets
    local missing_targets=()
    for target in aarch64-apple-ios aarch64-apple-ios-sim; do
        if ! rustup target list --installed | grep -q "$target"; then
            missing_targets+=("$target")
        fi
    done
    
    if [ ${#missing_targets[@]} -gt 0 ]; then
        log_warning "Installing missing iOS targets: ${missing_targets[*]}"
        rustup target add "${missing_targets[@]}" || {
            log_error "Failed to install iOS targets"
            validation_failed=true
        }
    fi
    
    # Check disk space (require at least 5GB)
    local available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 5 ]; then
        log_warning "Low disk space: ${available_space}GB available (5GB recommended)"
    fi
    
    if [ "$validation_failed" = true ]; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

validate_environment

# Step 2: Pre-build Frontend
log_step "2️⃣ Frontend Build"

build_frontend() {
    local start_time=$(date +%s)
    
    cd "$FRONTEND_DIR"
    
    log_info "Installing frontend dependencies..."
    bun install --frozen-lockfile || {
        log_error "Failed to install frontend dependencies"
        return 1
    }
    
    log_info "Building frontend for production..."
    NODE_ENV=production bun run build || {
        log_error "Frontend build failed"
        return 1
    }
    
    BUILD_METRICS["frontend"]=$(($(date +%s) - start_time))
    log_success "Frontend built in ${BUILD_METRICS[frontend]}s"
}

build_frontend

# Step 3: Enhanced Rust Pre-build
log_step "3️⃣ Rust Library Pre-build"

prebuild_rust_library() {
    local start_time=$(date +%s)
    
    cd "$SRC_TAUDIR"
    
    # Set iOS-specific environment
    export IPHONEOS_DEPLOYMENT_TARGET=14.0
    export CFLAGS="-miphoneos-version-min=14.0"
    export CXXFLAGS="-miphoneos-version-min=14.0"
    export RUST_BACKTRACE=0
    
    log_info "Pre-warming Rust dependencies..."
    cargo fetch --target aarch64-apple-ios || {
        log_error "Failed to fetch dependencies"
        return 1
    }
    
    log_info "Building Rust library for iOS (aarch64-apple-ios)..."
    cargo build --target aarch64-apple-ios --release --lib || {
        log_error "Rust library build failed"
        return 1
    }
    
    # Verify library was built
    local lib_name="libsrc_tauri_lib.a"
    local rust_lib_path="target/aarch64-apple-ios/release/$lib_name"
    
    if [ ! -f "$rust_lib_path" ]; then
        log_error "Expected library not found: $rust_lib_path"
        log_info "Available libraries:"
        find target/aarch64-apple-ios/release -name "*.a" -type f -exec ls -la {} \;
        return 1
    fi
    
    # Validate library format
    if ! file "$rust_lib_path" | grep -q "ar archive"; then
        log_error "Library is not a valid ar archive: $rust_lib_path"
        return 1
    fi
    
    # Validate architecture
    if ! lipo -info "$rust_lib_path" 2>/dev/null | grep -q "arm64"; then
        log_error "Library not built for arm64: $rust_lib_path"
        return 1
    fi
    
    BUILD_METRICS["rust_prebuild"]=$(($(date +%s) - start_time))
    log_success "Rust library pre-built in ${BUILD_METRICS[rust_prebuild]}s"
    log_info "Library: $lib_name ($(du -h "$rust_lib_path" | cut -f1))"
}

prebuild_rust_library

# Step 4: Enhanced iOS Project Setup
log_step "4️⃣ iOS Project Setup with CI Patches"

setup_ios_project() {
    local start_time=$(date +%s)
    
    cd "$SRC_TAUDIR"
    
    log_info "Initializing iOS project..."
    cargo tauri ios init || {
        log_error "Failed to initialize iOS project"
        return 1
    }
    
    # Create directory structure for pre-built libraries
    log_info "Creating Externals directory structure..."
    mkdir -p gen/apple/Externals/arm64/Release
    mkdir -p gen/apple/Externals/arm64/release
    
    # Copy pre-built library to expected locations
    log_info "Copying pre-built library to Xcode locations..."
    local lib_name="libsrc_tauri_lib.a"
    local rust_lib_path="target/aarch64-apple-ios/release/$lib_name"
    
    cp "$rust_lib_path" gen/apple/Externals/arm64/Release/libapp.a
    cp "$rust_lib_path" gen/apple/Externals/arm64/release/libapp.a
    
    # Verify copies
    if [ ! -f "gen/apple/Externals/arm64/Release/libapp.a" ]; then
        log_error "Failed to copy library to Release location"
        return 1
    fi
    
    log_info "Library copied successfully:"
    ls -la gen/apple/Externals/arm64/Release/
    ls -la gen/apple/Externals/arm64/release/
    
    # Copy configuration files if they exist
    if [ -f "ios-config/ExportOptions.plist" ]; then
        cp ios-config/ExportOptions.plist gen/apple/ExportOptions.plist
        log_info "ExportOptions.plist copied"
    fi
    
    # Apply CI compatibility patches
    log_info "Applying CI compatibility patches..."
    cd gen/apple
    local pbxproj="src-tauri.xcodeproj/project.pbxproj"
    
    if [ ! -f "$pbxproj" ]; then
        log_error "Xcode project file not found: $pbxproj"
        return 1
    fi
    
    # Backup original
    cp "$pbxproj" "$pbxproj.backup"
    
    # Apply patch to skip Rust build in CI
    # This adds a check for pre-built library before running cargo build
    if grep -q "cargo tauri ios xcode-script" "$pbxproj"; then
        log_info "Applying Rust build skip patch..."
        sed -i.bak 's|shellScript = "cargo tauri ios xcode-script|shellScript = "if [ -f \"${SRCROOT}/Externals/arm64/${CONFIGURATION}/libapp.a\" ]; then echo \"CI-Skip: Using pre-built library\"; exit 0; fi; cargo tauri ios xcode-script|' "$pbxproj"
        
        if grep -q "CI-Skip" "$pbxproj"; then
            log_success "Xcode project patched for CI compatibility"
        else
            log_warning "Patch may not have been applied correctly"
        fi
    else
        log_warning "Rust build script pattern not found - Tauri format may have changed"
    fi
    
    # Clean up backup files
    rm -f "$pbxproj.bak"
    
    BUILD_METRICS["xcode_setup"]=$(($(date +%s) - start_time))
    log_success "iOS project setup completed in ${BUILD_METRICS[xcode_setup]}s"
}

setup_ios_project

# Step 5: Validation
log_step "5️⃣ Build Validation"

validate_build_setup() {
    cd "$SRC_TAUDIR"
    
    local validation_failed=false
    
    # Check library exists
    local lib_path="gen/apple/Externals/arm64/Release/libapp.a"
    if [ ! -f "$lib_path" ]; then
        log_error "Pre-built library not found: $lib_path"
        validation_failed=true
    else
        log_success "Library found: $lib_path"
    fi
    
    # Check Xcode project
    if [ ! -f "gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        log_error "Xcode project not found"
        validation_failed=true
    else
        log_success "Xcode project found"
    fi
    
    # Check for CI patch
    if grep -q "CI-Skip" gen/apple/src-tauri.xcodeproj/project.pbxproj; then
        log_success "CI patch applied successfully"
    else
        log_warning "CI patch not found - build may be slower"
    fi
    
    if [ "$validation_failed" = true ]; then
        log_error "Build validation failed"
        exit 1
    fi
    
    log_success "Build validation passed"
}

validate_build_setup

# Step 6: Build Instructions
log_step "6️⃣ Build Instructions"

display_build_instructions() {
    local total_time=$(($(date +%s) - BUILD_START_TIME))
    
    echo ""
    log_success "🎉 Enhanced iOS build preparation completed!"
    echo ""
    echo -e "${BOLD}📊 Build Metrics:${NC}"
    echo "  • Frontend build: ${BUILD_METRICS[frontend]}s"
    echo "  • Rust pre-build: ${BUILD_METRICS[rust_prebuild]}s"
    echo "  • Xcode setup: ${BUILD_METRICS[xcode_setup]}s"
    echo "  • Total preparation: ${total_time}s"
    echo ""
    echo -e "${BOLD}🍎 Next Steps for Xcode Build:${NC}"
    echo "  1. Open Xcode workspace (recommended):"
    echo "     ${CYAN}open ${SRC_TAUDIR}/gen/apple/src-tauri.xcworkspace${NC}"
    echo ""
    echo "  2. In Xcode:"
    echo "     • Select 'src-tauri_iOS' scheme"
    echo "     • Set destination to 'Any iOS Device'"
    echo "     • Verify signing: Apple Developer Team (PCJU8QD9FN)"
    echo "     • Bundle ID: com.agentic-codeflow.opencode-nexus"
    echo ""
    echo "  3. Build and Archive:"
    echo "     • Product → Archive (⌘+B)"
    echo "     • The Rust build phase should skip (CI-Skip message)"
    echo ""
    echo "  4. Distribute to TestFlight:"
    echo "     • Organizer → Distribute App → App Store Connect"
    echo ""
    echo -e "${BOLD}🚀 Or use automated CI/CD:${NC}"
    echo "     ${CYAN}git tag ios-v1.0.0 && git push origin ios-v1.0.0${NC}"
    echo ""
    echo -e "${BOLD}🔧 Troubleshooting:${NC}"
    echo "  • If Rust build runs: Check libapp.a exists in Externals/"
    echo "  • Code signing errors: Verify certificate and profile"
    echo "  • Archive failures: Check iOS deployment target (14.0)"
    echo ""
}

display_build_instructions

log_success "Enhanced iOS build script completed successfully!"