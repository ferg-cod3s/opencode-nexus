# iOS Build Resolution - Phase 1 Diagnosis Complete

**Date:** November 14, 2025  
**Status:** Root cause confirmed, solution selected

---

## Phase 1 Findings

### Finding 1: Tauri Build System Architecture

**Location:** `src-tauri/build.rs:24`
```rust
fn main() {
    tauri_build::build();  // This is what's failing!
    // ... iOS frameworks config
}
```

**Analysis:**
- `tauri_build::build()` is a compile-time macro that generates code
- It **does NOT** try to connect to network socket during normal cargo build
- The network error is happening **inside Xcode's build phase**, not in Rust

---

### Finding 2: The Real Culprit - Xcode Build Phase

**Location:** `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`

**Build Phase: "Build Rust Code"**
```
shellScript = "cargo tauri ios xcode-script -v --platform ${PLATFORM_DISPLAY_NAME:?} --sdk-root ${SDKROOT:?} --framework-search-paths \"${FRAMEWORK_SEARCH_PATHS:?}\" --header-search-paths \"${HEADER_SEARCH_PATHS:?}\" --gcc-preprocessor-definitions \"${GCC_PREPROCESSOR_DEFINITIONS:-}\" --configuration ${CONFIGURATION:?} ${FORCE_COLOR} ${ARCHS:?}";
```

**The Problem:**
- Xcode runs: `cargo tauri ios xcode-script` (a Tauri CLI command)
- This command tries to connect to a local Tauri CLI server on TCP socket
- Server doesn't exist because it's not running
- Error: `Connection refused (os error 61)`

**Output Paths:**
- `$(SRCROOT)/Externals/x86_64/${CONFIGURATION}/libapp.a`
- `$(SRCROOT)/Externals/arm64/${CONFIGURATION}/libapp.a`

This is where the `libapp.a` static library comes from that breaks App Store validation!

---

### Finding 3: Why This Happens

The `cargo tauri ios xcode-script` command is designed to:
1. Connect to Tauri CLI server running on local machine
2. Get build options/configuration from server
3. Build Rust for iOS using those options

**Why It Fails in Our Case:**
- We're running `xcodebuild archive` directly (not via Tauri)
- Tauri's CLI server is not running
- Socket connection fails
- Archive fails

---

## Solution Selected: Track A2 (Recommended)

### Why Track A2?

**Option A1 (Skip Socket Check):**
- ❌ Would require modifying Tauri source or Xcode project internals
- ❌ May have side effects
- ⚠️ Not recommended

**Option A2 (Direct Xcode without Tauri CLI):**
- ✅ Bypass the problematic `cargo tauri ios xcode-script` command entirely
- ✅ Use pre-built Rust library + Xcode project
- ✅ Proven to work for iOS static library builds
- ✅ Most reliable approach

**Option B1 (Use Cargo Tauri Build):**
- ❌ Would require `cargo tauri build` which may have similar issues
- ❌ More complex setup
- Less reliable than A2

**Selected:** **Track A2 - Direct Xcode without Tauri CLI**

---

## Track A2 Implementation Plan

### Step 1: Pre-build Rust Library (30 min)
Already done! We have:
- `cargo build --release --target aarch64-apple-ios`
- Produces: `src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a`

### Step 2: Remove Problematic Build Phase (15 min)

**Goal:** Remove the "Build Rust Code" shell script phase that calls `cargo tauri ios xcode-script`

**Options:**
- Option A: Remove the build phase entirely from Xcode project
- Option B: Disable the shell script (keep phase but make it no-op)
- Option C: Replace with a simpler Cargo build command that doesn't use CLI

**Recommended:** Option C (Replace with direct cargo call)

### Step 3: Link Pre-built Library (30 min)

**Goal:** Point Xcode to the pre-built `.a` file

**Current State:**
- Xcode is expecting `libapp.a` at: `$(SRCROOT)/Externals/x86_64/` and `$(SRCROOT)/Externals/arm64/`
- We have: `src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a`

**Action:**
- Copy pre-built library to expected location
- Update Xcode build settings to use it
- Verify Xcode recognizes the library

### Step 4: Build Archive (30 min)
```bash
xcodebuild archive \
    -project src-tauri/gen/apple/src-tauri.xcodeproj \
    -scheme src-tauri_iOS \
    -archivePath /tmp/OpenCode_Nexus.xcarchive \
    -configuration Release \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_IDENTITY="Apple Distribution: John Ferguson (PCJU8QD9FN)" \
    DEVELOPMENT_TEAM="PCJU8QD9FN" \
    PROVISIONING_PROFILE="426123c5-c69c-4778-81ed-1210fc35a282" \
    -derivedDataPath /tmp/xcode_build
```

