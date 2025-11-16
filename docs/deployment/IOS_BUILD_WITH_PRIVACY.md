# iOS Build Process with Privacy Compliance

**Status:** Required for all TestFlight/App Store uploads  
**Last Updated:** November 16, 2025

## Overview

Apple requires all iOS apps to include a **Privacy Manifest** (`PrivacyInfo.xcprivacy`) file starting with iOS 17+. This document describes how to build OpenCode Nexus iOS app with privacy compliance.

## Quick Start

### Option 1: Automated Build Script (Recommended)
```bash
# Build iOS app with privacy manifest included
./build-ios-with-privacy.sh
```

### Option 2: Manual Process
```bash
# 1. Build the app
cd src-tauri
cargo tauri ios build

# 2. Add privacy manifest to archive
cp src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy \
   "src-tauri/gen/apple/build/src-tauri_iOS.xcarchive/Products/Applications/OpenCode Nexus.app/"

# 3. Export IPA
cd src-tauri/gen/apple
xcodebuild -exportArchive \
  -archivePath build/src-tauri_iOS.xcarchive \
  -exportPath build/ipa_final \
  -exportOptionsPlist ExportOptions.plist

# 4. Verify privacy manifest is included
unzip -l "build/ipa_final/OpenCode Nexus.ipa" | grep PrivacyInfo

# 5. Upload to TestFlight
source ../../../.env
xcrun altool --upload-app \
  --type ios \
  --file "build/ipa_final/OpenCode Nexus.ipa" \
  --apiKey $APP_STORE_CONNECT_API_KEY_ID \
  --apiIssuer $APP_STORE_CONNECT_ISSUER_ID
```

---

## Privacy Manifest Location

**Source File:** `src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy`  
**In IPA:** `Payload/OpenCode Nexus.app/PrivacyInfo.xcprivacy`

---

## What the Privacy Manifest Declares

### 1. No Tracking
```xml
<key>NSPrivacyTracking</key>
<false/>
<key>NSPrivacyTrackingDomains</key>
<array/>
```

We do not track users for advertising or analytics purposes.

### 2. Data Collection

| Data Type | Purpose | Linked to User | Tracking |
|-----------|---------|----------------|----------|
| User ID | App Functionality | No | No |
| Crash Data | App Functionality | No | No |
| Performance Data | App Functionality | No | No |

All data is used solely for app functionality (Sentry error reporting and server connections).

### 3. API Usage

| API Category | Reason Code | Purpose |
|--------------|-------------|---------|
| File Timestamp | DDA9.1 | Checking file modification times |
| System Boot Time | 35F9.1 | Performance metrics |
| User Defaults | CA92.1 | App preferences storage |
| Disk Space | E174.1 | Displaying storage info |

---

## Why Privacy Manifest is Required

### Apple's Requirements (2024+)

1. **Transparency**: Users must know what data apps collect
2. **Required Reason APIs**: Apps using certain APIs must declare why
3. **Third-party SDKs**: All SDKs must include privacy manifests
4. **App Store Review**: Apps without privacy manifests are rejected

### Our Compliance Status

✅ Privacy manifest created  
✅ All data collection declared  
✅ All Required Reason APIs documented  
✅ No tracking declared  
✅ Sentry integration disclosed  

---

## Build Process Details

### Step-by-Step: What Happens

#### 1. Build iOS App
```bash
cd src-tauri
cargo tauri ios build
```

**Result:**
- Frontend compiled (Astro → static HTML/JS/CSS)
- Rust backend compiled (`aarch64-apple-ios`)
- Xcode archive created at `gen/apple/build/src-tauri_iOS.xcarchive`

#### 2. Add Privacy Manifest
```bash
cp src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy \
   "src-tauri/gen/apple/build/src-tauri_iOS.xcarchive/Products/Applications/OpenCode Nexus.app/"
```

**Why:** Tauri doesn't automatically include custom plist files, so we manually copy it into the built app bundle before export.

#### 3. Export IPA with App Store Signing
```bash
xcodebuild -exportArchive \
  -archivePath build/src-tauri_iOS.xcarchive \
  -exportPath build/ipa_final \
  -exportOptionsPlist ExportOptions.plist
```

**ExportOptions.plist specifies:**
- Method: `app-store`
- Team ID: `PCJU8QD9FN`
- Provisioning Profile: `OpenCode Nexus App Store`
- Signing Style: `manual`

**Result:** IPA signed with Distribution certificate and App Store provisioning profile.

#### 4. Verify Privacy Manifest
```bash
unzip -l "build/ipa_final/OpenCode Nexus.ipa" | grep PrivacyInfo
```

**Expected output:**
```
3126  11-16-2025 09:39   Payload/OpenCode Nexus.app/PrivacyInfo.xcprivacy
```

#### 5. Upload to TestFlight
```bash
xcrun altool --upload-app \
  --type ios \
  --file "build/ipa_final/OpenCode Nexus.ipa" \
  --apiKey $APP_STORE_CONNECT_API_KEY_ID \
  --apiIssuer $APP_STORE_CONNECT_ISSUER_ID
```

**Result:** IPA uploaded to App Store Connect for TestFlight distribution.

---

## Automated Build Script

### Using `build-ios-with-privacy.sh`

The script automates all steps above:

```bash
#!/bin/bash
./build-ios-with-privacy.sh
```

**What it does:**
1. ✅ Builds iOS app with Tauri CLI
2. ✅ Locates built .app in archive
3. ✅ Copies privacy manifest to app bundle
4. ✅ Re-signs app with Distribution certificate
5. ✅ Exports IPA with App Store profile
6. ✅ Verifies privacy manifest is included
7. ✅ Copies IPA to `build/` directory

