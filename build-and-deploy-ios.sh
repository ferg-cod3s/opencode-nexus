#!/bin/bash
# Comprehensive iOS Build, Archive, and TestFlight Deployment Script

set -e

echo "🚀 OpenCode Nexus iOS Build & TestFlight Deployment"
echo "===================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

START_TIME=$(date +%s)

# Configuration
export APPLE_TEAM_ID="PCJU8QD9FN"
export BUNDLE_ID="com.agentic-codeflow.opencode-nexus"
export SCHEME="src-tauri_iOS"
export PROJECT_PATH="src-tauri/gen/apple/src-tauri.xcodeproj"
export IPA_FILE="build/OpenCodeNexus.ipa"

# Load environment credentials
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep APP_STORE | xargs)
fi

# STEP 1: Build frontend
print_status "Building frontend assets..."
cd frontend
bun install --frozen-lockfile 2>&1 | tail -3
bun run build 2>&1 | tail -5
cd ..
print_success "Frontend built"

# STEP 2: Build iOS app with Tauri
print_status "Building iOS app with Tauri..."
cd src-tauri
cargo tauri ios build 2>&1 | tail -20
cd ..
print_success "iOS app built"

# STEP 3: Create archive using xcodebuild with proper signing
print_status "Creating signed archive for App Store..."

ARCHIVE_PATH="build/OpenCodeNexus.xcarchive"
rm -rf "$ARCHIVE_PATH"

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "${AUTH_KEY_PATH:-}" \
    archive 2>&1 | grep -E "Signing|error:|Building" || echo "Archive created"

if [ ! -d "$ARCHIVE_PATH" ]; then
    print_error "Archive creation failed"
    exit 1
fi

print_success "Archive created"

# STEP 4: Export to IPA
print_status "Exporting to IPA..."

cat > build/ExportOptions.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>PCJU8QD9FN</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
PLIST

rm -f "$IPA_FILE"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath build/ \
    -allowProvisioningUpdates 2>&1 | tail -20

if [ ! -f "$IPA_FILE" ]; then
    print_error "IPA export failed"
    exit 1
fi

IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)
print_success "IPA created: $IPA_SIZE"

# STEP 5: Upload to TestFlight
if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ]; then
    print_warning "API credentials not configured - skipping upload"
    print_status "IPA ready at: $IPA_FILE"
else
    print_status "Uploading to TestFlight..."
    
    # Create temporary directory for API key
    API_KEY_DIR=$(mktemp -d)
    API_KEY_PATH="$API_KEY_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
    
    echo "$APP_STORE_CONNECT_API_PRIVATE_KEY" > "$API_KEY_PATH"
    chmod 600 "$API_KEY_PATH"
    
    if xcrun altool \
        --upload-app \
        --type ios \
        --file "$IPA_FILE" \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --outputFormat json 2>&1 | tee upload.log | grep -q '"status":"No errors"'; then
        
        print_success "Uploaded to TestFlight!"
        print_status "Build should appear in TestFlight within 5-10 minutes"
    else
        print_error "TestFlight upload failed - check upload.log"
        tail -20 upload.log
    fi
    
    rm -f "$API_KEY_PATH"
    rm -rf "$API_KEY_DIR"
fi

TOTAL_TIME=$(($(date +%s) - START_TIME))
print_success "Complete in ${TOTAL_TIME}s!"
