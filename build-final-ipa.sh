#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_PATH="/Users/johnferguson/Github/opencode-nexus"
TEAM_ID="PCJU8QD9FN"
BUNDLE_ID="com.agentic-codeflow.opencode-nexus"
SIGNING_CERTIFICATE="Apple Distribution: John Ferguson (PCJU8QD9FN)"
PROVISIONING_PROFILE_UUID="426123c5-c69c-4778-81ed-1210fc35a282"

cd "$PROJECT_PATH"

echo -e "${BLUE}[INFO]${NC} Building final iOS IPA for App Store..."

# Step 1: Build frontend
echo -e "${BLUE}[INFO]${NC} Building frontend..."
cd frontend && bun run build && cd ..
echo -e "${GREEN}[SUCCESS]${NC} Frontend built"

# Step 2: Build Rust
echo -e "${BLUE}[INFO]${NC} Building Rust for iOS..."
cd src-tauri
cargo build --release --target aarch64-apple-ios
cd ..
echo -e "${GREEN}[SUCCESS]${NC} Rust built"

# Step 3: Use xcodebuild to archive with manual signing
echo -e "${BLUE}[INFO]${NC} Building archive with xcodebuild..."

ARCHIVE_PATH="/tmp/OpenCode_Nexus.xcarchive"
rm -rf "$ARCHIVE_PATH"

cd src-tauri/gen/apple

xcodebuild archive \
    -project src-tauri.xcodeproj \
    -scheme src-tauri_iOS \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_IDENTITY="$SIGNING_CERTIFICATE" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PROVISIONING_PROFILE="$PROVISIONING_PROFILE_UUID" \
    -allowProvisioningUpdates \
    -derivedDataPath /tmp/xcode_build

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}[ERROR]${NC} Archive creation failed"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Archive created"

# Step 4: Create export options plist for App Store
EXPORT_OPTIONS="/tmp/ExportOptions_AppStore.plist"
cat > "$EXPORT_OPTIONS" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>PCJU8QD9FN</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.agentic-codeflow.opencode-nexus</key>
        <string>OpenCode_Nexus_App_Store(1)</string>
    </dict>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
</dict>
</plist>
PLIST

echo -e "${BLUE}[INFO]${NC} Exporting IPA..."

EXPORT_DIR="/tmp/ipa_export_final"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates

# Find and copy IPA
IPA_FILE=$(find "$EXPORT_DIR" -name "*.ipa" -type f)
if [ -z "$IPA_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} IPA export failed - no IPA file found"
    exit 1
fi

cp "$IPA_FILE" "$PROJECT_PATH/OpenCode_Nexus.ipa"
echo -e "${GREEN}[SUCCESS]${NC} IPA exported to: $PROJECT_PATH/OpenCode_Nexus.ipa"
ls -lh "$PROJECT_PATH/OpenCode_Nexus.ipa"

cd ../../..

# Verify the IPA
echo -e "${BLUE}[INFO]${NC} Verifying IPA..."
unzip -q "$PROJECT_PATH/OpenCode_Nexus.ipa" -d /tmp/ipa_verify_final
EMBEDDED_PROFILE="/tmp/ipa_verify_final/Payload/OpenCode Nexus.app/embedded.mobileprovision"

if [ -f "$EMBEDDED_PROFILE" ]; then
    if security cms -D -i "$EMBEDDED_PROFILE" 2>/dev/null | grep -q "Apple Distribution"; then
        echo -e "${GREEN}[SUCCESS]${NC} IPA contains App Store provisioning profile"
    else
        echo -e "${RED}[WARNING]${NC} Provisioning profile may not be App Store profile"
    fi
else
    echo -e "${RED}[ERROR]${NC} No provisioning profile in IPA"
fi

rm -rf /tmp/ipa_verify_final

echo -e "${GREEN}[SUCCESS]${NC} IPA is ready for upload to TestFlight!"

