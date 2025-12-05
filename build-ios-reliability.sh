#!/bin/bash
# iOS Build Reliability Script for OpenCode Nexus
# Addresses all known iOS build issues and provides comprehensive fixes

set -euo pipefail

# Enhanced error handling with detailed diagnostics
error_handler() {
    local line_number=$1
    local error_code=$2
    echo -e "\033[0;31m💥 CRITICAL ERROR: Failed at line $line_number with exit code $error_code\033[0m" >&2
    echo -e "\033[1;33m🔍 Immediate diagnostics:\033[0m" >&2
    echo "  • Working directory: $(pwd)" >&2
    echo "  • Available disk space: $(df -h . | awk 'NR==2 {print $4}')" >&2
    echo "  • Memory usage: $(vm_stat | grep 'Pages free' | awk '{print $3}' | sed 's/\.//')" >&2
    echo "  • Git status: $(git status --porcelain 2>/dev/null | wc -l) files modified" >&2
    echo -e "\033[1;33m🛠️ Common solutions:\033[0m" >&2
    echo "  1. Clean build: rm -rf src-tauri/target frontend/dist" >&2
    echo "  2. Reinstall tools: rustup update, bun upgrade" >&2
    echo "  3. Check Xcode: xcode-select --install" >&2
    echo "  4. Verify network: ping google.com" >&2
    exit $error_code
}

trap 'error_handler ${LINENO} $?' ERR

# Colors and enhanced formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Progress indicators
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}[WORKING]${NC} %s %s" "$message" "${SPINNER[i]}"
        sleep $delay
        i=$(( (i + 1) % 10 ))
    done
    printf "\r${GREEN}[DONE]${NC} %s\n" "$message"
}

# Logging functions with timestamps
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }
log_step() { echo -e "\n${CYAN}${BOLD}[STEP]${NC} $1"; }
log_debug() { echo -e "${DIM}[DEBUG]${NC} $(date '+%H:%M:%S') $1" >&2; }

# Configuration
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SRC_TAUDIR="${PROJECT_ROOT}/src-tauri"
readonly FRONTEND_DIR="${PROJECT_ROOT}/frontend"
readonly BUILD_START_TIME=$(date +%s)
readonly LOG_FILE="${PROJECT_ROOT}/ios-build-$(date +%Y%m%d-%H%M%S).log"

# Build metrics and health monitoring
declare -A BUILD_METRICS=(
    ["environment_check"]=0
    ["dependency_install"]=0
    ["frontend_build"]=0
    ["rust_prebuild"]=0
    ["xcode_setup"]=0
    ["validation"]=0
    ["total"]=0
)

declare -A HEALTH_CHECKS=(
    ["disk_space"]=0
    ["memory"]=0
    ["network"]=0
    ["tools"]=0
)

# Health monitoring functions
check_disk_space() {
    local available_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    local required_gb=5
    
    log_debug "Disk space check: ${available_gb}GB available, ${required_gb}GB required"
    
    if [ "$available_gb" -lt $required_gb ]; then
        log_warning "Low disk space: ${available_gb}GB available (need ${required_gb}GB)"
        HEALTH_CHECKS["disk_space"]=1
        return 1
    fi
    
    HEALTH_CHECKS["disk_space"]=0
    return 0
}

check_memory() {
    local free_pages=$(vm_stat | grep 'Pages free' | awk '{print $3}' | sed 's/\.//')
    local free_mb=$((free_pages * 4096 / 1024 / 1024))
    local required_mb=2048
    
    log_debug "Memory check: ${free_mb}MB free, ${required_mb}MB required"
    
    if [ "$free_mb" -lt $required_mb ]; then
        log_warning "Low memory: ${free_mb}MB free (recommend ${required_mb}MB)"
        HEALTH_CHECKS["memory"]=1
        return 1
    fi
    
    HEALTH_CHECKS["memory"]=0
    return 0
}

check_network() {
    log_debug "Network connectivity check"
    
    if ! ping -c 1 -W 5000 google.com >/dev/null 2>&1; then
        log_warning "Network connectivity issues detected"
        HEALTH_CHECKS["network"]=1
        return 1
    fi
    
    HEALTH_CHECKS["network"]=0
    return 0
}

