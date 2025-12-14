#!/bin/bash
# upload-testflight.sh - Upload IPA to TestFlight via App Store Connect API
set -euo pipefail

# Required environment variables
IPA_PATH="${1:?Error: Provide path to IPA file}"
API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:?Error: APP_STORE_CONNECT_API_KEY_ID required}"
API_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:?Error: APP_STORE_CONNECT_ISSUER_ID required}"

# API key can be path to .p8 file OR base64-encoded content
API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"
API_KEY_CONTENT="${APP_STORE_CONNECT_API_PRIVATE_KEY:-}"

# Verify IPA exists
if [ ! -f "$IPA_PATH" ]; then
    echo "❌ IPA file not found: $IPA_PATH"
    exit 1
fi

echo "🚀 Uploading to TestFlight"
echo "=========================="
echo "IPA: $IPA_PATH"
echo "Key ID: $API_KEY_ID"
echo "Issuer ID: $API_ISSUER_ID"

# Setup API key directory
TEMP_KEY_DIR=$(mktemp -d)
trap "rm -rf $TEMP_KEY_DIR" EXIT

# Write API key to expected location
if [ -n "$API_KEY_PATH" ] && [ -f "$API_KEY_PATH" ]; then
    # Copy from file path
    mkdir -p "$TEMP_KEY_DIR/private_keys"
    cp "$API_KEY_PATH" "$TEMP_KEY_DIR/private_keys/AuthKey_${API_KEY_ID}.p8"
elif [ -n "$API_KEY_CONTENT" ]; then
    # Decode from base64 (CI environment)
    mkdir -p "$TEMP_KEY_DIR/private_keys"
    echo "$API_KEY_CONTENT" | base64 --decode > "$TEMP_KEY_DIR/private_keys/AuthKey_${API_KEY_ID}.p8"
else
    echo "❌ No API key provided. Set APP_STORE_CONNECT_API_KEY_PATH or APP_STORE_CONNECT_API_PRIVATE_KEY"
    exit 1
fi

chmod 600 "$TEMP_KEY_DIR/private_keys/AuthKey_${API_KEY_ID}.p8"

# Upload using xcrun altool (still supported, widely used)
# Note: notarytool is for macOS apps, altool is correct for iOS
echo "Starting upload..."
UPLOAD_START=$(date +%s)

xcrun altool \
    --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$API_KEY_ID" \
    --apiIssuer "$API_ISSUER_ID" \
    --apiKeysDir "$TEMP_KEY_DIR/private_keys" \
    --verbose 2>&1 | tee /tmp/upload.log

UPLOAD_EXIT=${PIPESTATUS[0]}
UPLOAD_TIME=$(($(date +%s) - UPLOAD_START))

if [ $UPLOAD_EXIT -eq 0 ]; then
    echo ""
    echo "✅ Upload successful! (${UPLOAD_TIME}s)"
    echo "📱 Build will appear in TestFlight within 5-15 minutes"
    echo "🔗 https://appstoreconnect.apple.com/apps/6754924026/testflight/ios"
else
    echo ""
    echo "❌ Upload failed (exit code: $UPLOAD_EXIT)"
    echo "Check /tmp/upload.log for details"
    tail -50 /tmp/upload.log
    exit 1
fi