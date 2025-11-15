# iOS Build & TestFlight Upload - Resolution Plan

**Date:** November 14, 2025  
**Status:** Detailed problem breakdown & solutions identified  
**Goal:** Achieve valid App Store IPA and successful TestFlight upload

---

## Current State Analysis

### Root Problems Identified

**Problem 1: Xcode Archive Cannot Complete (BLOCKER)**
- **Symptom:** `xcodebuild archive` fails with TCP socket error from Tauri CLI
- **Root Cause:** Tauri's build script phase tries to connect to a local CLI server that isn't running
- **Impact:** `build-final-ipa.sh` cannot produce `.xcarchive`, so no valid IPA can be exported
- **Error Message:** 
  ```
  thread 'main' panicked at: failed to read CLI options: 
  Error when opening the TCP socket: Connection refused (os error 61)
  ```

**Problem 2: Manual Re-signing Process (Alternative Path, Failing)**
- **Current Situation:** `build-appstore-ipa.sh` uses pre-built app + manual re-signing
- **Known Issues:**
  - Produces invalid bundle structure (libapp.a inside app bundle)
  - Missing entitlements in embedded provisioning profile
  - Apple App Store validation rejects this IPA format
- **Root Cause:** Not using proper Xcode export pipeline (archive → export)

**Problem 3: No TestFlight Upload Possible**
- **Why:** No valid App Store IPA exists yet
- **Dependency:** Must resolve Problems 1 or 2 first

---

## Solution Approach: Three-Track Resolution

### Track A: Fix Tauri Build Script Issue (Recommended - Proper Solution)

**What's Happening:**
- Tauri 2.x uses a networked build system in `build.rs`
- When building via Xcode (`xcodebuild archive`), the Tauri build script tries to connect to a local socket server
- The server doesn't exist/isn't running in this context

**Solutions to Try (in order):**

#### A1: Disable CLI Check in Build Script (Fastest)
- **File:** `src-tauri/build.rs`
- **Approach:** Add environment variable to skip network socket check
- **Action:**
  1. Check if `build.rs` exists and contains CLI socket logic
  2. Add conditional: `if env::var("TAURI_CLI_SKIP_SOCKET").is_ok() { /* skip */ }`
  3. Run: `TAURI_CLI_SKIP_SOCKET=1 xcodebuild archive ...`
- **Estimated Success:** 60-70%
- **Effort:** 30 minutes

#### A2: Use Cargo Direct Build, Skip Tauri
- **Approach:** Build Rust library directly, don't use Tauri's CLI wrapper
- **Action:**
  1. Run: `cargo build --release --target aarch64-apple-ios` (already done)
  2. Manually run `xcodebuild archive` with direct Rust library
  3. Skip any Tauri build phase
- **Estimated Success:** 80%+
- **Effort:** 1-2 hours

#### A3: Launch Tauri CLI Server Before Build
- **Approach:** Start the socket server, then run archive
- **Action:**
  1. Research: How to manually start Tauri CLI socket server
  2. Run server in background: `tauri dev` or similar
  3. Then run `xcodebuild archive`
- **Estimated Success:** 40% (server may not be designed for this)
- **Effort:** 1-2 hours

---

### Track B: Fix Manual Re-signing Path (Backup)

**If Track A Fails, Use This:**

#### B1: Pre-Build App via Tauri CLI (Outside of Xcode)
- **Approach:** Build entire app via Tauri CLI first, capture build artifacts
- **Action:**
  1. Run: `cd src-tauri && cargo tauri build --target aarch64-apple-ios`
  2. Capture: The built `.app` bundle
  3. Use `build-appstore-ipa.sh` to re-sign it properly
- **Estimated Success:** 50-60%
- **Effort:** 2-3 hours

#### B2: Use Proper Xcode Archive Export Plist
- **Current Issue:** Export options plist missing `runFirstLaunchTest` and other keys
- **Action:**
  1. Add more keys to `ExportOptions_AppStore.plist` in `build-final-ipa.sh`:
     ```xml
     <key>runFirstLaunchTest</key>
     <false/>
     <key>stripSwiftSymbols</key>
     <true/>
     <key>embedOnDemandResourcesAssets</key>
     <false/>
     ```
  2. Test export with better-configured plist
