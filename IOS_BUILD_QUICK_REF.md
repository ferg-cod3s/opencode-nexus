# iOS Build Quick Reference - Session 3

## Current Blocker
**Tauri CLI Network Socket Error** during Xcode archive build. Need to:
1. Bypass Tauri's networked build system
2. Or manually configure build environment
3. Or use pre-built Rust library directly

## Quick Start Options

### Option A: Direct xcodebuild (RECOMMENDED)
If you can skip Tauri's build script and use pre-built libraries:

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
    -allowProvisioningUpdates
```

### Option B: Use Pre-built IPA
The IPA in the repo root (`OpenCode_Nexus.ipa`) is already built and signed. Just test upload:

```bash
./upload-to-testflight.sh /Users/johnferguson/Github/opencode-nexus/OpenCode_Nexus.ipa
```

### Option C: Environment Variable Approach
Set environment variables before xcodebuild to skip Tauri networking:

```bash
export RUST_BACKTRACE=full
export TAURI_CLI_NETWORK_DISABLED=1
# Try build...
```

## Key IDs & Credentials

| Item | Value |
|------|-------|
| Bundle ID | com.agentic-codeflow.opencode-nexus |
| Team ID | PCJU8QD9FN |
| App ID (App Store Connect) | 6754924026 |
| Distribution Cert | 814E6A19CE8D98976418745CB13F754E6D025CC8 |
| Provisioning Profile UUID | 426123c5-c69c-4778-81ed-1210fc35a282 |
| API Key ID | 78U6M64KJS |
| Issuer ID | c6f421de-3e35-4aab-b96d-4c4461c39766 |

## Commands to Test

### 1. Check Code Signing Setup
```bash
security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db 2>/dev/null | grep -i distribution
```

### 2. Verify Provisioning Profile
```bash
ls "$HOME/Library/MobileDevice/Provisioning Profiles/" | grep -i opencode
```

### 3. Check API Credentials
```bash
ls ~/.appstoreconnect/private_keys/
```

### 4. Test API Upload (without IPA)
```bash
source ~/.credentials/.env
echo "API Key ID: $APP_STORE_CONNECT_API_KEY_ID"
echo "Issuer ID: $APP_STORE_CONNECT_ISSUER_ID"
```

## Error Messages & Solutions

### "Connection refused (os error 61)"
**Cause:** Tauri CLI trying to connect to non-existent socket server
**Solutions:**
1. Set environment variable: `export TAURI_SKIP_CLI=1`
2. Pre-build Rust library separately
3. Use direct xcodebuild without Tauri wrapper

### "Conflicting provisioning settings"
**Cause:** Xcode has automatic signing enabled but manual being specified
**Solution:** Add `CODE_SIGN_STYLE="Manual"` to xcodebuild command

### "Provisioning profile doesn't include signing certificate"
**Cause:** Wrong provisioning profile UUID used
**Solution:** Use UUID `426123c5-c69c-4778-81ed-1210fc35a282`

## Next Steps

1. Try Option A first (direct xcodebuild)
2. If that works, skip to upload
3. If it fails with network error, try environment variables
4. If all fail, consider using Tauri CLI development mode

## Useful Files
- Config: `src-tauri/tauri.ios.conf.json`
- Entitlements: `src-tauri/gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements`
- Build scripts: `build-*.sh` in repo root
- Credentials: `~/.credentials/.env`
- Provisioning Profile: `~/Library/MobileDevice/Provisioning Profiles/OpenCode_Nexus_App_Store\(1\).mobileprovision`

## TestFlight Upload
Once IPA is ready:
```bash
./upload-to-testflight.sh /path/to/OpenCode_Nexus.ipa
```

Check status at: https://appstoreconnect.apple.com/apps/6754924026/testflight/ios