### Step 5: Verify Archive Works
```bash
ls -lah /tmp/OpenCode_Nexus.xcarchive
unzip -l /tmp/OpenCode_Nexus.xcarchive/Products/Applications/*/Frameworks | head -20
```

---

## Execution Steps for Track A2

### A2.1: Prepare Rust Library (5 min)

```bash
# Already built, just verify
ls -lh src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a

# Create Externals directory structure
mkdir -p src-tauri/gen/apple/Externals/arm64/Release
mkdir -p src-tauri/gen/apple/Externals/x86_64/Release

# Copy library (for now, use arm64 for both - we can fix simulator later)
cp src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a \
   src-tauri/gen/apple/Externals/arm64/Release/libapp.a

# Also copy for x86_64 (for simulator)
# We may need to build x86_64 separately if simulator testing is needed
# For now, copy arm64 version (won't work for simulator, but OK for release)
cp src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a \
   src-tauri/gen/apple/Externals/x86_64/Release/libapp.a
```

### A2.2: Disable Problematic Build Phase (10 min)

**Option:** Replace the shell script with a no-op command

Edit: `src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj`

Change this line (search for `cargo tauri ios xcode-script`):
```
FROM: shellScript = "cargo tauri ios xcode-script -v ...";
TO:   shellScript = "echo 'Skipping Tauri CLI build phase - using pre-built library'";
```

### A2.3: Link Frameworks and Library (5 min)

In Xcode Build Settings:
- Library Search Paths: Add `$(SRCROOT)/Externals/$(PLATFORM_PREFERRED_ARCH)/$(CONFIGURATION)`
- Link Binary With Libraries: Ensure `libapp.a` is linked

Or via command line in build script:
```bash
OTHER_LDFLAGS="-L$(SRCROOT)/Externals/$(PLATFORM_PREFERRED_ARCH)/$(CONFIGURATION) -lapp"
```

### A2.4: Run Archive Build (30 min)

```bash
cd /Users/johnferguson/Github/opencode-nexus/src-tauri/gen/apple

xcodebuild archive \
    -project src-tauri.xcodeproj \
    -scheme src-tauri_iOS \
    -archivePath /tmp/OpenCode_Nexus.xcarchive \
    -configuration Release \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_IDENTITY="Apple Distribution: John Ferguson (PCJU8QD9FN)" \
    DEVELOPMENT_TEAM="PCJU8QD9FN" \
    PROVISIONING_PROFILE="426123c5-c69c-4778-81ed-1210fc35a282" \
    -derivedDataPath /tmp/xcode_build \
    -allowProvisioningUpdates
```

### A2.5: Verify Success

```bash
if [ -d /tmp/OpenCode_Nexus.xcarchive ]; then
    echo "✅ Archive created successfully"
    ls -lah /tmp/OpenCode_Nexus.xcarchive/Products/Applications/
else
    echo "❌ Archive failed"
    exit 1
fi
```

---

## What Happens Next

Once Track A2 succeeds:
1. Export IPA from archive (using `build-final-ipa.sh` lines 90-104)
2. Verify IPA structure (no libapp.a, has provisioning profile)
3. Upload to TestFlight
4. Monitor validation

---

## Key Risk Factors for Track A2

**Risk 1: Simulator Architecture**
- Pre-built library is `aarch64-apple-ios` (device only)
- Won't work for x86_64 simulator
- **Mitigation:** Build x86_64 version separately if simulator testing needed
- **Acceptable:** For release/TestFlight, device architecture only is fine

**Risk 2: Xcode Project File Format**
- Modifying `project.pbxproj` is fragile
- **Mitigation:** Make minimal change to shell script only
- **Backup:** Keep original copy before editing

**Risk 3: Linking Issues**
- Library may have missing symbol references
- **Mitigation:** Ensure all iOS frameworks are linked in Xcode
- **Already Done:** In `src-tauri/build.rs` lines 29-36

---

## Success Criteria for Track A2

- [ ] Archive completes without socket/network errors
- [ ] `.xcarchive` exists at `/tmp/OpenCode_Nexus.xcarchive`
- [ ] Archive contains valid app bundle with all frameworks linked
- [ ] No "Build Rust Code" phase execution time (since we skip it)
- [ ] Archive is under 100MB (reasonable for app + libraries)