- **Estimated Success:** 30-40%
- **Effort:** 1 hour

---

### Track C: Rebuild Without Tauri (Nuclear Option)

**Last Resort - Only if A & B Fail:**

#### C1: Bypass Tauri Entirely for iOS
- **Approach:** Create custom Xcode build that skips Tauri layer
- **Components:**
  1. Frontend: Already built Astro → `frontend/dist/`
  2. Rust: Already built → `aarch64-apple-ios` library
  3. Xcode: Point directly to Rust library, skip Tauri
- **Estimated Success:** 90%+ (but most work-intensive)
- **Effort:** 4-6 hours

---

## Detailed Action Plan

### Phase 1: Investigation & Diagnosis (30 min)
**Goal:** Confirm exact failure point and select Track

**Steps:**

1. **Examine Tauri build.rs**
   ```bash
   cat src-tauri/build.rs | grep -A 5 -B 5 "socket\|CLI"
   ```

2. **Check for Tauri CLI Socket Logic**
   - Look for: `TcpListener`, `socket`, `127.0.0.1`
   - Understand: What command initiates socket server?

3. **Verify Xcode Build Phase Script**
   - Xcode Build Phases → Run Script
   - Does it invoke Tauri CLI?
   - Can we skip this phase?

4. **Decision:** Choose Track A1, A2, A3, or B1

---

### Phase 2: Implement Solution (1-3 hours)
**Goal:** Get valid `.xcarchive` or valid built `.app`

**Track A1 (30 min):**
- [ ] Modify `build.rs` to accept `TAURI_CLI_SKIP_SOCKET` env var
- [ ] Test: Run `TAURI_CLI_SKIP_SOCKET=1 xcodebuild archive ...`
- [ ] Check if `.xcarchive` is created
- [ ] If successful → Skip to Phase 3

**Track A2 (1-2 hours):**
- [ ] Examine Xcode project Build Phases
- [ ] Remove or comment out Tauri build phase
- [ ] Point Rust library path directly to pre-built library
- [ ] Test: Run `xcodebuild archive ...`
- [ ] Check if `.xcarchive` is created
- [ ] If successful → Skip to Phase 3

**Track B1 (2-3 hours):**
- [ ] Run: `cd src-tauri && cargo tauri build --target aarch64-apple-ios`
- [ ] Find output `.app` bundle
- [ ] Run: `bash build-appstore-ipa.sh` with updated app path
- [ ] If successful → Skip to Phase 3

---

### Phase 3: Export Valid IPA (1 hour)
**Goal:** Convert `.xcarchive` → `.ipa` using proper export options

**Steps:**

1. **Ensure Archive Exists**
   ```bash
   ls -lah /tmp/OpenCode_Nexus.xcarchive
   ```

2. **Run Export (from `build-final-ipa.sh`)**
   ```bash
   xcodebuild -exportArchive \
       -archivePath /tmp/OpenCode_Nexus.xcarchive \
       -exportOptionsPlist /tmp/ExportOptions_AppStore.plist \
       -exportPath /tmp/ipa_export_final
   ```

3. **Verify IPA Structure**
   ```bash
   unzip -l OpenCode_Nexus.ipa | grep -E "\.a$|embedded.mobileprovision"
   ```
   - Should NOT contain: `libapp.a`
   - Should contain: `embedded.mobileprovision`

4. **Verify Provisioning Profile**
   ```bash
   unzip -p OpenCode_Nexus.ipa "Payload/OpenCode Nexus.app/embedded.mobileprovision" | \
     security cms -D -i /dev/stdin | grep -i "distribution"
   ```

---

### Phase 4: Upload to TestFlight (30 min)
**Goal:** Upload IPA and monitor validation

**Steps:**

1. **Run Upload Script**
   ```bash
   bash upload-to-testflight.sh
   ```

2. **Monitor Upload Progress**
   - Check App Store Connect web UI
   - Wait for "Processing"
   - Monitor for validation errors

3. **If Validation Fails:**
   - Note exact error message
   - Correlate with known issues (libapp.a, missing entitlements, etc.)
   - Return to Phase 3 or 2 for fixes

---

## Detailed Issue-by-Issue Fixes

