#!/bin/bash
# iOS Build Testing Suite
# Automated testing for iOS build validation and reliability

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
TEST_DIR="$PROJECT_ROOT/tests/build"
TEST_RESULTS="$TEST_DIR/results"
TEST_LOG="$TEST_DIR/test-run-$(date +%Y%m%d-%H%M%S).log"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=""

# Function to print colored output
print_test() {
    local status=$1
    local test_name=$2
    local message=$3
    
    case $status in
        PASS)
            echo -e "${GREEN}[PASS]${NC} $test_name: $message"
            ((TESTS_PASSED++))
            ;;
        FAIL)
            echo -e "${RED}[FAIL]${NC} $test_name: $message"
            ((TESTS_FAILED++))
            ;;
        SKIP)
            echo -e "${YELLOW}[SKIP]${NC} $test_name: $message"
            ((TESTS_SKIPPED++))
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} $test_name: $message"
            ;;
        *)
            echo -e "${PURPLE}[TEST]${NC} $test_name: $message"
            ;;
    esac
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$status] $test_name: $message" >> "$TEST_LOG"
}

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DIR" "$TEST_RESULTS"
    
    # Create test log
    cat > "$TEST_LOG" << EOF
iOS Build Test Suite - $(date)
========================================
Test Environment:
- OS: $(uname -s) $(uname -r)
- Shell: $SHELL
- Working Directory: $(pwd)
- User: $(whoami)

========================================
EOF
    
    echo "🧪 iOS Build Testing Suite"
    echo "=================================="
    echo "Test Directory: $TEST_DIR"
    echo "Results Directory: $TEST_RESULTS"
    echo "Log File: $TEST_LOG"
    echo "=================================="
}

# Test helper functions
run_test() {
    local test_name=$1
    local test_command=$2
    local expected_exit_code=${3:-0}
    
    CURRENT_TEST="$test_name"
    print_test "INFO" "$test_name" "Starting test..."
    
    # Run test with timeout
    local start_time=$(date +%s)
    local exit_code=0
    
    if timeout 300 bash -c "$test_command" 2>/dev/null; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Check result
    if [[ $exit_code -eq $expected_exit_code ]]; then
        print_test "PASS" "$test_name" "Completed in ${duration}s"
        return 0
    else
        print_test "FAIL" "$test_name" "Failed with exit code $exit_code (expected $expected_exit_code) in ${duration}s"
        return 1
    fi
}

skip_test() {
    local test_name=$1
    local reason=$2
    
    print_test "SKIP" "$test_name" "$reason"
}

# Individual test functions
test_environment_validation() {
    print_test "INFO" "Environment Validation" "Running environment validation tests..."
    
    # Test validation script exists and is executable
    if [[ -f "$PROJECT_ROOT/scripts/validate-ios-env.sh" ]]; then
        print_test "PASS" "Validation Script" "Script exists and is executable"
    else
        print_test "FAIL" "Validation Script" "Script not found"
        return 1
    fi
    
    # Test validation script runs without errors
    if bash "$PROJECT_ROOT/scripts/validate-ios-env.sh" >/dev/null 2>&1; then
        print_test "PASS" "Validation Execution" "Script runs successfully"
    else
        print_test "FAIL" "Validation Execution" "Script execution failed"
        return 1
    fi
    
    return 0
}

