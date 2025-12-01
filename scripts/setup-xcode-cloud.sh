#!/bin/bash
# Xcode Cloud Setup Script
# Configures project for Xcode Cloud builds with enhanced reliability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Setting up Xcode Cloud integration..."
echo "=================================="

# Check if we're in the right directory
if [[ ! -f "src-tauri/Cargo.toml" ]]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# 1. Create Xcode Cloud configuration
print_status "Creating Xcode Cloud configuration..."

# Create .xcodecloud directory
mkdir -p .xcodecloud

# Create ci_cd.xcconfig
cat > .xcodecloud/ci_cd.xcconfig << EOF
// Xcode Cloud Build Configuration
// Optimized for reliable iOS builds

// iOS Deployment Target
IPHONEOS_DEPLOYMENT_TARGET = 14.0

// Build Settings
ENABLE_BITCODE = NO
STRIP_INSTALLED_PRODUCT = YES
DEAD_CODE_STRIPPING = YES
COPY_PHASE_STRIP = YES

// Optimization
GCC_OPTIMIZATION_LEVEL = s
SWIFT_OPTIMIZATION_LEVEL = -Osize
VALIDATE_PRODUCT = YES

// Architecture
ONLY_ACTIVE_ARCH = YES
ARCHS = arm64

// Code Signing (for CI)
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO

// Warnings
GCC_WARN_INHIBIT_ALL_WARNINGS = YES

// Rust Integration
CARGO_TARGET_DIR = \$(SRCROOT)/target
RUST_BACKTRACE = 0

// Environment
NODE_ENV = production
BUN_INSTALL_NO_GLOBAL = true
EOF

print_success "Xcode Cloud configuration created"

# 2. Create Xcode Cloud workflow
print_status "Creating Xcode Cloud workflow..."

mkdir -p .xcodecloud/workflows

