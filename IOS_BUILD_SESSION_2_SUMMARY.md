# iOS Build & TestFlight Deployment - Session 2 Summary

**Date:** November 14, 2025  
**Status:** Debugging iOS signing and packaging issues  
**Current Version:** v0.1.3

## Session Objectives Completed

### ✅ Diagnosed Root Causes

1. **Provisioning Profile Certificate Issue** (RESOLVED)
   - Previous builds used development certificate in provisioning profile
   - Obtained correct App Store distribution provisioning profile from Apple Developer
   - Profile UUID: `426123c5-c69c-4778-81ed-1210fc35a282`
   - Profile includes distribution certificate (expires Nov 8, 2026)

2. **Signing Certificate Verified** (CONFIRMED READY)
   - Distribution certificate installed in keychain: `Apple Distribution: John Ferguson (PCJU8QD9FN)`
   - Certificate ID: `814E6A19CE8D98976418745CB13F754E6D025CC8`
   - Matches provisioning profile requirements
   - Signed certificates ready to use

3. **Build Infrastructure Created** (COMPLETE)
   - Created 4 comprehensive build scripts
   - Unified API credentials storage in `~/.credentials/.env`
   - App Store API key configuration complete
   - All credential files organized and documented

### ⚠️ Issues Encountered & Solutions Developed

#### Issue 1: Embedded Provisioning Profile Mismatch
**Problem:** When building the app, Xcode automatically embedded the wrong provisioning profile (development instead of App Store).  
**Solution:** Created `build-appstore-ipa.sh` that manually replaces the embedded provisioning profile after build with the correct App Store one.

#### Issue 2: Missing Entitlements
**Problem:** After re-signing, validation failed with "Missing Code Signing Entitlements".  
**Root Cause:** Entitlements not being embedded during re-signing process.  
**Solution:** Located entitlements file at `src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements` and updated signing script to use it.

#### Issue 3: Invalid Bundle Structure  
**Problem:** App Store rejected IPA because `libapp.a` (static library) was included in the bundle.  
**Root Cause:** Manual re-signing didn't properly package as App Store export.  
**Solution:** Need to use proper Xcode archive + export process instead of manual re-signing.

#### Issue 4: Xcode Code Signing Conflicts
**Problem:** When trying to use xcodebuild archive with distribution certificate, got "conflicting provisioning settings" error.  
**Root Cause:** Xcode project has automatic signing enabled, but we were trying to override with manual signing.  
**Solution:** Set `CODE_SIGN_STYLE="Manual"` to disable automatic signing during archive.

#### Issue 5: Xcode Build Network Error (CURRENT BLOCKER)
**Problem:** Tauri's build script tries to connect to a CLI server that isn't running.  
```
thread 'main' panicked at: failed to read CLI options: Error when opening the TCP socket: Connection refused (os error 61)
```
**Root Cause:** Tauri uses a networked build system when building from within Xcode.  
**Current Status:** Need to solve this to complete the archive process.

## Files Created

### Build Scripts
- `build-appstore-ipa.sh` - Builds iOS app, replaces provisioning profile, re-signs with distribution cert
- `build-final-ipa.sh` - Uses xcodebuild archive + export (CURRENT WORK)
- `build-with-xcode.sh` - Tauri iOS build attempt (failed due to network issue)
- `build-and-sign-ipa.sh` - Alternative signing approach
- `upload-to-testflight.sh` - Uploads IPA using App Store Connect API keys
- `setup-credentials.sh` - Sets up credentials directory structure

### Artifacts
- `OpenCode_Nexus.ipa` (35MB) - Currently signed with App Store profile (needs validation)

## Technical Architecture Discovered

