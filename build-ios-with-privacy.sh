#!/bin/bash
# Build iOS IPA with Privacy Manifest
# This ensures PrivacyInfo.xcprivacy is included in the final IPA

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRIVACY_FILE="$SCRIPT_DIR/src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy"

echo "Building iOS app with privacy manifest..."

# Step 1: Build iOS app with Tauri
echo "Step 1: Building iOS app..."
cd "$SCRIPT_DIR/src-tauri"
cargo tauri ios build

# Step 2: Find the built app
echo "Step 2: Locating built app..."
APP_PATH=$(find "$SCRIPT_DIR/src-tauri/gen/apple/build" -name "*.app" -path "*/ArchiveIntermediates/*" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built .app"
    exit 1
fi

echo "Found app at: $APP_PATH"

# Step 3: Copy privacy manifest into app bundle
echo "Step 3: Adding privacy manifest to app bundle..."
cp "$PRIVACY_FILE" "$APP_PATH/PrivacyInfo.xcprivacy"
echo "Privacy manifest copied ✅"

# Step 4: Re-sign the app
echo "Step 4: Re-signing app..."
codesign --force --sign "Apple Distribution: John Ferguson (PCJU8QD9FN)" \
    --timestamp \
    --entitlements "$SCRIPT_DIR/src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements" \
    "$APP_PATH"
echo "App re-signed ✅"

# Step 5: Export IPA with privacy manifest
echo "Step 5: Exporting IPA..."
cd "$SCRIPT_DIR/src-tauri/gen/apple"
xcodebuild -exportArchive \
    -archivePath build/src-tauri_iOS.xcarchive \
    -exportPath build/ipa_with_privacy \
    -exportOptionsPlist ExportOptions.plist

# Step 6: Verify privacy manifest is in IPA
echo "Step 6: Verifying privacy manifest..."
if unzip -l "build/ipa_with_privacy/OpenCode Nexus.ipa" | grep -q "PrivacyInfo.xcprivacy"; then
    echo "✅ Privacy manifest confirmed in IPA"
else
    echo "⚠️  Privacy manifest NOT found in IPA"
    exit 1
fi

# Step 7: Copy to build directory
echo "Step 7: Copying IPA to build directory..."
cp "build/ipa_with_privacy/OpenCode Nexus.ipa" "$SCRIPT_DIR/build/OpenCodeNexus_v0.1.5_privacy.ipa"

echo ""
echo "==================================="
echo "Build complete! ✅"
echo "IPA location: build/OpenCodeNexus_v0.1.5_privacy.ipa"
echo "Privacy manifest: INCLUDED ✅"
echo "==================================="
echo ""
echo "To upload to TestFlight:"
echo "  source .env"
echo "  xcrun altool --upload-app \\"
echo "    --type ios \\"
echo "    --file build/OpenCodeNexus_v0.1.5_privacy.ipa \\"
echo "    --apiKey \$APP_STORE_CONNECT_API_KEY_ID \\"
echo "    --apiIssuer \$APP_STORE_CONNECT_ISSUER_ID"
