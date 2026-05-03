# OpenCode Nexus

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A native iOS client for OpenCode servers, built with SwiftUI and Liquid Glass (iOS 26+).

## Features

- **Native iOS app** — SwiftUI with Liquid Glass design language
- **Connect to any OpenCode server** — `opencode serve` on localhost or remote
- **Real-time chat** — Session management with SSE event streaming
- **No dependencies** — Pure Swift, URLSession, zero third-party packages
- **iOS 26 Liquid Glass** — Translucent, adaptive materials throughout

## Quick Start

Root-level Bun scripts wrap the common iOS commands:

```bash
bun run ios:build
bun run ios:device
```

```bash
# Prerequisites: Xcode 26, iOS 26 simulator

# Build and run
cd ios-app
xcodebuild -project OpenCodeNexus.xcodeproj -scheme OpenCodeNexus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData/Simulator build

# Or open in Xcode
open OpenCodeNexus.xcodeproj
```

If `.xcodeproj` opens in another app, open it with Xcode beta explicitly:

```bash
open -a /Applications/Xcode-beta.app /Users/johnferguson/Github/opencode-nexus/ios-app/OpenCodeNexus.xcodeproj
```

## Build For A Physical iPhone

The iOS app includes an SSH-friendly device build script:

```bash
bun run ios:device
```

That command builds with Xcode beta, installs to the paired iPhone, and launches `com.agenticcodeflow.opencodenexus`. If SSH signing fails because the login keychain is locked, prepare signing first:

```bash
bun run ios:device:prepare-signing
```

See [ios-app/README.md](ios-app/README.md) for the full device workflow, Xcode beta checks, signing certificate notes, and troubleshooting.

## OpenCode Server

The app connects to an OpenCode server via REST + SSE:

```bash
# Start a server
opencode serve --port 4096

# Then in the app, connect to http://localhost:4096
```

See [OpenCode Server Docs](https://opencode.ai/docs/server/) for full API reference.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI + Liquid Glass (iOS 26) |
| Networking | URLSession async/await + SSE |
| State | @Observable (Swift 6.2) |
| Platform | iOS 26.0+, no dependencies |

## Project Structure

```
ios-app/OpenCodeNexus/
├── Models/          # Codable API models
├── Services/        # OpenCodeClient (HTTP + SSE)
├── ViewModels/      # @Observable state management
├── Views/           # SwiftUI views
├── Extensions/      # Date formatting helpers
└── Assets.xcassets/ # Icons and colors
```

## License

[MIT](LICENSE)