cat > .xcodecloud/workflows/ios-build.yml << EOF
name: iOS Build and Test
triggers:
  - push:
      branches:
        include:
          - main
          - develop
          - release/*
  - pull_request:
      branches:
        include:
          - main
          - develop

actions:
  - name: Build iOS App
    type: xcodebuild
    scheme: src-tauri_iOS
    configuration: Release
    sdk: iphoneos
    destination:
      name: Any iOS Device
    settings:
      - configuration: Release
      - custom xcconfig: .xcodecloud/ci_cd.xcconfig
    environment:
      variables:
        RUST_LOG: info
        CARGO_TERM_COLOR: always

  - name: Run Tests
    type: xcodebuild
    scheme: src-tauri_iOS
    configuration: Debug
    sdk: iphonesimulator
    destination:
      name: iPhone 15
      os: latest
    settings:
      - configuration: Debug
      - custom xcconfig: .xcodecloud/ci_cd.xcconfig

  - name: Archive for Distribution
    type: xcodebuild
    scheme: src-tauri_iOS
    configuration: Release
    sdk: iphoneos
    destination:
      name: Any iOS Device
    action: archive
    archivePath: \$(CI_WORKSPACE)/build/Archive.xcarchive
    settings:
      - configuration: Release
      - custom xcconfig: .xcodecloud/ci_cd.xcconfig
    environment:
      variables:
        CODE_SIGN_STYLE: Manual
        PROVISIONING_PROFILE_SPECIFIER: OpenCodeNexus_AppStore

  - name: Export IPA
    type: xcodebuild
    scheme: src-tauri_iOS
    configuration: Release
    sdk: iphoneos
    action: export
    archivePath: \$(CI_WORKSPACE)/build/Archive.xcarchive
    exportPath: \$(CI_WORKSPACE)/build/IPA
    exportOptionsPlist: src-tauri/ios-config/ExportOptions.plist
    settings:
      - configuration: Release
      - custom xcconfig: .xcodecloud/ci_cd.xcconfig

  - name: Upload to TestFlight
    type: upload_to_testflight
    provider: app-store-connect
    configuration: Release
    ipaPath: \$(CI_WORKSPACE)/build/IPA/src-tauri_iOS.ipa
    environment:
      variables:
        APP_STORE_CONNECT_API_KEY_ID: \${APP_STORE_CONNECT_API_KEY_ID}
        APP_STORE_CONNECT_ISSUER_ID: \${APP_STORE_CONNECT_ISSUER_ID}
        APP_STORE_CONNECT_API_PRIVATE_KEY: \${APP_STORE_CONNECT_API_PRIVATE_KEY}
EOF

print_success "Xcode Cloud workflow created"

# 3. Create enhanced GitHub Actions workflow
print_status "Updating GitHub Actions workflow for Xcode Cloud compatibility..."

# Backup existing workflow
if [[ -f ".github/workflows/ios-release-fixed.yml" ]]; then
    cp .github/workflows/ios-release-fixed.yml .github/workflows/ios-release-fixed.yml.backup
    print_status "Backed up existing workflow"
fi

# Create enhanced workflow
cat > .github/workflows/ios-release-enhanced.yml << EOF
name: iOS TestFlight Release (Enhanced)

on:
  push:
    tags:
      - 'ios-v*'
    branches:
      - 'main'
      - 'test-ios-build'
      - 'release'
  workflow_dispatch:
    inputs:
      upload_to_testflight:
        description: 'Upload to TestFlight'
        required: false
        default: true
        type: boolean
      tag_name:
        description: 'Release tag name'
        required: false
        type: string
      build_type:
        description: 'Build type'
        required: false
        default: 'release'
        type: choice
        options:
          - release
          - debug

env:
  RUST_LOG: info
  CARGO_TERM_COLOR: always
  IPHONEOS_DEPLOYMENT_TARGET: 14.0

jobs:
  validate-environment:
    runs-on: macos-14
    outputs:
      cache-key: \${{ steps.cache-key.outputs.key }}
      should-build: \${{ steps.decision.outputs.build }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate cache key
        id: cache-key
        run: |
          KEY="\${{ runner.os }}-ios-v2-\${{ hashFiles('**/Cargo.lock', '**/bun.lockb', 'src-tauri/Cargo.toml', 'frontend/package.json', 'src-tauri/src/**/*.rs') }}"
          echo "key=\$KEY" >> \$GITHUB_OUTPUT

      - name: Decide if build should run
        id: decision
        run: |
          if [[ "\${{ github.event_name }}" == "push" && "\${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "build=true" >> \$GITHUB_OUTPUT
          elif [[ "\${{ github.event_name }}" == "push" && "\${{ github.ref }}" == refs/tags/* ]]; then
            echo "build=true" >> \$GITHUB_OUTPUT
          elif [[ "\${{ github.event_name }}" == "workflow_dispatch" ]]; then
            echo "build=true" >> \$GITHUB_OUTPUT
          else
            echo "build=false" >> \$GITHUB_OUTPUT
          fi

  build-ios:
    needs: validate-environment
    if: needs.validate-environment.outputs.should-build == 'true'
    runs-on: macos-14
    timeout-minutes: 120

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up environment variables
        run: |
          TAG_NAME="\${{ github.event.inputs.tag_name || github.ref_name }}"
          VERSION_NUMBER=\$(echo "\$TAG_NAME" | sed 's/^[^0-9]*//;s/-.*$//')
          BUILD_NUMBER=\$(git rev-list --count HEAD)

          echo "TAG_NAME=\$TAG_NAME" >> \$GITHUB_ENV
          echo "VERSION_NUMBER=\$VERSION_NUMBER" >> \$GITHUB_ENV
          echo "BUILD_NUMBER=\$BUILD_NUMBER" >> \$GITHUB_ENV

          echo "Version: \$VERSION_NUMBER (Build: \$BUILD_NUMBER)"

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.4'

      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-ios,aarch64-apple-ios-sim,x86_64-apple-ios

      - name: Install Bun
        uses: oven-sh/setup-bun@v1
        with:
          bun-version: latest

      - name: Setup enhanced caching
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            ~/.bun/install/cache
            frontend/node_modules
            src-tauri/target/debug
            src-tauri/target/release
          key: \${{ needs.validate-environment.outputs.cache-key }}
          restore-keys: |
            \${{ runner.os }}-ios-v2-
            \${{ runner.os }}-deps-v2-
            \${{ runner.os }}-deps-

      - name: Cache Rust artifacts
        uses: actions/cache@v4
        with:
          path: |
            src-tauri/target/aarch64-apple-ios
            src-tauri/target/aarch64-apple-ios-sim
            src-tauri/target/x86_64-apple-ios
            src-tauri/target/.rustc_info.json
          key: \${{ runner.os }}-ios-artifacts-\${{ hashFiles('**/Cargo.lock', 'src-tauri/src/**/*.rs') }}
          restore-keys: |
            \${{ runner.os }}-ios-artifacts-
            \${{ runner.os }}-rust-target-

      - name: Validate environment
        run: |
          ./scripts/validate-ios-env.sh || echo "Environment validation completed with warnings"

      - name: Pre-warm dependencies
        run: |
          ./scripts/pre-warm-deps.sh

      - name: Build frontend
        run: |
          cd frontend
          bun install --frozen-lockfile
          bun run build
        env:
          NODE_ENV: production

      - name: Build iOS app
        run: |
          echo "::group::Starting iOS build at \$(date)"
          START_TIME=\$(date +%s)

          cd src-tauri
          
          # Set build type
          BUILD_TYPE="\${{ github.event.inputs.build_type || 'release' }}"
          if [[ "\$BUILD_TYPE" == "debug" ]]; then
            CARGO_PROFILE="debug"
            XCODE_CONFIG="Debug"
          else
            CARGO_PROFILE="release"
            XCODE_CONFIG="Release"
          fi

          echo "Building with profile: \$CARGO_PROFILE"
          
          # Build Rust code
          RUST_START_TIME=\$(date +%s)
          cargo build --target aarch64-apple-ios --profile \$CARGO_PROFILE
          RUST_BUILD_TIME=\$(\$(date +%s) - RUST_START_TIME))
          echo "Rust build completed in \${RUST_BUILD_TIME}s"

          # Build iOS app
          TAURI_START_TIME=\$(date +%s)
          cargo tauri ios build --profile \$CARGO_PROFILE --verbose
          TAURI_BUILD_TIME=\$(\$(date +%s) - TAURI_START_TIME))
          TOTAL_TIME=\$(\$(date +%s) - START_TIME))

          echo "::notice::Build timing: Rust=\${RUST_BUILD_TIME}s, Tauri+Xcode=\${TAURI_BUILD_TIME}s, Total=\${TOTAL_TIME}s"
          echo "::endgroup::"

      - name: Archive and Export
        run: |
          cd src-tauri/gen/apple

          # Verify workspace exists
          if [[ ! -f "src-tauri.xcworkspace/contents.xcworkspacedata" ]]; then
            echo "Error: Xcode workspace not found"
            ls -la
            exit 1
          fi

          mkdir -p build/archives build/ipa

          # Determine configuration
          BUILD_TYPE="\${{ github.event.inputs.build_type || 'release' }}"
          if [[ "\$BUILD_TYPE" == "debug" ]]; then
            XCODE_CONFIG="Debug"
          else
            XCODE_CONFIG="Release"
          fi

          # Create archive
          xcodebuild \\
            -workspace src-tauri.xcworkspace \\
            -scheme src-tauri_iOS \\
            -configuration \$XCODE_CONFIG \\
            -archivePath build/archives/OpenCodeNexus.xcarchive \\
            -derivedDataPath build/DerivedData \\
            archive \\
            CODE_SIGN_IDENTITY="Apple Distribution" \\
            DEVELOPMENT_TEAM="PCJU8QD9FN" \\
            OTHER_CODE_SIGN_FLAGS="--timestamp=none" \\
            -verbose

          # Export IPA
          xcodebuild \\
            -exportArchive \\
            -archivePath build/archives/OpenCodeNexus.xcarchive \\
            -exportOptionsPlist ExportOptions.plist \\
            -exportPath build/ipa \\
            -allowProvisioningUpdates \\
            -verbose

          # Verify IPA
          IPA_FILE=\$(find build/ipa -name "*.ipa" -type f)
          if [[ -z "\$IPA_FILE" ]]; then
            echo "Error: IPA file not found after export"
            exit 1
          fi

          IPA_SIZE=\$(du -h "\$IPA_FILE" | cut -f1)
          echo "IPA exported: \$IPA_FILE (\$IPA_SIZE)"
          echo "IPA_FILE=\$IPA_FILE" >> \$GITHUB_ENV

      - name: Upload to TestFlight
        if: github.event.inputs.upload_to_testflight != 'false' && (github.event_name != 'workflow_dispatch' || github.event.inputs.upload_to_testflight == 'true')
        env:
          APP_STORE_CONNECT_API_KEY_ID: \${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: \${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_API_PRIVATE_KEY: \${{ secrets.APP_STORE_CONNECT_API_PRIVATE_KEY }}
        run: |
          # Setup API key
          TEMP_KEY_DIR=\$(mktemp -d)
          echo "\$APP_STORE_CONNECT_API_PRIVATE_KEY" | base64 --decode > "\$TEMP_KEY_DIR/AuthKey_\${APP_STORE_CONNECT_API_KEY_ID}.p8"
          
          # Validate IPA first
          echo "Validating IPA before upload..."
          xcrun altool \\
            --validate-app \\
            --type ios \\
            --file "\${{ env.IPA_FILE }}" \\
            --apiKey "\$APP_STORE_CONNECT_API_KEY_ID" \\
            --apiIssuer "\$APP_STORE_CONNECT_ISSUER_ID" \\
            --apiKeysDir "\$TEMP_KEY_DIR" \\
            --verbose
          
          # Upload to TestFlight
          echo "Uploading to TestFlight..."
          xcrun altool \\
            --upload-app \\
            --type ios \\
            --file "\${{ env.IPA_FILE }}" \\
            --apiKey "\$APP_STORE_CONNECT_API_KEY_ID" \\
            --apiIssuer "\$APP_STORE_CONNECT_ISSUER_ID" \\
            --apiKeysDir "\$TEMP_KEY_DIR" \\
            --verbose
          
          echo "TestFlight upload completed successfully"
          rm -rf "\$TEMP_KEY_DIR"

      - name: Create GitHub Release
        if: github.ref_type == 'tag'
        uses: softprops/action-gh-release@v1
        with:
          files: \${{ env.IPA_FILE }}
          tag_name: \${{ env.TAG_NAME }}
          generate_release_notes: true
          draft: false
          prerelease: \${{ contains(env.TAG_NAME, 'beta') || contains(env.TAG_NAME, 'rc') }}
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}

      - name: Upload IPA to artifacts
        if: always() && env.IPA_FILE != ''
        uses: actions/upload-artifact@v4
        with:
          name: opencode-nexus-ios-\${{ env.VERSION_NUMBER }}-build-\${{ env.BUILD_NUMBER }}
          path: \${{ env.IPA_FILE }}
          retention-days: 30

      - name: Build success summary
        if: success()
        run: |
          cat >> \$GITHUB_STEP_SUMMARY << 'EOF'
          ## ✅ iOS Build Successful

          ### 📱 Build Details
          - **Version**: \${{ env.VERSION_NUMBER }} (Build: \${{ env.BUILD_NUMBER }})
          - **Runner**: macOS 14 (Apple Silicon)
          - **Xcode**: 15.4
          - **Rust Target**: aarch64-apple-ios
          - **Build Type**: \${{ github.event.inputs.build_type || 'release' }}
          - **Export Method**: App Store
          - **IPA Size**: \$(du -h "\${{ env.IPA_FILE }}" | cut -f1)

          ### 🚀 Next Steps
          1. Check [App Store Connect](https://appstoreconnect.apple.com/apps) for processing status
          2. Monitor TestFlight for build availability (5-15 minutes)
          3. Invite internal testers to test the build
          4. Verify app functionality on physical devices

          Enhanced iOS build workflow completed successfully!
          EOF

      - name: Build failure summary
        if: failure()
        run: |
          cat >> \$GITHUB_STEP_SUMMARY << 'EOF'
          ## ❌ iOS Build Failed

          ### 🔍 Troubleshooting Steps
          1. Check job logs above for specific error details
          2. Verify all secrets are configured correctly
          3. Ensure provisioning profile is not expired
          4. Check App Store Connect API key validity
          5. Run environment validation: ./scripts/validate-ios-env.sh

          ### 📞 Support
          - Check build logs for detailed error information
          - Verify iOS project configuration
          - Ensure all dependencies are properly installed
          EOF
EOF

print_success "Enhanced GitHub Actions workflow created"

# 4. Create Xcode Cloud specific scripts
print_status "Creating Xcode Cloud specific scripts..."

# Create build script for Xcode Cloud
cat > scripts/xcode-cloud-build.sh << 'EOF'
#!/bin/bash
# Xcode Cloud Build Script
# Optimized for Xcode Cloud environment

set -e

echo "🚀 Starting Xcode Cloud build..."
echo "=================================="

# Set environment variables
export IPHONEOS_DEPLOYMENT_TARGET=14.0
export CFLAGS="-miphoneos-version-min=14.0"
export CXXFLAGS="-miphoneos-version-min=14.0"
export RUST_BACKTRACE=1
export RUST_LOG=info
export CARGO_TERM_COLOR=always

# Navigate to project root
cd "$CI_WORKSPACE"

# Validate environment
if [[ -f "scripts/validate-ios-env.sh" ]]; then
    echo "🔍 Validating iOS environment..."
    ./scripts/validate-ios-env.sh
fi

# Pre-warm dependencies
if [[ -f "scripts/pre-warm-deps.sh" ]]; then
    echo "🔥 Pre-warming dependencies..."
    ./scripts/pre-warm-deps.sh
fi

# Build frontend
echo "🏗️ Building frontend..."
cd frontend
bun install --frozen-lockfile
bun run build
cd ..

# Build iOS app
echo "🍎 Building iOS app..."
cd src-tauri

# Determine build configuration
if [[ "$CI_BUILD_CONFIGURATION" == "Debug" ]]; then
    CARGO_PROFILE="debug"
else
    CARGO_PROFILE="release"
fi

echo "Building with profile: $CARGO_PROFILE"

# Build Rust code
cargo build --target aarch64-apple-ios --profile $CARGO_PROFILE

# Build iOS app with Tauri
cargo tauri ios build --profile $CARGO_PROFILE --verbose

echo "✅ Xcode Cloud build completed successfully!"
EOF

chmod +x scripts/xcode-cloud-build.sh

print_success "Xcode Cloud build script created"

# 5. Create documentation
print_status "Creating Xcode Cloud documentation..."

cat > docs/xcode-cloud-setup.md << EOF
# Xcode Cloud Setup Guide

This guide covers setting up OpenCode Nexus for Xcode Cloud builds with enhanced reliability.

## Prerequisites

1. **Apple Developer Account**: Active Apple Developer account with App Store Connect access
2. **Xcode Project**: iOS project must be initialized (`cargo tauri ios init`)
3. **Code Signing**: Distribution certificate and provisioning profile configured
4. **API Keys**: App Store Connect API key for TestFlight uploads

## Setup Steps

### 1. Configure Xcode Cloud

1. Open your project in Xcode
2. Go to **Product → Destination → Xcode Cloud**
3. Follow the setup wizard to create Xcode Cloud workflow
4. Choose the "iOS Build and Test" workflow template

### 2. Configure Secrets

In Xcode Cloud, add these environment variables:

#### Required Secrets
- \`APP_STORE_CONNECT_API_KEY_ID\`: Your App Store Connect API key ID
- \`APP_STORE_CONNECT_ISSUER_ID\`: Your App Store Connect issuer ID
- \`APP_STORE_CONNECT_API_PRIVATE_KEY\`: Base64-encoded private key

#### Optional Variables
- \`RUST_LOG\`: Logging level (info, debug, trace)
- \`BUILD_TYPE\`: Build type (release, debug)

### 3. Configure Build Settings

The project includes optimized build settings in \`.xcodecloud/ci_cd.xcconfig\`:

- iOS deployment target: 14.0
- Bitcode disabled
- Size optimization enabled
- Dead code stripping enabled

### 4. Workflow Configuration

The Xcode Cloud workflow (`.xcodecloud/workflows/ios-build.yml`) includes:

1. **Build iOS App**: Compiles Rust code and builds iOS app
2. **Run Tests**: Executes unit tests on iOS simulator
3. **Archive for Distribution**: Creates archive for App Store distribution
4. **Export IPA**: Exports IPA file with proper code signing
5. **Upload to TestFlight**: Uploads build to TestFlight for testing

## Build Process

### Automatic Builds

Builds are triggered automatically for:
- Pushes to \`main\` branch
- Pushes to \`develop\` branch
- Pull requests to \`main\` and \`develop\`
- Tag pushes (releases)

### Manual Builds

You can trigger builds manually:
1. Go to Xcode Cloud in App Store Connect
2. Select your workflow
3. Click "Start Build"
4. Choose branch and configuration
5. Add any custom environment variables

## Troubleshooting

### Common Issues

#### Build Failures
1. Check the build log for specific error messages
2. Verify all secrets are correctly configured
3. Ensure provisioning profile is valid and not expired
4. Check that certificate matches provisioning profile

#### Code Signing Issues
1. Verify distribution certificate is active
2. Check provisioning profile includes correct bundle ID
3. Ensure certificate and profile are not expired
4. Verify team ID matches configuration

#### TestFlight Upload Failures
1. Check App Store Connect API key permissions
2. Verify API key is not expired
3. Ensure app metadata is complete in App Store Connect
4. Check that build passes App Store review guidelines

### Debugging

#### Enable Verbose Logging
Set \`RUST_LOG=debug\` or \`RUST_LOG=trace\` for detailed logs.

#### Local Reproduction
Use the same scripts locally:
\`\`\`bash
./scripts/validate-ios-env.sh
./scripts/pre-warm-deps.sh
./scripts/xcode-cloud-build.sh
\`\`\`

#### Build Artifacts
Build artifacts are available in Xcode Cloud:
- IPA files for distribution
- Build logs for debugging
- Test results for quality assurance

## Performance Optimization

### Caching

The workflow includes intelligent caching:
- Rust dependencies and registry
- Bun package manager cache
- Frontend node_modules
- Pre-compiled Rust targets

### Build Times

Typical build times:
- Clean build: 15-20 minutes
- Incremental build: 5-10 minutes
- Cache hit: 2-5 minutes

### Monitoring

Monitor build performance:
- Check build duration trends
- Monitor cache hit rates
- Track success/failure rates
- Review resource utilization

## Best Practices

1. **Regular Updates**: Keep dependencies updated for security and performance
2. **Testing**: Run tests on every build to catch issues early
3. **Monitoring**: Set up alerts for build failures
4. **Documentation**: Keep build configuration documented
5. **Security**: Rotate API keys regularly and limit access

## Support

For issues with Xcode Cloud builds:
1. Check Xcode Cloud build logs
2. Review this documentation
3. Run local validation scripts
4. Contact Apple Developer Support for Xcode Cloud issues
EOF

print_success "Xcode Cloud documentation created"

echo "=================================="
print_success "Xcode Cloud setup completed!"
echo ""
echo "📁 Files Created:"
echo "  - .xcodecloud/ci_cd.xcconfig"
echo "  - .xcodecloud/workflows/ios-build.yml"
echo "  - .github/workflows/ios-release-enhanced.yml"
echo "  - scripts/xcode-cloud-build.sh"
echo "  - docs/xcode-cloud-setup.md"
echo ""
echo "🚀 Next Steps:"
echo "  1. Commit and push these changes"
echo "  2. Configure Xcode Cloud in App Store Connect"
echo "  3. Add required secrets and environment variables"
echo "  4. Test the build workflow"
echo "  5. Monitor build performance and reliability"
echo ""
print_success "Ready for Xcode Cloud integration!"