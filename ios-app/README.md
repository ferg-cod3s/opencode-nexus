# OpenCode Nexus iOS App

Native SwiftUI client for OpenCode servers. The project requires Xcode 26 and iOS 26.

## Simulator Build

From the repo root:

```bash
bun run ios:build
```

Direct command:

```bash
cd ios-app
xcodebuild -project OpenCodeNexus.xcodeproj -scheme OpenCodeNexus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData/Simulator build
```

Open the project in Xcode beta explicitly if macOS opens `.xcodeproj` files in another editor:

```bash
open -a /Applications/Xcode-beta.app OpenCodeNexus.xcodeproj
```

Install and launch after a simulator build:

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/OpenCodeNexus-*/Build/Products/Debug-iphonesimulator/OpenCodeNexus.app
xcrun simctl launch booted com.agentic-codeflow.opencode-nexus
```

## Physical iPhone Build Over SSH

From the repo root:

```bash
bun run ios:device
```

Normal SSH device builds should use `bun run ios:device`.

Use `build-device.sh` to build, install, and launch on the paired iPhone from an SSH session:

```bash
cd /Users/johnferguson/Github/opencode-nexus/ios-app
./build-device.sh
```

The script defaults to:

| Setting | Value |
|---------|-------|
| Xcode | `/Applications/Xcode-beta.app/Contents/Developer` |
| Device | `00008140-000518440C7B001C` |
| Bundle ID | `com.agentic-codeflow.opencode-nexus` |
| Derived data | `ios-app/build/DerivedData` |
| Team | `PCJU8QD9FN` |
| Signing cert | Auto-detected `Apple Development` identity |

Provisioning profiles on this machine are for team `PCJU8QD9FN`.

After signing or team changes in `project.yml`, regenerate the Xcode project:

```bash
cd ios-app && xcodegen generate
```

Useful options:

```bash
bun run ios:device:prepare-signing
bun run ios:device:clean
bun run ios:device:build-only
bun run ios:device:skip-launch
bun run ios:device:fresh-signing

# Direct script form for custom options
./build-device.sh --device DEVICE_UDID
```

`--prepare-signing` unlocks the login keychain and grants `codesign` access for SSH builds. Use it only when `xcodebuild` fails during signing with keychain access errors such as `errSecInternalComponent` or when the keychain has relocked. Do not use it for provisioning or team mismatches.

For non-interactive SSH use, provide the keychain password through the environment:

```bash
KEYCHAIN_PASSWORD='your-keychain-password' ./build-device.sh --prepare-signing
```

Do not commit shell history or logs that contain `KEYCHAIN_PASSWORD`.

## Signing Behavior

The script defaults to `SIGNING_CERT_SHA=auto`. In auto mode it finds the first valid `Apple Development` signing identity in the login keychain and forces that SHA with `OTHER_CODE_SIGN_FLAGS=--sign ...`. This keeps command-line builds repeatable and avoids Xcode choosing stale duplicate identities.

The script passes `-allowProvisioningUpdates` for device builds. This lets Xcode create or download fresh signing assets for the configured Apple account while keeping the existing signing-certificate selection behavior.

The script also sets:

```text
ENABLE_DEBUG_DYLIB=NO
```

This avoids extra debug dylib signing friction for command-line device builds.

To force a specific identity:

```bash
SIGNING_CERT_SHA=4D7767099A85F91A8E29A389A069B2FC7D6A7D1F ./build-device.sh
./build-device.sh --signing-cert 4D7767099A85F91A8E29A389A069B2FC7D6A7D1F
```

To let Xcode choose and refresh signing assets:

```bash
./build-device.sh --default-signing --allow-provisioning-updates
```

If Xcode reports a revoked or expired duplicate certificate, identify it by SHA and delete only that certificate:

```bash
security find-identity -v -p codesigning
security delete-certificate -Z CERT_SHA "$HOME/Library/Keychains/login.keychain-db"
```

Repeat `security find-identity -v -p codesigning` afterward. The normal state should include one valid `Apple Development` identity and any distribution identities you still need.

If the phone rejects an install with:

```text
0xe8008018: The identity used to sign the executable is no longer valid.
```

Remove the rejected development certificate, then regenerate managed signing assets:

```bash
./build-device.sh --default-signing --allow-provisioning-updates
```

## Xcode Beta And iOS 26.5 Checks

If Xcode says the iOS runtime or SDK is missing, verify that the SSH session is using Xcode beta:

```bash
xcode-select -p
xcodebuild -showsdks
xcrun devicectl list devices
```

Expected Xcode path:

```text
/Applications/Xcode-beta.app/Contents/Developer
```

The script exports that path through `DEVELOPER_DIR`, so it does not depend on the global `xcode-select` state.

## Troubleshooting

If the device is not found, confirm the iPhone is plugged in, paired, unlocked, and has Developer Mode enabled:

```bash
xcrun devicectl list devices
xcrun devicectl device info details --device 00008140-000518440C7B001C
```

If signing fails from SSH:

```bash
./build-device.sh --prepare-signing
./build-device.sh
```

Use this only for keychain access failures such as `errSecInternalComponent`, not when provisioning assets belong to the wrong team.

If install fails with `0xe8008018`, remove the rejected development certificate from the login keychain, then run:

```bash
./build-device.sh --default-signing --allow-provisioning-updates
./build-device.sh
```

If the app builds but does not launch, install without launching and start it manually from the phone:

```bash
./build-device.sh --skip-launch
```
