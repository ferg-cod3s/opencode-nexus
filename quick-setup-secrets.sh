#!/bin/bash

# Quick GitHub Secrets Setup - Non-Interactive Version
# Sets up all iOS secrets using consolidated credential files

set -e

echo "🔐 OpenCode Nexus - Quick GitHub Secrets Setup"
echo "=============================================="
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

echo "🔍 Setting up GitHub secrets from consolidated credential files..."
echo ""

# Set App Store Connect API secrets
echo "📱 Setting App Store Connect API secrets..."
gh secret set APP_STORE_CONNECT_API_KEY_ID --body "78U6M64KJS"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "c6f421de-3e35-4aab-b96d-4c4461c39766"
base64 -w0 "$API_KEY_PATH" | gh secret set APP_STORE_CONNECT_API_PRIVATE_KEY
echo "✅ App Store Connect API secrets configured"

# Set Apple Developer Account
echo "🍎 Setting Apple Developer account secrets..."
gh secret set APPLE_ID --body "john.ferguson@unfergettabledesigns.com"
gh secret set APPLE_TEAM_ID --body "PCJU8QD9FN"
echo "✅ Apple Developer account secrets configured"

# Set Code Signing Certificate (requires password)
echo "🔐 Setting code signing certificate secrets..."
echo "⚠️  Certificate password required - please set manually:"
echo ""
echo "1. Set certificate password:"
echo "   gh secret set IOS_CERTIFICATE_PASSWORD --body \"YOUR_CERT_PASSWORD\""
echo ""
echo "2. Set keychain password (can be same as cert password):"
echo "   gh secret set KEYCHAIN_PASSWORD --body \"YOUR_CERT_PASSWORD\""
echo ""
echo "3. Set certificate file:"
base64 -w0 "$CERT_PATH" | gh secret set IOS_CERTIFICATE_P12
echo "✅ Certificate file configured (password required)"

# Set Provisioning Profile
echo "📋 Setting provisioning profile secret..."
base64 -w0 "$PROFILE_PATH" | gh secret set IOS_PROVISIONING_PROFILE
echo "✅ Provisioning profile configured"

echo ""
echo "🎉 Most GitHub secrets configured!"
echo ""
echo "📋 Status:"
echo "   ✅ APP_STORE_CONNECT_API_KEY_ID"
echo "   ✅ APP_STORE_CONNECT_ISSUER_ID"
echo "   ✅ APP_STORE_CONNECT_API_PRIVATE_KEY"
echo "   ✅ APPLE_ID"
echo "   ✅ APPLE_TEAM_ID"
echo "   ✅ IOS_CERTIFICATE_P12"
echo "   ✅ IOS_PROVISIONING_PROFILE"
echo "   ⚠️  IOS_CERTIFICATE_PASSWORD (set manually)"
echo "   ⚠️  KEYCHAIN_PASSWORD (set manually)"
echo ""
echo "🚀 Run these commands to complete setup:"
echo "   gh secret set IOS_CERTIFICATE_PASSWORD --body \"YOUR_CERT_PASSWORD\""
echo "   gh secret set KEYCHAIN_PASSWORD --body \"YOUR_CERT_PASSWORD\""
echo ""
echo "📱 Then test with: gh workflow run ios-release-optimized.yml"