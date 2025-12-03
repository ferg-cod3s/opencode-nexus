# CocoaPods pbxproj Parsing Error Fix

**Date**: 2025-12-03  
**Issue**: CocoaPods fails to parse Xcode project after Python patching script corrupts pbxproj format  
**Error**: `Nanaimo::Reader::ParseError - [!] Dictionary missing ';' after key-value pair for "shellScript", found "$"`

## Executive Summary

The iOS GitHub Actions build is failing because the Python script that patches `project.pbxproj` to skip the Rust build phase is generating malformed OpenStep plist syntax. When CocoaPods tries to parse the project file, it encounters corrupted `shellScript` values that break the dictionary format.

## Root Cause Analysis

### The Problem

1. **Original pbxproj format** (valid):
   ```
   shellScript = "cargo tauri ios xcode-script -v --platform ...";
   ```

2. **After Python regex replacement** (corrupted):
   ```
   shellScript = "# CI-Compatible: Skip if pre-built libapp.a exists
   OUTPUT_DIR="${SRCROOT}/Externals/arm64/${CONFIGURATION}"
   ...
   ```
   
   The multiline content with embedded quotes and newlines breaks the OpenStep plist format because:
   - Newlines in the value are not escaped as `\n`
   - The trailing semicolon is missing or malformed
   - Quotes within the string are not properly escaped

### Why This Happens

The Python regex in the workflow:
```python
old_pattern = r'(shellScript = ")[^"]*cargo tauri ios xcode-script[^"]*(")'
new_script = r'''\1# CI-Compatible: Skip if pre-built libapp.a exists
OUTPUT_DIR="${SRCROOT}/Externals/arm64/${CONFIGURATION}"
...'''
```

This creates literal newlines in the replacement, but pbxproj files require `\n` escape sequences for multiline scripts. The embedded `"` quotes in `${SRCROOT}` also break the string termination.

## Solution Options

### Option A: Use Proper pbxproj String Escaping (Recommended)

Replace newlines with `\n` and escape internal quotes:

```python
new_script_content = '''# CI-Compatible: Skip if pre-built libapp.a exists\\n\\
OUTPUT_DIR=\\"${SRCROOT}/Externals/arm64/${CONFIGURATION}\\"\\n\\
LIBAPP_PATH=\\"${OUTPUT_DIR}/libapp.a\\"\\n\\
if [ -f \\"$LIBAPP_PATH\\" ]; then\\n\\
  echo \\"Pre-built libapp.a found - skipping Rust build\\"\\n\\
  exit 0\\n\\
fi\\n\\
echo \\"libapp.a not found, falling back to Tauri build...\\"\\n\\
cargo tauri ios xcode-script -v --platform ${PLATFORM_DISPLAY_NAME:?} ...'''
```

**Pros**: Maintains the patching approach, fixes the syntax issue  
**Cons**: Complex escaping, fragile regex

### Option B: Delete the Build Phase Entirely (Simpler)

Instead of patching the script content, remove the entire "Build Rust Code" build phase from the project since we pre-build the library:

```python
# Remove the entire PBXShellScriptBuildPhase section for "Build Rust Code"
content = re.sub(
    r'/\* Build Rust Code \*/[^;]+;',
    '',
    content
)
```

**Pros**: Simpler, no string escaping issues  
**Cons**: May affect build order, need to ensure library is in place

### Option C: Skip CocoaPods, Modify Build Order (Best)

The cleanest solution is to:
1. Keep the original pbxproj untouched
2. Set environment variables that make the build phase succeed quickly
3. Run `pod install` BEFORE patching the project

**Pros**: No file manipulation, most reliable  
**Cons**: Requires changing workflow order

### Option D: Use sed Instead of Python (Alternative)

Use a simple sed command to replace just the script content on a single line:

```bash
sed -i.bak 's|cargo tauri ios xcode-script.*ARCHS:\?}"|if [ -f "${SRCROOT}/Externals/arm64/${CONFIGURATION}/libapp.a" ]; then exit 0; fi; cargo tauri ios xcode-script ... "|' project.pbxproj
```

**Pros**: Simple, single-line replacement  
**Cons**: Long line, still needs proper escaping

## Recommended Solution: Option C + D Hybrid

The best approach is:

