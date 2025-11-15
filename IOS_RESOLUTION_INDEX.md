# iOS Build & TestFlight Resolution - Complete Documentation Index

**Status:** Phase 1 Complete - Root Cause Identified - Solution Selected

**Last Updated:** November 14, 2025

---

## Quick Navigation

### For Quick Understanding (Start Here)
1. **[IOS_RESOLUTION_SUMMARY.md](IOS_RESOLUTION_SUMMARY.md)** - Executive summary (5 min read)
   - Problem overview
   - Root cause in plain English
   - Solution approach
   - Timeline and metrics

### For Technical Deep Dive
2. **[PHASE1_DIAGNOSIS.md](PHASE1_DIAGNOSIS.md)** - Detailed technical analysis (15 min read)
   - Exact root cause with code references
   - Why Track A2 was selected
   - Step-by-step implementation
   - Risk factors and success criteria

### For Comprehensive Planning
3. **[IOS_BUILD_RESOLUTION_PLAN.md](IOS_BUILD_RESOLUTION_PLAN.md)** - Full resolution plan (30 min read)
   - All three tracks detailed (A, B, C)
   - Detailed issue-by-issue fixes
   - Fallback procedures
   - Session checkpoints

### Historical Context
4. **[IOS_BUILD_SESSION_2_SUMMARY.md](IOS_BUILD_SESSION_2_SUMMARY.md)** - Previous session notes
   - What was attempted before
   - Issues encountered
   - Credentials and file locations

---

## Problem Statement (One Paragraph)

When running `xcodebuild archive`, Tauri's build system tries to connect to a local CLI server via TCP socket that doesn't exist, causing a "Connection refused" error. This prevents the creation of a valid `.xcarchive`, which blocks IPA export and TestFlight upload. Additionally, even when the app is manually re-signed, Apple rejects it because static libraries (`libapp.a`) are bundled directly instead of being linked into the executable.

---

## Solution (One Paragraph)

Use the pre-built Rust library that's already compiled (via `cargo build --release --target aarch64-apple-ios`) and bypass Tauri's CLI system by: (1) copying the pre-built `.a` file to Xcode's expected location, (2) disabling the problematic Tauri build phase in the Xcode project file, and (3) running `xcodebuild archive` directly with manual signing. This creates a valid App Store–ready `.xcarchive` that can be exported as an IPA and uploaded to TestFlight.

---

## Implementation Checklist

### Phase 2: Track A2 Implementation

**Step 1: Prepare Library (5 min)**
- [ ] Verify pre-built library exists
- [ ] Create Externals directory structure
- [ ] Copy library to expected location
- [ ] Document command used

**Step 2: Disable Tauri Build Phase (10 min)**
- [ ] Back up Xcode project file
- [ ] Edit project.pbxproj
- [ ] Replace shell script with no-op
- [ ] Verify change saved

**Step 3: Link Frameworks (5 min)**
- [ ] Verify iOS frameworks linked in build settings
- [ ] Confirm library path configured
- [ ] Document build settings changes

**Step 4: Run Archive (30 min)**
- [ ] Frontend build complete
- [ ] Rust pre-build complete
- [ ] Execute xcodebuild archive
- [ ] Monitor output for errors
- [ ] Record build time and size

**Step 5: Verify Archive (5 min)**
- [ ] Archive exists
- [ ] Archive size reasonable
- [ ] Archive contains app bundle
- [ ] No errors in build log

### Phase 3: Export IPA (1 hour)

**Step 1: Export Archive (15 min)**
- [ ] Export options plist configured
- [ ] Execute xcodebuild -exportArchive
- [ ] IPA file created
- [ ] Record IPA size

**Step 2: Verify IPA (15 min)**
- [ ] IPA unpacked and inspected
- [ ] No libapp.a bundled
- [ ] Provisioning profile present
- [ ] Entitlements embedded
- [ ] Code signature valid
- [ ] All checks passed

### Phase 4: Upload & Monitor (30 min)

**Step 1: Upload (15 min)**
- [ ] API credentials verified
- [ ] Upload script executed
- [ ] Upload completed
- [ ] App Store Connect updated

**Step 2: Monitor (15 min)**
- [ ] Check validation status
- [ ] Log any errors
- [ ] Document results
- [ ] Plan next steps

---

## Key Metrics

**Build Times:**
- Frontend build: ~2 min
- Rust build: ~5 min (already done, can skip)
- Archive build: ~30 min
- IPA export: ~5 min
- **Total:** ~40 minutes (first time), ~10 minutes (cached)

**Artifact Sizes:**
- Pre-built library: ~30-50MB
- Archive: ~50-100MB
- Final IPA: ~35-50MB