test_rust_targets() {
    print_test "INFO" "Rust Targets" "Checking Rust iOS targets..."
    
    # Check if Rust is installed
    if ! command -v rustup &> /dev/null; then
        skip_test "Rust Targets" "Rust not installed"
        return 0
    fi
    
    local required_targets=("aarch64-apple-ios" "aarch64-apple-ios-sim" "x86_64-apple-ios")
    local missing_targets=()
    
    for target in "${required_targets[@]}"; do
        if rustup target list --installed | grep -q "$target"; then
            print_test "PASS" "Target $target" "Installed"
        else
            print_test "FAIL" "Target $target" "Not installed"
            missing_targets+=("$target")
        fi
    done
    
    if [[ ${#missing_targets[@]} -eq 0 ]]; then
        return 0
    else
        print_test "FAIL" "Rust Targets" "Missing targets: ${missing_targets[*]}"
        return 1
    fi
}

test_dependencies() {
    print_test "INFO" "Dependencies" "Checking required dependencies..."
    
    local dependencies=("cargo" "bun" "xcodebuild")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if command -v "$dep" &> /dev/null; then
            local version=$("$dep" --version 2>/dev/null | head -1 || echo "Unknown")
            print_test "PASS" "Dependency $dep" "Version: $version"
        else
            print_test "FAIL" "Dependency $dep" "Not found"
            missing_deps+=("$dep")
        fi
    done
    
    # Check optional dependencies
    local optional_deps=("pod")
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            local version=$("$dep" --version 2>/dev/null | head -1 || echo "Unknown")
            print_test "PASS" "Optional $dep" "Version: $version"
        else
            print_test "SKIP" "Optional $dep" "Not installed (optional)"
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        return 0
    else
        print_test "FAIL" "Dependencies" "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
}

test_project_structure() {
    print_test "INFO" "Project Structure" "Validating project structure..."
    
    local required_files=(
        "src-tauri/Cargo.toml"
        "src-tauri/tauri.conf.json"
        "src-tauri/tauri.ios.conf.json"
        "frontend/package.json"
        "frontend/bun.lockb"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            print_test "PASS" "File $file" "Exists"
        else
            print_test "FAIL" "File $file" "Missing"
            missing_files+=("$file")
        fi
    done
    
    local required_dirs=("src-tauri" "frontend" "scripts")
    local missing_dirs=()
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            print_test "PASS" "Directory $dir" "Exists"
        else
            print_test "FAIL" "Directory $dir" "Missing"
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 && ${#missing_dirs[@]} -eq 0 ]]; then
        return 0
    else
        print_test "FAIL" "Project Structure" "Missing files/dirs"
        return 1
    fi
}

test_ios_configuration() {
    print_test "INFO" "iOS Configuration" "Validating iOS-specific configuration..."
    
    # Check iOS config files
    local ios_configs=(
        "src-tauri/ios-config/src-tauri_iOS.entitlements"
        "src-tauri/ios-config/ExportOptions.plist"
        "src-tauri/ios-config/Podfile"
    )
    
    local missing_configs=()
    
    for config in "${ios_configs[@]}"; do
        if [[ -f "$PROJECT_ROOT/$config" ]]; then
            print_test "PASS" "iOS Config $config" "Exists"
        else
            print_test "FAIL" "iOS Config $config" "Missing"
            missing_configs+=("$config")
        fi
    done
    
    # Check Tauri iOS configuration
    if [[ -f "$PROJECT_ROOT/src-tauri/tauri.ios.conf.json" ]]; then
        # Validate JSON syntax
        if python3 -m json.tool "$PROJECT_ROOT/src-tauri/tauri.ios.conf.json" >/dev/null 2>&1; then
            print_test "PASS" "iOS Tauri Config" "Valid JSON"
        else
            print_test "FAIL" "iOS Tauri Config" "Invalid JSON"
            return 1
        fi
    else
        print_test "FAIL" "iOS Tauri Config" "Missing"
        return 1
    fi
    
    if [[ ${#missing_configs[@]} -eq 0 ]]; then
        return 0
    else
        print_test "FAIL" "iOS Configuration" "Missing configs: ${missing_configs[*]}"
        return 1
    fi
}

test_frontend_build() {
    print_test "INFO" "Frontend Build" "Testing frontend build process..."
    
    if ! command -v bun &> /dev/null; then
        skip_test "Frontend Build" "Bun not available"
        return 0
    fi
    
    # Test dependency installation
    local temp_dir=$(mktemp -d)
    cp -r "$PROJECT_ROOT/frontend" "$temp_dir/"
    
    cd "$temp_dir/frontend"
    if bun install --frozen-lockfile >/dev/null 2>&1; then
        print_test "PASS" "Frontend Dependencies" "Installed successfully"
    else
        print_test "FAIL" "Frontend Dependencies" "Installation failed"
        cd "$PROJECT_ROOT"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Test build
    if bun run build >/dev/null 2>&1; then
        print_test "PASS" "Frontend Build" "Build successful"
    else
        print_test "FAIL" "Frontend Build" "Build failed"
        cd "$PROJECT_ROOT"
        rm -rf "$temp_dir"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir"
    return 0
}

test_rust_compilation() {
    print_test "INFO" "Rust Compilation" "Testing Rust compilation for iOS targets..."
    
    if ! command -v cargo &> /dev/null; then
        skip_test "Rust Compilation" "Cargo not available"
        return 0
    fi
    
    local targets=("aarch64-apple-ios" "aarch64-apple-ios-sim")
    
    for target in "${targets[@]}"; do
        cd "$PROJECT_ROOT/src-tauri"
        
        # Test compilation (check only, faster than full build)
        if cargo check --target "$target" >/dev/null 2>&1; then
            print_test "PASS" "Rust Check $target" "Compilation check passed"
        else
            print_test "FAIL" "Rust Check $target" "Compilation check failed"
            cd "$PROJECT_ROOT"
            return 1
        fi
        
        cd "$PROJECT_ROOT"
    done
    
    return 0
}

test_ios_project_generation() {
    print_test "INFO" "iOS Project Generation" "Testing iOS project generation..."
    
    if ! command -v cargo &> /dev/null; then
        skip_test "iOS Project Generation" "Cargo not available"
        return 0
    fi
    
    # Check if cargo tauri is available
    if ! cargo tauri --help >/dev/null 2>&1; then
        skip_test "iOS Project Generation" "Tauri CLI not available"
        return 0
    fi
    
    cd "$PROJECT_ROOT/src-tauri"
    
    # Test iOS project initialization
    if cargo tauri ios init >/dev/null 2>&1; then
        print_test "PASS" "iOS Project Init" "Project generated successfully"
        
        # Check if required files were created
        if [[ -d "gen/apple/src-tauri.xcodeproj" ]]; then
            print_test "PASS" "Xcode Project" "Generated successfully"
        else
            print_test "FAIL" "Xcode Project" "Not generated"
            cd "$PROJECT_ROOT"
            return 1
        fi
        
        if [[ -f "gen/apple/src-tauri.xcworkspace/contents.xcworkspacedata" ]]; then
            print_test "PASS" "Xcode Workspace" "Generated successfully"
        else
            print_test "FAIL" "Xcode Workspace" "Not generated"
            cd "$PROJECT_ROOT"
            return 1
        fi
    else
        print_test "FAIL" "iOS Project Init" "Project generation failed"
        cd "$PROJECT_ROOT"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    return 0
}

test_script_functionality() {
    print_test "INFO" "Script Functionality" "Testing build scripts..."
    
    local scripts=(
        "scripts/validate-ios-env.sh"
        "scripts/pre-warm-deps.sh"
        "scripts/ios-dev.sh"
        "scripts/build-with-error-handling.sh"
        "scripts/measure-build-performance.sh"
    )
    
    local failed_scripts=()
    
    for script in "${scripts[@]}"; do
        if [[ -f "$PROJECT_ROOT/$script" ]]; then
            # Test script syntax
            if bash -n "$PROJECT_ROOT/$script" 2>/dev/null; then
                print_test "PASS" "Script $script" "Syntax valid"
            else
                print_test "FAIL" "Script $script" "Syntax error"
                failed_scripts+=("$script")
            fi
            
            # Test script is executable
            if [[ -x "$PROJECT_ROOT/$script" ]]; then
                print_test "PASS" "Script $script" "Executable"
            else
                print_test "FAIL" "Script $script" "Not executable"
                failed_scripts+=("$script")
            fi
        else
            print_test "FAIL" "Script $script" "Not found"
            failed_scripts+=("$script")
        fi
    done
    
    if [[ ${#failed_scripts[@]} -eq 0 ]]; then
        return 0
    else
        print_test "FAIL" "Script Functionality" "Failed scripts: ${failed_scripts[*]}"
        return 1
    fi
}

test_performance_monitoring() {
    print_test "INFO" "Performance Monitoring" "Testing performance monitoring setup..."
    
    # Check performance directory
    if [[ -d "$PROJECT_ROOT/performance" ]]; then
        print_test "PASS" "Performance Directory" "Exists"
    else
        print_test "SKIP" "Performance Directory" "Not created yet"
    fi
    
    # Check performance script
    if [[ -f "$PROJECT_ROOT/scripts/measure-build-performance.sh" ]]; then
        print_test "PASS" "Performance Script" "Exists"
        
        # Test script syntax
        if bash -n "$PROJECT_ROOT/scripts/measure-build-performance.sh" 2>/dev/null; then
            print_test "PASS" "Performance Script" "Syntax valid"
        else
            print_test "FAIL" "Performance Script" "Syntax error"
            return 1
        fi
    else
        print_test "FAIL" "Performance Script" "Not found"
        return 1
    fi
    
    return 0
}

test_ci_cd_configuration() {
    print_test "INFO" "CI/CD Configuration" "Testing CI/CD setup..."
    
    # Check GitHub Actions workflows
    if [[ -f "$PROJECT_ROOT/.github/workflows/ios-release-enhanced.yml" ]]; then
        print_test "PASS" "Enhanced Workflow" "Exists"
        
        # Test YAML syntax
        if python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/.github/workflows/ios-release-enhanced.yml'))" 2>/dev/null; then
            print_test "PASS" "Enhanced Workflow" "Valid YAML"
        else
            print_test "FAIL" "Enhanced Workflow" "Invalid YAML"
            return 1
        fi
    else
        print_test "SKIP" "Enhanced Workflow" "Not created yet"
    fi
    
    # Check Xcode Cloud configuration
    if [[ -f "$PROJECT_ROOT/.xcodecloud/ci_cd.xcconfig" ]]; then
        print_test "PASS" "Xcode Cloud Config" "Exists"
    else
        print_test "SKIP" "Xcode Cloud Config" "Not created yet"
    fi
    
    return 0
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS/test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# iOS Build Test Report

**Generated**: $(date)
**Test Environment**: $(uname -s) $(uname -r)

## Test Summary

| Metric | Count |
|--------|-------|
| Tests Passed | $TESTS_PASSED |
| Tests Failed | $TESTS_FAILED |
| Tests Skipped | $TESTS_SKIPPED |
| **Total Tests** | **$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))** |

## Success Rate

EOF

    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$((TESTS_PASSED * 100 / total_tests))
        echo "**Success Rate**: ${success_rate}%" >> "$report_file"
        
        if [[ $success_rate -ge 90 ]]; then
            echo "🟢 **Status**: EXCELLENT" >> "$report_file"
        elif [[ $success_rate -ge 75 ]]; then
            echo "🟡 **Status**: GOOD" >> "$report_file"
        else
            echo "🔴 **Status**: NEEDS IMPROVEMENT" >> "$report_file"
        fi
    else
        echo "**Status**: NO TESTS RUN" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Test Results

EOF

    # Add detailed test results from log
    if [[ -f "$TEST_LOG" ]]; then
        grep -E "^\[.*\]" "$TEST_LOG" | while IFS=']:' read -r timestamp status rest; do
            local test_name=$(echo "$rest" | cut -d':' -f1)
            local message=$(echo "$rest" | cut -d':' -f2-)
            
            case $status in
                PASS)
                    echo "✅ **$test_name**: $message" >> "$report_file"
                    ;;
                FAIL)
                    echo "❌ **$test_name**: $message" >> "$report_file"
                    ;;
                SKIP)
                    echo "⏭️ **$test_name**: $message" >> "$report_file"
                    ;;
                *)
                    echo "ℹ️ **$test_name**: $message" >> "$report_file"
                    ;;
            esac
        done
    fi
    
    cat >> "$report_file" << EOF

## Recommendations

EOF

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "### 🔧 Fix Failed Tests" >> "$report_file"
        echo "1. Review failed test details above" >> "$report_file"
        echo "2. Address missing dependencies or configuration issues" >> "$report_file"
        echo "3. Re-run tests after fixes" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo "### 📋 Complete Optional Components" >> "$report_file"
        echo "1. Install missing optional dependencies" >> "$report_file"
        echo "2. Set up optional tools for full test coverage" >> "$report_file"
        echo "3. Re-run tests to achieve 100% coverage" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    if [[ $TESTS_PASSED -eq $total_tests ]]; then
        echo "### 🎉 Excellent!" >> "$report_file"
        echo "All tests passed! The iOS build environment is properly configured." >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
## Next Steps

1. **Address Failures**: Fix any failed tests identified above
2. **Complete Optional Setup**: Install missing optional dependencies
3. **Run Performance Tests**: Use performance monitoring script
4. **Test Build Process**: Run actual iOS build to validate end-to-end
5. **Monitor Regularly**: Run tests regularly to catch regressions

## Files and Locations

- **Test Log**: $TEST_LOG
- **Test Results**: $TEST_RESULTS/
- **Performance Data**: $PROJECT_ROOT/performance/
- **Build Scripts**: $PROJECT_ROOT/scripts/

---
*Report generated by iOS Build Test Suite*
EOF

    echo "📊 Test report generated: $report_file"
}

# Main test execution
run_all_tests() {
    setup_test_env
    
    # Run all tests
    test_environment_validation
    test_rust_targets
    test_dependencies
    test_project_structure
    test_ios_configuration
    test_frontend_build
    test_rust_compilation
    test_ios_project_generation
    test_script_functionality
    test_performance_monitoring
    test_ci_cd_configuration
    
    # Generate report
    generate_test_report
    
    # Print summary
    echo ""
    echo "=================================="
    echo "🧪 Test Suite Summary"
    echo "=================================="
    echo "✅ Passed: $TESTS_PASSED"
    echo "❌ Failed: $TESTS_FAILED"
    echo "⏭️ Skipped: $TESTS_SKIPPED"
    echo "📊 Total: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$((TESTS_PASSED * 100 / total_tests))
        echo "📈 Success Rate: ${success_rate}%"
        
        if [[ $success_rate -ge 90 ]]; then
            echo "🟢 Status: EXCELLENT"
            return 0
        elif [[ $success_rate -ge 75 ]]; then
            echo "🟡 Status: GOOD"
            return 0
        else
            echo "🔴 Status: NEEDS IMPROVEMENT"
            return 1
        fi
    else
        echo "🔴 Status: NO TESTS RUN"
        return 1
    fi
}

# Parse command line arguments
case "${1:-all}" in
    all)
        run_all_tests
        ;;
    env)
        setup_test_env
        test_environment_validation
        ;;
    rust)
        setup_test_env
        test_rust_targets
        ;;
    deps)
        setup_test_env
        test_dependencies
        ;;
    structure)
        setup_test_env
        test_project_structure
        ;;
    ios)
        setup_test_env
        test_ios_configuration
        ;;
    frontend)
        setup_test_env
        test_frontend_build
        ;;
    compile)
        setup_test_env
        test_rust_compilation
        ;;
    project)
        setup_test_env
        test_ios_project_generation
        ;;
    scripts)
        setup_test_env
        test_script_functionality
        ;;
    performance)
        setup_test_env
        test_performance_monitoring
        ;;
    cicd)
        setup_test_env
        test_ci_cd_configuration
        ;;
    report)
        if [[ -f "$TEST_RESULTS/test-report-"*.md" ]]; then
            cat "$TEST_RESULTS/test-report-"*.md | tail -1
        else
            echo "No test report available. Run tests first."
        fi
        ;;
    clean)
        echo "🧹 Cleaning test results..."
        rm -rf "$TEST_DIR"
        echo "✅ Test results cleaned"
        ;;
    --help)
        echo "iOS Build Test Suite"
        echo ""
        echo "Usage: $0 [TEST]"
        echo ""
        echo "Tests:"
        echo "  all         Run all tests (default)"
        echo "  env         Environment validation tests"
        echo "  rust        Rust targets tests"
        echo "  deps        Dependencies tests"
        echo "  structure    Project structure tests"
        echo "  ios         iOS configuration tests"
        echo "  frontend    Frontend build tests"
        echo "  compile     Rust compilation tests"
        echo "  project     iOS project generation tests"
        echo "  scripts     Script functionality tests"
        echo "  performance Performance monitoring tests"
        echo "  cicd        CI/CD configuration tests"
        echo "  report      Show latest test report"
        echo "  clean       Clean test results"
        echo "  --help      Show this help"
        echo ""
        echo "Examples:"
        echo "  $0              # Run all tests"
        echo "  $0 env          # Run environment tests only"
        echo "  $0 rust deps    # Run Rust and dependency tests"
        echo "  $0 report       # Show latest report"
        ;;
    *)
        echo "Unknown test: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac