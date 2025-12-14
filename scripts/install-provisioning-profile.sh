#!/bin/bash
# install-provisioning-profile.sh - Install and verify provisioning profile
set -euo pipefail

PROFILE_SOURCE="${1:?Error: Provide path to .mobileprovision file}"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

# Create directory if needed
mkdir -p "$PROFILE_DIR"

# Extract UUID from profile
PROFILE_UUID=$(openssl smime -verify -inform DER -in "$PROFILE_SOURCE" -noverify 2>/dev/null | \
    grep -A1 "<key>UUID</key>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

if [ -z "$PROFILE_UUID" ]; then
    echo "❌ Failed to extract UUID from profile"
    exit 1
fi

# Copy with UUID as filename (Xcode standard)
DEST_PATH="$PROFILE_DIR/${PROFILE_UUID}.mobileprovision"
cp "$PROFILE_SOURCE" "$DEST_PATH"

# Extract and display profile info
PROFILE_NAME=$(openssl smime -verify -inform DER -in "$PROFILE_SOURCE" -noverify 2>/dev/null | \
    grep -A1 "<key>Name</key>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

BUNDLE_ID=$(openssl smime -verify -inform DER -in "$PROFILE_SOURCE" -noverify 2>/dev/null | \
    grep -A1 "<key>application-identifier</key>" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

EXPIRATION=$(openssl smime -verify -inform DER -in "$PROFILE_SOURCE" -noverify 2>/dev/null | \
    grep -A1 "<key>ExpirationDate</key>" | grep "<date>" | sed 's/.*<date>\(.*\)<\/date>.*/\1/' | cut -d'T' -f1)

echo "✅ Provisioning profile installed"
echo "   Name: $PROFILE_NAME"
echo "   UUID: $PROFILE_UUID"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Expires: $EXPIRATION"
echo "   Path: $DEST_PATH"

# Export for use in build scripts
echo "PROVISIONING_PROFILE_UUID=$PROFILE_UUID"