# iOS Build Fix Plan for OpenCode Nexus

## 🎯 Executive Summary

This plan addresses critical iOS build failures in Xcode Cloud and enables reliable TestFlight deployment for OpenCode Nexus, a Tauri 2.x application using @opencode-ai/sdk.

## 🔍 Current Issues Identified

### 1. **Tauri 2.x Compatibility Problems**
- Outdated Tauri CLI installation pattern
- Missing iOS-specific dependencies
- Incorrect build command usage

### 2. **Code Signing Conflicts**
- Conflicting approaches between `--no-codesign` and manual signing
- Improper entitlements configuration
- Missing network permissions for @opencode-ai/sdk

### 3. **iOS Configuration Gaps**
- Incomplete Podfile configuration
- Missing ATS exceptions for OpenCode servers
- Outdated iOS dependency versions

### 4. **TestFlight Deployment Issues**
- Error-prone manual IPA normalization
- Incomplete App Store Connect API usage
- Missing validation steps

## 🛠 Step-by-Step Fix Plan

### Phase 1: Core Dependencies & Configuration (Priority: High)

#### Step 1.1: Update Cargo.toml iOS Dependencies
```toml
[target.'cfg(target_os = "ios")'.dependencies]
# Core iOS support
tauri-plugin-ios = "2.0"
mobile-entry-point = "1.0"

# Updated Objective-C bindings for compatibility
objc2 = "0.5"
objc2-ui-kit = "0.2"
objc2-foundation = "0.2"

# iOS-specific networking
tokio = { version = "1", features = ["rt-multi-thread", "macros", "sync", "time", "io-util", "net", "fs"] }
```

#### Step 1.2: Fix Tauri CLI Installation
```yaml
# Replace in .github/workflows/ios-release.yml (line 85)
- name: Install Tauri CLI
  run: cargo install tauri-cli@2.0.0 --locked
```

#### Step 1.3: Update iOS Build Command
```yaml
# Replace iOS build step (lines 159-177)
- name: Build iOS app (Tauri 2.x)
  run: |
    cd src-tauri
    echo "Building iOS app with Tauri 2.x..."
    
    # Build with proper iOS target and verbose output
    cargo tauri ios build \
      --release \
      --target aarch64-apple-ios \
      --verbose
  env:
    RUST_LOG: info
```

### Phase 2: Code Signing & Entitlements (Priority: High)

#### Step 2.1: Create Proper iOS Entitlements
Create `src-tauri/ios-config/src-tauri_iOS.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Group for data sharing -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.agentic-codeflow.opencode-nexus</string>
    </array>
    
    <!-- Network client permissions for @opencode-ai/sdk -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Team identifier -->
    <key>com.apple.developer.team-identifier</key>
    <string>PCJU8QD9FN</string>
    
    <!-- Distribution settings -->
    <key>get-task-allow</key>
    <false/>
    
    <!-- Keychain access -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.agentic-codeflow.opencode-nexus</string>
    </array>
</dict>
</plist>
```

#### Step 2.2: Update ExportOptions.plist
```xml
<!-- Enhanced ExportOptions.plist -->
<key>signingStyle</key>
<string>manual</string>  <!-- Changed from automatic -->

<key>provisioningProfiles</key>
<dict>
    <key>com.agentic-codeflow.opencode-nexus</key>
    <string>OpenCodeNexus_AppStore</string>
</dict>

<key>signingCertificate</key>
<string>Apple Distribution: John Ferguson (PCJU8QD9FN)</string>
```

#### Step 2.3: Fix Code Signing Workflow
```yaml
# Updated code signing step (lines 111-142)
- name: Setup iOS code signing
  env:
    IOS_CERTIFICATE_P12: ${{ secrets.IOS_CERTIFICATE_P12 }}
    IOS_CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
    DEVELOPMENT_TEAM: ${{ secrets.DEVELOPMENT_TEAM || 'PCJU8QD9FN' }}
  run: |
    # Create secure keychain
    KEYCHAIN_PATH="$RUNNER_TEMP/build.keychain"
    security create-keychain -p "$IOS_CERTIFICATE_PASSWORD" "$KEYCHAIN_PATH"
    security default-keychain -s "$KEYCHAIN_PATH"
    security unlock-keychain -p "$IOS_CERTIFICATE_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -t 3600 -u "$KEYCHAIN_PATH"
    
    # Import certificate
    echo "$IOS_CERTIFICATE_P12" | base64 --decode > /tmp/cert.p12
    security import /tmp/cert.p12 -k "$KEYCHAIN_PATH" -P "$IOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/xcodebuild
    
    # Configure keychain access
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$IOS_CERTIFICATE_PASSWORD" "$KEYCHAIN_PATH"
    
    # Verify certificate
    security find-identity -v -p codesigning "$KEYCHAIN_PATH"
```

