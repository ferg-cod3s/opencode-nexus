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

echo -e "${BLUE}[INFO]${NC} Creating IPA with distribution signing..."

# Create staging directory
STAGING="/tmp/ipa-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING/Payload"

# Copy app bundle
cp -r "$APP_PATH" "$STAGING/Payload/"

# Re-sign with distribution certificate
echo -e "${BLUE}[INFO]${NC} Re-signing app with distribution certificate..."
codesign --remove-signature "$STAGING/Payload/OpenCode Nexus.app" 2>/dev/null || true

# Sign frameworks first if they exist
if [ -d "$STAGING/Payload/OpenCode Nexus.app/Frameworks" ]; then
    find "$STAGING/Payload/OpenCode Nexus.app/Frameworks" -name "*.framework" -o -name "*.dylib" | while read framework; do
        echo -e "${BLUE}[INFO]${NC} Signing framework: $(basename "$framework")"
        codesign -f -s "$SIGNING_CERTIFICATE" "$framework" || true
    done
fi

# Sign the app
codesign -f -s "$SIGNING_CERTIFICATE" \
    --entitlements "$ENTITLEMENTS" \
    "$STAGING/Payload/OpenCode Nexus.app" \
    -v

echo -e "${GREEN}[SUCCESS]${NC} App signed"

# Create IPA
IPA_PATH="$PROJECT_PATH/OpenCode_Nexus.ipa"
cd "$STAGING"
zip -r "$IPA_PATH" Payload/ SwiftSupport/ 2>/dev/null || zip -r "$IPA_PATH" Payload/ || true
cd - > /dev/null

echo -e "${GREEN}[SUCCESS]${NC} IPA created: $IPA_PATH"
ls -lh "$IPA_PATH"

# Step 4: Upload to TestFlight
if [ -f ~/.credentials/.env ]; then
    echo -e "${BLUE}[INFO]${NC} Loading credentials..."
    source ~/.credentials/.env
    
    if [ -z "$APP_STORE_USERNAME" ] || [ -z "$APP_STORE_PASSWORD" ]; then
        echo -e "${RED}[ERROR]${NC} Credentials not found in .env"
        exit 1
    fi
    
    echo -e "${BLUE}[INFO]${NC} Uploading to TestFlight..."
    
    xcrun altool --upload-app \
        -f "$IPA_PATH" \
        -t ios \
        -u "$APP_STORE_USERNAME" \
        -p "$APP_STORE_PASSWORD" \
        --output-format json
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Upload complete!"
    else
        echo -e "${RED}[ERROR]${NC} Upload failed"
        exit 1
    fi
fi

echo -e "${GREEN}[SUCCESS]${NC} All done!"
