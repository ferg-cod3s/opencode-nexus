#!/bin/bash
# iOS TestFlight Build & Upload Script for OpenCode Nexus
# Creates properly signed archive and uploads to TestFlight

set -e

echo "🚀 OpenCode Nexus iOS TestFlight Build & Upload"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
APPLE_TEAM_ID="${APPLE_TEAM_ID:-PCJU8QD9FN}"
BUNDLE_ID="com.agentic-codeflow.opencode-nexus"
SCHEME="src-tauri_iOS"
PROJECT_PATH="src-tauri/gen/apple/src-tauri.xcodeproj"
EXPORT_OPTIONS="src-tauri/gen/apple/ExportOptions.plist"
ARCHIVE_PATH="build/OpenCodeNexus.xcarchive"
IPA_PATH="build/OpenCodeNexus.ipa"

START_TIME=$(date +%s)
print_status "Build started at $(date)"

# Step 1: Check prerequisites
print_status "Checking prerequisites..."

if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode command line tools not found"
    exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
    print_error "Xcode project not found at $PROJECT_PATH"
    exit 1
fi

print_success "Prerequisites check passed"

# Step 2: Verify code signing identity
print_status "Verifying code signing identity for App Store distribution..."

# List available signing identities
IDENTITIES=$(security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db | grep "Distribution" || true)

if [ -z "$IDENTITIES" ]; then
    print_warning "No 'Distribution' certificate found in login keychain"
    print_status "Available certificates:"
    security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db || true
    print_warning "You may need to download certificate from Apple Developer"
else
    print_success "Found Distribution certificate(s)"
    echo "$IDENTITIES"
fi

# Step 3: Prepare export options
print_status "Creating export options for App Store distribution..."

mkdir -p build

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

print_success "Export options configured for App Store"

# Step 4: Clean and build archive
print_status "Building archive for App Store..."
print_status "This may take 3-5 minutes..."

ARCHIVE_START=$(date +%s)

# Clean build folder
print_status "Cleaning build folder..."
xcodebuild clean -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration Release 2>&1 | tail -5 || true

# Build archive
print_status "Creating archive..."
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    archive \
    2>&1 | grep -E "error:|warning:|Build complete|Compiling" | head -50

ARCHIVE_RESULT=${PIPESTATUS[0]}
ARCHIVE_TIME=$(($(date +%s) - ARCHIVE_START))

if [ $ARCHIVE_RESULT -ne 0 ]; then
    print_error "Archive failed. Check full log:"
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -allowProvisioningUpdates \
        archive \
        2>&1 | tail -100
    exit 1
fi

print_success "Archive created in ${ARCHIVE_TIME}s"

if [ ! -d "$ARCHIVE_PATH" ]; then
    print_error "Archive path not found: $ARCHIVE_PATH"
    exit 1
fi

# Step 5: Export IPA
print_status "Exporting IPA from archive..."

EXPORT_START=$(date +%s)

xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "build/" \
    -allowProvisioningUpdates \
    2>&1 | tail -50

EXPORT_RESULT=${PIPESTATUS[0]}
EXPORT_TIME=$(($(date +%s) - EXPORT_START))

if [ $EXPORT_RESULT -ne 0 ]; then
    print_error "IPA export failed"
    exit 1
fi

print_success "IPA exported in ${EXPORT_TIME}s"

if [ ! -f "$IPA_PATH" ]; then
    print_error "IPA file not found at: $IPA_PATH"
    ls -lh build/
    exit 1
fi

# Step 6: Verify IPA
print_status "Verifying IPA integrity..."
IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
print_success "IPA created successfully: $IPA_SIZE"

# Step 7: Check for TestFlight upload requirements
print_status "Checking TestFlight requirements..."

if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ]; then
    print_warning "APP_STORE_CONNECT_API_KEY_ID not set"
    print_status "TestFlight upload requires API credentials"
    print_status "Set these environment variables to upload:"
    print_status "  - APP_STORE_CONNECT_API_KEY_ID"
    print_status "  - APP_STORE_CONNECT_ISSUER_ID"
    print_status "  - APP_STORE_CONNECT_API_PRIVATE_KEY"
else
    print_status "API credentials detected, preparing upload..."
    
    # Step 8: Upload to TestFlight
    print_status "Uploading to TestFlight..."
    
    # Create temporary directory for API key
    API_KEY_DIR=$(mktemp -d)
    API_KEY_PATH="$API_KEY_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
    
    # Write API key to file
    echo "$APP_STORE_CONNECT_API_PRIVATE_KEY" > "$API_KEY_PATH"
    chmod 600 "$API_KEY_PATH"
    
    # Upload using xcrun altool
    UPLOAD_START=$(date +%s)
    
    print_status "Uploading via App Store Connect API..."
    xcrun altool \
        --upload-app \
        --type ios \
        --file "$IPA_PATH" \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --outputFormat json \
        2>&1 | tee upload.log
    
    UPLOAD_RESULT=${PIPESTATUS[0]}
    UPLOAD_TIME=$(($(date +%s) - UPLOAD_START))
    
    # Clean up API key
    rm -f "$API_KEY_PATH"
    rm -rf "$API_KEY_DIR"
    
    if [ $UPLOAD_RESULT -eq 0 ]; then
        print_success "Uploaded to TestFlight in ${UPLOAD_TIME}s"
        print_status "Build should appear in TestFlight within 5-10 minutes"
        print_status "Check: https://appstoreconnect.apple.com/apps/6754924026/testflight/ios"
    else
        print_error "TestFlight upload failed (code: $UPLOAD_RESULT)"
        print_status "Check upload.log for details"
        tail -30 upload.log
        exit 1
    fi
fi

TOTAL_TIME=$(($(date +%s) - START_TIME))

print_success "Build completed successfully in ${TOTAL_TIME}s!"
echo ""
echo "📊 Build Timing Summary:"
echo "  - Total time: ${TOTAL_TIME}s"
echo "  - Archive: ${ARCHIVE_TIME}s"
echo "  - Export: ${EXPORT_TIME}s"
if [ ! -z "$UPLOAD_TIME" ]; then
    echo "  - Upload: ${UPLOAD_TIME}s"
fi
echo ""
print_success "IPA ready for distribution: $IPA_PATH"
