# iOS Privacy & Compliance Automation

**Status:** Automated ✅  
**Last Updated:** November 14, 2025

## Overview

This document describes how privacy compliance is automated in OpenCode Nexus iOS builds. As of iOS 16.4+, Apple requires apps to include a **Privacy Manifest** (`PrivacyInfo.xcprivacy`) file that declares:

1. Types of data collected
2. APIs used and their purposes
3. Tracking practices
4. Third-party integrations

This is now **automatically included** in every build. No manual steps needed.

---

## What's Automated

### 1. Privacy Manifest Generation
- **File:** `src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy`
- **Format:** XML plist (Apple's standard)
- **Included in:** Every Xcode build
- **Bundled with:** Final IPA

### 2. Xcode Project Configuration
- **File:** `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`
- **Change:** PrivacyInfo.xcprivacy added to Resources build phase
- **Result:** File automatically bundled during archive/export

### 3. Build Pipeline Integration
- Privacy manifest is included automatically in:
  - ✅ `xcodebuild archive`
  - ✅ `xcodebuild -exportArchive` (IPA export)
  - ✅ GitHub Actions builds
  - ✅ Manual builds via `build-final-ipa.sh`

---

## Privacy Manifest Contents

The `PrivacyInfo.xcprivacy` file declares:

### Data Collection
```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
  <dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeUserID</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>
    <false/>  <!-- Not linked to user -->
    <key>NSPrivacyCollectedDataTypeTracking</key>
    <false/>  <!-- Not used for tracking -->
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array>
      <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
  </dict>
</array>
```

### API Usage Declarations
```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <!-- File timestamp APIs (DDA9.1) -->
  <!-- System boot time APIs (35F9.1) -->
  <!-- User defaults APIs (CA92.1) -->
</array>
```

### Tracking Disabled
```xml
<key>NSPrivacyTracking</key>
<false/>
<key>NSPrivacyTrackingDomains</key>
<array/>  <!-- No tracking domains -->
```

---

## When Privacy Manifest is Applied

The privacy manifest is automatically included during:

### Normal Development Build
```bash
cd frontend && bun run build
cd src-tauri && cargo build --release --target aarch64-apple-ios
cd src-tauri/gen/apple
xcodebuild archive -project src-tauri.xcodeproj -scheme src-tauri_iOS
```

→ PrivacyInfo.xcprivacy bundled automatically ✅

### Build Script (build-final-ipa.sh)
```bash
bash build-final-ipa.sh
```

→ Privacy manifest included in output IPA ✅

### GitHub Actions Workflow
```bash
git tag -a ios-v1.X.X -m "Release"
git push origin ios-v1.X.X
```

→ GitHub Actions automatically includes privacy manifest ✅

### Manual Upload
```bash
xcodebuild -exportArchive -archivePath $ARCHIVE -exportOptionsPlist $PLIST -exportPath $DIR
```

→ IPA includes privacy manifest ✅

---

## Updating Privacy Declaration

If you need to update the privacy manifest (e.g., add new data types or APIs):

### Step 1: Edit Privacy Manifest
```bash
# Open and edit the XML file
nano src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy

# OR use Xcode's editor (visual)
open "src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy"
```

### Step 2: Add New Data Types
```xml
<dict>
  <key>NSPrivacyCollectedDataType</key>
  <string>NSPrivacyCollectedDataTypePhoneNumber</string>
  <key>NSPrivacyCollectedDataTypeLinked</key>
  <false/>
  <key>NSPrivacyCollectedDataTypeTracking</key>
  <false/>
  <key>NSPrivacyCollectedDataTypePurposes</key>
  <array>
    <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
  </array>
</dict>
```

### Step 3: Add New API Declarations
```xml
<dict>
  <key>NSPrivacyAccessedAPIType</key>
  <string>NSPrivacyAccessedAPICategoryUIWebViewJavaScript</string>
  <key>NSPrivacyAccessedAPITypeReasons</key>
  <array>
    <string>CA92.1</string>
  </array>
</dict>
```

### Step 4: Verify and Test
```bash
# Verify XML is valid
plutil -lint src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy

# Rebuild to include changes
bash build-final-ipa.sh

# Check IPA contains updated privacy manifest
unzip -l OpenCode_Nexus.ipa | grep PrivacyInfo
```

### Step 5: Commit Changes
```bash
git add src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy
git commit -m "docs: Update privacy manifest with new data types"
```

---

## Common Data Types

| Type | Value | Use Case |
|------|-------|----------|
| User ID | `NSPrivacyCollectedDataTypeUserID` | Identifying users |
| Device ID | `NSPrivacyCollectedDataTypeDeviceID` | Device identification |
| Email | `NSPrivacyCollectedDataTypeEmailAddress` | Contact info |
| Phone | `NSPrivacyCollectedDataTypePhoneNumber` | Contact info |
| Photos | `NSPrivacyCollectedDataTypePhotoLibrary` | Photo access |
| Location | `NSPrivacyCollectedDataTypeLocation` | GPS data |
| Health | `NSPrivacyCollectedDataTypeHealth` | Health/fitness data |
| Payment | `NSPrivacyCollectedDataTypePaymentInfo` | Payment data |

---

## Common API Declarations

| Purpose Code | API Type | Use Case |
|--------------|----------|----------|
| `DDA9.1` | File Timestamp APIs | Checking file modification times |
| `35F9.1` | System Boot Time | Timing/performance metrics |
| `CA92.1` | User Defaults | Reading/writing app preferences |
| `3EC4.1` | System Volume APIs | Audio/sound control |
| `E7EF.1` | WebView JavaScript | Running JavaScript in web views |

---

## Verification in TestFlight

After uploading to TestFlight:

### Check Privacy Manifest Presence
```bash
# Download IPA from App Store Connect
# Then verify privacy manifest is included

unzip OpenCode_Nexus.ipa
find . -name "PrivacyInfo*"
```

Expected output:
```
./Payload/OpenCode Nexus.app/PrivacyInfo.xcprivacy
```

### Validate XML Format
```bash
plutil -p ./Payload/OpenCode\ Nexus.app/PrivacyInfo.xcprivacy
```

Should show structured plist format without errors.

---

## Troubleshooting

### Privacy Manifest Not in IPA

**Problem:** IPA is missing `PrivacyInfo.xcprivacy`

**Solution:**
1. Verify file exists: `ls -la src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy`
2. Check Xcode project includes it: `grep "PrivacyInfo.xcprivacy" src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`
3. Verify it's in Resources phase: `grep "F0D9E1B2F3C4E5D6A7B8C9E0" src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`
4. Rebuild archive: `bash build-final-ipa.sh`

### Invalid XML Format

**Problem:** Privacy manifest has XML syntax errors

**Solution:**
```bash
# Check validity
plutil -lint src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy

# Fix using plutil
plutil -convert xml1 src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy
```

### App Rejected with "Missing Privacy Manifest"

**Problem:** App Store rejects build saying privacy manifest is missing

**Solution:**
1. Verify privacy manifest is in IPA (see verification section above)
2. Check file has correct extension: `.xcprivacy` (not `.plist`)
3. Ensure it's in app bundle root: `Payload/[AppName].app/PrivacyInfo.xcprivacy`
4. Rebuild with updated Xcode project file
5. Re-upload to TestFlight

---

## Files Modified

### Primary
- `src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy` - The privacy manifest XML

### Supporting
- `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`
  - Added file reference (line ~48)
  - Added to file group (line ~180)
  - Added build file entry (line ~22)
  - Added to Resources build phase (line ~260)

---

## Next Steps

1. **Rebuild and Test**
   ```bash
   bash build-final-ipa.sh
   ```

2. **Upload to TestFlight**
   ```bash
   bash upload-to-testflight.sh
   ```

3. **Verify in App Store Connect**
   - Check build appears in TestFlight
   - Verify "Ready to Test" status
   - Check privacy manifest details

4. **Monitor Compliance**
   - Review App Store privacy report
   - Monitor user feedback
   - Update manifest if new data types are collected

---

## References

- [Apple Privacy Manifest Documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [App Privacy Declaration](https://developer.apple.com/app-store/app-privacy-details/)
- [iOS Privacy Best Practices](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_apis)

---

**Automated by:** iOS Build Pipeline  
**Maintained by:** Development Team  
**Last Review:** November 14, 2025