1. **Run CocoaPods BEFORE any project modification** - This avoids the parsing error entirely
2. **Use a simple, single-line skip check** - Minimal change to the original script

### Implementation

```yaml
# Step 1: Initialize iOS project (creates gen/apple/)
- name: Setup iOS Xcode project
  run: |
    cd src-tauri
    cargo tauri ios init
    
    # Create directories and copy library FIRST
    mkdir -p gen/apple/Externals/arm64/Release gen/apple/Externals/arm64/release
    cp target/aarch64-apple-ios/release/libsrc_tauri_lib.a gen/apple/Externals/arm64/Release/libapp.a
    cp target/aarch64-apple-ios/release/libsrc_tauri_lib.a gen/apple/Externals/arm64/release/libapp.a
    
    # Run CocoaPods BEFORE modifying project.pbxproj
    cd gen/apple
    pod install --repo-update || pod install
    
    # NOW patch the project (after CocoaPods is done)
    cd ../..
    PBXPROJ="gen/apple/src-tauri.xcodeproj/project.pbxproj"
    
    # Simple single-line patch: prepend exit check to existing script
    sed -i.bak 's|shellScript = "cargo|shellScript = "if [ -f \\"${SRCROOT}/Externals/arm64/${CONFIGURATION}/libapp.a\\" ]; then echo Skip; exit 0; fi; cargo|' "$PBXPROJ"
    
    echo "✅ Project patched and CocoaPods installed"
```

## Files to Modify

| File | Change |
|------|--------|
| `.github/workflows/ios-release-optimized.yml` | Reorder steps: CocoaPods before patch, simplify patch logic |

## Technical Details

### Why CocoaPods Fails

CocoaPods uses the `xcodeproj` gem which uses `nanaimo` to parse OpenStep plist files. The pbxproj format has strict requirements:

1. **Strings**: Must be enclosed in quotes, multiline content uses `\n`
2. **Dictionaries**: Each key-value pair must end with `;`
3. **Escaping**: Internal quotes must be `\"`

### Valid Multiline Script Example

```
shellScript = "line1\\nline2\\nline3";
```

Or with actual newlines (less common):
```
shellScript = "line1\nline2\nline3";
```

The Python regex was creating:
```
shellScript = "line1
line2
line3
```

Missing the closing quote and semicolon after the first line.

## Testing Strategy

### 1. Local Validation

```bash
# Create a test pbxproj file
cp src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj /tmp/test.pbxproj

# Apply the sed patch
sed -i.bak 's|shellScript = "cargo|shellScript = "if [ -f \\"${SRCROOT}/Externals/arm64/${CONFIGURATION}/libapp.a\\" ]; then echo Skip; exit 0; fi; cargo|' /tmp/test.pbxproj

# Validate it's still parseable (requires Ruby with xcodeproj gem)
ruby -e "require 'xcodeproj'; Xcodeproj::Project.open('/tmp/test.pbxproj')"
```

### 2. CI Validation

1. Push to a test branch
2. Monitor the workflow for:
   - CocoaPods `pod install` succeeds
   - Xcode archive step works
   - No parsing errors

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| sed patch breaks on Tauri update | Low | Medium | Validate pattern exists before patching |
| CocoaPods caches corrupted project | Low | Low | Clear derived data before pod install |
| Build phase still runs | Low | Low | Verify library exists before build |

## Rollback Plan

If the fix doesn't work:
1. Remove the patching step entirely
2. Use environment variables to skip the Rust build:
   ```bash
   export TAURI_IOS_SKIP_RUST_BUILD=1  # hypothetical
   ```
3. Or manually run xcodebuild with `-derivedDataPath` to a clean location

## Implementation Checklist

- [ ] Update workflow to run CocoaPods BEFORE patching
- [ ] Replace Python regex patch with simple sed command
- [ ] Add validation that patch was applied correctly
- [ ] Test on a feature branch before merging
- [ ] Monitor first successful build

## Expected Outcome

After implementation:
1. **CocoaPods will succeed** because it parses the original, valid pbxproj
2. **Xcode build phase will skip** due to the prepended exit check
3. **IPA will be generated** successfully for TestFlight

## Timeline

- **Immediate**: Implement the workflow fix (15 minutes)
- **Validation**: Push to test branch and monitor CI (30 minutes)
- **Merge**: Once confirmed working, merge to main
