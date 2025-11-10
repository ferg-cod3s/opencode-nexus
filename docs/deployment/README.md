# Deployment Documentation

This directory contains guides for deploying OpenCode Nexus across platforms.

## Guides

### 📱 iOS TestFlight Release
- **[IOS_RELEASE.md](./IOS_RELEASE.md)** - Complete iOS release process
  - Prerequisites and one-time setup
  - GitHub secrets configuration
  - Automated release workflow
  - Monitoring and troubleshooting
  - Manual fallback procedures

- **[GITHUB_SECRETS_SETUP.md](./GITHUB_SECRETS_SETUP.md)** - Quick reference for `gh cli` secrets setup
  - One-time setup commands
  - Base64 encoding helpers
  - Verification steps
  - Troubleshooting secrets

## Quick Start: iOS Release

### 1. Initial Setup (One-Time)
```bash
# Create App Store Connect API Key in Apple Developer account
# Export Distribution Certificate from Xcode
# Download App Store Provisioning Profile
# Base64 encode all files

# See IOS_RELEASE.md Step 1-4 for detailed instructions
```

### 2. Configure GitHub Secrets
```bash
gh secret set APPLE_ID --body "your-apple@email.com"
gh secret set APPLE_TEAM_ID --body "PCJU8QD9FN"
gh secret set APP_STORE_CONNECT_API_KEY_ID --body "YOUR_KEY_ID"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "YOUR_ISSUER_ID"
gh secret set APP_STORE_CONNECT_API_PRIVATE_KEY < authkey.p8.base64
gh secret set IOS_CERTIFICATE_P12 < cert.p12.base64
gh secret set IOS_CERTIFICATE_PASSWORD --body "cert-password"
gh secret set IOS_PROVISIONING_PROFILE < profile.mobileprovision.base64

# Verify
gh secret list
```

### 3. Release to TestFlight
```bash
# Automatic: Push a tag
git tag -a ios-v1.0.0 -m "Release 1.0.0"
git push origin ios-v1.0.0

# The GitHub Actions workflow will:
# ✅ Build iOS app
# ✅ Generate IPA
# ✅ Upload to TestFlight
# ✅ Create GitHub release
# ✅ Monitor build processing

# Estimated time: 15-20 minutes
```

### 4. Monitor Build
1. Go to [GitHub Actions](../../actions) → iOS TestFlight Release
2. Watch the build progress in real-time
3. Check [App Store Connect](https://appstoreconnect.apple.com) for TestFlight build status
4. Add internal testers in TestFlight after build is "Ready to Test"

## Workflow Details

### iOS Release Workflow (`.github/workflows/ios-release.yml`)

**Triggers:**
- Automatic: Push `ios-v*` or `v*` tags
- Manual: GitHub Actions → Run workflow with options

**Jobs:**
1. **Setup** - Install Xcode 15.4, Rust iOS targets, Bun
2. **Dependencies** - Install frontend and backend dependencies
3. **Build** - Build Astro frontend + Tauri iOS app
4. **Code Signing** - Import certificate and provisioning profile from secrets
5. **Archive** - Create Xcode archive
6. **Export** - Generate App Store-ready IPA
7. **Upload** - Send IPA to TestFlight via App Store Connect API
8. **Release** - Create GitHub release with IPA artifact
9. **Notify** - Post build summary to GitHub

**Artifacts:**
- `.ipa` file uploaded to GitHub Releases
- Build logs available in GitHub Actions
- Notifications in workflow summary

## Other Platforms

Future documentation for:
- [ ] Android (Google Play Console)
- [ ] macOS (direct distribution)
- [ ] Windows (MSIX distribution)
- [ ] Web (static hosting)

## Troubleshooting

### Build Fails
1. Check logs in GitHub Actions
2. Review [IOS_RELEASE.md - Troubleshooting](./IOS_RELEASE.md#troubleshooting)
3. Verify secrets are configured (see [GITHUB_SECRETS_SETUP.md](./GITHUB_SECRETS_SETUP.md))
4. Ensure certificates haven't expired

### TestFlight Upload Fails
- Verify App Store Connect API key is valid and has "App Manager" role
- Check IPA format is correct
- Ensure bundle ID matches: `com.agentic-codeflow.opencode-nexus`
- Try manual upload using Transporter app (fallback)

### Secrets Not Working
1. Verify all 8 required secrets are configured: `gh secret list`
2. Re-check base64 encoding of binary files
3. Ensure no extra whitespace in secret values
4. See [GITHUB_SECRETS_SETUP.md - Troubleshooting](./GITHUB_SECRETS_SETUP.md#troubleshooting)

## Security Considerations

### Secret Management
- ✅ Never commit secrets to version control
- ✅ Use GitHub Actions Secrets (encrypted, masked in logs)
- ✅ API keys can be rotated without rebuilding
- ✅ Certificates valid for 12 months - set renewal reminders

### Code Signing
- ✅ Distribution certificates stored securely in GitHub Secrets
- ✅ Keychain created fresh for each build (temporary)
- ✅ Private keys never stored permanently in CI/CD
- ✅ Provisioning profiles validated before each build

### API Access
- ✅ App Store Connect API key has "App Manager" role (minimum required)
- ✅ API key can be revoked in App Store Connect at any time
- ✅ API key is specific to OpenCode Nexus app (not global)

## Release Schedule

Recommended release cadence:
- **Alpha**: Weekly (ios-v1.0.0-alpha)
- **Beta**: Every 2 weeks (ios-v1.0.0-beta.1)
- **Production**: Every 4 weeks (ios-v1.0.0)

Each release triggers automated workflow:
- Builds in ~20 minutes
- Available in TestFlight in ~10 minutes
- Can be released to production 24 hours after submission

## Automation Status

| Component | Status | Notes |
|-----------|--------|-------|
| iOS Build | ✅ Automated | Via GitHub Actions on tag push |
| TestFlight Upload | ✅ Automated | App Store Connect API |
| GitHub Release | ✅ Automated | IPA attached as artifact |
| Build Notifications | ✅ Automated | GitHub Actions summary |
| Test Release | ✅ Manual | Manual invite in TestFlight |
| App Store Release | ⏳ Manual | Requires TestFlight review approval |

## Resources

- [iOS Release Guide](./IOS_RELEASE.md) - Complete process documentation
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md) - `gh cli` quick reference
- [Apple Developer](https://developer.apple.com) - Certificates and provisioning
- [App Store Connect](https://appstoreconnect.apple.com) - TestFlight management
- [GitHub Actions Docs](https://docs.github.com/en/actions) - Workflow reference

## Support

For issues or questions:
1. Check the troubleshooting sections in relevant guides
2. Review GitHub Actions logs for specific errors
3. Ask team members for help
4. Contact Apple Developer Support for account/certificate issues

---

**Last updated**: November 10, 2025
**Current iOS Version**: 1.0.0
**Minimum iOS**: 14.0
**Xcode Version**: 15.4
**API Version**: App Store Connect API v1
