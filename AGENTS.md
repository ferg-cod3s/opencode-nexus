# AGENTS.md – OpenCode Nexus (Swift iOS App)

Native iOS client for OpenCode servers, built with SwiftUI and Liquid Glass (iOS 26+).

## Quick Start

```bash
# Build & run on simulator
cd ios-app
xcodebuild -project OpenCodeNexus.xcodeproj -scheme OpenCodeNexus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Install & launch (after build)
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/OpenCodeNexus-*/Build/Products/Debug-iphonesimulator/OpenCodeNexus.app
xcrun simctl launch booted com.agentic-codeflow.opencode-nexus
```

## Architecture

```
ios-app/OpenCodeNexus/
├── Models/          # Codable structs (Session, Message, HealthResponse, SSEEvent)
├── Services/        # OpenCodeClient (URLSession async/await + SSE)
├── ViewModels/      # @Observable classes (ConnectionManager, ChatViewModel)
├── Views/           # SwiftUI views (ConnectView, ChatView, MessageBubble, etc.)
├── Extensions/      # Date helpers
└── Assets.xcassets/ # App icons and colors
```

## OpenCode Server API

The app talks to an OpenCode server (`opencode serve`) via REST + SSE. No auth needed for localhost.

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/global/health` | GET | Health check |
| `/session` | GET/POST | List/create sessions |
| `/session/:id` | GET/DELETE | Get/delete session |
| `/session/:id/message` | GET/POST | List/send messages |
| `/session/:id/prompt_async` | POST | Send message async |
| `/session/:id/abort` | POST | Abort running session |
| `/config/providers` | GET | Available AI models |
| `/event` | GET (SSE) | Real-time event stream |

Full API docs: https://opencode.ai/docs/server/

## Code Style

- Swift 6.2, iOS 26.0+ deployment target
- `@Observable` for state, `async/await` for networking
- No third-party dependencies
- No comments in code
- Liquid Glass effects via `.glassEffect()`, `.buttonStyle(.glass)`
- 44pt minimum touch targets
- WCAG 2.2 AA accessibility

## Testing

```bash
# Unit tests
xcodebuild test -project OpenCodeNexus.xcodeproj -scheme OpenCodeNexus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Take screenshot
xcrun simctl io booted screenshot screenshot.png
```

## Key Files

| File | Purpose |
|------|---------|
| `Services/OpenCodeClient.swift` | HTTP + SSE client for OpenCode API |
| `ViewModels/ConnectionManager.swift` | Server URL, test/connect/disconnect |
| `ViewModels/ChatViewModel.swift` | Sessions, messages, SSE events |
| `Views/ConnectView.swift` | Server connection screen |
| `Views/ChatView.swift` | Main chat (NavigationSplitView) |
| `Views/MessageBubble.swift` | User/assistant message styling |
| `Views/MessageInputView.swift` | Message input + send button |
| `project.yml` | XcodeGen project spec |

## Agent Role: Build

Focus on:
- Writing idiomatic Swift/SwiftUI
- Following iOS 26 design patterns (Liquid Glass)
- Async/await error handling
- Keeping the API client in sync with OpenCode server changes
