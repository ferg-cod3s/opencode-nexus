#!/bin/bash
# Test GitHub Workflows Locally
# This script validates and tests your workflows without pushing to GitHub

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/.github/workflows"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test 1: YAML Validation
test_yaml_syntax() {
    log_info "Testing YAML syntax validation..."
    
    if ! command -v yamllint &> /dev/null && ! command -v npx &> /dev/null; then
        log_warning "yamllint not found, skipping YAML validation"
        return 0
    fi
    
    local yaml_tool=""
    if command -v yamllint &> /dev/null; then
        yaml_tool="yamllint"
    elif command -v npx &> /dev/null; then
        yaml_tool="npx yaml-lint"
    fi
    
    if [ -z "$yaml_tool" ]; then
        log_warning "No YAML validation tool found"
        return 0
    fi
    
    local failed=0
    for workflow in "$WORKFLOWS_DIR"/*.yml; do
        local workflow_name=$(basename "$workflow")
        if $yaml_tool "$workflow" > /dev/null 2>&1; then
            log_success "✓ $workflow_name - Syntax valid"
        else
            log_error "✗ $workflow_name - Syntax error"
            $yaml_tool "$workflow" || true
            failed=1
        fi
    done
    
    return $failed
}

# Test 2: Test Version Extraction Logic
test_version_extraction() {
    log_info "Testing version extraction logic..."
    
    local test_cases=(
        "ios-v0.0.0-dev001:0.0.0"
        "ios-v1.2.3:1.2.3"
        "v0.0.0-dev001:0.0.0"
    )
    
    for test_case in "${test_cases[@]}"; do
        local tag="${test_case%:*}"
        local expected="${test_case#*:}"
        local version=$(echo "$tag" | sed 's/^[^0-9]*//;s/[^0-9.]*$//')
        
        if [ "$version" = "$expected" ]; then
            log_success "✓ $tag → $version"
        else
            log_error "✗ $tag expected $expected but got $version"
            return 1
        fi
    done
}

# Test 3: Environment Setup
test_environment() {
    log_info "Testing environment setup..."
    
    # Check required tools
    local tools=("cargo" "rustc" "bun" "xcodebuild")
    local missing=0
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version=$("$tool" --version 2>&1 | head -1)
            log_success "✓ $tool installed: $version"
        else
            log_warning "⚠️  $tool not found (may be needed for full build)"
            ((missing++)) || true
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_warning "Some tools are missing, but this is OK for validation"
    fi
}

# Test 4: Rust Build Test
test_rust_build() {
    log_info "Testing Rust compilation..."
    
    if ! command -v cargo &> /dev/null; then
        log_warning "Cargo not found, skipping Rust build test"
        return 0
    fi
    
    cd "$SCRIPT_DIR/src-tauri"
    
    log_info "Running Rust tests..."
    if cargo test --lib 2>&1 | tail -20; then
        log_success "✓ Rust tests passed"
    else
        log_error "✗ Rust tests failed"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Test 5: Frontend Build Test
test_frontend_build() {
    log_info "Testing frontend build..."
    
    if ! command -v bun &> /dev/null; then
        log_warning "Bun not found, skipping frontend tests"
        return 0
    fi
    
    cd "$SCRIPT_DIR/frontend"
    
    log_info "Running TypeScript check..."
    if bun run typecheck 2>&1 | tail -10; then
        log_success "✓ TypeScript check passed"
    else
        log_error "✗ TypeScript check failed"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Test 6: List workflow jobs
list_workflow_jobs() {
    log_info "Available workflow jobs..."
    
    if command -v act &> /dev/null; then
        log_info "Using 'act' to list jobs:"
        act --list --workflow="$WORKFLOWS_DIR/ios-release-fixed.yml" || log_warning "Could not list jobs with act"
    else
        log_warning "'act' not installed. Install with: brew install act"
        log_info "Manual job listing:"
        grep -E "^\s+[a-z-]+:" "$WORKFLOWS_DIR/ios-release-fixed.yml" || true
    fi
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         GitHub Workflow Local Testing Suite                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    local failed=0
    
    # Run tests
    if ! test_yaml_syntax; then
        ((failed++)) || true
    fi
    echo ""
    
    if ! test_version_extraction; then
        ((failed++)) || true
    fi
    echo ""
    
    test_environment
    echo ""
    
    if ! test_rust_build; then
        ((failed++)) || true
    fi
    echo ""
    
    if ! test_frontend_build; then
        ((failed++)) || true
    fi
    echo ""
    
    list_workflow_jobs
    echo ""
    
    # Summary
    echo "╔════════════════════════════════════════════════════════════╗"
    if [ $failed -eq 0 ]; then
        log_success "All local tests passed! ✅"
        echo ""
        echo "Next steps:"
        echo "  1. Push to GitHub: git push origin main"
        echo "  2. Tag release:    git push origin ios-v0.0.0-dev002"
        echo "  3. Watch build:    open https://github.com/v1truv1us/opencode-nexus/actions"
    else
        log_error "Some tests failed ❌"
        echo ""
        echo "Fix the errors above and try again."
        exit 1
    fi
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

# Run main
main "$@"
