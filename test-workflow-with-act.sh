#!/bin/bash
# Test GitHub Workflows Locally with act (Docker-based simulation)
# This script runs your GitHub Actions workflows in Docker containers
# simulating the exact GitHub Actions environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check dependencies
check_dependencies() {
    log_section "Checking Dependencies"
    
    if ! command -v act &> /dev/null; then
        log_error "act is not installed!"
        log_info "Install with: brew install act"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        log_info "Install from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    
    log_success "act installed: $(act --version)"
    log_success "Docker installed: $(docker --version)"
}

# List available workflows
list_workflows() {
    log_section "Available Workflows"
    
    log_info "Listing all workflow jobs..."
    act --list --workflow=.github/workflows/ios-release.yml 2>/dev/null || {
        log_warning "Could not list workflows with act"
        log_info "Showing manually:"
        grep "^    [a-z-]*:$" .github/workflows/ios-release.yml || true
    }
}

# Test YAML syntax
test_yaml() {
    log_section "YAML Syntax Validation"
    
    if command -v npx &> /dev/null; then
        if npx yaml-lint .github/workflows/ios-release.yml > /dev/null 2>&1; then
            log_success "✓ Workflow YAML is valid"
        else
            log_error "✗ Workflow YAML has syntax errors"
            npx yaml-lint .github/workflows/ios-release.yml || true
            return 1
        fi
    fi
}

# Test with act (dry-run first)
test_with_act_dry_run() {
    log_section "Dry-Run with act (No Docker Execution)"
    
    log_info "Running workflow jobs with --dryrun flag..."
    
    if act -l --workflow=.github/workflows/ios-release.yml 2>/dev/null | grep -q "build-ios"; then
        log_success "✓ Found build-ios job in workflow"
    else
        log_warning "Could not find jobs"
    fi
}

# Test with act (actual docker execution - optional)
test_with_act_docker() {
    log_section "Testing with act (Docker Simulation)"
    
    log_warning "Full Docker execution not recommended for iOS builds (requires macOS)"
    log_info "Reasons:"
    log_info "  1. iOS build requires macOS + Xcode"
    log_info "  2. Code signing requires certificates"
    log_info "  3. Apple tools not available in Linux containers"
    echo ""
    log_info "What you CAN test with act:"
    log_info "  ✓ YAML syntax validation"
    log_info "  ✓ Step ordering and conditions"
    log_info "  ✓ Environment variable setup"
    log_info "  ✓ Bash script logic (non-Apple specific)"
    echo ""
    
    read -p "Do you want to run act anyway (may fail on iOS steps)? [y/N] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping Docker execution"
        return 0
    fi
    
    log_info "Starting act workflow execution in Docker..."
    log_warning "This will create Docker containers and run the workflow"
    log_warning "iOS-specific steps will likely fail"
    echo ""
    
    # Run with reusable containers and custom image
    act push \
        --workflow=.github/workflows/ios-release.yml \
        --reuse-containers \
        --container-architecture=linux/arm64 \
        --job=build-ios \
        2>&1 | tail -100 || log_warning "Workflow execution completed with errors (expected for iOS steps)"
}

# Create .actrc config
create_actrc() {
    log_section "Creating act Configuration"
    
    if [ ! -f ".actrc" ]; then
        cat > .actrc << 'EOF'
# act configuration for local workflow testing
# Reuse containers between runs for faster testing
--reuse-containers

# Use ARM64 architecture for Mac with Apple Silicon
--container-architecture linux/arm64

# Enable verbose output for debugging
# --verbose
EOF
        log_success "Created .actrc configuration file"
    else
        log_info "Using existing .actrc"
    fi
}

# Summary and next steps
show_summary() {
    log_section "Summary"
    
    log_success "Workflow testing setup complete!"
    echo ""
    
    echo "📋 Next Steps:"
    echo ""
    echo "1. For YAML validation only (fastest):"
    echo "   npx yaml-lint .github/workflows/ios-release.yml"
    echo ""
    echo "2. To list jobs with act:"
    echo "   act --list --workflow=.github/workflows/ios-release.yml"
    echo ""
    echo "3. To run specific job with act (in Docker):"
    echo "   act -j build-ios --workflow=.github/workflows/ios-release.yml"
    echo ""
    echo "4. To run full workflow on GitHub:"
    echo "   git push origin ios-v0.0.0-dev002"
    echo ""
    
    log_info "For iOS builds, GitHub Actions runner is recommended (macOS with Xcode)"
    log_info "Local Docker testing works best for non-Apple-specific steps"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║    GitHub Workflow Testing with act (Docker-based)        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    check_dependencies
    test_yaml || exit 1
    create_actrc
    list_workflows
    test_with_act_dry_run
    test_with_act_docker
    show_summary
}

# Run main
main "$@"