### Phase 3: Network & SDK Configuration (Priority: High)

#### Step 3.1: Configure ATS for @opencode-ai/sdk
Update `tauri.ios.conf.json`:
```json
{
  "bundle": {
    "iOS": {
      "developmentTeam": "PCJU8QD9FN",
      "minimumSystemVersion": "14.0",
      "infoPlist": {
        "NSAppTransportSecurity": {
          "NSAllowsArbitraryLoads": false,
          "NSExceptionDomains": {
            "api.opencode.ai": {
              "NSExceptionAllowsInsecureHTTPLoads": false,
              "NSExceptionMinimumTLSVersion": "TLSv1.2",
              "NSExceptionRequiresForwardSecrecy": true
            },
            "opencode.ai": {
              "NSExceptionAllowsInsecureHTTPLoads": false,
              "NSExceptionMinimumTLSVersion": "TLSv1.2",
              "NSExceptionRequiresForwardSecrecy": true
            }
          }
        },
        "ITSAppUsesNonExemptEncryption": true,
        "NSCameraUsageDescription": "This app may use the camera for scanning QR codes and other features.",
        "NSMicrophoneUsageDescription": "This app may access the microphone for voice input features."
      }
    }
  }
}
```

#### Step 3.2: Update Podfile
Create `src-tauri/gen/apple/Podfile` (updated):
```ruby
platform :ios, '14.0'

target 'src-tauri_iOS' do
  use_frameworks!
  
  # iOS-specific pods for Tauri 2.x
  pod 'Tauri', :path => '../../node_modules/@tauri-apps/cli'
  
  # Network and security
  pod 'TrustKit', '~> 2.0'
  
  target 'src-tauri_iOSTests' do
    inherit! :search_paths
  end
end

# Post-install script for Xcode 15 compatibility
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'YES'
    end
  end
end
```

### Phase 4: TestFlight Deployment (Priority: Medium)

#### Step 4.1: Simplify IPA Export
```yaml
# Replace archive and export steps (lines 182-235)
- name: Archive and Export iOS app
  run: |
    cd src-tauri/gen/apple
    
    # Verify workspace
    if [ ! -f "src-tauri.xcworkspace/contents.xcworkspacedata" ]; then
      echo "Error: Xcode workspace not found"
      ls -la
      exit 1
    fi
    
    # Create archive
    xcodebuild \
      -workspace src-tauri.xcworkspace \
      -scheme src-tauri_iOS \
      -configuration Release \
      -archivePath build/archives/OpenCodeNexus.xcarchive \
      -derivedDataPath build/DerivedData \
      archive \
      CODE_SIGN_IDENTITY="Apple Distribution" \
      DEVELOPMENT_TEAM="PCJU8QD9FN" \
      OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
      -verbose
    
    # Export IPA
    xcodebuild \
      -exportArchive \
      -archivePath build/archives/OpenCodeNexus.xcarchive \
      -exportOptionsPlist ExportOptions.plist \
      -exportPath build/ipa \
      -allowProvisioningUpdates \
      -verbose
    
    # Verify IPA
    IPA_FILE=$(find build/ipa -name "*.ipa" -type f)
    if [ -z "$IPA_FILE" ]; then
      echo "Error: IPA file not found after export"
      exit 1
    fi
    
    echo "IPA_FILE=$IPA_FILE" >> $GITHUB_ENV
    echo "IPA exported successfully: $IPA_FILE"
```

#### Step 4.2: Enhanced TestFlight Upload
```yaml
# Replace TestFlight upload step (lines 304-328)
- name: Upload to TestFlight
  env:
    APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
    APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
    APP_STORE_CONNECT_API_PRIVATE_KEY: ${{ secrets.APP_STORE_CONNECT_API_PRIVATE_KEY }}
  run: |
    # Setup API key
    TEMP_KEY_DIR=$(mktemp -d)
    echo "$APP_STORE_CONNECT_API_PRIVATE_KEY" | base64 --decode > "$TEMP_KEY_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
    
    # Validate IPA first
    echo "Validating IPA before upload..."
    xcrun altool \
      --validate-app \
      --type ios \
      --file "${{ env.IPA_FILE }}" \
      --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
      --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
      --apiKeysDir "$TEMP_KEY_DIR" \
      --verbose
    
    # Upload to TestFlight
    echo "Uploading to TestFlight..."
    xcrun altool \
      --upload-app \
      --type ios \
      --file "${{ env.IPA_FILE }}" \
      --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
      --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
      --apiKeysDir "$TEMP_KEY_DIR" \
      --verbose
    
    echo "TestFlight upload completed successfully"
    rm -rf "$TEMP_KEY_DIR"
```

### Phase 5: Xcode Cloud Migration (Optional)

