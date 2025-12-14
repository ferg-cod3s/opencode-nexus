# iOS TestFlight Release Pipeline

This directory contains scripts for building, signing, and uploading iOS apps to TestFlight using a fully scriptable, headless pipeline.

## Quick Start

### One-Time Setup

1. **Export Distribution Certificate** (GUI required once):
   ```bash
   # Open Keychain Access → login keychain → My Certificates
   # Find "Apple Distribution: John Ferguson (PCJU8QD9FN)"
   # Right-click → Export → Save as ~/.ios-signing/distribution.p12
   ```

2. **Set Environment Variables** (add to `~/.zshrc` or use `.env` file):
   ```bash
   export KEYCHAIN_PASSWORD="your-secure-password"
   export P12_PATH="$HOME/.ios-signing/distribution.p12"
   export P12_PASSWORD="your-p12-password"
   export APP_STORE_CONNECT_API_KEY_ID="J94Q923ZNG"
   export APP_STORE_CONNECT_ISSUER_ID="c6f421de-3e35-4aab-b96d-4c4461c39766"
   export APP_STORE_CONNECT_API_KEY_PATH="$HOME/Github/opencode-nexus/AuthKey_J94Q923ZNG.p8"
   ```

3. **Setup Keychain** (one-time):
   ```bash
   ./scripts/setup-keychain.sh
   ```

4. **Install Provisioning Profile**:
   ```bash
   ./scripts/install-provisioning-profile.sh ../Opencode_Nexus_App_Store_V2.mobileprovision
   ```

### Build & Upload

```bash
# Full pipeline (build + upload)
./scripts/ios-testflight-release.sh

# Individual steps
./scripts/unlock-keychain.sh
./scripts/build-ios-archive.sh
./scripts/upload-testflight.sh build/ipa/OpenCodeNexus.ipa
```

### Verification

```bash
# Check all signing assets and configuration
./scripts/verify-signing-assets.sh
```

## Scripts Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `setup-keychain.sh` | Create dedicated build keychain and import certificate | One-time setup |
| `unlock-keychain.sh` | Unlock keychain before builds | Before each build |
| `install-provisioning-profile.sh` | Install provisioning profile to system | When profile changes |
| `build-ios-archive.sh` | Build Xcode archive and export IPA | Main build step |
| `upload-testflight.sh` | Upload IPA to TestFlight | After successful build |
| `ios-testflight-release.sh` | Complete pipeline (all steps) | Full release |
| `verify-signing-assets.sh` | Check signing configuration | Troubleshooting |

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `KEYCHAIN_PASSWORD` | Password for build keychain | Yes |
| `P12_PATH` | Path to distribution .p12 file | Yes (for setup) |
| `P12_PASSWORD` | Password for .p12 file | Yes (for setup) |
| `APP_STORE_CONNECT_API_KEY_ID` | API key ID (J94Q923ZNG) | Yes (for upload) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (c6f421de-3e35-4aab-b96d-4c4461c39766) | Yes (for upload) |
| `APP_STORE_CONNECT_API_KEY_PATH` | Path to .p8 API key file | Alternative to content |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | Base64-encoded .p8 content | Alternative to path |

### Files

- `src-tauri/ios-config/ExportOptions.plist` - Export configuration for manual signing
- `Opencode_Nexus_App_Store_V2.mobileprovision` - Provisioning profile (in project root)
- `AuthKey_J94Q923ZNG.p8` - App Store Connect API key

## CI/CD Integration

### GitHub Actions Secrets

Set these secrets in your repository:

```bash
IOS_CERTIFICATE_P12          # base64 of distribution.p12
IOS_CERTIFICATE_PASSWORD     # .p12 password
IOS_PROVISIONING_PROFILE     # base64 of .mobileprovision
KEYCHAIN_PASSWORD           # build keychain password
APP_STORE_CONNECT_API_KEY_ID         # J94Q923ZNG
APP_STORE_CONNECT_ISSUER_ID          # c6f421de-3e35-4aab-b96d-4c4461c39766
APP_STORE_CONNECT_API_PRIVATE_KEY    # base64 of .p8 file
```

### GitHub Actions Workflow

The pipeline works with the existing `.github/workflows/ios-release.yml` workflow. The scripts handle the keychain setup, profile installation, and signing automatically.

## Troubleshooting

### Common Issues

1. **"codesign wants to access key" prompts**:
   - Run `setup-keychain.sh` to configure partition list
   - Use dedicated build keychain instead of login keychain

2. **Archive fails with signing errors**:
   - Run `verify-signing-assets.sh` to check configuration
   - Ensure provisioning profile is installed with correct UUID

3. **Upload fails**:
   - Check API credentials are set correctly
   - Verify .p8 file permissions (600)
   - Check App Store Connect API key hasn't expired

4. **Keychain locked**:
   - Run `unlock-keychain.sh` before builds
   - Check `KEYCHAIN_PASSWORD` is set

### Debug Commands

```bash
# Check available signing identities
security find-identity -v -p codesigning

# List installed provisioning profiles
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/

# Check Xcode build settings
xcodebuild -project src-tauri/gen/apple/src-tauri.xcodeproj -scheme src-tauri_iOS -showBuildSettings | grep CODE_SIGN

# Test API key validity
xcrun altool --apiKey J94Q923ZNG --apiIssuer c6f421de-3e35-4aab-b96d-4c4461c39766 --list-apps
```

## Security Notes

- Never commit `.p12` or `.p8` files to Git
- Use strong, unique passwords for keychains and certificates
- Store API keys as GitHub secrets (not environment variables)
- The build keychain is separate from your login keychain for security

## Architecture

The pipeline uses **manual signing** for reliability in CI/headless environments:

1. **Dedicated Keychain**: Isolated from login keychain to avoid GUI prompts
2. **Explicit Profiles**: Provisioning profiles installed by UUID
3. **Manual Signing**: No reliance on Xcode's automatic resolution
4. **App Store Connect API**: Direct upload without iTunes Connect

This approach is more reliable than automatic signing in headless environments.