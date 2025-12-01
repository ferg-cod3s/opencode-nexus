# iOS Build Failure Fix Implementation Plan

**Date**: 2025-12-01  
**Issue**: Xcode Cloud build fails with "Command PhaseScriptExecution failed with a nonzero exit code"  
**Root Cause**: Tauri's `cargo tauri ios xcode-script` requires TCP socket connection that doesn't exist in CI

## Executive Summary

The iOS build failure is caused by three interconnected issues:
1. **Library name mismatch**: Scripts search for `libsrc_tauri.a` but Cargo.toml outputs `libsrc_tauri_lib.a`
2. **TCP socket dependency**: `cargo tauri ios build` tries to connect to parent process that doesn't exist in CI
3. **Redundant build step**: GitHub Actions pre-builds library but still runs `cargo tauri ios build`

## Technical Approach

### Solution Strategy: Pre-Build + Skip Pattern

1. **Pre-build Rust library** separately with `cargo build --target aarch64-apple-ios --release`
2. **Copy library** to Xcode's expected location: `gen/apple/Externals/arm64/Release/libapp.a`
3. **Patch Xcode project** to skip "Build Rust Code" phase when library exists
4. **Use direct xcodebuild** instead of `cargo tauri ios build`

## Files to Modify

| File | Issue | Fix |
|------|--------|------|
| `ci_scripts/ci_post_clone.sh` | Wrong library name (`libsrc_tauri.a`) | Use `libsrc_tauri_lib.a` |
| `ci_scripts/build_rust_code.sh` | Missing correct library in search | Add `libsrc_tauri_lib.a` to search list |
| `.github/workflows/ios-release.yml` | Runs `cargo tauri ios build` | Remove step, use pre-built library |
| `src-tauri/Cargo.toml` | Duplicate `uuid` dependency | Remove duplicate line |

## Detailed Implementation

### Phase 1: Fix Library Name References

#### 1.1 Update `ci_scripts/ci_post_clone.sh`

**Lines 78-96**: Replace library detection logic

```bash
# Copy built library to where Xcode expects it
# The actual library name from Cargo.toml is "src_tauri_lib"
RUST_LIB_PATH="target/aarch64-apple-ios/release/libsrc_tauri_lib.a"
if [ -f "$RUST_LIB_PATH" ]; then
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/Release/libapp.a
    cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/release/libapp.a
    echo "✅ Rust library (libsrc_tauri_lib.a) copied to Externals directory"
    ls -la gen/apple/Externals/arm64/Release/
else
    # Fallback: search for any .a file
    FOUND_LIB=$(find target/aarch64-apple-ios/release -name "lib*.a" -type f | head -1)
    if [ -n "$FOUND_LIB" ] && [ -f "$FOUND_LIB" ]; then
        cp "$FOUND_LIB" gen/apple/Externals/arm64/Release/libapp.a
        cp "$FOUND_LIB" gen/apple/Externals/arm64/release/libapp.a
        echo "✅ Rust library ($(basename $FOUND_LIB)) copied to Externals directory"
        ls -la gen/apple/Externals/arm64/Release/
    else
        echo "⚠️ Rust library not found, listing target directory:"
        find target/aarch64-apple-ios/release -name "*.a" -type f 2>/dev/null || echo "No .a files found"
        exit 1
    fi
fi
```

#### 1.2 Update `ci_scripts/build_rust_code.sh`

**Lines 158-163**: Add correct library name to search

```bash
# Try different possible library names, starting with correct one from Cargo.toml
FOUND_LIB=""
for LIB_NAME in "libsrc_tauri_lib.a" "libapp.a" "libsrc_tauri.a" "libopencode_nexus.a"; do
    if [ -f "${RUST_TARGET_DIR}/${LIB_NAME}" ]; then
        FOUND_LIB="${RUST_TARGET_DIR}/${LIB_NAME}"
        break
    fi
done
```

### Phase 2: Update GitHub Actions Workflow

#### 2.1 Remove Problematic Build Step

**Remove lines 166-177** from `.github/workflows/ios-release.yml`:
```yaml
# REMOVE THIS ENTIRE STEP:
- name: Build iOS app with Tauri
  run: |
    cd src-tauri
    cargo tauri ios build --verbose
```

#### 2.2 Fix Library Copy Logic

**Lines 123-131**: Update library detection