### Issue: "Conflicting Provisioning Settings" in xcodebuild

**Error:**
```
Xcode project has automatic signing enabled, conflicting with manual override
```

**Fix Already Applied:**
- `CODE_SIGN_STYLE="Manual"` in `build-final-ipa.sh` line 44
- Should be sufficient

**Verify:**
- Open Xcode project: `src-tauri/gen/apple/src-tauri.xcodeproj`
- Select target: `src-tauri_iOS`
- Build Settings → Signing → Code Signing Style
- If "Automatic", change to "Manual"
- Save and close

---

### Issue: "Missing Code Signing Entitlements"

**Root Cause:** Entitlements not included in export

**Fix:**
- Entitlements file already located: `src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements`
- Export plist in `build-final-ipa.sh` line 65-82 should handle this automatically

**Verify:**
```bash
unzip -p OpenCode_Nexus.ipa "Payload/OpenCode Nexus.app/CodeResources" | grep -i "entitlements"
```

---

### Issue: "Invalid Bundle Structure (libapp.a included)"

**Root Cause:** Pre-built app includes static library that shouldn't be in IPA

**Fix:**
- Don't use manual re-signing path (Track B)
- Use proper Xcode archive → export (Track A)
- Archive process filters out unwanted binaries automatically

---

### Issue: "Provisioning Profile Mismatch"

**Root Cause:** Development profile embedded instead of App Store profile

**Fix (Already Applied):**
- `build-final-ipa.sh` lines 73-77 specify App Store profile in export plist
- Manual copy in `build-appstore-ipa.sh` line 54 replaces embedded profile

**Verify:**
```bash
PROFILE_UUID="426123c5-c69c-4778-81ed-1210fc35a282"
security find-identity -p basicIdentities -v | grep -i "$PROFILE_UUID"
```

---

## Success Criteria

### For Each Phase

**Phase 1:** ✅ Identified root cause, selected Track, documented findings

**Phase 2:** ✅ Have valid `.xcarchive` or valid `.app` with:
- Correct provisioning profile
- Correct signing certificate  
- No extraneous files (libapp.a)
- All entitlements included

**Phase 3:** ✅ Have valid `OpenCode_Nexus.ipa` with:
- Correct bundle structure
- Provisioning profile is App Store distribution type
- No static libraries included
- All required entitlements embedded

**Phase 4:** ✅ IPA uploaded to TestFlight and:
- Passes Apple validation
- Moves to "Processing" state
- Can be distributed to testers

---

## Fallback Plans

### If Track A Fails After 2 Hours
→ Switch to Track B1 (Use `cargo tauri build` then re-sign)

### If Track B Fails After 3 Hours  
→ Switch to Track C (Manual Xcode without Tauri)

### If All Tracks Fail After 6 Hours
→ Document blocking issues, prepare for next session

---

## Estimated Total Time

- **Phase 1 (Diagnosis):** 30 min
- **Phase 2 (Implementation):** 30 min - 3 hours (depends on Track)
- **Phase 3 (Export & Verify):** 1 hour  
- **Phase 4 (Upload & Monitor):** 30 min - 2 hours (depends on validation)

**Total:** 2.5 - 6.5 hours

**Most Likely Path (Track A2):** 3-4 hours

---

## Files to Modify/Create

### No New Files Needed

**Files to Inspect:**
- `src-tauri/build.rs` - Check for CLI socket logic
- `src-tauri/Cargo.toml` - Review Tauri features
- `src-tauri/gen/apple/src-tauri.xcodeproj` - Check build phases
- `src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements` - Verify entitlements

**Scripts to Run (Existing):**
- `build-final-ipa.sh` - With potential env var modifications
- `build-appstore-ipa.sh` - For Track B fallback
- `upload-to-testflight.sh` - For Phase 4

---

## Session Checkpoints

- [ ] Diagnosis complete (Phase 1) - 30 min
- [ ] Track selected and documented
- [ ] Implementation started (Phase 2) - 1-3 hours depending on Track
- [ ] Valid IPA produced (Phase 3) - confirmed via verification steps
- [ ] IPA uploaded (Phase 4) - TestFlight shows upload received
- [ ] Validation complete - IPA either approved or error logged for next iteration

