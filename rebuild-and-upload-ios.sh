#!/bin/bash
# Rebuild iOS app with App Store profile and upload to TestFlight

set -e

echo "🔨 Rebuilding iOS app for App Store..."
echo "======================================"

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

# Step 1: Check provisioning profile
print_status "Checking for App Store provisioning profile..."
PROFILE_COUNT=$(ls ~/Library/MobileDevice/Provisioning\ Profiles/ 2>/dev/null | wc -l)

if [ $PROFILE_COUNT -eq 0 ]; then
    print_error "No provisioning profiles found!"
    print_status "Please follow the guide: GET_APPSTORE_PROFILE.md"
    print_status "Then run this script again"
    exit 1
fi

print_success "Found $PROFILE_COUNT provisioning profile(s)"

# Step 2: Clean derived data
print_status "Cleaning previous build data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/src-tauri-* 2>/dev/null || true
print_success "Cleaned"

# Step 3: Build frontend
print_status "Building frontend..."
cd frontend
bun install --frozen-lockfile 2>&1 | tail -2
bun run build 2>&1 | tail -3
cd ..
print_success "Frontend built"

# Step 4: Build iOS
print_status "Building iOS app (this may take 3-5 minutes)..."
cd src-tauri
cargo tauri ios build 2>&1 | grep -E "Finished|error:|Signing" | head -20
cd ..
print_success "iOS app built"

# Step 5: Find built app
APP_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData/src-tauri-*/Build/Products/release-iphoneos/ -name "OpenCode Nexus.app" -type d | head -1)

if [ -z "$APP_BUNDLE" ]; then
    print_error "App bundle not found!"
    exit 1
fi

print_status "App found: $APP_BUNDLE"

# Step 6: Create IPA
print_status "Packaging IPA..."
STAGING="build/ipa-rebuild"
rm -rf "$STAGING"
mkdir -p "$STAGING/Payload"
cp -r "$APP_BUNDLE" "$STAGING/Payload/"
cd "$STAGING"
zip -r -q ../OpenCodeNexus_new.ipa Payload
cd ../..

if [ -f "build/OpenCodeNexus_new.ipa" ]; then
    rm -f build/OpenCodeNexus.ipa
    mv build/OpenCodeNexus_new.ipa build/OpenCodeNexus.ipa
    SIZE=$(du -h build/OpenCodeNexus.ipa | cut -f1)
    print_success "IPA packaged: $SIZE"
else
    print_error "IPA packaging failed"
    exit 1
fi

# Step 7: Check provisioning profile in app
print_status "Verifying provisioning profile..."
if unzip -l build/OpenCodeNexus.ipa | grep -q "embedded.mobileprovision"; then
    print_success "Provisioning profile embedded"
else
    print_warning "No provisioning profile found in IPA"
fi

# Step 8: Upload to TestFlight
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | grep APP_STORE | xargs)
fi

if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ]; then
    print_warning "API credentials not set"
    print_status "To upload manually:"
    print_status "  source .env"
    print_status "  xcrun altool --upload-app --type ios --file build/OpenCodeNexus.ipa --apiKey \$APP_STORE_CONNECT_API_KEY_ID --apiIssuer \$APP_STORE_CONNECT_ISSUER_ID"
else
    print_status "Uploading to TestFlight..."
    
    API_KEY_DIR=$(mktemp -d -t app_upload)
    API_KEY_PATH="$API_KEY_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
    echo "$APP_STORE_CONNECT_API_PRIVATE_KEY" > "$API_KEY_PATH"
    chmod 600 "$API_KEY_PATH"
    
    if xcrun altool \
        --upload-app \
        --type ios \
        --file build/OpenCodeNexus.ipa \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --outputFormat json 2>&1 | tee upload.log | grep -q '"message":"No errors"'; then
        
        print_success "Uploaded to TestFlight!"
        print_status "v0.1.3 should appear within 5-10 minutes"
        print_status "Check: https://appstoreconnect.apple.com/apps/6754924026/testflight/ios"
    else
        print_error "Upload failed - check upload.log"
        tail -30 upload.log
    fi
    
    rm -f "$API_KEY_PATH"
    rmdir "$API_KEY_DIR" 2>/dev/null || true
fi

TOTAL_TIME=$(($(date +%s) - START_TIME))
print_success "Complete in ${TOTAL_TIME}s!"
