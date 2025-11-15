# iOS Build & TestFlight Resolution - Executive Summary

**Date:** November 14, 2025  
**Status:** Phase 1 Complete - Ready for Implementation  
**Estimated Time to Completion:** 2-3 hours

---

## Problem Summary

The iOS build pipeline is stuck at the **Xcode archive step** due to a Tauri CLI network socket error:

```
thread 'main' panicked at: failed to read CLI options:
Error when opening the TCP socket: Connection refused (os error 61)
```

This prevents creation of a valid `.xcarchive`, which means no App Store–ready IPA can be exported to TestFlight.

---

## Root Cause Identified

### The Issue (Not in Rust, but in Xcode Build Phase)

**File:** `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`

**Build Phase Command:**
```bash
cargo tauri ios xcode-script -v --platform ${PLATFORM_DISPLAY_NAME:?} ...
```

This command tries to connect to a local Tauri CLI server that doesn't exist, causing the build to fail with a socket error.

### Secondary Issue (Why App Store Rejects Manual IPA)

The Xcode build phase outputs a **static library** (`libapp.a`) that gets included in the app bundle. Apple's App Store validation rejects IPAs containing static libraries—they must be linked into the executable, not bundled separately.

---

## Solution Selected: Track A2

**Bypass Tauri's CLI system entirely** by:

1. Using the pre-built Rust library (already compiled via `cargo build --release --target aarch64-apple-ios`)
2. Removing the problematic Tauri build phase from Xcode
3. Linking the pre-built library directly in Xcode
4. Running `xcodebuild archive` without Tauri involvement

**Why This Works:**
- ✅ No network socket needed
- ✅ No CLI server required
- ✅ Pre-built library is already available
- ✅ Xcode can handle static library linking without bundling them
- ✅ Creates proper App Store–compliant bundle

---

## Implementation Roadmap

### Phase 2: Implement Track A2 (90 min)

**A2.1: Prepare Rust Library** (5 min)
- Copy pre-built `libsrc_tauri_lib.a` to Xcode's expected location
- Create directory structure: `src-tauri/gen/apple/Externals/{arm64,x86_64}/Release/`

**A2.2: Disable Tauri Build Phase** (10 min)
- Edit `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`
- Replace Tauri CLI command with no-op shell script
- This prevents the socket error from occurring

**A2.3: Link Library in Xcode** (5 min)
- Update build settings to reference pre-built library
- Ensure iOS frameworks are linked (already configured in `build.rs`)

**A2.4: Run Archive Build** (30 min)
- Execute: `xcodebuild archive -project src-tauri.xcodeproj -scheme src-tauri_iOS ...`
- With proper signing certificate and provisioning profile

**A2.5: Verify Archive** (5 min)
- Confirm `.xcarchive` created successfully
- Check archive contains valid app bundle with linked frameworks

### Phase 3: Export IPA (1 hour)

**Export Archive** (15 min)
- Use: `xcodebuild -exportArchive -archivePath ... -exportOptionsPlist ...`
- Proper App Store export options configured

**Verify IPA Structure** (15 min)
- Confirm: No `libapp.a` in IPA
- Confirm: Contains proper `embedded.mobileprovision`
- Confirm: All required entitlements embedded

### Phase 4: Upload to TestFlight (30 min)

**Upload** (15 min)
- Run: `bash upload-to-testflight.sh`
- Monitor upload progress

**Monitor Validation** (15 min)
- Check App Store Connect
- Wait for validation to complete
- Log results

---

## Files and Changes

### Files to Modify

**1. `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`**
- Find the "Build Rust Code" shell script phase
- Replace: `cargo tauri ios xcode-script ...`
- With: `echo 'Using pre-built Rust library'`
- ~1 line change

### Files to Create/Copy

**1. `src-tauri/gen/apple/Externals/arm64/Release/libapp.a`**
- Copy from: `src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a`

**2. `src-tauri/gen/apple/Externals/x86_64/Release/libapp.a`**
- Same copy (for now—simulator support is secondary)

### Existing Scripts to Use

**1. `build-final-ipa.sh`**
- Will be updated to skip Rust build (already pre-built)
- Uses already-prepared export options plist

**2. `upload-to-testflight.sh`**
- Already configured with correct API credentials
- Ready to use after IPA is built

---

## Success Metrics

### After Phase 2 (Archive)
- [ ] `.xcarchive` exists at `/tmp/OpenCode_Nexus.xcarchive`
- [ ] Archive size reasonable (~50-100MB)
- [ ] No build errors or warnings related to socket/network
- [ ] Xcode reports "Build successful"

