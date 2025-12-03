#!/bin/bash

# GitHub Secrets Verification Script
# Checks all required iOS CI/CD secrets are properly configured

set -e

echo "🔍 OpenCode Nexus - GitHub Secrets Verification"
echo "============================================"
echo ""

# Required secrets for iOS workflows
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

echo "🔍 Checking required GitHub secrets..."
echo ""

# Get list of configured secrets
CONFIGURED_SECRETS=$(gh secret list | awk '{print $1}')

missing_count=0
configured_count=0

for secret in "${REQUIRED_SECRETS[@]}"; do
    if echo "$CONFIGURED_SECRETS" | grep -q "^$secret$"; then
        log_success "$secret"
        ((configured_count++))
    else
        log_error "$secret - MISSING"
        ((missing_count++))
    fi
done

echo ""
log_info "Secrets Summary:"
echo "   ✅ Configured: $configured_count/${#REQUIRED_SECRETS[@]}"
echo "   ❌ Missing: $missing_count/${#REQUIRED_SECRETS[@]}"

if [ $missing_count -eq 0 ]; then
    echo ""
    log_success "🎉 All iOS CI/CD secrets are configured!"
    echo ""
    log_info "📱 Ready for iOS workflows:"
    echo "   - ios-release.yml"
    echo "   - ios-release-optimized.yml"
    echo ""
    log_info "🚀 Test with:"
    echo "   gh workflow run ios-release-optimized.yml"
    echo ""
    log_info "📋 Workflow fixes needed:"
    echo "   - Fix actions/setup-rust@v1 → dtolnay/rust-toolchain@stable"
    echo "   - Fix license-check.yml YAML syntax"
    echo ""
else
    echo ""
    log_warning "⚠️  Some secrets are missing - workflows may fail"
    echo ""
    log_info "🔧 To complete setup:"
    
    if echo "$CONFIGURED_SECRETS" | grep -q "IOS_CERTIFICATE_P12"; then
        if ! echo "$CONFIGURED_SECRETS" | grep -q "IOS_CERTIFICATE_PASSWORD"; then
            echo "   gh secret set IOS_CERTIFICATE_PASSWORD --body \"YOUR_CERT_PASSWORD\""
        fi
        if ! echo "$CONFIGURED_SECRETS" | grep -q "KEYCHAIN_PASSWORD"; then
            echo "   gh secret set KEYCHAIN_PASSWORD --body \"YOUR_CERT_PASSWORD\""
        fi
    fi
    
    echo ""
    log_info "📱 After setting secrets, test with:"
    echo "   gh workflow run ios-release-optimized.yml"
fi

echo ""
log_info "📁 Credential files location:"
echo "   $(pwd)/.credentials/"
echo ""
log_info "🔐 All secrets are encrypted and stored securely by GitHub"