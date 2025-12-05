#!/bin/bash
# iOS Build Validation Script for OpenCode Nexus
# Tests the enhanced build process and validates all components

set -euo pipefail

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Test results
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -i TESTS_SKIPPED=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[SKIP]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_test() { echo -e "${CYAN}[TEST]${NC} $1"; }

# Test functions
test_command() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"
    
    log_test "$test_name"
    
    if eval "$command" >/dev/null 2>&1; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_file_exists() {
    local test_name="$1"
    local file_path="$2"
    
    log_test "$test_name"
    
    if [ -f "$file_path" ]; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name - File not found: $file_path"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_directory_exists() {
    local test_name="$1"
    local dir_path="$2"
    
    log_test "$test_name"
    
    if [ -d "$dir_path" ]; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name - Directory not found: $dir_path"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_file_content() {
    local test_name="$1"
    local file_path="$2"
    local search_pattern="$3"
    
    log_test "$test_name"
    
    if [ -f "$file_path" ] && grep -q "$search_pattern" "$file_path"; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name - Pattern not found in $file_path: $search_pattern"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Main validation
echo -e "${BOLD}🔍 iOS Build Validation for OpenCode Nexus${NC}"
echo "============================================"
echo ""

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log_info "Project root: $PROJECT_ROOT"
log_info "Validating iOS build setup..."
echo ""

# 1. Environment Tests
echo -e "${BOLD}1️⃣ Environment Validation${NC}"
echo "------------------------"

test_command "Xcode command line tools" "command -v xcodebuild"
test_command "Rust toolchain" "command -v cargo"
test_command "Bun runtime" "command -v bun"

# Test iOS targets
log_test "iOS Rust targets installed"
if rustup target list --installed | grep -q "aarch64-apple-ios"; then
    log_success "iOS Rust targets installed"
    ((TESTS_PASSED++))
else
    log_error "iOS Rust targets missing"
    ((TESTS_FAILED++))
fi

echo ""

# 2. Project Structure Tests
echo -e "${BOLD}2️⃣ Project Structure${NC}"
echo "---------------------"

test_directory_exists "Frontend directory exists" "frontend"
test_directory_exists "Source Tauri directory exists" "src-tauri"
test_file_exists "Tauri configuration exists" "src-tauri/tauri.conf.json"
test_file_exists "Cargo.toml exists" "src-tauri/Cargo.toml"
test_file_exists "Frontend package.json exists" "frontend/package.json"

echo ""

# 3. Configuration Tests
echo -e "${BOLD}3️⃣ Configuration Validation${NC}"
echo "--------------------------"

test_file_content "iOS bundle identifier configured" "src-tauri/tauri.conf.json" "com.agentic-codeflow.opencode-nexus"
test_file_content "iOS deployment target" "src-tauri/tauri.conf.json" "14.0"
test_file_content "Development team configured" "src-tauri/tauri.conf.json" "PCJU8QD9FN"

echo ""

# 4. Build Script Tests
echo -e "${BOLD}4️⃣ Build Scripts${NC}"
echo "----------------"

test_file_exists "Enhanced iOS build script" "build-ios-enhanced.sh"
test_file_exists "Original iOS build script" "build-ios.sh"
test_file_exists "iOS build reliability script" "build-ios-reliability.sh"

# Test script permissions
log_test "Build scripts are executable"
if [ -x "build-ios-enhanced.sh" ] && [ -x "build-ios.sh" ]; then
    log_success "Build scripts are executable"
    ((TESTS_PASSED++))
else
    log_error "Build scripts lack execute permissions"
    ((TESTS_FAILED++))
fi

echo ""

# 5. iOS Project Generation Test (if exists)
echo -e "${BOLD}5️⃣ iOS Project Files${NC}"
echo "-------------------"

if [ -d "src-tauri/gen/apple" ]; then
    test_directory_exists "iOS generated directory exists" "src-tauri/gen/apple"
    test_directory_exists "Xcode project directory exists" "src-tauri/gen/apple/src-tauri.xcodeproj"
    test_file_exists "Xcode project file exists" "src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj"
    
    # Test for CI patch if project exists
    if [ -f "src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        test_file_content "CI patch applied" "src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj" "CI-Skip"
    fi
    
    # Test for library structure
    test_directory_exists "Externals directory exists" "src-tauri/gen/apple/Externals"
    test_directory_exists "Arm64 Release directory exists" "src-tauri/gen/apple/Externals/arm64/Release"
else
    log_warning "iOS project not yet generated - run build script first"
    ((TESTS_SKIPPED++))
fi

echo ""

# 6. Rust Library Tests (if built)
echo -e "${BOLD}6️⃣ Rust Library Validation${NC}"
echo "-------------------------"

if [ -f "src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a" ]; then
    test_file_exists "Rust iOS library exists" "src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a"
    
    # Test library format
    log_test "Rust library format validation"
    if file "src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a" | grep -q "ar archive"; then
        log_success "Rust library format validation"
        ((TESTS_PASSED++))
    else
        log_error "Rust library format validation"
        ((TESTS_FAILED++))
    fi
    
    # Test library architecture
    log_test "Rust library architecture validation"
    if lipo -info "src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a" 2>/dev/null | grep -q "arm64"; then
        log_success "Rust library architecture validation"
        ((TESTS_PASSED++))
    else
        log_error "Rust library architecture validation"
        ((TESTS_FAILED++))
    fi
else
    log_warning "Rust library not yet built - run build script first"
    ((TESTS_SKIPPED++))
fi

echo ""

# 7. Frontend Build Tests (if built)
echo -e "${BOLD}7️⃣ Frontend Validation${NC}"
echo "----------------------"

if [ -d "frontend/dist" ]; then
    test_directory_exists "Frontend dist directory exists" "frontend/dist"
    
    # Test for essential frontend files
    if [ -f "frontend/dist/index.html" ]; then
        log_success "Frontend index.html exists"
        ((TESTS_PASSED++))
    else
        log_error "Frontend index.html missing"
        ((TESTS_FAILED++))
    fi
else
    log_warning "Frontend not yet built - run build script first"
    ((TESTS_SKIPPED++))
fi

echo ""

# 8. GitHub Workflow Tests
echo -e "${BOLD}8️⃣ CI/CD Configuration${NC}"
echo "----------------------"

test_file_exists "iOS release workflow exists" ".github/workflows/ios-release-optimized.yml"
test_file_content "Workflow uses self-hosted runner" ".github/workflows/ios-release-optimized.yml" "self-hosted"
test_file_content "Workflow includes pre-build strategy" ".github/workflows/ios-release-optimized.yml" "pre-build"

echo ""

# 9. Summary
echo -e "${BOLD}📊 Test Summary${NC}"
echo "==============="
echo ""

# Calculate total tests
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo "Total tests: $TOTAL_TESTS"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo -e "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo ""

# Overall result
if [ $TESTS_FAILED -eq 0 ]; then
    if [ $TESTS_PASSED -gt 0 ]; then
        echo -e "${GREEN}${BOLD}✅ All critical tests passed!${NC}"
        echo ""
        echo -e "${BOLD}Next steps:${NC}"
        echo "1. Run the enhanced build script:"
        echo "   ${CYAN}./build-ios-enhanced.sh${NC}"
        echo ""
        echo "2. For CI/CD, create and push a tag:"
        echo "   ${CYAN}git tag ios-v1.0.0 && git push origin ios-v1.0.0${NC}"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}⚠️ No tests were executed${NC}"
        exit 1
    fi
else
    echo -e "${RED}${BOLD}❌ Some tests failed!${NC}"
    echo ""
    echo -e "${BOLD}Please fix the following issues:${NC}"
    echo "1. Install missing tools (Xcode, Rust, Bun)"
    echo "2. Configure iOS Rust targets: rustup target add aarch64-apple-ios"
    echo "3. Run the build script to generate missing files"
    echo "4. Check configuration files for correct values"
    echo ""
    exit 1
fi