#!/bin/bash
# Enhanced iOS Build Script with Error Handling and Logging
# Provides comprehensive error handling, logging, and recovery mechanisms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
BUILD_LOG="$LOG_DIR/ios-build-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="$LOG_DIR/ios-errors-$(date +%Y%m%d-%H%M%S).log"
TIMING_LOG="$LOG_DIR/ios-timing-$(date +%Y%m%d-%H%M%S).log"

# Build state
BUILD_STATE_FILE="$LOG_DIR/.build-state"
RETRY_COUNT=0
MAX_RETRIES=3
BUILD_PHASE="initialization"

# Function to print colored output with timestamps
print_with_timestamp() {
    local color=$1
    local prefix=$2
    local message=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}[$timestamp]${NC} ${color}${prefix}${NC} $message" | tee -a "$BUILD_LOG"
}

print_status() {
    print_with_timestamp "$BLUE" "[INFO]" "$1"
}

print_success() {
    print_with_timestamp "$GREEN" "[SUCCESS]" "$1"
}

print_warning() {
    print_with_timestamp "$YELLOW" "[WARNING]" "$1"
}

print_error() {
    print_with_timestamp "$RED" "[ERROR]" "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$ERROR_LOG"
}

print_debug() {
    if [[ "${RUST_LOG:-info}" == "debug" || "${RUST_LOG:-info}" == "trace" ]]; then
        print_with_timestamp "$PURPLE" "[DEBUG]" "$1"
    fi
}

print_timing() {
    local phase=$1
    local duration=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,$phase,$duration" >> "$TIMING_LOG"
    print_with_timestamp "$CYAN" "[TIMING]" "$phase: ${duration}s"
}

# Error handling functions
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    print_error "Script failed with exit code $exit_code at line $line_number"
    print_error "Failed command: $command"
    print_error "Current phase: $BUILD_PHASE"
    
    # Save build state
    save_build_state "failed" "$exit_code" "$line_number" "$command"
    
    # Attempt error recovery
    attempt_error_recovery "$exit_code" "$line_number" "$command"
    
    # Generate error report
    generate_error_report "$exit_code" "$line_number" "$command"
    
    cleanup_on_error
    
    exit "$exit_code"
}

save_build_state() {
    local status=$1
    local exit_code=${2:-0}
    local line_number=${3:-0}
    local command=${4:-""}
    
    cat > "$BUILD_STATE_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "status": "$status",
    "exit_code": $exit_code,
    "line_number": $line_number,
    "command": "$command",
    "phase": "$BUILD_PHASE",
    "retry_count": $RETRY_COUNT,
    "build_log": "$BUILD_LOG",
    "error_log": "$ERROR_LOG",
    "timing_log": "$TIMING_LOG"
}
EOF
}

attempt_error_recovery() {
    local exit_code=$1
    local line_number=$2
    local command=$3
    
    print_status "Attempting error recovery..."
    
    case $exit_code in
        1)
            # General error - retry if under limit
            if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
                print_warning "Retrying build (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."
                ((RETRY_COUNT++))
                sleep 5
                return 0
            fi
            ;;
        2)
            # Missing dependencies
            print_status "Attempting to install missing dependencies..."
            install_missing_dependencies
            return 0
            ;;
        127)
            # Command not found
            print_status "Installing missing tools..."
            install_missing_tools "$command"
            return 0
            ;;
        *)
            print_warning "No automatic recovery available for exit code $exit_code"
            ;;
    esac
    
    return 1
}

install_missing_dependencies() {
    print_status "Installing missing dependencies..."
    
    # Install Rust targets if missing
    if ! rustup target list --installed | grep -q "aarch64-apple-ios"; then
        print_status "Installing aarch64-apple-ios target..."
        rustup target add aarch64-apple-ios
    fi
    
    if ! rustup target list --installed | grep -q "aarch64-apple-ios-sim"; then
        print_status "Installing aarch64-apple-ios-sim target..."
        rustup target add aarch64-apple-ios-sim
    fi
    
    # Install CocoaPods if missing
    if ! command -v pod &> /dev/null; then
        print_status "Installing CocoaPods..."
        sudo gem install cocoapods
    fi
    
    # Install Bun if missing
    if ! command -v bun &> /dev/null; then
        print_status "Installing Bun..."
        curl -fsSL https://bun.sh/install | bash
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
    fi
}

install_missing_tools() {
    local command=$1
    
    case $command in
        *cargo*)
            print_status "Installing Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
            ;;
        *bun*)
            print_status "Installing Bun..."
            curl -fsSL https://bun.sh/install | bash
            ;;
        *pod*)
            print_status "Installing CocoaPods..."
            sudo gem install cocoapods
            ;;
        *xcodebuild*)
            print_error "Xcode must be installed manually from the App Store"
            ;;
        *)
            print_warning "Unknown tool: $command"
            ;;
    esac
}

generate_error_report() {
    local exit_code=$1
    local line_number=$2
    local command=$3
    
    local report_file="$LOG_DIR/error-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# iOS Build Error Report

**Generated**: $(date)
**Exit Code**: $exit_code
**Line Number**: $line_number
**Failed Command**: $command
**Build Phase**: $BUILD_PHASE
**Retry Count**: $RETRY_COUNT

## Environment Information

**Operating System**: $(uname -s) $(uname -r)
**Shell**: $SHELL
**Working Directory**: $(pwd)
**User**: $(whoami)

## Build Configuration

**Rust Version**: $(rustc --version 2>/dev/null || echo "Not installed")
**Cargo Version**: $(cargo --version 2>/dev/null || echo "Not installed")
**Bun Version**: $(bun --version 2>/dev/null || echo "Not installed")
**Xcode Version**: $(xcodebuild -version 2>/dev/null | head -n1 || echo "Not installed")
**CocoaPods Version**: $(pod --version 2>/dev/null || echo "Not installed")

## iOS Targets

\`\`\`
$(rustup target list --installed 2>/dev/null || echo "Rust not available")
\`\`\`

## Recent Log Entries

**Build Log (last 20 lines)**:
\`\`\`
$(tail -20 "$BUILD_LOG" 2>/dev/null || echo "No build log available")
\`\`\`

**Error Log (last 20 lines)**:
\`\`\`
$(tail -20 "$ERROR_LOG" 2>/dev/null || echo "No error log available")
\`\`\`

## Timing Information

**Build Timing**:
\`\`\`
$(cat "$TIMING_LOG" 2>/dev/null || echo "No timing data available")
\`\`\`

## Troubleshooting Steps

1. **Check Dependencies**: Ensure all required tools are installed
2. **Verify Environment**: Run \`./scripts/validate-ios-env.sh\`
3. **Clean Build**: Try cleaning the build directory
4. **Update Tools**: Update Rust, Bun, and Xcode to latest versions
5. **Check Permissions**: Ensure proper file permissions and code signing

## Recovery Actions

EOF

    if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
        echo "- **Retry Available**: Build can be retried ($((MAX_RETRIES - RETRY_COUNT)) attempts remaining)" >> "$report_file"
    else
        echo "- **No More Retries**: Maximum retry attempts reached" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Next Steps

1. Review the error logs above
2. Check the build configuration
3. Verify all prerequisites are met
4. Try the suggested troubleshooting steps
5. Contact support if issues persist

---
*Report generated by iOS build system*
EOF

    print_status "Error report generated: $report_file"
}

cleanup_on_error() {
    print_status "Performing cleanup..."
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Clean up temporary files
    find /tmp -name "ios-build-*" -user "$(whoami)" -mtime +1 -delete 2>/dev/null || true
    
    # Reset environment variables
    unset RUST_BACKTRACE
    unset RUST_LOG
    
    print_status "Cleanup completed"
}

# Setup logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    
    # Create log files
    touch "$BUILD_LOG" "$ERROR_LOG" "$TIMING_LOG"
    
    print_status "Logging initialized:"
    echo "  Build log: $BUILD_LOG"
    echo "  Error log: $ERROR_LOG"
    echo "  Timing log: $TIMING_LOG"
}

# Phase timing functions
start_phase_timer() {
    BUILD_PHASE=$1
    PHASE_START_TIME=$(date +%s)
    print_status "Starting phase: $BUILD_PHASE"
}

end_phase_timer() {
    local phase_end_time=$(date +%s)
    local phase_duration=$((phase_end_time - PHASE_START_TIME))
    print_timing "$BUILD_PHASE" "$phase_duration"
}

# Validation functions
validate_prerequisites() {
    start_phase_timer "prerequisite_validation"
    
    print_status "Validating prerequisites..."
    
    local validation_errors=0
    
    # Check macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "iOS builds require macOS"
        ((validation_errors++))
    fi
    
    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode not found"
        ((validation_errors++))
    else
        local xcode_version=$(xcodebuild -version | head -n1 | awk '{print $2}')
        print_status "Xcode version: $xcode_version"
    fi
    
    # Check Rust
    if ! command -v cargo &> /dev/null; then
        print_error "Rust/Cargo not found"
        ((validation_errors++))
    else
        local rust_version=$(rustc --version)
        print_status "Rust version: $rust_version"
    fi
    
    # Check Bun
    if ! command -v bun &> /dev/null; then
        print_error "Bun not found"
        ((validation_errors++))
    else
        local bun_version=$(bun --version)
        print_status "Bun version: $bun_version"
    fi
    
    # Check iOS targets
    if command -v rustup &> /dev/null; then
        local ios_targets=$(rustup target list --installed | grep ios | wc -l)
        print_status "iOS targets installed: $ios_targets"
        
        if [[ $ios_targets -lt 3 ]]; then
            print_warning "Some iOS targets may be missing"
        fi
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        print_error "$validation_errors prerequisite validation errors found"
        save_build_state "validation_failed" "$validation_errors" "0" "prerequisite_validation"
        exit 1
    fi
    
    print_success "Prerequisite validation passed"
    end_phase_timer
}

# Main build functions
build_frontend() {
    start_phase_timer "frontend_build"
    
    print_status "Building frontend..."
    cd "$PROJECT_ROOT/frontend"
    
    # Install dependencies
    print_status "Installing frontend dependencies..."
    if ! bun install --frozen-lockfile; then
        print_error "Frontend dependency installation failed"
        return 1
    fi
    
    # Build frontend
    print_status "Building frontend for production..."
    if ! bun run build; then
        print_error "Frontend build failed"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    print_success "Frontend build completed"
    end_phase_timer
}

build_rust() {
    local target=${1:-aarch64-apple-ios}
    local profile=${2:-release}
    
    start_phase_timer "rust_build"
    
    print_status "Building Rust code for $target ($profile)..."
    cd "$PROJECT_ROOT/src-tauri"
    
    # Set environment variables
    export IPHONEOS_DEPLOYMENT_TARGET=14.0
    export CFLAGS="-miphoneos-version-min=14.0"
    export CXXFLAGS="-miphoneos-version-min=14.0"
    export RUST_BACKTRACE=1
    
    # Build Rust code
    if ! cargo build --target "$target" --profile "$profile"; then
        print_error "Rust build failed for $target"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    print_success "Rust build completed for $target"
    end_phase_timer
}

build_ios_app() {
    local profile=${1:-release}
    
    start_phase_timer "ios_build"
    
    print_status "Building iOS app..."
    cd "$PROJECT_ROOT/src-tauri"
    
    # Initialize iOS project if needed
    if [[ ! -d "gen/apple/src-tauri.xcodeproj" ]]; then
        print_status "Initializing iOS project..."
        if ! cargo tauri ios init; then
            print_error "iOS project initialization failed"
            return 1
        fi
    fi
    
    # Install CocoaPods dependencies
    if [[ -d "gen/apple" && -f "gen/apple/Podfile" ]]; then
        print_status "Installing CocoaPods dependencies..."
        cd gen/apple
        if ! pod install --repo-update; then
            print_warning "CocoaPods install failed, trying without repo update..."
            if ! pod install; then
                print_error "CocoaPods installation failed"
                return 1
            fi
        fi
        cd ../..
    fi
    
    # Build iOS app
    print_status "Building iOS app with Tauri..."
    if ! cargo tauri ios build --profile "$profile" --verbose; then
        print_error "iOS app build failed"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    print_success "iOS app build completed"
    end_phase_timer
}

# Main execution function
main() {
    local build_type=${1:-release}
    local target=${2:-aarch64-apple-ios}
    
    # Setup error handling
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
    trap 'cleanup_on_error' EXIT
    
    # Initialize
    setup_logging
    save_build_state "started" "0" "0" "main"
    
    print_status "Starting enhanced iOS build..."
    echo "=================================="
    echo "Build Type: $build_type"
    echo "Target: $target"
    echo "Log Directory: $LOG_DIR"
    echo "=================================="
    
    local total_start_time=$(date +%s)
    
    # Execute build phases
    validate_prerequisites
    build_frontend
    build_rust "$target" "$build_type"
    build_ios_app "$build_type"
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    print_timing "total_build" "$total_duration"
    
    # Success
    save_build_state "completed" "0" "0" "main"
    
    print_success "iOS build completed successfully in ${total_duration}s!"
    echo ""
    echo "📊 Build Summary:"
    echo "  - Total time: ${total_duration}s"
    echo "  - Build type: $build_type"
    echo "  - Target: $target"
    echo "  - Logs: $LOG_DIR"
    echo ""
    echo "📱 Build Artifacts:"
    echo "  - iOS App: src-tauri/gen/apple/build/Build/Products/"
    echo "  - Archive: src-tauri/gen/apple/build/archives/"
    echo "  - IPA: Generated after export"
    echo ""
    
    # Generate success report
    generate_success_report "$total_duration" "$build_type" "$target"
}

generate_success_report() {
    local duration=$1
    local build_type=$2
    local target=$3
    
    local report_file="$LOG_DIR/success-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# iOS Build Success Report

**Generated**: $(date)
**Build Duration**: ${duration}s
**Build Type**: $build_type
**Target**: $target

## Build Phases

EOF
    
    # Add timing information
    if [[ -f "$TIMING_LOG" ]]; then
        while IFS=',' read -r timestamp phase duration; do
            echo "- **$phase**: ${duration}s" >> "$report_file"
        done < "$TIMING_LOG"
    fi
    
    cat >> "$report_file" << EOF

## Build Artifacts

- **iOS App**: Available in \`src-tauri/gen/apple/build/Build/Products/\`
- **Archive**: Available in \`src-tauri/gen/apple/build/archives/\`
- **IPA**: Ready for TestFlight upload

## Next Steps

1. **Test on Simulator**: Use Xcode to run on iOS simulator
2. **Archive for Distribution**: Create archive for App Store
3. **Upload to TestFlight**: Distribute to beta testers
4. **Deploy to App Store**: Submit for review and release

## Performance Metrics

- **Build Success**: ✅
- **Error Count**: 0
- **Retry Count**: $RETRY_COUNT
- **Cache Hit**: Check build logs for caching efficiency

---
*Report generated by iOS build system*
EOF

    print_status "Success report generated: $report_file"
}

# Parse command line arguments
BUILD_TYPE="release"
TARGET="aarch64-apple-ios"

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug           Build in debug mode (default: release)"
            echo "  --target TARGET    Rust target (default: aarch64-apple-ios)"
            echo "  --help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Release build for iOS device"
            echo "  $0 --debug           # Debug build for iOS device"
            echo "  $0 --target aarch64-apple-ios-sim  # Build for iOS simulator"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main "$BUILD_TYPE" "$TARGET"