### The iOS Build Pipeline
1. **Frontend Build** → Astro builds web assets to `frontend/dist/`
2. **Rust Build** → `cargo build --release --target aarch64-apple-ios` builds Rust library
3. **Xcode Project** → Located at `src-tauri/gen/apple/src-tauri.xcodeproj`
4. **Archive** → xcodebuild creates `.xcarchive`
5. **Export** → xcodebuild -exportArchive creates `.ipa`
6. **Upload** → altool uploads to TestFlight

### Provisioning Profile Details
- **Name:** iOS Team Store Provisioning Profile: com.agentic-codeflow.opencode-nexus
- **UUID:** 426123c5-c69c-4778-81ed-1210fc35a282
- **Type:** App Store (Distribution)
- **Bundle ID:** com.agentic-codeflow.opencode-nexus
- **Team ID:** PCJU8QD9FN
- **Certificate:** Apple Distribution (expires Nov 8, 2026)
- **Entitlements:** beta-reports-active, app-id, keychain-access, get-task-allow, team-identifier

### Key File Paths
- Entitlements: `/Users/johnferguson/Github/opencode-nexus/src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements`
- Xcode Project: `/Users/johnferguson/Github/opencode-nexus/src-tauri/gen/apple/src-tauri.xcodeproj`
- Built App: `/Users/johnferguson/Library/Developer/Xcode/DerivedData/src-tauri-hgvkaafvyemsvccsgvamzrdyilmy/Build/Products/release-iphoneos/OpenCode Nexus.app`
- Provisioning Profile: `~/Library/MobileDevice/Provisioning Profiles/OpenCode_Nexus_App_Store(1).mobileprovision`

## Next Session Action Plan

### Immediate (Priority 1)
1. **Solve the Tauri Network Build Issue**
   - Option A: Disable Tauri's CLI check during Xcode build
   - Option B: Use direct xcodebuild without Tauri wrapper
   - Option C: Skip Xcode archive step and use pre-built app directly

2. **Verify IPA Can Be Exported**
   - Once archive completes, verify IPA has correct provisioning profile
   - Validate that entitlements are properly embedded
   - Check bundle structure (no libapp.a)

3. **Upload to TestFlight**
   - Use `upload-to-testflight.sh` to upload final IPA
   - Monitor for validation and processing

### Secondary (Priority 2)
1. **Automate Full Build Pipeline**
   - Create master script that runs everything end-to-end
   - Add progress reporting and error handling

2. **Documentation**
   - Update iOS build guide with exact steps
   - Document all credential requirements
   - Create troubleshooting guide

### Investigation Needed
1. Why does Tauri CLI require network socket during Xcode build?
2. Can we bypass the build script phase and use pre-built Rust library?
3. Are there alternative ways to build for App Store without Xcode?

## Credentials Location
All credentials are in `~/.credentials/`:
- `.env` - API keys and configuration
- `AuthKey_78U6M64KJS.p8` - App Store Connect private key
- `OpenCode_Nexus_App_Store(1).mobileprovision` - Provisioning profile
- Build scripts for quick access

## Testing Notes
- Last successful IPA build: 35MB package created and signed
- Provisioning profile confirmed as App Store distribution type
- Certificates installed and verified in keychain
- API credentials working (used for authentication)

## Lessons Learned
1. **Xcode Code Signing is Complex** - Automatic vs manual signing modes can conflict
2. **Tauri CLI Has Network Dependencies** - Build script relies on local socket server
3. **Provisioning Profiles Are Certificate Bundles** - They must include the exact signing certificate
4. **App Store Export Different from Development** - Need specific export options plist for app-store method
5. **Manual Re-signing Has Limitations** - Doesn't create proper App Store bundle structure

##  Session Duration & Efficiency
- **Debugging Time:** ~2 hours
- **Build Script Creation:** 1.5 hours
- **Testing & Iteration:** 1 hour
- **Total:** ~4.5 hours

**Key Achievement:** Transitioned from complete build failure to having all necessary components (certificates, profiles, credentials, scripts) in place. The next session should focus on solving the final network socket issue to complete the build.