### After Phase 3 (IPA Export)
- [ ] `OpenCode_Nexus.ipa` exists (35-50MB)
- [ ] No static libraries bundled in IPA
- [ ] Provisioning profile is App Store distribution type
- [ ] All entitlements embedded
- [ ] Code signature valid

### After Phase 4 (TestFlight Upload)
- [ ] IPA uploaded successfully
- [ ] App Store Connect shows "Processing"
- [ ] No validation errors about bundle structure, profiles, or entitlements
- [ ] Within 24-48 hours: testable in TestFlight

---

## Risk Mitigation

### Risk 1: Xcode Project File Corruption
**Mitigation:** Back up the project file before editing
```bash
cp -r src-tauri/gen/apple/src-tauri.xcodeproj \
      src-tauri/gen/apple/src-tauri.xcodeproj.backup
```

### Risk 2: Missing Symbol References
**Mitigation:** All required frameworks already linked in `src-tauri/build.rs`
- UIKit, Foundation, CoreGraphics, Metal, QuartzCore, Security, WebKit

### Risk 3: Simulator Incompatibility
**Mitigation:** Device architecture (aarch64) sufficient for TestFlight
- Simulator support (x86_64) can be added later if needed

---

## Alternative Fallback Plans

### If Archive Still Fails
→ **Option B1:** Use `cargo tauri build` command (instead of Xcode)
- More complex but proven to work
- Estimated additional time: 2 hours

### If Export Fails
→ **Option C:** Use older `altool` upload method
- May have different validation requirements
- Estimated additional time: 1 hour

### If TestFlight Upload Fails with App Store Errors
→ **Document error** and iterate on IPA structure
- Estimated additional time: varies per error

---

## Estimated Timeline

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Diagnosis & analysis | ✅ 30 min | Complete |
| 2.1 | Prepare Rust library | 5 min | Ready |
| 2.2 | Disable build phase | 10 min | Ready |
| 2.3 | Link frameworks | 5 min | Ready |
| 2.4 | Run archive | 30 min | Ready |
| 2.5 | Verify archive | 5 min | Ready |
| 3.1 | Export IPA | 15 min | Ready |
| 3.2 | Verify IPA | 15 min | Ready |
| 4.1 | Upload | 15 min | Ready |
| 4.2 | Monitor | 15 min | Ready |
| **Total** | | **~2.5 hours** | |

---

## Documentation Created

### Phase 1 Outputs
- ✅ `IOS_BUILD_RESOLUTION_PLAN.md` - Comprehensive plan with all tracks and details
- ✅ `PHASE1_DIAGNOSIS.md` - Technical root cause analysis
- ✅ This summary document

### Phase 2-4 Outputs (to be created during implementation)
- Track A2 Implementation Steps
- Final IPA Verification Report
- TestFlight Upload Results

---

## Next Steps

**Immediate Action:** Choose to proceed with Track A2 implementation

**Decision Points:**
- Proceed with Phase 2? → Answer: **YES**
- Use Track A2 as planned? → Answer: **YES**
- If A2 fails, escalate to Track B1? → Answer: **YES (auto-fallback)**

**Start Time:** Ready to begin immediately

---

## Key Contacts & Resources

**Apple Developer Account:** PCJU8QD9FN (John Ferguson)

**Credentials Location:** `~/.credentials/.env`

**API Key:** AuthKey_78U6M64KJS.p8

**Provisioning Profile:** OpenCode_Nexus_App_Store(1).mobileprovision

**Distribution Certificate:** Apple Distribution: John Ferguson (PCJU8QD9FN)

---

## Questions Answered

**Q: Why is the socket error happening?**
A: Tauri's CLI system expects a network server to be running locally, but when we invoke Xcode directly, no server is running.

**Q: Why does the manual re-signing fail?**
A: Apple rejects IPAs that bundle static libraries (libapp.a). Static libraries must be linked into the executable at build time, not bundled separately.

**Q: Will bypassing Tauri cause other problems?**
A: No. The Tauri layer is just a wrapper around Xcode's archive process. The pre-built Rust library is valid and properly configured.

**Q: Can we use this approach for development builds?**
A: Yes, once this works for release builds, we can adapt it for development/simulator builds by building x86_64 versions.

**Q: What if the archive still fails after these changes?**
A: We have documented fallback plans (Options B and C) ready to implement immediately.

