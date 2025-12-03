#!/bin/bash

# Quick validation script for GitHub Actions workflows
# This script provides fast feedback on workflow changes

set -e

echo "⚡ Quick GitHub Actions validation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if Act CLI is available
if ! command -v act &> /dev/null; then
    print_error "Act CLI not found"
    echo "Install it with: brew install act"
    exit 1
fi

# List available workflows
print_info "Available workflows:"
act -l

echo
print_info "Validating workflow syntax..."

# Validate all workflow files
for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
    if [ -f "$workflow" ]; then
        workflow_name=$(basename "$workflow")
        print_info "Validating $workflow_name..."
        
        # Check YAML syntax
        if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
            print_status "YAML syntax valid: $workflow_name"
        else
            print_error "YAML syntax error in $workflow_name"
            exit 1
        fi
        
        # Check for required fields
        if ! grep -q "^name:" "$workflow"; then
            print_error "Missing 'name' field in $workflow_name"
            exit 1
        fi
        
        if ! grep -q "^on:" "$workflow"; then
            print_error "Missing 'on:' field in $workflow_name"
            exit 1
        fi
        
        if ! grep -q "^jobs:" "$workflow"; then
            print_error "Missing 'jobs:' field in $workflow_name"
            exit 1
        fi
        
        print_status "Structure valid: $workflow_name"
    fi
done

echo
print_info "Testing workflow execution (dry run)..."

# Test workflows with dry run
if act --dryrun 2>/dev/null; then
    print_status "All workflows pass dry run validation"
else
    print_warning "Some workflows failed dry run"
    echo "Run 'act' for full testing"
fi

echo
print_status "Quick validation completed! 🎉"
echo
print_info "For full testing, run:"
echo "  act                    # Run default workflow"
echo "  act -j <job-name>      # Run specific job"
echo "  act -W <workflow-file>  # Run specific workflow"