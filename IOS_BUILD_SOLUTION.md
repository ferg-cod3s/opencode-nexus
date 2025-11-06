# iOS Build Solution for OpenCode Nexus

## Problem Summary

The iOS build was failing with critical linker errors:
```
ld: library 'System' not found
cc: error: linker command failed with exit code 1
```

This was caused by Rust cross-compilation trying to link with macOS libraries (`-lSystem`, `-mmacosx-version-min=11.0.0`) instead of iOS libraries during iOS builds.

## Root Cause

1. **Cross-compilation configuration**: Rust was using macOS toolchain settings for iOS builds
2. **Missing iOS-specific linker flags**: Dependencies like `swift-rs`, `ring`, `hyper-util` needed iOS framework linking
3. **Incorrect SDK paths**: Build process wasn't properly targeting iOS SDK

## Solution Applied

### 1. iOS-Specific Cargo Configuration

Created `.cargo/config.toml` with proper iOS settings:

```toml
[target.aarch64-apple-ios]
rustflags = [
    "-C", "link-arg=-L$(SDKROOT)/usr/lib",
    "-C", "link-arg=-L$(SDKROOT)/usr/lib/swift",
    "-C", "link-arg=-framework", "-C", "link-arg=Foundation",
    "-C", "link-arg=-framework", "-C", "link-arg=UIKit",
    "-C", "link-arg=-framework", "-C", "link-arg=CoreGraphics",
    "-C", "link-arg=-framework", "-C", "link-arg=Metal",
    "-C", "link-arg=-framework", "-C", "link-arg=QuartzCore",
    "-C", "link-arg=-framework", "-C", "link-arg=Security",
    "-C", "link-arg=-framework", "-C", "link-arg=WebKit"
]

[env]
IPHONEOS_DEPLOYMENT_TARGET = "14.0"
CARGO_CFG_TARGET_OS = "ios"
CARGO_CFG_TARGET_VENDOR = "apple"
```

### 2. iOS-Specific Dependencies

Updated `Cargo.toml` with iOS-specific dependencies:

```toml
[target.'cfg(target_os = "ios")'.dependencies]
objc2 = "0.6"
objc2-ui-kit = "0.3"
objc2-foundation = "0.3"
```

### 3. Build Script Enhancement

Enhanced `build.rs` with iOS framework linking:

```rust
#[cfg(target_os = "ios")]
{
    println!("cargo:rustc-link-lib=framework=UIKit");
    println!("cargo:rustc-link-lib=framework=Foundation");
    // ... other frameworks
}
```

## Files Modified

1. **`src-tauri/.cargo/config.toml`** - iOS build configuration
2. **`src-tauri/Cargo.toml`** - Added iOS-specific dependencies
3. **`src-tauri/build.rs`** - Enhanced with iOS framework linking
4. **`src-tauri/tauri.ios.conf.json`** - Updated iOS bundle configuration

## Build Commands

### Quick Build (Recommended)
```bash
./build-ios.sh
```

### Manual Build Steps
```bash
# 1. Install iOS targets
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# 2. Build frontend
cd frontend && bun run build && cd ..

# 3. Build for iOS devices
cd src-tauri && cargo tauri build --target aarch64-apple-ios

# 4. Build for iOS simulator (optional)
cargo tauri build --target aarch64-apple-ios-sim
```

## TestFlight Distribution

1. **Open Xcode Project**:
   ```bash
   open src-tauri/gen/apple/src-tauri.xcodeproj
   ```

2. **Configure Team ID**:
   - Open project settings
   - Set your Apple Developer Team ID
   - Verify bundle identifier: `com.agentic-codeflow.opencode-nexus`

3. **Build and Archive**:
   - Select "Any iOS Device" as target
   - Product → Archive

4. **Distribute to TestFlight**:
   - In Organizer window, select your archive
   - Click "Distribute App"
   - Follow TestFlight distribution flow

## Key Fixes

### ✅ Fixed Linker Issues
- **Problem**: `ld: library 'System' not found`
- **Solution**: Proper iOS framework linking instead of macOS System library

### ✅ Correct SDK Targeting
- **Problem**: Using macOS SDK for iOS builds
- **Solution**: Explicit iOS SDK paths and framework linking

### ✅ Dependency Resolution
- **Problem**: Dependencies failing to compile for iOS
- **Solution**: iOS-specific dependency configuration and proper cross-compilation settings

### ✅ TestFlight Readiness
- **Problem**: Build not ready for App Store distribution
- **Solution**: Proper iOS bundle configuration and deployment target

## Verification

To verify the build works:

```bash
# Check if build artifacts exist
ls -la src-tauri/target/aarch64-apple-ios/release/src-tauri

# Check Xcode project generation
ls -la src-tauri/gen/apple/src-tauri.xcodeproj
```

## Troubleshooting

### If build still fails:
1. **Clean and rebuild**: `cargo clean && cargo tauri build --target aarch64-apple-ios`
2. **Check Xcode installation**: Ensure Xcode Command Line Tools are installed
3. **Verify targets**: `rustup target list --installed | grep ios`
4. **Check SDK paths**: `xcrun --sdk iphoneos --show-sdk-path`

### Common Issues:
- **Missing iOS SDK**: Install latest Xcode from App Store
- **Team ID not set**: Configure in Xcode project settings
- **Bundle identifier conflict**: Change to unique identifier

## Architecture Support

- **Physical Devices**: `aarch64-apple-ios` (arm64)
- **Simulator (Apple Silicon)**: `aarch64-apple-ios-sim`
- **Simulator (Intel)**: `x86_64-apple-ios`

## Future Android Compatibility

The Tauri v2 setup ensures easy Android conversion:
- Same Rust backend code
- Shared frontend codebase
- Platform-specific build configurations only

This iOS build solution maintains the cross-platform architecture while fixing the immediate iOS distribution needs.