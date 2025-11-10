# iOS TestFlight Release Guide

This guide covers the complete process for building and releasing OpenCode Nexus to TestFlight through automated GitHub Actions workflows.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup (One-Time)](#initial-setup-one-time)
3. [GitHub Secrets Configuration](#github-secrets-configuration)
4. [Release Process](#release-process)
5. [Monitoring Builds](#monitoring-builds)
6. [Troubleshooting](#troubleshooting)
7. [Manual Release (Fallback)](#manual-release-fallback)

---

## Prerequisites

Before starting, ensure you have:

- ✅ **Apple Developer Account** - Team member with app management access
- ✅ **App Store Connect Access** - Ability to manage "OpenCode Nexus" app (ID: com.agentic-codeflow.opencode-nexus)
- ✅ **GitHub Repository Access** - Ability to configure secrets and trigger workflows
- ✅ **Distribution Certificate** - Apple Distribution certificate exported from Xcode
- ✅ **App Store Provisioning Profile** - Profile for App Store distribution
- ✅ **App Store Connect API Key** - For automated TestFlight uploads

---

## Initial Setup (One-Time)

### Step 1: Create App Store Connect API Key

This is the **recommended approach** - no Apple ID credentials stored in CI/CD.

**In App Store Connect:**

1. Navigate to **Users and Access** → **Keys** (left sidebar)
2. Click **Generate API Key** (if you don't see it, contact team admin)
3. **Select role**: "App Manager" (can manage builds and TestFlight)
4. Give it a name: `OpenCode CI/CD`
5. Click **Generate**
6. **IMPORTANT**: Download the `.p8` file immediately (you'll only see it once)
7. Save these values:
   - **Key ID** (shown in the UI)
   - **Issuer ID** (shown in the UI)
   - **Private Key File** (`.p8` downloaded)

**Keep these secure** - they grant access to upload builds to your app.

### Step 2: Export Distribution Certificate

**In Xcode (on your Mac):**

1. Open **Xcode** → **Settings** → **Accounts**
2. Select your Apple ID, then click **Manage Certificates**
3. Find "Apple Distribution" certificate for the team
4. Right-click → **Export Certificate**
5. Save as `distribution_cert.p12` with a strong password
6. Remember the password you use

**In Terminal** (prepare for GitHub Secrets):

```bash
# Base64 encode the certificate for GitHub Secrets
base64 -i distribution_cert.p12 -o cert.p12.base64

# Store the password securely (you'll need it for secrets)
echo "your-certificate-password" > /tmp/cert_password.txt
```

### Step 3: Ensure App Store Provisioning Profile

**In Apple Developer Portal:**

1. Go to **Certificates, IDs & Profiles** → **Profiles**
2. Create or verify you have a profile for:
   - **App ID**: com.agentic-codeflow.opencode-nexus
   - **Type**: App Store
   - **Certificates**: Includes your Distribution certificate
3. Download the profile (`.mobileprovision`)
4. Name it: `OpenCodeNexus_AppStore.mobileprovision`

**In Terminal** (prepare for GitHub Secrets):

```bash
# Base64 encode the provisioning profile
base64 -i OpenCodeNexus_AppStore.mobileprovision -o profile.mobileprovision.base64
```

### Step 4: Encode API Key for GitHub Secrets

**In Terminal:**

```bash
# Base64 encode your .p8 API key file
base64 -i AuthKey_KEYID.p8 -o authkey.p8.base64

# Or use this if you have a key file without the prefix:
base64 -i api_key.p8 -o authkey.p8.base64
```

---

## GitHub Secrets Configuration

Now add all the secrets to your GitHub repository using `gh cli`:

### Option A: Using `gh` CLI (Recommended - faster)

```bash
# Navigate to your repository
cd opencode-nexus

# Set all required secrets
gh secret set APPLE_ID --body "your-apple-id@email.com"
gh secret set APPLE_TEAM_ID --body "PCJU8QD9FN"

# App Store Connect API (from Step 1)
gh secret set APP_STORE_CONNECT_API_KEY_ID --body "YOUR_KEY_ID"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "YOUR_ISSUER_ID"
gh secret set APP_STORE_CONNECT_API_PRIVATE_KEY < authkey.p8.base64

# Code signing certificate (from Step 2)
gh secret set IOS_CERTIFICATE_P12 < cert.p12.base64
gh secret set IOS_CERTIFICATE_PASSWORD --body "your-certificate-password"

# Provisioning profile (from Step 3)
gh secret set IOS_PROVISIONING_PROFILE < profile.mobileprovision.base64

# Verify all secrets are configured
gh secret list
```

### Option B: Using GitHub Web UI

If you prefer the web interface:

1. Go to your repository on GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret listed in the table below

### Required Secrets Checklist

| Secret Name | Source | Safe? |
|------------|--------|-------|
| `APPLE_ID` | Your Apple ID email | ✅ Non-sensitive |
| `APPLE_TEAM_ID` | Apple Developer account | ✅ Public |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect → Keys | ✅ Non-sensitive (ID only) |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect → Keys | ✅ UUID, non-sensitive |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | App Store Connect → Download `.p8` | 🔐 **KEEP SECURE** - grants API access |
| `IOS_CERTIFICATE_P12` | Xcode → Export certificate (Base64) | 🔐 **KEEP SECURE** - code signing certificate |
| `IOS_CERTIFICATE_PASSWORD` | Password you set during export | 🔐 **KEEP SECURE** |
| `IOS_PROVISIONING_PROFILE` | Developer Portal → Profiles (Base64) | 🔐 **KEEP SECURE** - app provisioning |

**Security Note**: Never commit these secrets to version control. GitHub hides secret values in logs, but be cautious when troubleshooting.

---

## Release Process

### Automatic Release (Recommended)

Push a tag to trigger the workflow automatically:

```bash
# Increment version number (update first in version tracking)
# Example: 1.0.0 → 1.0.1

# Create and push tag
git tag -a ios-v1.0.1 -m "Release 1.0.1 to TestFlight"
git push origin ios-v1.0.1
```

The tag naming convention:
- **`ios-v*.*.*`** - iOS-specific release (e.g., `ios-v1.0.1`)
- **`v*.*.*`** - General release (will build iOS if on main, also Android/Desktop)

### Manual Release (Advanced)

If you want to build without pushing a tag:

1. Go to **Actions** → **iOS TestFlight Release** (in GitHub UI)
2. Click **Run workflow**
3. Enter optional tag name (e.g., `ios-v1.0.1`)
4. Toggle **Upload to TestFlight** (default: true)
5. Click **Run workflow**

### What Happens During the Build

1. **Checkout code** - Latest from your branch/tag
2. **Setup environment** - Xcode 15.4, Rust for iOS, Bun
3. **Build frontend** - Astro production build
4. **Build backend** - Tauri iOS app (Rust → iOS)
5. **Code signing** - Configure keychain with certificate from secrets
6. **Archive** - Create `.xcarchive` from the built app
7. **Export IPA** - Convert archive to App Store-ready IPA
8. **Upload TestFlight** - Send IPA to App Store Connect
9. **Create release** - Add IPA to GitHub releases (if tag push)
10. **Notify** - Add build summary to workflow

**Estimated time**: 15-20 minutes

---

## Monitoring Builds

### During Build (GitHub Actions)

1. Go to **Actions** tab in your GitHub repository
2. Click **iOS TestFlight Release** workflow
3. Select the latest run
4. Watch real-time logs as each step executes

**Key milestones to watch:**
- ✅ Frontend build successful
- ✅ iOS build successful
- ✅ Archive created
- ✅ IPA exported
- ✅ Uploaded to TestFlight

### After Build Completes

1. **Check App Store Connect**:
   - Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Select "OpenCode Nexus"
   - Go to **TestFlight** tab
   - Look for "iOS Builds" section
   - New build should appear within 5-10 minutes

2. **Build Processing**:
   - Status will show "Processing" initially
   - Then "Waiting for Review" (automated checks)
   - Finally "Ready to Test" when approved

3. **Invite Internal Testers**:
   - Click the build in TestFlight
   - Add internal testers or test groups
   - They'll receive invitation via email

---

## Troubleshooting

### Common Errors

#### ❌ "Code signing failed"

**Symptoms**: Build fails with code signing errors

**Causes**:
- Certificate is expired
- Wrong certificate/provisioning profile
- Secrets not properly base64 encoded
- Keychain issues in CI/CD environment

**Solutions**:
1. Verify certificate is valid: `security find-certificate -c "Apple Distribution"`
2. Check provisioning profile hasn't expired in Apple Developer portal
3. Re-export certificate and profile
4. Update GitHub secrets with new values
5. Check logs for specific codesign error: `codesign: ...: Error...`

#### ❌ "TestFlight upload failed"

**Symptoms**: IPA generated but upload to TestFlight fails

**Causes**:
- App Store Connect API key invalid or expired
- API key doesn't have required permissions
- IPA format incorrect
- Bundle ID mismatch

**Solutions**:
1. Verify API key in App Store Connect hasn't been revoked
2. Check API key has "App Manager" or admin role
3. Run build with `--verbose` flag to see upload details
4. Check IPA is for correct bundle ID: `unzip -l app.ipa | grep "Payload"`
5. Try uploading manually using Transporter app

**Verify API Key**:
```bash
# In your terminal, check if the key file is valid
file ~/Downloads/AuthKey_XXXXX.p8
cat ~/Downloads/AuthKey_XXXXX.p8 | head -5
# Should show "-----BEGIN PRIVATE KEY-----"
```

#### ❌ "Provisioning profile not found"

**Symptoms**: Xcode export fails - "No provisioning profile found"

**Causes**:
- Profile name doesn't match Xcode configuration
- Profile expired
- Profile not for correct bundle ID

**Solutions**:
1. Check `ExportOptions.plist` has correct profile name
2. Verify profile in Apple Developer portal is valid
3. Re-download profile and re-encode for GitHub Secrets
4. Update `IOS_PROVISIONING_PROFILE` secret with new profile

#### ❌ "Keychain timeout"

**Symptoms**: Workflow hangs or times out during code signing

**Causes**:
- Keychain password incorrect
- Keychain operations timing out
- Secret not properly decoded

**Solutions**:
1. Verify `IOS_CERTIFICATE_PASSWORD` is correct
2. Check certificate is properly base64 encoded
3. Increase timeout in workflow if needed
4. Review keychain debug logs in workflow output

### Debug Mode

To get more detailed output:

```bash
# In the workflow, add debug logging:
env:
  RUST_LOG: debug
  # Add this for more verbose output
  VERBOSE: 1
```

Or check the **raw logs** in GitHub Actions:
1. Go to **Actions** → workflow run
2. Click any step
3. Look for detailed error messages

### Manual Test Build

To test code signing locally before pushing:

```bash
# Build locally first
cd src-tauri
cargo tauri ios build --release

# Try archiving
xcodebuild -project gen/apple/src-tauri.xcodeproj \
  -scheme src-tauri_iOS \
  -configuration Release \
  -archivePath build/OpenCodeNexus.xcarchive \
  archive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/OpenCodeNexus.xcarchive \
  -exportOptionsPlist gen/apple/ExportOptions.plist \
  -exportPath build/ipa
```

---

## Manual Release (Fallback)

If the automated workflow fails, you can still release manually:

### Using Xcode (GUI)

1. **Build in Xcode**:
   - Open `src-tauri/gen/apple/src-tauri.xcodeproj`
   - Select "src-tauri_iOS" scheme
   - Select "Generic iOS Device" in build target
   - Product → Archive
   - Select archive when complete

2. **Export for App Store**:
   - Organizer window opens after archive
   - Select archive → Click "Distribute App"
   - Choose "App Store Connect"
   - Follow prompts

### Using Command Line

```bash
cd src-tauri/gen/apple

# Archive
xcodebuild \
  -project src-tauri.xcodeproj \
  -scheme src-tauri_iOS \
  -configuration Release \
  -archivePath build/OpenCodeNexus.xcarchive \
  archive

# Export
xcodebuild \
  -exportArchive \
  -archivePath build/OpenCodeNexus.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/ipa \
  -allowProvisioningUpdates

# Upload with Transporter (Apple's modern tool)
# Install: Download from App Store
open /Applications/Transporter.app

# Or use xcrun altool (deprecated but still works)
xcrun altool \
  --upload-app \
  --type ios \
  --file "build/ipa/OpenCode Nexus.ipa" \
  --apiKey "YOUR_KEY_ID" \
  --apiIssuer "YOUR_ISSUER_ID" \
  --apiKeysDir "~/Keys"
```

### Upload Using Transporter App

1. Download **Transporter** from App Store
2. Open Transporter app
3. Sign in with Apple ID
4. Drag and drop IPA file into Transporter window
5. Click "Deliver"
6. Monitor progress and wait for completion

---

## Release Checklist

Before each release, verify:

- [ ] Version number bumped in `src-tauri/Cargo.toml` and `frontend/package.json`
- [ ] Changelog updated (`CHANGELOG.md`)
- [ ] All tests passing locally (`cargo test && cd frontend && bun test`)
- [ ] Code review completed
- [ ] Branch merged to main (if required)
- [ ] No security vulnerabilities (`cargo audit`, `bun audit`)
- [ ] All secrets configured in GitHub
- [ ] Documentation updated if needed

---

## Support & Questions

If you encounter issues:

1. **Check logs** - GitHub Actions provides detailed output
2. **Review this guide** - Troubleshooting section covers common errors
3. **Apple Developer Support** - For App Store Connect issues
4. **Team Slack** - Ask team members for help
5. **Documentation** - See `/docs/client/` for architecture details

---

**Last updated**: November 10, 2025
**Workflow version**: 1.0
**iOS target**: iOS 14.0+
**Xcode version**: 15.4
**Rust target**: aarch64-apple-ios
