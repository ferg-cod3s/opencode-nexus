#!/bin/bash
# build-ios-archive.sh - Build iOS archive for TestFlight
set -euo pipefail

# Change to project root directory
cd "$(dirname "$0")/.."

# Configuration
PROJECT_PATH="src-tauri/gen/apple/src-tauri.xcodeproj"
SCHEME="src-tauri_iOS"
CONFIGURATION="${ARCHIVE_CONFIGURATION:-release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/OpenCodeNexus.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-build/ipa}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-src-tauri/ios-config/ExportOptions.plist}"

# Signing configuration
TEAM_ID="PCJU8QD9FN"
CODE_SIGN_ENTITLEMENTS="$(pwd)/src-tauri/ios-config/src-tauri_iOS.entitlements"

# Keychain Configuration
# Uses login keychain by default (where Apple Distribution certificate is stored)
# For CI: Self-hosted runner already has certificate in login keychain
# For local: Developer must set "Always Allow" for codesign access once
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

# Step 2: Clean previous build artifacts
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

# Determine iOS version/build numbers (App Store Connect compatible)
# - CFBundleShortVersionString must be a numeric dot-separated string (no "-dev")
# - CFBundleVersion must be a monotonically increasing numeric string
ROOT_VERSION_RAW=$(python3 -c 'import json; print(json.load(open("package.json"))['"'"'version'"'"'])' 2>/dev/null || true)
ROOT_VERSION_RAW=${ROOT_VERSION_RAW:-"0.0.0-dev001"}

DERIVED_MARKETING_VERSION=""
DERIVED_BUILD_NUMBER=""

# Use python for robust parsing and stripping leading zeros.
read -r DERIVED_MARKETING_VERSION DERIVED_BUILD_NUMBER < <(
  python3 - <<'PY'
import json
import re

try:
  with open('package.json', 'r', encoding='utf-8') as f:
    version_raw = json.load(f).get('version', '0.0.0-dev001')
except Exception:
  version_raw = '0.0.0-dev001'

match = re.match(r'^(\d+\.\d+\.\d+)-dev(\d+)$', version_raw)
if match:
  marketing = match.group(1)
  build = int(match.group(2))
else:
  marketing = version_raw.split('-', 1)[0]
  build = 1

print(marketing, build)
PY
)

IOS_MARKETING_VERSION="${IOS_MARKETING_VERSION:-$DERIVED_MARKETING_VERSION}"
IOS_BUILD_NUMBER="${IOS_BUILD_NUMBER:-$DERIVED_BUILD_NUMBER}"

if [[ ! "$IOS_MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Invalid IOS_MARKETING_VERSION: $IOS_MARKETING_VERSION"
  echo "Expected format: X.Y.Z (numeric)"
  exit 1
fi

if [[ ! "$IOS_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid IOS_BUILD_NUMBER: $IOS_BUILD_NUMBER"
  echo "Expected numeric build number (e.g. 2)"
  exit 1
fi

if [[ "$IOS_BUILD_NUMBER" -le 0 ]]; then
  echo "❌ IOS_BUILD_NUMBER must be >= 1 (got: $IOS_BUILD_NUMBER)"
  exit 1
fi

echo "iOS versioning: MARKETING_VERSION=$IOS_MARKETING_VERSION, CURRENT_PROJECT_VERSION=$IOS_BUILD_NUMBER"

# Step 3: Build archive with automatic signing
echo "Creating archive..."
xcodebuild \
     -project "$PROJECT_PATH" \
     -scheme "$SCHEME" \
     -configuration "$CONFIGURATION" \
     -archivePath "$ARCHIVE_PATH" \
     -destination "generic/platform=iOS" \
     DEVELOPMENT_TEAM="$TEAM_ID" \
     MARKETING_VERSION="$IOS_MARKETING_VERSION" \
     CURRENT_PROJECT_VERSION="$IOS_BUILD_NUMBER" \
     clean archive


ARCHIVE_EXIT=$?

if [ $ARCHIVE_EXIT -ne 0 ] || [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive failed (exit code: $ARCHIVE_EXIT)"
    exit 1
fi

echo "✅ Archive created: $ARCHIVE_PATH"

# Step 4: Export IPA
echo "Exporting IPA..."
xcodebuild \
     -exportArchive \
     -archivePath "$ARCHIVE_PATH" \
     -exportOptionsPlist "$EXPORT_OPTIONS" \
     -exportPath "$EXPORT_PATH" \
     DEVELOPMENT_TEAM="$TEAM_ID" \
     MARKETING_VERSION="$IOS_MARKETING_VERSION" \
     CURRENT_PROJECT_VERSION="$IOS_BUILD_NUMBER"

EXPORT_EXIT=$?

if [ $EXPORT_EXIT -ne 0 ]; then
    echo "❌ Export failed (exit code: $EXPORT_EXIT)"
    exit 1
fi

# Find the generated IPA
IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -1)

if [ -z "$IPA_FILE" ]; then
    echo "❌ No IPA file found in $EXPORT_PATH"
    ls -la "$EXPORT_PATH"
    exit 1
fi

IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)
echo "✅ IPA exported: $IPA_FILE ($IPA_SIZE)"

# Step 5: Validate IPA structure
echo "Validating IPA structure..."
IPA_CONTENTS=$(unzip -l "$IPA_FILE" 2>/dev/null | grep -E "Payload/|Info.plist" | wc -l)
if [ "$IPA_CONTENTS" -lt 2 ]; then
    echo "❌ IPA validation failed - missing required files"
    unzip -l "$IPA_FILE"
    exit 1
fi

# Check for Info.plist
if ! unzip -l "$IPA_FILE" 2>/dev/null | grep -q "Info.plist"; then
    echo "❌ IPA validation failed - no Info.plist found"
    exit 1
fi

# Skip codesign validation for now due to keychain issues
echo "⚠️  Skipping code signature validation (keychain locked)"
echo "✅ IPA structure validation passed"

# Export path for subsequent scripts
echo "IPA_PATH=$IPA_FILE"