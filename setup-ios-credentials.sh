#!/bin/bash
# setup-ios-credentials.sh
# Industry-standard iOS credential setup script

set -e

echo "🔐 Setting up iOS development credentials..."
echo "==========================================="

# Create credentials directory
CREDENTIALS_DIR="$HOME/.credentials"
mkdir -p "$CREDENTIALS_DIR"

# Check if .env exists
if [ ! -f "$CREDENTIALS_DIR/.env" ]; then
    if [ -f ".credentials.example" ]; then
        echo "📋 Copying .credentials.example to $CREDENTIALS_DIR/.env"
        cp .credentials.example "$CREDENTIALS_DIR/.env"
        echo "✏️  Please edit $CREDENTIALS_DIR/.env with your actual credentials"
    else
        echo "❌ .credentials.example not found. Please create it manually."
        exit 1
    fi
else
    echo "✅ $CREDENTIALS_DIR/.env already exists"
fi

# Set proper permissions
chmod 600 "$CREDENTIALS_DIR/.env"

# Check for provisioning profile
PROFILE_DEST="$HOME/Library/MobileDevice/Provisioning Profiles/b6219b46-9281-48fa-9616-338ce39c6a21.mobileprovision"
if [ -f "$CREDENTIALS_DIR/OpenCode_Nexus_App_Store.mobileprovision" ]; then
    if [ ! -f "$PROFILE_DEST" ]; then
        echo "📱 Installing provisioning profile..."
        cp "$CREDENTIALS_DIR/OpenCode_Nexus_App_Store.mobileprovision" "$PROFILE_DEST"
        echo "✅ Provisioning profile installed"
    else
        echo "✅ Provisioning profile already installed"
    fi
else
    echo "⚠️  Provisioning profile not found in $CREDENTIALS_DIR/"
    echo "   Download from Apple Developer Portal and place in $CREDENTIALS_DIR/"
fi

# Check for distribution certificate
echo "🔍 Checking for distribution certificate..."
if security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
    echo "✅ Distribution certificate found in keychain"
else
    echo "❌ Distribution certificate not found in keychain"
    echo "   Please install your Apple Distribution certificate"
fi

# Verify credentials
echo ""
echo "🔍 Verifying credentials..."
if [ -f "$CREDENTIALS_DIR/.env" ]; then
    source "$CREDENTIALS_DIR/.env"
    if [ -n "$APPLE_API_KEY" ] && [ -n "$APPLE_API_ISSUER" ]; then
        echo "✅ API credentials configured"
    else
        echo "❌ API credentials missing in .env file"
    fi
fi

echo ""
echo "🎯 Setup complete! Run 'cargo tauri ios build' to test."
echo ""
echo "📚 For detailed setup instructions, see:"
echo "   - .credentials/README.md"
echo "   - docs/client/AUTH_SETUP.md"