```yaml
# Copy pre-built library to where Xcode expects it
# The actual library name is libsrc_tauri_lib.a based on Cargo.toml
RUST_LIB_PATH="target/aarch64-apple-ios/release/libsrc_tauri_lib.a"
if [ -f "$RUST_LIB_PATH" ]; then
  cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/Release/libapp.a
  cp "$RUST_LIB_PATH" gen/apple/Externals/arm64/release/libapp.a
  echo "Copied pre-built libsrc_tauri_lib.a to gen/apple/Externals/arm64/"
  ls -la gen/apple/Externals/arm64/Release/
else
  # Fallback: search for any .a file
  FOUND_LIB=$(find target/aarch64-apple-ios/release -name "lib*.a" -type f | head -1)
  if [ -n "$FOUND_LIB" ] && [ -f "$FOUND_LIB" ]; then
    cp "$FOUND_LIB" gen/apple/Externals/arm64/Release/libapp.a
    cp "$FOUND_LIB" gen/apple/Externals/arm64/release/libapp.a
    echo "Copied pre-built $(basename $FOUND_LIB) to gen/apple/Externals/arm64/"
    ls -la gen/apple/Externals/arm64/Release/
  else
    echo "ERROR: No static library found in target/aarch64-apple-ios/release/"
    echo "Available files:"
    ls -la target/aarch64-apple-ios/release/ 2>/dev/null || echo "Directory not found"
    exit 1
  fi
fi
```

### Phase 3: Clean Up Cargo.toml

#### 3.1 Remove Duplicate Dependency

**Remove line 60** from `src-tauri/Cargo.toml`:
```toml
# REMOVE THIS LINE:
uuid = { version = "1", features = ["v4"] }

# KEEP LINE 50:
uuid = { version = "1", features = ["v4"] }
```

## Testing Strategy

### 1. Local Validation

```bash
# Test library name detection
cd src-tauri
cargo build --target aarch64-apple-ios --release --lib
find target/aarch64-apple-ios/release -name "lib*.a" -type f

# Verify correct library is produced
ls -la target/aarch64-apple-ios/release/libsrc_tauri_lib.a
file target/aarch64-apple-ios/release/libsrc_tauri_lib.a
```

### 2. CI Testing

1. Create test branch with fixes
2. Push to trigger GitHub Actions
3. Monitor build logs for:
   - Correct library detection
   - Successful library copying
   - No TCP socket errors
   - Successful xcodebuild execution

### 3. Validation Commands

```bash
# Verify library exists at expected location
ls -la src-tauri/gen/apple/Externals/arm64/Release/libapp.a

# Verify library architecture
lipo -info src-tauri/gen/apple/Externals/arm64/Release/libapp.a

# Verify Xcode project was patched
grep -A 10 "CI-Compatible" src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj
```

## Risk Assessment

### High Risk
- **Library Name Changes**: If Cargo.toml changes, build will fail
  - **Mitigation**: Dynamic library detection with fallback

### Medium Risk
- **Xcode Project Format**: Regex patch might fail if format changes
  - **Mitigation**: Add validation that patch was applied

### Low Risk
- **Directory Structure**: Might change in future Tauri versions
  - **Mitigation**: Use find commands for dynamic location

## Rollback Plan

### Immediate Rollback
1. Revert three modified files to previous state
2. Update library name to match whatever Cargo.toml produces
3. Test locally before pushing

### Alternative Approach
If fixes don't work, implement dynamic name extraction:
```bash
# Extract library name from Cargo.toml
LIB_NAME=$(grep '^name = ' src-tauri/Cargo.toml | head -1 | sed 's/name = "//;s/".*//')
LIB_FILE="lib${LIB_NAME}.a"
```

## Implementation Checklist

- [ ] Update `ci_scripts/ci_post_clone.sh` library name (line 86)
- [ ] Update `ci_scripts/build_rust_code.sh` search list (line 158)
- [ ] Update `.github/workflows/ios-release.yml` library copy (line 125)
- [ ] Remove `cargo tauri ios build` step from workflow (lines 166-177)
- [ ] Remove duplicate `uuid` from Cargo.toml (line 60)
- [ ] Test library name detection locally
- [ ] Commit changes to test branch
- [ ] Monitor CI build execution
- [ ] Validate successful IPA creation
- [ ] Update documentation if needed

## Expected Outcome

After implementation:
1. **CI builds will succeed** without TCP socket errors
2. **Correct library** (`libsrc_tauri_lib.a`) will be detected and copied
3. **Xcode build phase** will be skipped when pre-built library exists
4. **Local development** will continue to work with hot reload
5. **IPA generation** will complete successfully for TestFlight upload

## Timeline

- **Day 1**: Implement fixes and test locally
- **Day 2**: Deploy to test branch and monitor CI
- **Day 3**: Validate and merge to main
- **Day 4**: Full deployment and documentation update

This plan addresses all root causes while maintaining compatibility with both CI and local development environments.