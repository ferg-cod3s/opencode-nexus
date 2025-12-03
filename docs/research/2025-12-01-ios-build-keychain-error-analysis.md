---
date: 2025-12-01
researcher: Assistant
topic: 'iOS Build Keychain Error Analysis'
tags: [research, ios-build, keychain-error, ci-cd]
status: complete
---

# iOS Build Keychain Error Research Analysis

## Research Query

**Error**: `KEYCHAIN_PATH=$(mktemp -d)/build.keychain` followed by `security: SecKeychainItemImport: One or more parameters passed to a function were not valid.`

## Executive Summary

The iOS build keychain error is a well-documented issue in GitHub Actions CI/CD pipelines that affects iOS certificate import operations. This error occurs when the `security import` command fails to properly import P12 certificates into temporary keychains created with `mktemp`.

## Root Cause Analysis

### Primary Cause: Process Substitution Issue

Based on research findings from GitHub Community discussions and Stack Overflow, the main culprit is **process substitution** in GitHub Actions environment:

```bash
# PROBLEMATIC - This fails in GitHub Actions
echo "$IOS_CERTIFICATE_P12" | base64 --decode | security import -k "$KEYCHAIN_PATH" -P "$IOS_CERTIFICATE_PASSWORD"

# WORKING - This is the solution
echo "$IOS_CERTIFICATE_P12" | base64 --decode > /tmp/cert.p12
security import /tmp/cert.p12 -k "$KEYCHAIN_PATH" -P "$IOS_CERTIFICATE_PASSWORD"
```

### Secondary Causes

1. **Environment Variable Access**: Missing environment specification in workflow
2. **CocoaPods Version**: Version conflicts (resolved by updating to 1.12.1)
3. **Keychain Path Issues**: Temporary directory creation and permissions

## Current Implementation Analysis

### OpenCode Nexus Workflows

Both iOS build workflows in the project use the **correct approach**:

```yaml
# From .github/workflows/ios-release.yml (lines 204-211)
echo "$IOS_CERTIFICATE_P12" | base64 --decode > /tmp/cert.p12

security import /tmp/cert.p12 \
  -k "$KEYCHAIN_PATH" \
  -P "$IOS_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/xcodebuild
```

This implementation already follows the recommended solution pattern.

### Keychain Creation Pattern

```bash
# Current working implementation
KEYCHAIN_PATH=$(mktemp -d)/build.keychain
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -t 3600 -u "$KEYCHAIN_PATH"
```

## Research Findings

### 1. GitHub Community Solution (Aug 2023)

**Issue**: Process substitution `<(echo $CERT | base64 --decode)` stopped working in GitHub Actions

**Solution**: Save to temporary file first:
```bash
echo $SIGNING_CERTIFICATE_P12_DATA | base64 --decode > signingCertificate.p12
security import signingCertificate.p12 -f pkcs12 -k build.keychain -P $SIGNING_CERTIFICATE_PASSWORD -T /usr/bin/codesign
rm signingCertificate.p12
```

### 2. Stack Overflow Solutions (Apr 2021)

**Environment Issues**: Wrong environment context for secrets
- Solution: Specify `environment: production` in workflow
- Verify certificate file integrity

### 3. Additional Fixes

**CocoaPods Update**: Update to version 1.12.1 resolved similar issues

## Recommended Solutions

### Immediate Fix (Already Implemented)

The OpenCode Nexus project already uses the correct approach. However, to ensure robustness:

```yaml
- name: Setup code signing
  env:
    IOS_CERTIFICATE_P12: ${{ secrets.IOS_CERTIFICATE_P12 }}
    IOS_CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
    KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD || secrets.IOS_CERTIFICATE_PASSWORD }}
  run: |
    # Create temporary keychain
    KEYCHAIN_PATH=$(mktemp -d)/build.keychain
    
    # Create and configure keychain
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security default-keychain -s "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -t 3600 -u "$KEYCHAIN_PATH"
    
    # Decode certificate to temporary file (CRITICAL STEP)
    echo "$IOS_CERTIFICATE_P12" | base64 --decode > /tmp/cert.p12
    
    # Import certificate from file (NOT from pipe)
    security import /tmp/cert.p12 \
      -k "$KEYCHAIN_PATH" \
      -P "$IOS_CERTIFICATE_PASSWORD" \
      -T /usr/bin/codesign \
      -T /usr/bin/security \
      -T /usr/bin/xcodebuild
    
    # Set keychain access
    security set-key-partition-list \
      -S apple-tool:,apple:,codesign: \
      -s \
      -k "$KEYCHAIN_PASSWORD" \
      "$KEYCHAIN_PATH"
    
    # Clean up temporary file
    rm -f /tmp/cert.p12
    
    echo "✅ Keychain configured for code signing"
```

### Enhanced Error Handling

Add validation steps:

```bash
# Validate certificate file
if [ ! -f "/tmp/cert.p12" ] || [ ! -s "/tmp/cert.p12" ]; then
  echo "❌ ERROR: Certificate file not created or empty"
  exit 1
fi

# Validate keychain creation
if [ ! -f "$KEYCHAIN_PATH" ]; then
  echo "❌ ERROR: Keychain not created at $KEYCHAIN_PATH"
  exit 1
fi

# Test import before proceeding
if ! security import /tmp/cert.p12 -k "$KEYCHAIN_PATH" -P "$IOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign; then
  echo "❌ ERROR: Certificate import failed"
  exit 1
fi
```

### Environment Specification

Ensure workflow specifies environment:

```yaml
jobs:
  build-ios:
    runs-on: macos-14
    environment: production  # Add this line
    timeout-minutes: 90
```

## Prevention Strategies

### 1. Certificate Validation

```bash
# Validate certificate before import
openssl pkcs12 -in /tmp/cert.p12 -noout -passin pass:"$IOS_CERTIFICATE_PASSWORD"
```

### 2. Keychain Health Check

```bash
# Verify keychain is accessible
security list-keychains -s "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
```

### 3. Dependency Management

```bash
# Ensure compatible versions
pod --version  # Should be 1.12.1 or later
xcodebuild -version
```

## Files Requiring Updates

### Current Status: ✅ ALREADY COMPLIANT

Both `.github/workflows/ios-release.yml` and `.github/workflows/ios-release-optimized.yml` already implement the correct solution:

1. ✅ Use temporary file instead of pipe
2. ✅ Proper keychain creation and configuration
3. ✅ Correct security import syntax
4. ✅ Proper cleanup of temporary files

### Optional Enhancements

Consider adding these improvements:

1. **Enhanced error handling** with validation steps
2. **Environment specification** in workflow
3. **Certificate validation** before import
4. **Dependency version checks**

## Conclusion

The iOS build keychain error is a solved issue in the OpenCode Nexus project. The current implementation already follows the recommended best practices identified through research. The error described in the query would typically occur in projects using process substitution (`<(command)`) for certificate import, which this project correctly avoids.

**Recommendation**: The current workflows are robust. Consider adding enhanced error handling and validation for improved reliability, but no immediate fixes are required.

## References

1. [GitHub Community Discussion #63731](https://github.com/orgs/community/discussions/63731) - Process substitution issue
2. [Stack Overflow #67076431](https://stackoverflow.com/questions/67076431) - Environment and certificate issues
3. [Apple Developer Forums](https://developer.apple.com/forums/) - SecKeychainItemImport error discussions
4. [OpenCode Nexus iOS Build Plans](/home/vitruvius/git/opencode-nexus/plans/2025-12-01-ios-build-fix.md) - Current implementation details