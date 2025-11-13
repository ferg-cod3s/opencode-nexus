# iOS Release Checklist

Use this checklist before each iOS release to TestFlight.

## Pre-Release (1 day before)

### Code Review
- [ ] All changes merged to main
- [ ] Pull requests approved and merged
- [ ] No failing tests in CI/CD
- [ ] Code quality checks passing (linting, type checking)
- [ ] Security scan completed (no vulnerabilities)

### Documentation
- [ ] Changelog updated with new features/fixes
- [ ] README updated if needed
- [ ] API documentation updated if applicable
- [ ] Known issues documented

### Testing
- [ ] Manual testing completed on device
- [ ] Edge cases tested
- [ ] Accessibility compliance verified (WCAG 2.2 AA)
- [ ] Performance acceptable on older devices
- [ ] Offline functionality tested

### Version & Metadata
- [ ] Version number bumped in `src-tauri/Cargo.toml`
- [ ] Version number bumped in `frontend/package.json`
- [ ] Build number incremented if needed
- [ ] Release notes prepared for TestFlight

## Release Day

### Final Checks
- [ ] No active branches being merged
- [ ] Latest code pulled from main
- [ ] All dependencies up to date (`cargo update`, `bun install`)
- [ ] Local build succeeds: `cargo tauri build --target aarch64-apple-ios`
- [ ] No uncommitted changes: `git status` shows clean

### GitHub Secrets Verification
```bash
# Verify all 8 secrets are configured
gh secret list
```

Checklist:
- [ ] `APPLE_ID` set
- [ ] `APPLE_TEAM_ID` set (PCJU8QD9FN)
- [ ] `APP_STORE_CONNECT_API_KEY_ID` set
- [ ] `APP_STORE_CONNECT_ISSUER_ID` set
- [ ] `APP_STORE_CONNECT_API_PRIVATE_KEY` set
- [ ] `IOS_CERTIFICATE_P12` set
- [ ] `IOS_CERTIFICATE_PASSWORD` set
- [ ] `IOS_PROVISIONING_PROFILE` set

### Release Tag Creation
```bash
# Create annotated tag
git tag -a ios-v1.X.X -m "Release 1.X.X to TestFlight"

# Example versions:
# ios-v1.0.0      (Production release)
# ios-v1.0.1      (Bug fix)
# ios-v1.1.0      (Feature release)
# ios-v1.0.0-beta (Beta release)
# ios-v1.0.0-rc   (Release candidate)

# Push tag to trigger workflow
git push origin ios-v1.X.X
```

**Don't forget**: Push the tag, not just the code

### Monitor Build
- [ ] GitHub Actions workflow triggered (check [Actions](../../actions) tab)
- [ ] Build starts within 1-2 minutes
- [ ] All steps complete successfully:
  - [ ] Checkout
  - [ ] Setup environment
  - [ ] Install dependencies
  - [ ] Build frontend
  - [ ] Build iOS app
  - [ ] Code signing
  - [ ] Archive app
  - [ ] Export IPA
  - [ ] Upload to TestFlight
  - [ ] Create GitHub release
  - [ ] Build summary posted

**Build time**: ~15-20 minutes

### Verify TestFlight Build
- [ ] Check [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Navigate to OpenCode Nexus app → TestFlight
- [ ] New build appears in "iOS Builds" section within 10 minutes
- [ ] Build status shows "Processing" then "Waiting for Review"
- [ ] Build eventually shows "Ready to Test" (usually within 30 minutes)

### Add Testers
- [ ] Invite internal testers to new build
- [ ] Add to test groups (if using groups)
- [ ] Send test invitations
- [ ] Update team about availability

## Post-Release (Within 48 hours)

### Gather Feedback
- [ ] Internal testers have had access for at least 24 hours
- [ ] Collect feedback on functionality
- [ ] Monitor for crash reports
- [ ] Note any blocking issues

### Verify Stability
- [ ] No critical crashes reported
- [ ] Features working as expected
- [ ] Performance acceptable
- [ ] No regressions from previous version

### Document Results
- [ ] Create issue for any bugs found
- [ ] Close any release-related issues
- [ ] Update status in TODO.md
- [ ] Announce release to team

## Troubleshooting During Release

### Build Fails
1. Check GitHub Actions logs for specific error
2. See [IOS_RELEASE.md - Troubleshooting](./IOS_RELEASE.md#troubleshooting)
3. Common issues:
   - [ ] Code signing error → Check certificate/profile validity
   - [ ] Build error → Check Rust compilation
   - [ ] Archive error → Check Xcode compatibility
   - [ ] Export error → Check ExportOptions.plist

### TestFlight Upload Fails
1. Verify IPA was generated successfully
2. Check App Store Connect API key validity
3. See [IOS_RELEASE.md - Troubleshooting](./IOS_RELEASE.md#troubleshooting)

### Build Hangs or Times Out
1. Cancel workflow in GitHub Actions
2. Review logs for where it got stuck
3. Check for network issues
4. Retry from beginning

## Rollback Plan

If a released version has critical issues:

### Immediate Actions
1. [ ] Notify team and testers immediately
2. [ ] Remove from TestFlight if possible
3. [ ] Post incident summary

### Create Hotfix
```bash
# Create hotfix branch from last good tag
git checkout -b hotfix/critical-issue ios-v1.X.X

# Fix the issue
# Test thoroughly
# Merge to main

# Create new release tag
git tag -a ios-v1.X.Y -m "Hotfix release"
git push origin ios-v1.X.Y
```

### Communicate
- [ ] Explain issue and fix to testers
- [ ] Release hotfix version
- [ ] Follow standard release process

## Release Notes Template

When creating release, include these details:

```markdown
## OpenCode Nexus iOS v1.X.X

### New Features
- List new features added

### Bug Fixes
- List bugs fixed

### Improvements
- Performance improvements
- UI/UX improvements
- Accessibility improvements

### Known Issues
- List any known issues
- Provide workarounds if available

### Requirements
- iOS 14.0 or later
- Recommended: Latest iOS version

### Contributors
- List contributors

### TestFlight Notes
- Internal testing version
- Expected release to App Store: [date]
```

## Automation Summary

This process is mostly automated:
- ✅ **Build**: GitHub Actions (automatic on tag push)
- ✅ **Code Signing**: Automated with GitHub Secrets
- ✅ **TestFlight Upload**: Automated via App Store Connect API
- ✅ **GitHub Release**: Automated with IPA artifact
- ⏳ **Tester Invites**: Manual (TestFlight UI)
- ⏳ **App Store Release**: Manual (requires TestFlight review)

Typical timeline:
- `git push tag` → Build starts (within 1-2 min)
- Build completes (15-20 min)
- Build appears in TestFlight (5-10 min)
- Ready to test (within 30 min total)
- Can invite testers immediately

---

## Sign-Off

**Release Version**: ios-v______

**Released By**: _________________ (Name)

**Date**: ________________________

**Notes**:
```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

**Reference**:
- [iOS Release Guide](./IOS_RELEASE.md)
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md)
- [Deployment README](./README.md)
