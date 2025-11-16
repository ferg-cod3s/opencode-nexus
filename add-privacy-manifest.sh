#!/bin/bash
# Add Privacy Manifest to iOS Build
# This ensures PrivacyInfo.xcprivacy is included in every Xcode build

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRIVACY_FILE="$SCRIPT_DIR/src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy"
PROJECT_FILE="$SCRIPT_DIR/src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj"

echo "Adding Privacy Manifest to Xcode project..."

# Check if privacy manifest exists
if [ ! -f "$PRIVACY_FILE" ]; then
    echo "Error: PrivacyInfo.xcprivacy not found at $PRIVACY_FILE"
    exit 1
fi

# Validate privacy manifest
plutil -lint "$PRIVACY_FILE" || {
    echo "Error: Invalid privacy manifest XML"
    exit 1
}

# Check if already in project
if grep -q "PrivacyInfo.xcprivacy" "$PROJECT_FILE"; then
    echo "Privacy manifest already in Xcode project ✅"
else
    echo "Adding privacy manifest to Xcode project..."
    
    # Generate unique ID for the file reference
    PRIVACY_FILE_ID=$(uuidgen | tr '[:lower:]' '[:upper:]' | tr -d '-' | cut -c 1-24)
    PRIVACY_BUILD_ID=$(uuidgen | tr '[:lower:]' '[:upper:]' | tr -d '-' | cut -c 1-24)
    
    # Backup project file
    cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
    
    # Add file reference (after entitlements)
    sed -i '' "/src-tauri_iOS.entitlements/a\\
\t\t$PRIVACY_FILE_ID /* PrivacyInfo.xcprivacy */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; };
" "$PROJECT_FILE"
    
    # Add to build file section (after Assets.xcassets)
    sed -i '' "/Assets.xcassets in Resources/a\\
\t\t$PRIVACY_BUILD_ID /* PrivacyInfo.xcprivacy in Resources */ = {isa = PBXBuildFile; fileRef = $PRIVACY_FILE_ID /* PrivacyInfo.xcprivacy */; };
" "$PROJECT_FILE"
    
    # Add to file group (after entitlements)
    sed -i '' "/0C5D7940F7C4BFDEA6173651 \/\* src-tauri_iOS.entitlements \*\//a\\
\t\t\t\t$PRIVACY_FILE_ID /* PrivacyInfo.xcprivacy */,
" "$PROJECT_FILE"
    
    # Add to Resources build phase
    sed -i '' "/6B75E98049548D6E03A78DC9 \/\* LaunchScreen.storyboard in Resources \*\//a\\
\t\t\t\t$PRIVACY_BUILD_ID /* PrivacyInfo.xcprivacy in Resources */,
" "$PROJECT_FILE"
    
    echo "Privacy manifest added to Xcode project ✅"
fi

echo "Done! Privacy manifest will be included in all future builds."
