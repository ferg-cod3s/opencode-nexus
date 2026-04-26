# iOS TestFlight Deployment - Next Session Checklist

## ⚠️ Current Blocker: App Store Distribution Provisioning Profile

The iOS app (v0.1.3) is **fully built and ready** but cannot be uploaded to TestFlight without a valid App Store distribution provisioning profile.

## Quick Start for Next Session

### 1. Get Distribution Provisioning Profile (5-10 minutes)
```bash
# Go to: https://developer.apple.com/account/

# Navigate to: Certificates, Identifiers & Profiles → Provisioning Profiles

# Create new "App Store" profile:
# - App ID: com.agentic-codeflow.opencode-nexus
# - Certificate: "Apple Distribution: John Ferguson (PCJU8QD9FN)"
# - Devices: Not applicable for App Store

# Download the .mobileprovision file

# Install by double-clicking or placing in:
~/Library/MobileDevice/Provisioning\ Profiles/
```

### 2. Rebuild iOS App (3-5 minutes)
```bash
cd /Users/johnferguson/Github/opencode-nexus

# Build frontend
cd frontend && bun run build && cd ..

# Build iOS with new provisioning profile
cd src-tauri && cargo tauri ios build && cd ..
```

### 3. Deploy to TestFlight (2 minutes)
```bash
# Option A: Use automated script (recommended)
./build-and-deploy-ios.sh

# Option B: Manual upload
source .env
xcrun altool \
    --upload-app \
    --type ios \
    --file build/OpenCodeNexus.ipa \
    --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

### 4. Verify Upload (5 minutes)
```bash
# Wait 5-10 minutes, then check:
# https://appstoreconnect.apple.com/apps/6754924026/testflight/ios

# v0.1.3 should appear in "Builds" section
```

## Current Build Status

| Component | Status | Details |
|-----------|--------|---------|
| **Frontend** | ✅ Built | Astro + Svelte, optimized |
| **Rust Backend** | ✅ Built | arm64, release mode |
| **App Bundle** | ✅ Created | 5.2MB binary |
| **Code Signing** | ✅ Working | Dev certificate valid |
| **IPA Package** | ✅ Ready | 35MB in `build/OpenCodeNexus.ipa` |
| **Provisioning Profile** | ⏳ NEEDED | Must get from App Store |
| **TestFlight Upload** | ⏳ PENDING | Blocked on provisioning profile |

## Key Files & Locations

### Build Scripts
- `build-and-deploy-ios.sh` ← **Recommended**: Full build + deploy
- `build-and-upload-ios.sh` - Archive and upload only
- `build-ios.sh` - Local development build

### Build Artifacts
- IPA: `build/OpenCodeNexus.ipa` (35MB)
- App: `~/Library/Developer/Xcode/DerivedData/src-tauri-hgvkaafvyemsvccsgvamzrdyilmy/Build/Products/release-iphoneos/OpenCode Nexus.app`

### Configuration
- Bundle ID: `com.agentic-codeflow.opencode-nexus`
- Team ID: `PCJU8QD9FN`
- App ID: `6754924026`
- Min iOS: 14.0
- Architecture: arm64

## Credentials Required

All stored in `.env` (not committed):
```
APP_STORE_CONNECT_API_KEY_ID=78U6M64KJS
APP_STORE_CONNECT_ISSUER_ID=c6f421de-3e35-4aab-b96d-4c4461c39766
APP_STORE_CONNECT_API_PRIVATE_KEY=<private key content>
APPLE_TEAM_ID=PCJU8QD9FN
```

## Verification Commands

```bash
# Check if app is properly signed
codesign -d -v "~/Library/Developer/Xcode/DerivedData/src-tauri-hgvkaafvyemsvccsgvamzrdyilmy/Build/Products/release-iphoneos/OpenCode Nexus.app"

# Check IPA contents
unzip -l build/OpenCodeNexus.ipa | head -20

# Verify provisioning profile installed
ls ~/Library/MobileDevice/Provisioning\ Profiles/ | grep -i opencode || echo "No profiles found"
```

## Troubleshooting

### If upload fails with "Missing code-signing certificate"
- The provisioning profile needs the Apple Distribution certificate
- Verify certificate is in Keychain: `security find-identity -v -p codesigning`
- Check profile at: https://developer.apple.com/account/resources/profiles/

### If build fails
- Clean: `rm -rf ~/Library/Developer/Xcode/DerivedData/src-tauri-*`
- Rebuild: `cd src-tauri && cargo tauri ios build`

### If xcodebuild times out
- Already optimized in Cargo.toml
- Should complete in 2-3 minutes now
- Check internet connection if slower

## Post-Upload Steps

Once v0.1.3 appears in TestFlight:

1. **Release to External Testers** (optional for v0.1.3)
2. **Gather Feedback** from testers
3. **Fix Issues** found during testing
4. **Release to App Store** when ready
   - Click "Add to Build" in App Store Connect
   - Fill in release notes
   - Submit for review

## Important Dates

- Build Completed: Nov 14, 2025
- Expected TestFlight Upload: Nov 14-15, 2025
- Expected App Review: 24-48 hours from submission

## Next Major Features

After v0.1.3 is live on TestFlight:
1. Push notifications
2. Offline mode
3. Advanced chat features
4. Performance optimization

---

**Status Updated**: Nov 14, 2025
**Expected Time to Deploy**: ~15 minutes (once provisioning profile is ready)
