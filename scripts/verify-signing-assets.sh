#!/bin/bash
# verify-signing-assets.sh - Verify iOS signing assets and configuration
set -euo pipefail

echo "🔍 Verifying iOS Signing Assets"
echo "==============================="

# Step 1: Check distribution certificate
echo "1. Checking Distribution Certificate..."
CERT_INFO=$(security find-identity -v -p codesigning | grep "Apple Distribution" || true)

if [ -z "$CERT_INFO" ]; then
    echo "❌ No Apple Distribution certificate found"
    echo "Available identities:"
    security find-identity -v -p codesigning
    exit 1
else
    echo "✅ Found Distribution certificate:"
    echo "$CERT_INFO"
fi
echo ""

# Step 2: Check provisioning profile
echo "2. Checking Provisioning Profile..."
PROFILE_PATH="Opencode_Nexus_App_Store_V2.mobileprovision"

if [ ! -f "$PROFILE_PATH" ]; then
    echo "❌ Provisioning profile not found: $PROFILE_PATH"
    exit 1
fi

# Extract profile details
PROFILE_NAME=$(openssl smime -verify -inform DER -in "$PROFILE_PATH" -noverify 2>/dev/null | \
    grep -A1 "<key>Name</key>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

PROFILE_UUID=$(openssl smime -verify -inform DER -in "$PROFILE_PATH" -noverify 2>/dev/null | \
    grep -A1 "<key>UUID</key>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

BUNDLE_ID=$(openssl smime -verify -inform DER -in "$PROFILE_PATH" -noverify 2>/dev/null | \
    grep -A1 "<key>application-identifier</key>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

EXPIRATION=$(openssl smime -verify -inform DER -in "$PROFILE_PATH" -noverify 2>/dev/null | \
    grep -A1 "<key>ExpirationDate</key>" | grep "<date>" | sed 's/.*<date>\(.*\)<\/date>.*/\1/' | cut -d'T' -f1)

TEAM_ID=$(openssl smime -verify -inform DER -in "$PROFILE_PATH" -noverify 2>/dev/null | \
    grep -A1 "<key>com.apple.developer.team-identifier</key>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

echo "✅ Provisioning profile details:"
echo "   Name: $PROFILE_NAME"
echo "   UUID: $PROFILE_UUID"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Team ID: $TEAM_ID"
echo "   Expires: $EXPIRATION"

# Check if profile is installed
PROFILE_INSTALLED="$HOME/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision"
if [ -f "$PROFILE_INSTALLED" ]; then
    echo "   Status: ✅ Installed"
else
    echo "   Status: ⚠️  Not installed (run install-provisioning-profile.sh)"
fi
echo ""

# Step 3: Check Xcode project settings
echo "3. Checking Xcode Project Settings..."
PROJECT_PATH="src-tauri/gen/apple/src-tauri.xcodeproj"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Xcode project not found: $PROJECT_PATH"
    echo "Run 'cargo tauri ios init' to generate it"
    exit 1
fi

# Check build settings
BUILD_SETTINGS=$(xcodebuild -project "$PROJECT_PATH" -scheme src-tauri_iOS -configuration Release -showBuildSettings 2>/dev/null | \
    grep -E "CODE_SIGN|PROVISIONING|DEVELOPMENT_TEAM|PRODUCT_BUNDLE" || true)

echo "✅ Xcode build settings:"
echo "$BUILD_SETTINGS"
echo ""

# Step 4: Check ExportOptions.plist
echo "4. Checking ExportOptions.plist..."
EXPORT_OPTIONS="src-tauri/ios-config/ExportOptions.plist"

if [ ! -f "$EXPORT_OPTIONS" ]; then
    echo "❌ ExportOptions.plist not found: $EXPORT_OPTIONS"
    exit 1
fi

METHOD=$(grep -A1 "<key>method</key>" "$EXPORT_OPTIONS" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
SIGNING_STYLE=$(grep -A1 "<key>signingStyle</key>" "$EXPORT_OPTIONS" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

echo "✅ ExportOptions configuration:"
echo "   Method: $METHOD"
echo "   Signing Style: $SIGNING_STYLE"
echo ""

# Step 5: Check API credentials (if available)
echo "5. Checking App Store Connect API Credentials..."
if [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ]; then
    echo "✅ API Key ID: ${APP_STORE_CONNECT_API_KEY_ID}"
else
    echo "⚠️  APP_STORE_CONNECT_API_KEY_ID not set"
fi

if [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]; then
    echo "✅ Issuer ID: ${APP_STORE_CONNECT_ISSUER_ID}"
else
    echo "⚠️  APP_STORE_CONNECT_ISSUER_ID not set"
fi

if [ -f "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]; then
    echo "✅ API Key file: ${APP_STORE_CONNECT_API_KEY_PATH}"
elif [ -n "${APP_STORE_CONNECT_API_PRIVATE_KEY:-}" ]; then
    echo "✅ API Key content: (base64 encoded)"
else
    echo "⚠️  No API key found (set APP_STORE_CONNECT_API_KEY_PATH or APP_STORE_CONNECT_API_PRIVATE_KEY)"
fi

echo ""
echo "🎉 Verification complete!"
echo "Run './scripts/ios-testflight-release.sh' to build and upload to TestFlight"