# Getting App Store Distribution Provisioning Profile

## The Problem
The app was built with a development provisioning profile, but TestFlight requires an **App Store distribution profile**.

## Solution: Get Distribution Profile from Apple Developer

### Step 1: Log into Apple Developer (2 minutes)
1. Go to: https://appstoreconnect.apple.com/
2. Click "Teams" icon in top right
3. Select team: `c6f421de-3e35-4aab-b96d-4c4461c39766`
4. Or go directly to: https://appstoreconnect.apple.com/teams/c6f421de-3e35-4aab-b96d-4c4461c39766/

### Step 2: Access Certificates & Profiles (1 minute)
1. From App Store Connect homepage, click "Certificates, Identifiers & Profiles"
   - Or go to: https://developer.apple.com/account/resources/profiles
2. In left sidebar, click "Profiles"

### Step 3: Create New Profile (2 minutes)
1. Click "+" button to create new profile
2. Select "App Store Connect" (not Ad Hoc, not Development)
3. Click Continue

### Step 4: Select App ID (1 minute)
1. Choose: `com.agentic-codeflow.opencode-nexus` 
2. Click Continue

### Step 5: Select Certificate (1 minute)
1. Choose: "Apple Distribution: John Ferguson (PCJU8QD9FN)"
   - This should already exist in your account
2. Click Continue

### Step 6: Download Profile (1 minute)
1. Name: `OpenCode_Nexus_AppStore` (or any name)
2. Click "Generate"
3. Click "Download"
4. File saves as `.mobileprovision`

### Step 7: Install Profile (1 minute)
**Option A: Automatic (Recommended)**
- Double-click the `.mobileprovision` file
- Xcode will automatically install it

**Option B: Manual**
```bash
cp ~/Downloads/*.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
```

### Step 8: Verify Installation
```bash
ls ~/Library/MobileDevice/Provisioning\ Profiles/ | wc -l
# Should show 1 profile now
```

## Rebuild and Upload

Once profile is installed:

```bash
cd /Users/johnferguson/Github/opencode-nexus

# Clean previous build
rm -rf ~/Library/Developer/Xcode/DerivedData/src-tauri-*

# Rebuild with new profile
cd frontend && bun run build && cd ..
cd src-tauri && cargo tauri ios build && cd ..

# Upload to TestFlight
source .env
xcrun altool \
    --upload-app \
    --type ios \
    --file build/OpenCodeNexus.ipa \
    --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --outputFormat json
```

## Troubleshooting

### "Profile not found"
- Make sure profile is in: `~/Library/MobileDevice/Provisioning\ Profiles/`
- Restart Xcode if it was open
- Run: `security find-identity -v -p codesigning`

### "Missing code-signing certificate"
- The distribution profile must include the "Apple Distribution" certificate
- Check at: https://developer.apple.com/account/resources/certificates/
- Certificate must be named: "Apple Distribution: John Ferguson (PCJU8QD9FN)"

### Upload still fails
1. Try building and signing in Xcode directly:
   ```bash
   open src-tauri/gen/apple/src-tauri.xcodeproj
   ```
2. In Xcode:
   - Select "src-tauri_iOS" scheme
   - Select "Any iOS Device"
   - Product → Archive
   - Follow UI prompts to export and upload

## Expected Time
- Download profile: 2 minutes
- Install: 1 minute
- Rebuild iOS: 3-5 minutes
- Upload: 2 minutes
- **Total: ~10-15 minutes**

---
**Critical**: The App Store profile is different from the development profile. Make sure to select "App Store Connect" in Step 3, not "Ad Hoc" or "Development".