#### Step 5.1: Create Xcode Cloud Configuration
Create `.ci/xcode-cloud/ci.yml`:
```yaml
name: OpenCode Nexus iOS Build

triggers:
  - push:
      branches:
        - main
        - release
  - pull_request:
      branches:
        - main

environment:
  xcode: 15.4
  node: 18

scripts:
  - name: Install Dependencies
    script: |
      cd frontend
      bun install --frozen-lockfile
      
      cd ../src-tauri
      cargo fetch --target aarch64-apple-ios
      
  - name: Build Frontend
    script: |
      cd frontend
      bun run build
      
  - name: Build iOS App
    script: |
      cd src-tauri
      cargo tauri ios build --release --verbose
      
  - name: Archive and Export
    script: |
      cd src-tauri/gen/apple
      xcodebuild -workspace src-tauri.xcworkspace \
        -scheme src-tauri_iOS \
        -configuration Release \
        -archivePath $CI_WORKSPACE/build/archives/OpenCodeNexus.xcarchive \
        archive
        
      xcodebuild -exportArchive \
        -archivePath $CI_WORKSPACE/build/archives/OpenCodeNexus.xcarchive \
        -exportOptionsPlist ExportOptions.plist \
        -exportPath $CI_WORKSPACE/build/ipa

artifacts:
  - build/ipa/*.ipa
```

## 🔧 Subagent Usage Strategy

### Primary Subagents for iOS Development

1. **development/ios_developer** - Core iOS development and debugging
2. **operations/deployment_engineer** - CI/CD pipeline optimization
3. **development/mobile_developer** - Cross-platform mobile best practices
4. **operations/devops_troubleshooter** - Build failure resolution

### Subagent Delegation Plan

#### Phase 1: Configuration Fixes
```bash
# Use ios_developer for core iOS setup
Task: "Fix iOS configuration and dependencies"
Agent: development/ios_developer
Focus: Cargo.toml updates, entitlements, Podfile
```

#### Phase 2: Build System Optimization
```bash
# Use deployment_engineer for CI/CD improvements
Task: "Optimize iOS build pipeline"
Agent: operations/deployment_engineer
Focus: GitHub Actions workflow, caching, parallel builds
```

#### Phase 3: Testing & Validation
```bash
# Use mobile_developer for comprehensive testing
Task: "Validate iOS build and TestFlight deployment"
Agent: development/mobile_developer
Focus: E2E testing, device compatibility, performance
```

#### Phase 4: Production Deployment
```bash
# Use devops_troubleshooter for production issues
Task: "Troubleshoot production deployment issues"
Agent: operations/devops_troubleshooter
Focus: Monitoring, error handling, rollback procedures
```

## 📋 Implementation Checklist

### Immediate Actions (Day 1)
- [ ] Update Cargo.toml iOS dependencies
- [ ] Fix Tauri CLI version in workflow
- [ ] Create iOS entitlements file
- [ ] Update ExportOptions.plist
- [ ] Configure ATS for @opencode-ai/sdk

### Build System Fixes (Day 2)
- [ ] Update iOS build command
- [ ] Fix code signing workflow
- [ ] Update Podfile configuration
- [ ] Simplify IPA export process
- [ ] Enhance TestFlight upload

### Validation & Testing (Day 3)
- [ ] Run full iOS build test
- [ ] Validate IPA format
- [ ] Test TestFlight upload
- [ ] Verify app functionality on device
- [ ] Performance and security testing

### Optional Xcode Cloud Migration (Day 4-5)
- [ ] Create Xcode Cloud configuration
- [ ] Migrate build scripts
- [ ] Test Xcode Cloud pipeline
- [ ] Compare with GitHub Actions
- [ ] Decide on final CI/CD strategy

## 🚀 Success Metrics

### Technical Metrics
- iOS build success rate: >95%
- Build time: <30 minutes
- IPA size: <50MB
- TestFlight upload success: 100%

### Business Metrics
- Time to deployment: <2 hours from merge
- Crash rate: <0.1%
- App Store approval: First submission success

## 🔄 Rollback Plan

If any changes cause issues:
1. Revert to previous working commit
2. Restore original Cargo.toml dependencies
3. Use backup workflow file
4. Manual TestFlight upload if needed
5. Document issues and retry with fixes

## 📞 Support & Escalation

### Primary Contacts
- iOS Development: development/ios_developer
- Build Issues: operations/devops_troubleshooter
- Deployment: operations/deployment_engineer

### Emergency Procedures
1. Immediate rollback to last known good state
2. Hotfix branch creation
3. Emergency TestFlight deployment
4. User communication plan

---

**Next Steps**: Begin with Phase 1 implementation, focusing on core dependency updates and configuration fixes. Use the ios_developer subagent for specialized iOS expertise.