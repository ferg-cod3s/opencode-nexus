#!/bin/bash
set -euo pipefail

# OpenCode Nexus - TestFlight Upload Script
# Usage: ./upload-testflight.sh [build_number]
# Requires: xcodebuild, xcrun altool, valid Apple Distribution signing certificate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_FILE="$PROJECT_DIR/OpenCodeNexus.xcodeproj"
SCHEME="OpenCodeNexus"
CONFIG="Release"
ARCHIVE_PATH="$PROJECT_DIR/build/OpenCodeNexus.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/export"
EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-c6f421de-3e35-4aab-b96d-4c4461c39766}"
API_PRIVATE_KEYS_DIR="${API_PRIVATE_KEYS_DIR:-$HOME/.appstoreconnect}"
SANITIZED_EXPORT_PATH="${SANITIZED_EXPORT_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"

# Build number (timestamp if not provided)
BUILD_NUMBER="${1:-$(date +%Y%m%d%H%M%S)}"

echo "=== OpenCode Nexus TestFlight Upload ==="
echo "Build number: $BUILD_NUMBER"

if [[ -z "${ASC_KEY_ID:-}" ]]; then
    echo "ERROR: ASC_KEY_ID is not set"
    echo "Set ASC_KEY_ID to your App Store Connect API key ID before running this script."
    exit 1
fi

KEY_FILE="$API_PRIVATE_KEYS_DIR/AuthKey_${ASC_KEY_ID}.p8"
if [[ ! -f "$KEY_FILE" ]]; then
    echo "ERROR: API key file not found: $KEY_FILE"
    echo "Set API_PRIVATE_KEYS_DIR if your AuthKey_<KEY_ID>.p8 file lives elsewhere."
    exit 1
fi

export API_PRIVATE_KEYS_DIR

# Step 1: Regenerate project if needed
if [ ! -d "$PROJECT_FILE" ]; then
    echo "Regenerating Xcode project..."
    cd "$PROJECT_DIR" && xcodegen generate
fi

# Step 2: Archive
echo "Archiving..."
xcodebuild archive \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    BUILD_NUMBER="$BUILD_NUMBER"

# Step 3: Export IPA
echo "Exporting IPA..."
mkdir -p "$EXPORT_PATH"
PATH="$SANITIZED_EXPORT_PATH" xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

# Step 4: Upload to TestFlight
echo "Uploading to TestFlight..."
IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -print -quit)
if [ -z "$IPA_FILE" ]; then
    echo "ERROR: No IPA file found in $EXPORT_PATH"
    exit 1
fi

xcrun altool --upload-package "$IPA_FILE" \
    --type ios \
    --api-key "${ASC_KEY_ID}" \
    --api-issuer "$ASC_ISSUER_ID" \
    --show-progress \
    --output-format json

echo "=== Upload complete ==="
echo "Check App Store Connect for processing status."
