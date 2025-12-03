#!/bin/bash

# Final GitHub Secrets Setup Script
# Reads from .env file and sets remaining iOS secrets

set -e

echo "🔐 Final GitHub Secrets Setup"
echo "============================="
echo ""

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI not authenticated"
    exit 1
fi

# Load environment variables from .env file
ENV_FILE="$(pwd)/.credentials/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found at $ENV_FILE"
    exit 1
fi

echo "📁 Loading environment from: $ENV_FILE"
echo ""

# Source the .env file (safely)
set -a
source "$ENV_FILE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if certificate password is set
if [ "$IOS_CERTIFICATE_PASSWORD" = "YOUR_CERT_PASSWORD_HERE" ]; then
    echo ""
    log_warning "⚠️  Certificate password not set in .env file"
    echo ""
    log_info "Please edit $(pwd)/.credentials/.env and replace:"
    echo "   IOS_CERTIFICATE_PASSWORD=YOUR_CERT_PASSWORD_HERE"
    echo "   KEYCHAIN_PASSWORD=YOUR_CERT_PASSWORD_HERE"
    echo ""
    log_info "With your actual certificate password:"
    echo "   IOS_CERTIFICATE_PASSWORD=your_actual_password"
    echo "   KEYCHAIN_PASSWORD=your_actual_password"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "🔍 Found certificate password in .env file"
echo ""

# Set the remaining secrets
log_info "Setting iOS certificate secrets..."

if [ -n "$IOS_CERTIFICATE_PASSWORD" ]; then
    if gh secret set IOS_CERTIFICATE_PASSWORD --body "$IOS_CERTIFICATE_PASSWORD"; then
        log_success "IOS_CERTIFICATE_PASSWORD configured"
    else
        log_error "Failed to set IOS_CERTIFICATE_PASSWORD"
    fi
else
    log_error "IOS_CERTIFICATE_PASSWORD not found in .env"
fi

if [ -n "$KEYCHAIN_PASSWORD" ]; then
    if gh secret set KEYCHAIN_PASSWORD --body "$KEYCHAIN_PASSWORD"; then
        log_success "KEYCHAIN_PASSWORD configured"
    else
        log_error "Failed to set KEYCHAIN_PASSWORD"
    fi
else
    log_error "KEYCHAIN_PASSWORD not found in .env"
fi

echo ""
log_info "🔍 Verifying all secrets are now configured..."

# Check all required secrets
REQUIRED_SECRETS=(
    "APP_STORE_CONNECT_API_KEY_ID"
    "APP_STORE_CONNECT_ISSUER_ID"
    "APP_STORE_CONNECT_API_PRIVATE_KEY"
    "APPLE_ID"
    "APPLE_TEAM_ID"
    "IOS_CERTIFICATE_P12"
    "IOS_CERTIFICATE_PASSWORD"
    "KEYCHAIN_PASSWORD"
    "IOS_PROVISIONING_PROFILE"
)

CONFIGURED_SECRETS=$(gh secret list | awk '{print $1}')
missing_count=0

for secret in "${REQUIRED_SECRETS[@]}"; do
    if echo "$CONFIGURED_SECRETS" | grep -q "^$secret$"; then
        log_success "$secret"
    else
        log_error "$secret - MISSING"
        ((missing_count++))
    fi
done

echo ""
if [ $missing_count -eq 0 ]; then
    log_success "🎉 ALL GitHub secrets are now configured!"
    echo ""
    log_info "📱 iOS workflows ready:"
    echo "   - ios-release.yml"
    echo "   - ios-release-optimized.yml"
    echo ""
    log_info "🚀 Test with:"
    echo "   gh workflow run ios-release-optimized.yml"
    echo ""
    log_info "📋 Workflow fixes still needed:"
    echo "   - Fix actions/setup-rust@v1 → dtolnay/rust-toolchain@stable"
    echo "   - Fix license-check.yml YAML syntax"
else
    log_error "❌ Some secrets are still missing"
    echo ""
    log_info "Missing count: $missing_count"
fi

echo ""
log_info "📁 Credential files location:"
echo "   $(pwd)/.credentials/"
echo ""
log_info "🔐 All secrets are encrypted and stored securely by GitHub"