**Output:**
- `build/OpenCodeNexus_v0.1.5_privacy.ipa` - Ready for TestFlight upload

---

## Verification Checklist

Before uploading to TestFlight:

### 1. Privacy Manifest Exists
```bash
ls -la src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy
```
✅ File should exist and be ~3KB

### 2. Privacy Manifest is Valid XML
```bash
plutil -lint src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy
```
✅ Should output: `PrivacyInfo.xcprivacy: OK`

### 3. Privacy Manifest in IPA
```bash
unzip -l build/OpenCodeNexus_v0.1.5_privacy.ipa | grep PrivacyInfo
```
✅ Should show: `Payload/OpenCode Nexus.app/PrivacyInfo.xcprivacy`

### 4. App Signed with Distribution Certificate
```bash
codesign -dv --verbose=4 "Payload/OpenCode Nexus.app" 2>&1 | grep Authority
```
✅ Should show: `Authority=Apple Distribution: John Ferguson`

### 5. Correct Provisioning Profile
```bash
unzip -p build/OpenCodeNexus_v0.1.5_privacy.ipa \
  "Payload/OpenCode Nexus.app/embedded.mobileprovision" | \
  security cms -D | grep "Name"
```
✅ Should show: `<string>OpenCode Nexus App Store</string>`

---

## Updating Privacy Manifest

If you add new features that collect data or use new APIs:

### 1. Edit Privacy Manifest
```bash
nano src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy
```

### 2. Add New Data Type (if applicable)
```xml
<dict>
  <key>NSPrivacyCollectedDataType</key>
  <string>NSPrivacyCollectedDataTypeLocation</string>
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

### 3. Add New API Declaration (if applicable)
```xml
<dict>
  <key>NSPrivacyAccessedAPIType</key>
  <string>NSPrivacyAccessedAPICategoryLocation</string>
  <key>NSPrivacyAccessedAPITypeReasons</key>
  <array>
    <string>C617.1</string>
  </array>
</dict>
```

### 4. Validate Changes
```bash
plutil -lint src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy
```

### 5. Rebuild
```bash
./build-ios-with-privacy.sh
```

---

## Troubleshooting

### Problem: "Missing Privacy Manifest" Warning in App Store Connect

**Solution:**
1. Verify privacy manifest is in IPA: `unzip -l <ipa> | grep Privacy`
2. If missing, rebuild using `build-ios-with-privacy.sh`
3. Don't use `cargo tauri ios build --export-method app-store-connect` directly (it doesn't include custom files)

### Problem: "Invalid Privacy Manifest Format"

**Solution:**
```bash
# Check XML validity
plutil -lint src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy

# Fix formatting
plutil -convert xml1 src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy
```

### Problem: Privacy Manifest Disappears After Rebuild

**Cause:** `cargo tauri ios build` regenerates the Xcode project, which doesn't include the privacy manifest.

**Solution:** Always use the build script or manually copy the privacy manifest after building.

### Problem: App Rejected for "Undeclared Data Collection"

**Solution:**
1. Review rejection notice for specific data types
2. Add missing data types to privacy manifest
3. Update `NSPrivacyCollectedDataTypes` array
4. Rebuild and resubmit

---

## Common Data Types Reference

| Type | Value | When to Declare |
|------|-------|-----------------|
| User ID | `NSPrivacyCollectedDataTypeUserID` | User login/auth |
| Email | `NSPrivacyCollectedDataTypeEmailAddress` | Contact info |
| Phone | `NSPrivacyCollectedDataTypePhoneNumber` | Contact info |
| Location | `NSPrivacyCollectedDataTypeLocation` | GPS data |
| Photos | `NSPrivacyCollectedDataTypePhotoLibrary` | Photo access |
| Contacts | `NSPrivacyCollectedDataTypeContacts` | Address book access |
| Health | `NSPrivacyCollectedDataTypeHealth` | HealthKit data |
| Payment | `NSPrivacyCollectedDataTypePaymentInfo` | Payment processing |
| Crash Data | `NSPrivacyCollectedDataTypeCrashData` | Error reporting (Sentry) |
| Performance | `NSPrivacyCollectedDataTypePerformanceData` | Performance monitoring |

---

## Common API Reason Codes

| Code | API Category | When to Use |
|------|--------------|-------------|
| DDA9.1 | File Timestamp | Checking file modification times |
| 35F9.1 | System Boot Time | Performance/uptime tracking |
| CA92.1 | User Defaults | App preferences storage |
| E174.1 | Disk Space | Showing storage info |
| C617.1 | Location | User-initiated location features |
| 3EC4.1 | System Volume | Audio control |
| E7EF.1 | WebView JavaScript | Running JS in WebView |

---

## Files Created/Modified

### New Files
- `src-tauri/gen/apple/src-tauri_iOS/PrivacyInfo.xcprivacy` - Privacy manifest
- `build-ios-with-privacy.sh` - Automated build script
- `docs/deployment/IOS_BUILD_WITH_PRIVACY.md` - This document

### Modified Files
- None (Xcode project is regenerated by Tauri, so we don't modify it)

---

## Next Steps

1. **Always use the build script** for TestFlight uploads
2. **Update privacy manifest** when adding new features
3. **Monitor App Store Connect** for compliance warnings
4. **Review annually** as Apple updates privacy requirements

---

## References

- [Apple Privacy Manifest Documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Required Reason API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_apis)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

---

**Last Updated:** November 16, 2025  
**Maintained By:** Development Team
