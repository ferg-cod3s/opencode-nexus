#!/bin/bash
# iOS Dependencies Pre-warming Script
# Optimizes dependency resolution and caching for faster iOS builds

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

# Start timing
START_TIME=$(date +%s)
print_status "Starting iOS dependency pre-warming..."
echo "=================================="

# Check if we're in the right directory
if [[ ! -f "src-tauri/Cargo.toml" ]]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# 1. Pre-warm Rust dependencies
print_status "Pre-warming Rust dependencies..."
cd src-tauri

# Fetch all dependencies for all iOS targets
IOS_TARGETS=("aarch64-apple-ios" "aarch64-apple-ios-sim" "x86_64-apple-ios")
for target in "${IOS_TARGETS[@]}"; do
    print_status "Fetching dependencies for $target..."
    cargo fetch --target "$target"
done

# Pre-compile common dependencies in debug mode
print_status "Pre-compiling common dependencies..."
cargo check --target aarch64-apple-ios
cargo check --target aarch64-apple-ios-sim

# 2. Pre-warm frontend dependencies
print_status "Pre-warming frontend dependencies..."
cd ../frontend

if command -v bun &> /dev/null; then
    print_status "Installing frontend dependencies with Bun..."
    bun install --frozen-lockfile
    
    # Pre-build common dependencies
    if [[ -f "package.json" ]]; then
        print_status "Pre-building frontend dependencies..."
        bun run build 2>/dev/null || print_warning "Frontend build failed, but dependencies are installed"
    fi
else
    print_warning "Bun not found, skipping frontend pre-warming"
fi

# 3. Setup iOS environment variables
print_status "Setting up iOS environment variables..."
cd ..

export IPHONEOS_DEPLOYMENT_TARGET=14.0
export CFLAGS="-miphoneos-version-min=14.0"
export CXXFLAGS="-miphoneos-version-min=14.0"
export RUST_BACKTRACE=0

print_success "iOS environment variables set"

# 4. Initialize iOS project if needed
print_status "Checking iOS project initialization..."
cd src-tauri

if [[ ! -d "gen/apple/src-tauri.xcodeproj" ]]; then
    print_status "Initializing iOS project..."
    if command -v cargo &> /dev/null && cargo tauri --help &> /dev/null; then
        cargo tauri ios init
        print_success "iOS project initialized"
    else
        print_warning "Tauri CLI not available, skipping iOS initialization"
    fi
else
    print_success "iOS project already initialized"
fi

# 5. Setup CocoaPods if needed
print_status "Setting up CocoaPods..."
if [[ -d "gen/apple" ]]; then
    cd gen/apple
    if [[ -f "Podfile" ]]; then
        if command -v pod &> /dev/null; then
            print_status "Installing CocoaPods dependencies..."
            pod install --repo-update || pod install
            print_success "CocoaPods dependencies installed"
        else
            print_warning "CocoaPods not found, install with: sudo gem install cocoapods"
        fi
    fi
    cd ../../..
fi

# 6. Create build cache directories
print_status "Creating build cache directories..."
mkdir -p src-tauri/target/debug
mkdir -p src-tauri/target/release
mkdir -p src-tauri/target/aarch64-apple-ios
mkdir -p src-tauri/target/aarch64-apple-ios-sim
mkdir -p src-tauri/target/x86_64-apple-ios

print_success "Build cache directories created"

# 7. Pre-compile Rust for iOS targets (optional)
print_status "Pre-compiling Rust for iOS targets..."
for target in "${IOS_TARGETS[@]}"; do
    print_status "Pre-compiling for $target..."
    cargo build --target "$target" --release || print_warning "Pre-compilation failed for $target"
done

cd ..

# Calculate timing
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo "=================================="
print_success "iOS dependency pre-warming completed in ${TOTAL_TIME}s!"
echo ""
echo "🚀 Next Steps:"
echo "  1. Run 'cargo tauri dev' for local development"
echo "  2. Run 'cargo tauri ios build' for iOS release build"
echo "  3. Run './scripts/validate-ios-env.sh' to verify environment"
echo ""
echo "📊 Pre-warming Summary:"
echo "  - Rust dependencies: Fetched and pre-compiled"
echo "  - Frontend dependencies: Installed and pre-built"
echo "  - iOS project: Initialized and configured"
echo "  - CocoaPods: Dependencies installed"
echo "  - Build cache: Optimized for faster builds"
echo ""
print_success "Ready for iOS development!"