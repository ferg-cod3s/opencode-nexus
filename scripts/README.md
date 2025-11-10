# Deployment Scripts

Automation scripts for version management and TestFlight deployment.

## Quick Start

### 1. Bump Version & Deploy

```bash
# Bump patch version (0.1.2 → 0.1.3) and deploy to TestFlight
npm run release
```

This single command will:
1. Bump patch version in all files
2. Commit the version change
3. Build iOS release
4. Upload to TestFlight

### 2. Manual Version Bumping

```bash
# Bump patch version (0.1.2 → 0.1.3)
npm run version:patch

# Bump minor version (0.1.2 → 0.2.0)
npm run version:minor

# Bump major version (0.1.2 → 1.0.0)
npm run version:major

# Set specific version
node scripts/bump-version.js 1.2.3
```

### 3. Build Only

```bash
# Build iOS IPA without uploading
npm run build:ios
```

### 4. Upload Only

```bash
# Upload existing IPA to TestFlight (skip build)
npm run deploy:testflight:quick
```

## Setup

### Option 1: App Store Connect API Key (Recommended)

1. Go to [App Store Connect API Keys](https://appstoreconnect.apple.com/access/api)
2. Create new API Key with **"App Manager"** role
3. Download the `.p8` file
4. Set environment variables:

```bash
export APPLE_API_KEY_ID="ABC123XYZ"
export APPLE_API_ISSUER_ID="abc-123-xyz-456"
export APPLE_API_KEY_PATH="/path/to/AuthKey_ABC123XYZ.p8"
```

**Tip**: Add these to your `~/.zshrc` or `~/.bashrc` for persistence.

### Option 2: App-Specific Password

1. Go to [Apple ID Account](https://appleid.apple.com/account/manage)
2. Generate app-specific password
3. Set environment variables:

```bash
export APPLE_ID="your@email.com"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

## Scripts Overview

### `bump-version.js`

Updates version in all three files consistently:
- `src-tauri/tauri.conf.json`
- `package.json`
- `src-tauri/Cargo.toml`

**Usage:**
```bash
node scripts/bump-version.js patch   # 0.1.2 → 0.1.3
node scripts/bump-version.js minor   # 0.1.2 → 0.2.0
node scripts/bump-version.js major   # 0.1.2 → 1.0.0
node scripts/bump-version.js 1.2.3   # Set specific version
```

### `deploy-testflight.sh`

Builds iOS IPA and uploads to TestFlight.

**Usage:**
```bash
# Full deployment (build + upload)
./scripts/deploy-testflight.sh

# Build only (skip upload)
./scripts/deploy-testflight.sh --skip-upload

# Upload only (skip build, use existing IPA)
./scripts/deploy-testflight.sh --skip-build

# Show help
./scripts/deploy-testflight.sh --help
```

## Troubleshooting

### Authentication Errors

**Error**: `App Store Connect API key not found`
- Verify `APPLE_API_KEY_PATH` points to valid `.p8` file
- Check file permissions: `chmod 600 /path/to/AuthKey_*.p8`

**Error**: `Invalid credentials`
- Verify API Key ID and Issuer ID are correct
- For app-specific password, regenerate if needed

### Build Errors

**Error**: `Xcode Command Line Tools not found`
```bash
xcode-select --install
```

**Error**: `iOS target not found`
```bash
rustup target add aarch64-apple-ios
```

**Error**: `CocoaPods not found`
```bash
sudo gem install cocoapods
```

### Upload Errors

**Error**: `App validation failed`
- Check bundle identifier matches App Store Connect
- Verify provisioning profile is valid
- Ensure version number is higher than current TestFlight build

**Error**: `IPA not found`
- Run build first: `npm run build:ios`
- Check path: `src-tauri/gen/apple/build/OpenCode Nexus.ipa`

## npm Scripts Reference

| Script | Description |
|--------|-------------|
| `npm run version:patch` | Bump patch version (0.1.2 → 0.1.3) |
| `npm run version:minor` | Bump minor version (0.1.2 → 0.2.0) |
| `npm run version:major` | Bump major version (0.1.2 → 1.0.0) |
| `npm run build:ios` | Build iOS IPA (no upload) |
| `npm run deploy:testflight` | Full deployment (build + upload) |
| `npm run deploy:testflight:quick` | Upload existing IPA (no build) |
| `npm run release` | Bump patch + commit + deploy |

## CI/CD Integration

To use in CI/CD (GitHub Actions, GitLab CI, etc.):

```yaml
# Example GitHub Actions workflow
- name: Deploy to TestFlight
  env:
    APPLE_API_KEY_ID: ${{ secrets.APPLE_API_KEY_ID }}
    APPLE_API_ISSUER_ID: ${{ secrets.APPLE_API_ISSUER_ID }}
    APPLE_API_KEY_PATH: ${{ secrets.APPLE_API_KEY_PATH }}
  run: npm run deploy:testflight
```

## Post-Upload Steps

After successful upload:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **TestFlight** tab
3. Wait for processing (5-15 minutes)
4. Add build to testing group
5. Invite testers or share public link

## Version Sync

All three files are kept in sync:
- ✅ `src-tauri/tauri.conf.json` - Tauri app version
- ✅ `package.json` - npm package version
- ✅ `src-tauri/Cargo.toml` - Rust crate version

Current version: **0.1.2**

## Additional Resources

- [Tauri iOS Build Guide](https://tauri.app/v2/guides/distribute/ios/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
