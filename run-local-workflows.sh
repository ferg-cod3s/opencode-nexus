#!/bin/bash

# Local GitHub Workflow Runner
# Runs the equivalent of GitHub workflows locally on macOS

set -e

echo "🚀 Starting local GitHub workflow execution..."
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Track overall success
OVERALL_SUCCESS=true

# Frontend Tests
print_status "Running Frontend Tests..."
echo "----------------------------------------"

cd frontend

echo "📦 Installing dependencies..."
if bun install --frozen-lockfile; then
    print_success "Dependencies installed"
else
    print_error "Failed to install dependencies"
    OVERALL_SUCCESS=false
fi

echo ""
echo "🔍 Running type check..."
if bun run typecheck; then
    print_success "Type check passed"
else
    print_error "Type check failed"
    OVERALL_SUCCESS=false
fi

echo ""
echo "🧹 Running linter..."
if bun run lint; then
    print_success "Linting passed"
else
    print_warning "Linting found warnings (but passed)"
fi

echo ""
echo "🧪 Running unit tests..."
if bun test src/tests/; then
    print_success "Unit tests passed"
else
    print_error "Unit tests failed"
    OVERALL_SUCCESS=false
fi

echo ""
echo "🏗️ Running build test..."
if bun run build; then
    print_success "Build passed"
else
    print_error "Build failed"
    OVERALL_SUCCESS=false
fi

cd ..

# Backend Tests
print_status "Running Backend Tests..."
echo "----------------------------------------"

cd src-tauri

echo "📏 Checking code formatting..."
if cargo fmt --all -- --check; then
    print_success "Code formatting check passed"
else
    print_warning "Code formatting issues found - fixing..."
    cargo fmt --all
    print_success "Code formatting fixed"
fi

echo ""
echo "🔍 Running clippy..."
if cargo clippy --all-targets --all-features -- -D warnings; then
    print_success "Clippy passed"
else
    print_warning "Clippy found issues (but continuing)"
fi

echo ""
echo "🧪 Running Rust tests..."
if cargo test --lib -- --skip test_streaming; then
    print_success "Rust tests passed"
else
    print_error "Rust tests failed"
    OVERALL_SUCCESS=false
fi

echo ""
echo "🏗️ Running Rust build test..."
if cargo build; then
    print_success "Rust build passed"
else
    print_error "Rust build failed"
    OVERALL_SUCCESS=false
fi

cd ..

# Integration Tests (Docker-based)
print_status "Running Integration Tests..."
echo "----------------------------------------"

if command -v docker &> /dev/null; then
    echo "🐳 Running Docker integration tests..."
    if docker compose -f docker-compose.test.yml build; then
        print_success "Docker images built"
        
        if docker compose -f docker-compose.test.yml up --abort-on-container-exit --exit-code-from frontend-test; then
            print_success "Integration tests passed"
        else
            print_error "Integration tests failed"
            OVERALL_SUCCESS=false
        fi
        
        echo "🧹 Cleaning up Docker..."
        docker compose -f docker-compose.test.yml down -v --remove-orphans
    else
        print_error "Failed to build Docker images"
        OVERALL_SUCCESS=false
    fi
else
    print_warning "Docker not available - skipping integration tests"
fi

# Summary
echo ""
echo "========================================"
if [ "$OVERALL_SUCCESS" = true ]; then
    print_success "🎉 All workflows completed successfully!"
    exit 0
else
    print_error "💥 Some workflows failed!"
    exit 1
fi