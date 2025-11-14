#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_PATH="/Users/johnferguson/Github/opencode-nexus"
TEAM_ID="PCJU8QD9FN"

cd "$PROJECT_PATH"

echo -e "${BLUE}[INFO]${NC} Building iOS app using Tauri iOS build..."

# Step 1: Build frontend
echo -e "${BLUE}[INFO]${NC} Building frontend..."
cd frontend && bun run build && cd ..
echo -e "${GREEN}[SUCCESS]${NC} Frontend built"

# Step 2: Use Tauri to build iOS (this generates Xcode project)
echo -e "${BLUE}[INFO]${NC} Building iOS with Tauri iOS build..."
cd src-tauri

# First, initialize iOS if not already done
if [ ! -d "gen/apple" ]; then
    echo -e "${BLUE}[INFO]${NC} Initializing iOS..."
    cargo tauri ios init
fi

# Now build using Tauri's iOS build which handles Xcode properly
# Release mode is passed after --
RUST_BACKTRACE=0 cargo tauri ios build -- --configuration Release

cd ../..

echo -e "${GREEN}[SUCCESS]${NC} iOS build complete"

# Find the generated IPA
IPA_FILE=$(find "$PROJECT_PATH/src-tauri/gen/apple" -name "*.ipa" -type f | head -1)

if [ -z "$IPA_FILE" ]; then
    echo -e "${BLUE}[INFO]${NC} No IPA found from Tauri build, checking for archive..."
    
    # If no IPA, we may need to extract from archive
    ARCHIVE=$(find "$PROJECT_PATH/src-tauri/gen/apple" -name "*.xcarchive" -type d | head -1)
    if [ -n "$ARCHIVE" ]; then
        echo -e "${BLUE}[INFO]${NC} Found archive: $ARCHIVE"
        
        # Create export options plist
        EXPORT_PLIST="/tmp/ExportOptions.plist"
        cat > "$EXPORT_PLIST" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>PCJU8QD9FN</string>
</dict>
</plist>
PLIST
        
        EXPORT_DIR="/tmp/ipa_export"
        mkdir -p "$EXPORT_DIR"
        
        echo -e "${BLUE}[INFO]${NC} Exporting IPA from archive..."
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE" \
            -exportOptionsPlist "$EXPORT_PLIST" \
            -exportPath "$EXPORT_DIR" \
            -allowProvisioningUpdates
        
        IPA_FILE=$(find "$EXPORT_DIR" -name "*.ipa" -type f)
        if [ -n "$IPA_FILE" ]; then
            cp "$IPA_FILE" "$PROJECT_PATH/OpenCode_Nexus.ipa"
            echo -e "${GREEN}[SUCCESS]${NC} IPA exported: $PROJECT_PATH/OpenCode_Nexus.ipa"
        fi
    fi
fi

if [ -f "$PROJECT_PATH/OpenCode_Nexus.ipa" ]; then
    ls -lh "$PROJECT_PATH/OpenCode_Nexus.ipa"
    echo -e "${GREEN}[SUCCESS]${NC} IPA is ready for upload!"
else
    echo -e "${RED}[ERROR]${NC} Could not find or create IPA file"
    exit 1
fi

