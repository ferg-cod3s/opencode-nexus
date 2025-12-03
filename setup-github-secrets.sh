#!/bin/bash

# GitHub Secrets Setup Script for OpenCode Nexus iOS CI/CD
# This script configures all required secrets for iOS TestFlight workflows

set -e

echo "🔐 OpenCode Nexus - GitHub Secrets Setup"
echo "======================================"
echo ""

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    echo "Install with: curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "Then: echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list"
    echo "Then: sudo apt update && sudo apt install gh"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI not authenticated"
    echo "Run: gh auth login"
    exit 1
fi

# Credential paths
CREDENTIALS_DIR="$(pwd)/.credentials"
API_KEY_PATH="$CREDENTIALS_DIR/AuthKey_78U6M64KJS.p8"
CERT_PATH="$CREDENTIALS_DIR/distribution_cert.p12"
PROFILE_PATH="$CREDENTIALS_DIR/OpenCode_Nexus_App_Store.mobileprovision"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verify all credential files exist
echo "🔍 Verifying credential files..."
echo ""

if [ ! -f "$API_KEY_PATH" ]; then
    log_error "App Store Connect API key not found: $API_KEY_PATH"
    exit 1
fi
log_success "App Store Connect API key found"

if [ ! -f "$CERT_PATH" ]; then
    log_error "Distribution certificate not found: $CERT_PATH"
    exit 1
fi
log_success "Distribution certificate found"

if [ ! -f "$PROFILE_PATH" ]; then
    log_error "Provisioning profile not found: $PROFILE_PATH"
    exit 1
fi
log_success "Provisioning profile found"

echo ""
log_info "All credential files verified!"
echo ""

# Function to set secret with error handling
set_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"
    
    echo "Setting $description..."
    if echo "$secret_value" | gh secret set "$secret_name"; then
        log_success "$secret_name set successfully"
    else
        log_error "Failed to set $secret_name"
        return 1
    fi
}

# Function to set secret from file
set_secret_from_file() {
    local secret_name="$1"
    local file_path="$2"
    local description="$3"
    
    echo "Setting $description from file..."
    if base64 -w0 "$file_path" | gh secret set "$secret_name"; then
        log_success "$secret_name set successfully from file"
    else
        log_error "Failed to set $secret_name from file"
        return 1
    fi
}

echo "🚀 Setting up GitHub secrets..."
echo ""

# 1. App Store Connect API secrets
log_info "Setting App Store Connect API secrets..."

set_secret "APP_STORE_CONNECT_API_KEY_ID" "78U6M64KJS" "API Key ID"
set_secret "APP_STORE_CONNECT_ISSUER_ID" "c6f421de-3e35-4aab-b96d-4c4461c39766" "Issuer ID"
set_secret_from_file "APP_STORE_CONNECT_API_PRIVATE_KEY" "$API_KEY_PATH" "API Private Key (.p8)"

# 2. Apple Developer Account
log_info "Setting Apple Developer account secrets..."

set_secret "APPLE_ID" "john.ferguson@unfergettabledesigns.com" "Apple ID"
set_secret "APPLE_TEAM_ID" "PCJU8QD9FN" "Team ID"

# 3. Code Signing Certificate
log_info "Setting code signing certificate secrets..."

# Prompt for certificate password
echo ""
read -sp "Enter distribution certificate password: " CERT_PASSWORD
echo ""
if [ -z "$CERT_PASSWORD" ]; then
    log_error "Certificate password is required"
    exit 1
fi

set_secret_from_file "IOS_CERTIFICATE_P12" "$CERT_PATH" "iOS Distribution Certificate (.p12)"
set_secret "IOS_CERTIFICATE_PASSWORD" "$CERT_PASSWORD" "Certificate Password"
set_secret "KEYCHAIN_PASSWORD" "$CERT_PASSWORD" "Keychain Password"

# 4. Provisioning Profile
log_info "Setting provisioning profile secret..."

set_secret_from_file "IOS_PROVISIONING_PROFILE" "$PROFILE_PATH" "iOS Provisioning Profile (.mobileprovision)"

echo ""
log_success "All GitHub secrets configured successfully!"
echo ""

# Verify secrets were set
echo "🔍 Verifying configured secrets..."
echo ""

SECRETS=(
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

for secret in "${SECRETS[@]}"; do
    if gh secret list | grep -q "$secret"; then
        log_success "$secret is configured"
    else
        log_warning "$secret may not be configured"
    fi
done

echo ""
log_info "🎉 GitHub secrets setup complete!"
echo ""
echo "📋 Summary of configured secrets:"
echo "   - App Store Connect API (3 secrets)"
echo "   - Apple Developer Account (2 secrets)"  
echo "   - Code Signing Certificate (3 secrets)"
echo "   - Provisioning Profile (1 secret)"
echo "   - Total: 9 secrets configured"
echo ""
echo "🚀 Your iOS workflows should now work!"
echo "📱 Test by running: gh workflow run ios-release-optimized.yml"