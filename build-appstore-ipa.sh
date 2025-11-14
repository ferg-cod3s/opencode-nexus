#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_PATH="/Users/johnferguson/Github/opencode-nexus"
TEAM_ID="PCJU8QD9FN"
SIGNING_CERTIFICATE="Apple Distribution: John Ferguson (PCJU8QD9FN)"
ENTITLEMENTS="$PROJECT_PATH/src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements"
PROVISIONING_PROFILE_PATH="$HOME/Library/MobileDevice/Provisioning Profiles/OpenCode_Nexus_App_Store(1).mobileprovision"

cd "$PROJECT_PATH"

# Step 1: Build frontend
echo -e "${BLUE}[INFO]${NC} Building frontend..."
cd frontend && bun run build && cd ..
echo -e "${GREEN}[SUCCESS]${NC} Frontend built"

# Step 2: Build iOS release
echo -e "${BLUE}[INFO]${NC} Building iOS app release..."
cd src-tauri
cargo build --release --target aarch64-apple-ios
cd ..
echo -e "${GREEN}[SUCCESS]${NC} iOS built"

# Step 3: Build archive and sign with distribution certificate  
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/src-tauri-hgvkaafvyemsvccsgvamzrdyilmy/Build/Products/release-iphoneos/OpenCode Nexus.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}[ERROR]${NC} App not found at $APP_PATH"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Creating IPA with App Store provisioning profile..."

# Create staging directory
STAGING="/tmp/ipa-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING/Payload"

# Copy app bundle
cp -r "$APP_PATH" "$STAGING/Payload/"

# Remove existing signature
echo -e "${BLUE}[INFO]${NC} Removing existing signature..."
codesign --remove-signature "$STAGING/Payload/OpenCode Nexus.app" 2>/dev/null || true

# Replace embedded provisioning profile with App Store one
echo -e "${BLUE}[INFO]${NC} Installing App Store provisioning profile..."
if [ -f "$PROVISIONING_PROFILE_PATH" ]; then
    cp "$PROVISIONING_PROFILE_PATH" "$STAGING/Payload/OpenCode Nexus.app/embedded.mobileprovision"
    echo -e "${GREEN}[SUCCESS]${NC} App Store provisioning profile installed"
else
    echo -e "${RED}[ERROR]${NC} App Store provisioning profile not found at: $PROVISIONING_PROFILE_PATH"
    exit 1
fi

# Sign frameworks if they exist
if [ -d "$STAGING/Payload/OpenCode Nexus.app/Frameworks" ]; then
    echo -e "${BLUE}[INFO]${NC} Signing frameworks..."
    find "$STAGING/Payload/OpenCode Nexus.app/Frameworks" -type d -name "*.framework" | while read framework; do
        codesign -f -s "$SIGNING_CERTIFICATE" "$framework" 2>/dev/null || true
    done
fi

# Sign the app with distribution certificate
echo -e "${BLUE}[INFO]${NC} Re-signing app with distribution certificate..."
codesign -f -s "$SIGNING_CERTIFICATE" \
    --entitlements "$ENTITLEMENTS" \
    "$STAGING/Payload/OpenCode Nexus.app" \
    -v

echo -e "${GREEN}[SUCCESS]${NC} App signed with distribution certificate"

# Create IPA
IPA_PATH="$PROJECT_PATH/OpenCode_Nexus.ipa"
echo -e "${BLUE}[INFO]${NC} Creating IPA package..."
cd "$STAGING"
zip -r "$IPA_PATH" Payload/ -q
cd - > /dev/null

echo -e "${GREEN}[SUCCESS]${NC} IPA created: $IPA_PATH"
ls -lh "$IPA_PATH"

# Verify the signature
echo -e "${BLUE}[INFO]${NC} Verifying IPA signature..."
if codesign -v "$STAGING/Payload/OpenCode Nexus.app" 2>&1 | grep -q "valid on disk"; then
    echo -e "${GREEN}[SUCCESS]${NC} IPA signature verified"
else
    echo -e "${RED}[WARNING]${NC} Could not verify IPA signature"
fi

# Verify provisioning profile in IPA
echo -e "${BLUE}[INFO]${NC} Verifying provisioning profile in IPA..."
unzip -q "$IPA_PATH" -d /tmp/ipa_verify
EMBEDDED_PROFILE="/tmp/ipa_verify/Payload/OpenCode Nexus.app/embedded.mobileprovision"
if [ -f "$EMBEDDED_PROFILE" ]; then
    TEAM_ID_IN_PROFILE=$(security cms -D -i "$EMBEDDED_PROFILE" 2>/dev/null | grep -m 1 -A 1 "<string>PCJU8QD9FN" || echo "")
    if [ -n "$TEAM_ID_IN_PROFILE" ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Correct Team ID found in provisioning profile"
    else
        echo -e "${RED}[WARNING]${NC} Team ID not found in provisioning profile"
    fi
else
    echo -e "${RED}[ERROR]${NC} Embedded provisioning profile not found"
fi

rm -rf /tmp/ipa_verify

echo -e "${GREEN}[SUCCESS]${NC} IPA is ready for upload!"