check_tools() {
    local tools_missing=()
    
    for tool in xcodebuild cargo bun; do
        if ! command -v "$tool" &> /dev/null; then
            tools_missing+=("$tool")
        fi
    done
    
    if [ ${#tools_missing[@]} -gt 0 ]; then
        log_error "Missing tools: ${tools_missing[*]}"
        HEALTH_CHECKS["tools"]=1
        return 1
    fi
    
    HEALTH_CHECKS["tools"]=0
    return 0
}

# Comprehensive environment validation
validate_environment() {
    local start_time=$(date +%s)
    log_step "🔍 Comprehensive Environment Validation"
    
    # Run health checks
    log_info "Running system health checks..."
    check_disk_space
    check_memory
    check_network
    check_tools
    
    # Report health status
    local health_issues=0
    for check in "${!HEALTH_CHECKS[@]}"; do
        if [ "${HEALTH_CHECKS[$check]}" -ne 0 ]; then
            ((health_issues++))
        fi
    done
    
    if [ $health_issues -gt 0 ]; then
        log_warning "$health_issues health issues detected - build may be affected"
    else
        log_success "All system health checks passed"
    fi
    
    # Detailed tool validation
    log_info "Validating development tools..."
    
    # Xcode validation
    local xcode_version=$(xcodebuild -version 2>/dev/null | head -1 || echo "Not found")
    log_info "Xcode: $xcode_version"
    
    # Rust validation
    local rust_version=$(rustc --version 2>/dev/null || echo "Not found")
    log_info "Rust: $rust_version"
    
    # Bun validation
    local bun_version=$(bun --version 2>/dev/null || echo "Not found")
    log_info "Bun: $bun_version"
    
    # iOS targets validation
    log_info "Checking iOS Rust targets..."
    local missing_targets=()
    local required_targets=("aarch64-apple-ios" "aarch64-apple-ios-sim")
    
    for target in "${required_targets[@]}"; do
        if ! rustup target list --installed | grep -q "$target"; then
            missing_targets+=("$target")
        fi
    done
    
    if [ ${#missing_targets[@]} -gt 0 ]; then
        log_info "Installing missing iOS targets: ${missing_targets[*]}"
        rustup target add "${missing_targets[@]}" || {
            log_error "Failed to install iOS targets"
            return 1
        }
    fi
    
    # Certificate and provisioning check (optional)
    log_info "Checking for iOS development certificates..."
    if security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
        log_success "iOS distribution certificates found"
    else
        log_warning "No iOS distribution certificates found (may need manual setup)"
    fi
    
    BUILD_METRICS["environment_check"]=$(($(date +%s) - start_time))
    log_success "Environment validation completed in ${BUILD_METRICS[environment_check]}s"
}

# Enhanced dependency management
setup_dependencies() {
    local start_time=$(date +%s)
    log_step "📦 Enhanced Dependency Setup"
    
    cd "$SRC_TAUDIR"
    
    log_info "Pre-warming Rust dependencies..."
    cargo fetch --target aarch64-apple-ios &
    local cargo_pid=$!
    show_spinner $cargo_pid "Fetching Rust dependencies"
    wait $cargo_pid
    
    log_info "Checking Rust dependencies..."
    cargo check --target aarch64-apple-ios &
    local check_pid=$!
    show_spinner $check_pid "Checking Rust dependencies"
    wait $check_pid
    
    cd "$FRONTEND_DIR"
    
    log_info "Installing frontend dependencies..."
    bun install --frozen-lockfile &
    local bun_pid=$!
    show_spinner $bun_pid "Installing frontend dependencies"
    wait $bun_pid
    
    BUILD_METRICS["dependency_install"]=$(($(date +%s) - start_time))
    log_success "Dependencies setup completed in ${BUILD_METRICS[dependency_install]}s"
}

# Robust frontend build
build_frontend() {
    local start_time=$(date +%s)
    log_step "🎨 Frontend Build"
    
    cd "$FRONTEND_DIR"
    
    # Clean previous builds
    if [ -d "dist" ]; then
        log_info "Cleaning previous frontend build..."
        rm -rf dist
    fi
    
    log_info "Building frontend for production..."
    NODE_ENV=production bun run build &
    local build_pid=$!
    show_spinner $build_pid "Building frontend"
    wait $build_pid
    
    # Validate build output
    if [ ! -f "dist/index.html" ]; then
        log_error "Frontend build failed - no index.html found"
        return 1
    fi
    
    BUILD_METRICS["frontend_build"]=$(($(date +%s) - start_time))
    log_success "Frontend built in ${BUILD_METRICS[frontend_build]}s"
}

# Enhanced Rust pre-build with error recovery
prebuild_rust_library() {
    local start_time=$(date +%s)
    log_step "🦀 Rust Library Pre-build"
    
    cd "$SRC_TAUDIR"
    
    # Set iOS-specific environment
    export IPHONEOS_DEPLOYMENT_TARGET=14.0
    export CFLAGS="-miphoneos-version-min=14.0"
    export CXXFLAGS="-miphoneos-version-min=14.0"
    export RUST_BACKTRACE=0
    export RUST_LOG="warn"
    
    # Clean previous builds
    log_info "Cleaning previous Rust builds..."
    cargo clean --target aarch64-apple-ios --release 2>/dev/null || true
    
    log_info "Building Rust library for iOS..."
    cargo build --target aarch64-apple-ios --release --lib &
    local rust_pid=$!
    show_spinner $rust_pid "Building Rust library"
    wait $rust_pid
    
    # Comprehensive library validation
    local lib_name="libsrc_tauri_lib.a"
    local rust_lib_path="target/aarch64-apple-ios/release/$lib_name"
    
    log_info "Validating built library..."
    
    if [ ! -f "$rust_lib_path" ]; then
        log_error "Library not found: $rust_lib_path"
        log_info "Available files in target directory:"
        find target/aarch64-apple-ios/release -name "*.a" -type f -exec ls -la {} \; 2>/dev/null || true
        return 1
    fi
    
    # Format validation
    if ! file "$rust_lib_path" | grep -q "ar archive"; then
        log_error "Invalid library format: $rust_lib_path"
        return 1
    fi
    
    # Architecture validation
    if ! lipo -info "$rust_lib_path" 2>/dev/null | grep -q "arm64"; then
        log_error "Library not built for arm64: $rust_lib_path"
        return 1
    fi
    
    # Size validation (should be reasonable)
    local lib_size=$(du -m "$rust_lib_path" | cut -f1)
    if [ "$lib_size" -gt 100 ]; then
        log_warning "Large library size: ${lib_size}MB (may affect app size)"
    fi
    
    BUILD_METRICS["rust_prebuild"]=$(($(date +%s) - start_time))
    log_success "Rust library pre-built in ${BUILD_METRICS[rust_prebuild]}s (${lib_size}MB)"
}

# Enhanced iOS project setup
setup_ios_project() {
    local start_time=$(date +%s)
    log_step "🍎 iOS Project Setup with CI Optimization"
    
    cd "$SRC_TAUDIR"
    
    # Clean previous iOS projects
    if [ -d "gen/apple" ]; then
        log_info "Cleaning previous iOS project..."
        rm -rf gen/apple
    fi
    
    log_info "Initializing iOS project..."
    cargo tauri ios init &
    local init_pid=$!
    show_spinner $init_pid "Initializing iOS project"
    wait $init_pid
    
    # Create directory structure
    log_info "Creating Externals directory structure..."
    mkdir -p gen/apple/Externals/arm64/Release
    mkdir -p gen/apple/Externals/arm64/release
    
    # Copy pre-built library
    log_info "Copying pre-built library..."
    local lib_name="libsrc_tauri_lib.a"
    local rust_lib_path="target/aarch64-apple-ios/release/$lib_name"
    
    cp "$rust_lib_path" gen/apple/Externals/arm64/Release/libapp.a
    cp "$rust_lib_path" gen/apple/Externals/arm64/release/libapp.a
    
    # Copy configuration files
    if [ -f "ios-config/ExportOptions.plist" ]; then
        cp ios-config/ExportOptions.plist gen/apple/ExportOptions.plist
        log_info "ExportOptions.plist copied"
    fi
    
    # Apply CI patches
    log_info "Applying CI optimization patches..."
    cd gen/apple
    local pbxproj="src-tauri.xcodeproj/project.pbxproj"
    
    if [ ! -f "$pbxproj" ]; then
        log_error "Xcode project file not found"
        return 1
    fi
    
    # Backup and patch
    cp "$pbxproj" "$pbxproj.backup"
    
    # Apply the CI skip patch
    if grep -q "cargo tauri ios xcode-script" "$pbxproj"; then
        log_info "Applying Rust build optimization patch..."
        sed -i.bak 's|shellScript = "cargo tauri ios xcode-script|shellScript = "if [ -f \"${SRCROOT}/Externals/arm64/${CONFIGURATION}/libapp.a\" ]; then echo \"🚀 CI-Skip: Using pre-built library\"; exit 0; fi; cargo tauri ios xcode-script|' "$pbxproj"
        
        if grep -q "CI-Skip" "$pbxproj"; then
            log_success "CI optimization patch applied"
        else
            log_warning "CI patch may not have been applied correctly"
        fi
    fi
    
    # Clean up
    rm -f "$pbxproj.bak"
    
    BUILD_METRICS["xcode_setup"]=$(($(date +%s) - start_time))
    log_success "iOS project setup completed in ${BUILD_METRICS[xcode_setup]}s"
}

# Comprehensive validation
validate_build() {
    local start_time=$(date +%s)
    log_step "✅ Comprehensive Build Validation"
    
    cd "$SRC_TAUDIR"
    
    local validation_errors=0
    
    # Library validation
    local lib_path="gen/apple/Externals/arm64/Release/libapp.a"
    if [ -f "$lib_path" ]; then
        log_success "Pre-built library found: $lib_path"
        
        # Additional library checks
        local lib_size=$(du -h "$lib_path" | cut -f1)
        log_info "Library size: $lib_size"
    else
        log_error "Pre-built library not found: $lib_path"
        ((validation_errors++))
    fi
    
    # Xcode project validation
    if [ -f "gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        log_success "Xcode project found"
        
        # Check for CI patch
        if grep -q "CI-Skip" gen/apple/src-tauri.xcodeproj/project.pbxproj; then
            log_success "CI optimization patch applied"
        else
            log_warning "CI patch not found - build may be slower"
        fi
    else
        log_error "Xcode project not found"
        ((validation_errors++))
    fi
    
    # Frontend validation
    if [ -f "$FRONTEND_DIR/dist/index.html" ]; then
        log_success "Frontend build found"
    else
        log_error "Frontend build not found"
        ((validation_errors++))
    fi
    
    # Configuration validation
    if grep -q "com.agentic-codeflow.opencode-nexus" tauri.conf.json; then
        log_success "Bundle identifier configured"
    else
        log_error "Bundle identifier not configured"
        ((validation_errors++))
    fi
    
    if [ $validation_errors -gt 0 ]; then
        log_error "Build validation failed with $validation_errors errors"
        return 1
    fi
    
    BUILD_METRICS["validation"]=$(($(date +%s) - start_time))
    log_success "Build validation completed in ${BUILD_METRICS[validation]}s"
}

# Generate comprehensive report
generate_report() {
    local total_time=$(($(date +%s) - BUILD_START_TIME))
    BUILD_METRICS["total"]=$total_time
    
    log_step "📊 Build Report & Next Steps"
    
    echo ""
    echo -e "${BOLD}🎉 Enhanced iOS Build Completed Successfully!${NC}"
    echo ""
    echo -e "${BOLD}⏱️ Build Metrics:${NC}"
    echo "  • Environment check: ${BUILD_METRICS[environment_check]}s"
    echo "  • Dependencies: ${BUILD_METRICS[dependency_install]}s"
    echo "  • Frontend build: ${BUILD_METRICS[frontend_build]}s"
    echo "  • Rust pre-build: ${BUILD_METRICS[rust_prebuild]}s"
    echo "  • Xcode setup: ${BUILD_METRICS[xcode_setup]}s"
    echo "  • Validation: ${BUILD_METRICS[validation]}s"
    echo "  • ${BOLD}Total time: ${BUILD_METRICS[total]}s${NC}"
    echo ""
    
    echo -e "${BOLD}🏥 System Health:${NC}"
    for check in "${!HEALTH_CHECKS[@]}"; do
        local status="${HEALTH_CHECKS[$check]}"
        if [ "$status" -eq 0 ]; then
            echo "  • $check: ${GREEN}✅ OK${NC}"
        else
            echo "  • $check: ${YELLOW}⚠️ Warning${NC}"
        fi
    done
    echo ""
    
    echo -e "${BOLD}🍎 Xcode Build Instructions:${NC}"
    echo "  1. Open Xcode workspace:"
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
    echo "     • Look for '🚀 CI-Skip' message in build log"
    echo ""
    echo "  4. Distribute to TestFlight:"
    echo "     • Organizer → Distribute App → App Store Connect"
    echo ""
    
    echo -e "${BOLD}🚀 Automated CI/CD:${NC}"
    echo "     ${CYAN}git tag ios-v1.0.0 && git push origin ios-v1.0.0${NC}"
    echo ""
    
    echo -e "${BOLD}🔧 Troubleshooting:${NC}"
    echo "  • If Rust build runs: Check libapp.a in Externals/"
    echo "  • Code signing errors: Verify certificate and profile"
    echo "  • Build failures: Check iOS deployment target (14.0)"
    echo "  • TCP socket errors: Should be resolved with pre-build"
    echo ""
    
    echo -e "${BOLD}📝 Log file:${NC}"
    echo "     ${CYAN}$LOG_FILE${NC}"
    echo ""
    
    log_success "Enhanced iOS build reliability script completed!"
}

# Main execution
main() {
    echo -e "${BOLD}🚀 iOS Build Reliability Script for OpenCode Nexus${NC}"
    echo "=================================================="
    log_info "Build started at $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Log file: $LOG_FILE"
    
    # Redirect all output to log file
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    
    validate_environment
    setup_dependencies
    build_frontend
    prebuild_rust_library
    setup_ios_project
    validate_build
    generate_report
}

# Run main function
main "$@"