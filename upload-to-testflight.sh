#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_PATH="${PROJECT_PATH:-$(pwd)}"
IPA_PATH="${1:-$PROJECT_PATH/OpenCode_Nexus.ipa}"

# Load credentials
source ~/.credentials/.env

if [ ! -f "$IPA_PATH" ]; then
    echo -e "${RED}[ERROR]${NC} IPA file not found at: $IPA_PATH"
    exit 1
fi

if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ] || [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
    echo -e "${RED}[ERROR]${NC} API credentials not found in .env"
    exit 1
fi

# Check if private key file exists
PRIVATE_KEY_PATH="~/.appstoreconnect/private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH/#\~/$HOME}"

if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo -e "${RED}[ERROR]${NC} Private key not found at: $PRIVATE_KEY_PATH"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Uploading IPA to TestFlight..."
echo -e "${BLUE}[INFO]${NC} IPA: $IPA_PATH"
echo -e "${BLUE}[INFO]${NC} Size: $(ls -lh "$IPA_PATH" | awk '{print $5}')"
echo -e "${BLUE}[INFO]${NC} API Key ID: $APP_STORE_CONNECT_API_KEY_ID"
echo -e "${BLUE}[INFO]${NC} Issuer ID: $APP_STORE_CONNECT_ISSUER_ID"

# Create temporary directory for API key
TEMP_API_DIR=$(mktemp -d)
trap "rm -rf $TEMP_API_DIR" EXIT

# Copy private key to temp directory
API_KEY_FILE="$TEMP_API_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
cp "$PRIVATE_KEY_PATH" "$API_KEY_FILE"

# Upload using xcrun altool with API key
echo -e "${BLUE}[INFO]${NC} Starting upload..."

if xcrun altool \
    --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --apiKeysDir "$TEMP_API_DIR" \
    --output-format json; then
    
    echo -e "${GREEN}[SUCCESS]${NC} IPA uploaded to TestFlight successfully!"
    echo -e "${BLUE}[INFO]${NC} Check App Store Connect in 5-10 minutes: https://appstoreconnect.apple.com/apps/6754924026/testflight/ios"
else
    echo -e "${RED}[ERROR]${NC} Upload failed"
    exit 1
fi

