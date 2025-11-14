#!/bin/bash
# iOS Build, Archive, and TestFlight Upload Script
# Uses already-built app from tauri ios build

set -e

echo "🚀 iOS App Archive & TestFlight Upload"
echo "========================================"

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
print_status "Build started at $(date)"

# Configuration
PROJECT_PATH="src-tauri/gen/apple/src-tauri.xcodeproj"
SCHEME="src-tauri_iOS"
ARCHIVE_PATH="build/OpenCodeNexus.xcarchive"
IPA_PATH="build/OpenCodeNexus.ipa"
EXPORT_OPTIONS="src-tauri/gen/apple/ExportOptions.plist"

# Create build directory
mkdir -p build

# Step 1: Create export options for App Store
print_status "Configuring export options for App Store distribution..."
cat > "$EXPORT_OPTIONS" << 'PLIST'
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

print_success "Export options configured"

# Step 2: Create archive with App Store signing
print_status "Creating archive for App Store distribution..."
print_status "This may take 2-3 minutes..."

ARCHIVE_START=$(date +%s)

# Clean previous archive
rm -rf "$ARCHIVE_PATH" 2>/dev/null || true

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    archive \
    2>&1 | grep -E "error:|warning:|Build complete|Compiling|Signing" || true

ARCHIVE_CODE=${PIPESTATUS[0]}
ARCHIVE_TIME=$(($(date +%s) - ARCHIVE_START))

if [ ! -d "$ARCHIVE_PATH" ]; then
    print_error "Archive creation failed"
    print_status "Running full build log..."
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -allowProvisioningUpdates \
        archive 2>&1 | tail -100
    exit 1
fi

print_success "Archive created in ${ARCHIVE_TIME}s"

# Step 3: Export IPA
print_status "Exporting IPA from archive..."

EXPORT_START=$(date +%s)
rm -f "$IPA_PATH" 2>/dev/null || true

xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "build/" \
    -allowProvisioningUpdates \
    2>&1 | tail -50

EXPORT_CODE=${PIPESTATUS[0]}
EXPORT_TIME=$(($(date +%s) - EXPORT_START))

if [ ! -f "$IPA_PATH" ]; then
    print_error "IPA export failed"
    exit 1
fi

print_success "IPA exported in ${EXPORT_TIME}s"

# Step 4: Verify IPA
IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
print_success "IPA created: $IPA_SIZE at $IPA_PATH"

# Step 5: Upload to TestFlight
if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ]; then
    print_warning "API credentials not set - skipping upload"
    print_status "To upload, set:"
    print_status "  export APP_STORE_CONNECT_API_KEY_ID=..."
    print_status "  export APP_STORE_CONNECT_ISSUER_ID=..."
    print_status "  export APP_STORE_CONNECT_API_PRIVATE_KEY=..."
else
    print_status "Uploading to TestFlight..."
    
    API_KEY_DIR=$(mktemp -d)
    API_KEY_PATH="$API_KEY_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
    
    echo "$APP_STORE_CONNECT_API_PRIVATE_KEY" > "$API_KEY_PATH"
    chmod 600 "$API_KEY_PATH"
    
    UPLOAD_START=$(date +%s)
    
    if xcrun altool \
        --upload-app \
        --type ios \
        --file "$IPA_PATH" \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --outputFormat json \
        2>&1 | tee upload.log; then
        
        UPLOAD_TIME=$(($(date +%s) - UPLOAD_START))
        print_success "Uploaded to TestFlight in ${UPLOAD_TIME}s"
        print_status "Build should appear in TestFlight within 5-10 minutes"
    else
        print_error "TestFlight upload failed"
        tail -20 upload.log
    fi
    
    rm -f "$API_KEY_PATH"
    rm -rf "$API_KEY_DIR"
fi

TOTAL_TIME=$(($(date +%s) - START_TIME))
print_success "Complete in ${TOTAL_TIME}s!"
echo ""
echo "📊 Timing Summary:"
echo "  - Archive: ${ARCHIVE_TIME}s"
echo "  - Export: ${EXPORT_TIME}s"
echo "  - Total: ${TOTAL_TIME}s"
echo ""
print_success "IPA: $IPA_PATH"