**Success Rate:**
- Track A2: 85-90% (most likely to succeed)
- Fallback B1: 60-70% (if A2 fails)
- Fallback C: 95%+ (but takes 4-6 hours)

---

## Troubleshooting Guide

### Issue: Archive Build Fails with Socket Error
**Solution:** Confirm Tauri build phase was disabled
```bash
grep "cargo tauri ios xcode-script" src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj
```
Should return nothing. If it returns the script, edit the file again.

### Issue: Missing Symbol Error During Link
**Solution:** Verify all frameworks linked in build settings
```bash
grep "FRAMEWORK" src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj | head -10
```

### Issue: "Invalid Bundle Structure" App Store Error
**Solution:** Verify IPA structure before upload
```bash
unzip -l OpenCode_Nexus.ipa | grep -E "\.(a|o|dylib)$"
```
Should return no results.

### Issue: "Missing Code Signing Entitlements"
**Solution:** Verify entitlements in IPA
```bash
unzip -p OpenCode_Nexus.ipa "Payload/OpenCode Nexus.app/embedded.mobileprovision" | \
  security cms -D -i /dev/stdin | grep -i "entitlements"
```

---

## File References

**Xcode Project:**
- Location: `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`
- Change: Replace `cargo tauri ios xcode-script` with no-op

**Pre-built Library:**
- Source: `src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a`
- Target: `src-tauri/gen/apple/Externals/arm64/Release/libapp.a`

**Build Scripts:**
- `build-final-ipa.sh` - Archive to IPA export pipeline
- `build-appstore-ipa.sh` - Manual re-signing (fallback)
- `upload-to-testflight.sh` - API upload
- `build-and-upload-ios.sh` - Combined build + upload

**Credentials:**
- Location: `~/.credentials/.env`
- Contains: API key, provisioning profile UUID, certificates

**Entitlements:**
- Location: `src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements`
- Required: Embedded in IPA for App Store validation

---

## Decision Tree

```
Is archive failing with socket error?
├─ YES → Track A2 (Disable Tauri CLI) [SELECTED]
│   └─ Does archive complete? YES → Continue to Phase 3
│       └─ Continue to Phase 4
├─ NO / Track A2 fails?
│   └─ Try Track B1 (Use cargo tauri build)
│       └─ Still failing?
│           └─ Use Track C (Manual Xcode without Tauri)
```

---

## Session Continuation Guide

### If Continuing This Session
1. Read `IOS_RESOLUTION_SUMMARY.md` (5 min)
2. Start with Phase 2.1 from `PHASE1_DIAGNOSIS.md`
3. Follow checklist in this document
4. Reference troubleshooting guide as needed

### If Starting Next Session
1. Read `IOS_RESOLUTION_SUMMARY.md` (5 min)
2. Read `PHASE1_DIAGNOSIS.md` (15 min)
3. Confirm Phase 1 completion with checklist
4. Begin Phase 2.1

### If Debugging a Failure
1. Identify which phase failed (2, 3, or 4)
2. Reference appropriate document section
3. Use troubleshooting guide
4. Document findings
5. Escalate to next track if needed

---

## Success Criteria Summary

**Phase 2 Success:**
- Archive builds without socket/network errors
- `.xcarchive` file created
- Size between 50-100MB

**Phase 3 Success:**
- IPA exports successfully
- IPA size between 35-50MB
- No static libraries bundled
- Provisioning profile is App Store type
- All entitlements embedded

**Phase 4 Success:**
- IPA uploaded to App Store Connect
- Validation passes
- Status shows "Processing"
- Can be distributed to TestFlight testers

---

## Contact & Escalation

**Questions about Track A2?** → See `PHASE1_DIAGNOSIS.md`

**Need to understand all options?** → See `IOS_BUILD_RESOLUTION_PLAN.md`

**Track A2 failing?** → Escalate to Track B1 following fallback procedures in resolution plan

**Need Apple Developer support?** → Use Apple Developer account: PCJU8QD9FN

---

## Revision History

| Date | Author | Change | Status |
|------|--------|--------|--------|
| Nov 14, 2025 | System | Phase 1 diagnosis complete | ✅ Complete |
| Nov 14, 2025 | System | Track A2 selected | ✅ Complete |
| Nov 14, 2025 | System | Documentation created | ✅ Complete |
| TBD | TBD | Phase 2 implementation | ⏳ Pending |
| TBD | TBD | Phase 3 IPA export | ⏳ Pending |
| TBD | TBD | Phase 4 TestFlight upload | ⏳ Pending |

---

**Next Step:** Begin Phase 2.1 - Prepare Rust Library
