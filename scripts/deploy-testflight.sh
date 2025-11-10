#!/bin/bash

##############################################################################
# TestFlight Deployment Script for OpenCode Nexus
#
# Prerequisites:
#   1. Xcode Command Line Tools installed
#   2. Apple Developer account with TestFlight access
#   3. App-specific password or App Store Connect API key
#
# Setup App Store Connect API Key (Recommended):
#   1. Go to https://appstoreconnect.apple.com/access/api
#   2. Create new API Key with "App Manager" role
#   3. Download the .p8 file
#   4. Set environment variables:
#      export APPLE_API_KEY_ID="ABC123XYZ"
#      export APPLE_API_ISSUER_ID="abc-123-xyz"
#      export APPLE_API_KEY_PATH="/path/to/AuthKey_ABC123XYZ.p8"
#
# Or use app-specific password:
#   1. Go to https://appleid.apple.com/account/manage
#   2. Generate app-specific password
#   3. Set environment variables:
#      export APPLE_ID="your@email.com"
#      export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#
# Usage:
#   ./scripts/deploy-testflight.sh [--skip-build] [--skip-upload]
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="OpenCode Nexus"
BUNDLE_ID="com.agentic-codeflow.opencode-nexus"
IPA_PATH="src-tauri/gen/apple/build/OpenCode Nexus.ipa"

# Parse arguments
SKIP_BUILD=false
SKIP_UPLOAD=false

for arg in "$@"; do
  case $arg in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --skip-upload)
      SKIP_UPLOAD=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--skip-build] [--skip-upload]"
      echo ""
      echo "Options:"
      echo "  --skip-build    Skip the build step and use existing IPA"
      echo "  --skip-upload   Skip the upload step (build only)"
      echo "  --help          Show this help message"
      exit 0
      ;;
  esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

log_error() {
    echo -e "${RED}❌ ${NC}$1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for Xcode Command Line Tools
    if ! command -v xcrun &> /dev/null; then
        log_error "Xcode Command Line Tools not found"
        log_error "Install with: xcode-select --install"
        exit 1
    fi

    # Check for cargo and tauri
    if ! command -v cargo &> /dev/null; then
        log_error "Cargo not found. Please install Rust: https://rustup.rs/"
        exit 1
    fi

    # Check authentication method
    if [[ -z "$APPLE_API_KEY_ID" ]]; then
        if [[ -z "$APPLE_ID" || -z "$APPLE_APP_PASSWORD" ]]; then
            log_error "Authentication not configured!"
            log_error ""
            log_error "Option 1: App Store Connect API Key (Recommended)"
            log_error "  export APPLE_API_KEY_ID='ABC123XYZ'"
            log_error "  export APPLE_API_ISSUER_ID='abc-123-xyz'"
            log_error "  export APPLE_API_KEY_PATH='/path/to/AuthKey_ABC123XYZ.p8'"
            log_error ""
            log_error "Option 2: App-Specific Password"
            log_error "  export APPLE_ID='your@email.com'"
            log_error "  export APPLE_APP_PASSWORD='xxxx-xxxx-xxxx-xxxx'"
            exit 1
        fi
    fi

    log_success "Prerequisites check passed"
}

# Build iOS IPA
build_ios() {
    if [[ "$SKIP_BUILD" == true ]]; then
        log_warning "Skipping build (--skip-build flag)"

        if [[ ! -f "$IPA_PATH" ]]; then
            log_error "IPA not found at: $IPA_PATH"
            log_error "Run without --skip-build to build first"
            exit 1
        fi

        return
    fi

    log_info "Building iOS app for release..."
    log_info "This may take several minutes..."

    # Clean previous builds
    log_info "Cleaning previous builds..."
    rm -rf src-tauri/gen/apple/build

    # Build with cargo tauri
    log_info "Running cargo tauri ios build --release..."
    cd "$(dirname "$0")/.." || exit 1

    if ! cargo tauri ios build --release; then
        log_error "Build failed!"
        exit 1
    fi

    # Verify IPA was created
    if [[ ! -f "$IPA_PATH" ]]; then
        log_error "IPA not found at expected path: $IPA_PATH"
        exit 1
    fi

    # Get IPA size
    IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
    log_success "Build complete! IPA size: $IPA_SIZE"
    log_success "IPA location: $IPA_PATH"
}

# Upload to TestFlight
upload_testflight() {
    if [[ "$SKIP_UPLOAD" == true ]]; then
        log_warning "Skipping upload (--skip-upload flag)"
        return
    fi

    log_info "Uploading to TestFlight..."

    # Build xcrun command based on auth method
    if [[ -n "$APPLE_API_KEY_ID" ]]; then
        log_info "Using App Store Connect API Key authentication"

        # Verify API key file exists
        if [[ ! -f "$APPLE_API_KEY_PATH" ]]; then
            log_error "API Key file not found: $APPLE_API_KEY_PATH"
            exit 1
        fi

        log_info "Validating app with App Store Connect..."
        if ! xcrun altool --validate-app \
            --type ios \
            --file "$IPA_PATH" \
            --apiKey "$APPLE_API_KEY_ID" \
            --apiIssuer "$APPLE_API_ISSUER_ID"; then
            log_error "App validation failed!"
            exit 1
        fi

        log_success "Validation passed!"
        log_info "Uploading to App Store Connect..."

        if ! xcrun altool --upload-app \
            --type ios \
            --file "$IPA_PATH" \
            --apiKey "$APPLE_API_KEY_ID" \
            --apiIssuer "$APPLE_API_ISSUER_ID"; then
            log_error "Upload failed!"
            exit 1
        fi

    else
        log_info "Using Apple ID and app-specific password"

        log_info "Validating app with App Store Connect..."
        if ! xcrun altool --validate-app \
            --type ios \
            --file "$IPA_PATH" \
            --username "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD"; then
            log_error "App validation failed!"
            exit 1
        fi

        log_success "Validation passed!"
        log_info "Uploading to App Store Connect..."

        if ! xcrun altool --upload-app \
            --type ios \
            --file "$IPA_PATH" \
            --username "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD"; then
            log_error "Upload failed!"
            exit 1
        fi
    fi

    log_success "Upload complete!"
    log_info ""
    log_info "🎉 Your app has been uploaded to TestFlight!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Go to https://appstoreconnect.apple.com/"
    log_info "  2. Navigate to TestFlight tab"
    log_info "  3. Wait for processing (usually 5-15 minutes)"
    log_info "  4. Add build to testing group"
    log_info "  5. Invite testers or share public link"
}

# Main execution
main() {
    echo ""
    log_info "🚀 TestFlight Deployment Script"
    log_info "================================"
    echo ""

    check_prerequisites
    echo ""

    build_ios
    echo ""

    upload_testflight
    echo ""

    log_success "Deployment complete! 🎊"
    echo ""
}

# Run main function
main
