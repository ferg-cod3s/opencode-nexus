# iOS Client Stabilization Spec

## Objective

Stabilize and simplify the OpenCode Nexus iOS client while preserving current user-facing functionality. The work focuses on API parity with the OpenCode server/TypeScript SDK, robust server-sent event handling, safer SwiftUI state ownership, targeted tests, and smaller maintainable SwiftUI views.

The target users are developers using OpenCode Nexus as a native iOS client for `opencode serve`. They need reliable connection/session/message behavior, responsive streaming updates, clear recoverable errors, and an interface that remains native to iOS 26 Liquid Glass.

Success criteria:

- The app connects to a real `opencode serve` instance and supports the current core session/message workflows.
- Swift API models and endpoints stay aligned with the TypeScript SDK/server contract.
- Event streaming is resilient to cancellation, malformed events, and session switching.
- ViewModels have clear async task ownership and main-actor-safe state updates.
- Core API, decoding, SSE, and ViewModel behavior are covered by tests before larger UI refactors.
- `ChatView.swift` and `MessageInputView.swift` become easier to read without behavior regressions.
- Accessibility and iOS 26 Liquid Glass conventions remain intact or improve.

## Interface Contracts

### Native Swift API Client

The production networking interface remains a native Swift client built on `URLSession`, async/await, Codable models, and native SSE parsing.

Expected contract areas:

- Health check: `GET /global/health`
- Sessions: `GET /session`, `POST /session`, `GET /session/:id`, `DELETE /session/:id`
- Messages: `GET /session/:id/message`, `POST /session/:id/message`
- Async prompt: `POST /session/:id/prompt_async`
- Abort: `POST /session/:id/abort`
- Providers/models: `GET /config/providers`
- Events: `GET /event` via SSE

The Swift client must preserve these behavioral contracts:

- Request payloads must match server expectations.
- Response models must tolerate unknown JSON fields.
- Optional server fields must decode safely.
- Missing required fields must produce actionable decoding errors during development.
- Cancellation must not be presented as a scary user-facing failure.
- Non-2xx responses must include status and diagnostic body context where available.

### SSE Event Contract

The event stream must provide one active stream per connected client. Events must be parsed according to SSE semantics, including multi-line `data:` fields.

Required behaviors:

- Start the stream only after a valid client is configured.
- Stop the stream on disconnect and view disappearance.
- Avoid duplicate listeners across repeated view tasks or reconnects.
- Ignore or safely log malformed events instead of crashing.
- Prevent stale events from mutating the wrong selected session.

### ViewModel Contract

`ConnectionManager` owns connection-level state and the configured client. `ChatViewModel` owns chat/session/message state for the currently connected server.

Required behaviors:

- UI-observed state mutations happen on the main actor.
- Long-lived async work has explicit task ownership and cancellation.
- Rapid connect, disconnect, send, abort, and session switching leave UI state consistent.
- ViewModels remain testable without a real network by depending on mockable client boundaries where practical.

### JS/TS SDK Contract Decision

The TypeScript SDK remains the reference contract, not the iOS runtime dependency.

Decision:

- Do not replace the native Swift API client with a `WKWebView` or `JavaScriptCore` bridge for production networking.
- Use the TypeScript SDK/generated client as a parity reference.
- Prefer contract fixtures, schema comparisons, or generated Swift bindings only if a stable OpenCode schema becomes available.

Rationale:

- `WKWebView` adds browser lifecycle, debugging, serialization, and App Store review risk for core networking.
- `JavaScriptCore` lacks browser/Node APIs like `fetch`, `EventSource`, and streams without polyfills.
- SSE, cancellation, large payloads, and async error translation are simpler and safer in native Swift.

## Project Structure

Existing files likely to change:

- `ios-app/OpenCodeNexus/Services/OpenCodeClient.swift`
- `ios-app/OpenCodeNexus/Models/*.swift`
- `ios-app/OpenCodeNexus/ViewModels/ConnectionManager.swift`
- `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`
- `ios-app/OpenCodeNexus/Views/ChatView.swift`
- `ios-app/OpenCodeNexus/Views/MessageInputView.swift`
- `ios-app/OpenCodeNexus/Views/MessageListView.swift`
- `ios-app/OpenCodeNexus/Views/MessageBubble.swift`
- `ios-app/OpenCodeNexus/Views/SessionRow.swift`

New files may be created only where they reduce complexity or enable tests:

- `ios-app/OpenCodeNexus/Views/SessionSidebar.swift`
- `ios-app/OpenCodeNexus/Views/SessionDetailView.swift`
- `ios-app/OpenCodeNexus/Views/ChatModalDestination.swift` or equivalent enum-backed modal state type
- `ios-app/OpenCodeNexusTests/OpenCodeClientTests.swift`
- `ios-app/OpenCodeNexusTests/SSEParserTests.swift`
- `ios-app/OpenCodeNexusTests/ChatViewModelTests.swift`
- `ios-app/OpenCodeNexusTests/Fixtures/*.json`

Implementation priority:

1. API parity and decoding resilience.
2. SSE/event stream robustness.
3. ViewModel state ownership and cancellation.
4. Contract-focused tests for API/SSE/ViewModels.
5. `ChatView.swift` extraction.
6. Modal/sheet state simplification.
7. `MessageInputView.swift` cleanup.
8. Accessibility and Liquid Glass polish.

## Code Style

Swift conventions:

- Use Swift 6.2, SwiftUI, iOS 26+, and async/await.
- Keep state models `@Observable` where already used by the app.
- Keep UI-bound async state mutations main-actor safe.
- Prefer small, direct types over broad abstractions.
- Prefer native Swift networking and parsing for app runtime behavior.
- Keep changes incremental and behavior-preserving unless explicitly called out.
- Do not add third-party dependencies unless approved first.
- Do not add comments unless the code is otherwise hard to understand.
- Use existing naming and file organization patterns.
- Preserve Liquid Glass patterns: `.glassEffect()`, `.buttonStyle(.glass)`, native SwiftUI controls, and existing `Theme` usage.

Error handling conventions:

- Distinguish invalid URL, unreachable server, non-2xx response, decoding failure, stream failure, and cancellation.
- Preserve diagnostics for development without overwhelming users.
- Avoid treating intentional cancellation as a user-facing error.

Refactor conventions:

- Extract views when it removes clear responsibility overload.
- Do not create generic helpers unless at least two call sites benefit immediately.
- Keep extracted views explicit about input state and actions.
- Do not introduce compatibility shims for unused or hypothetical APIs.

## Testing Strategy

Test command:

```bash
bun run ios:test
```

Equivalent direct command:

```bash
xcodebuild test -project OpenCodeNexus.xcodeproj -scheme OpenCodeNexus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData/Simulator
```

Required test categories:

- Unit tests for URL construction and request configuration.
- Codable fixture tests for session, message, provider/model, and event payloads.
- SSE parser tests covering normal events, multi-line data, malformed events, and stream termination.
- ViewModel tests using a mockable client boundary for loading sessions, selecting sessions, sending messages, aborting, and surfacing errors.
- Build verification after each implementation phase.

Coverage target:

- Minimum 80% coverage for new pure parsing/model/client helper logic where measurable.
- Critical-path coverage is more important than broad UI snapshot coverage for this phase.

Critical paths to verify:

- Connect to server.
- Load sessions.
- Select session and load messages.
- Send message.
- Abort active session.
- Receive streaming updates.
- Disconnect and cancel streaming.
- Recover from network, server, decoding, and malformed SSE errors.

## Boundaries

Always do:

- Keep the native Swift client as the production networking path.
- Compare Swift API behavior against the TypeScript SDK/server contract before changing models or endpoints.
- Preserve current user-facing behavior unless a behavior change is explicitly approved.
- Keep the app buildable and testable after each phase.
- Respect iOS 26 Liquid Glass and existing visual language.
- Maintain 44pt minimum touch targets for custom controls.
- Add accessibility labels/hints where custom controls are not self-describing.

Ask first:

- Replacing native Swift networking with a JS/TS bridge.
- Adding third-party dependencies.
- Introducing code generation into the build.
- Changing visible interaction flows, navigation, or modal presentation behavior.
- Dropping support for any existing OpenCode server endpoint currently used by the app.
- Adding persistent data migrations or storage format changes.

Never do:

- Do not execute downloaded or remotely mutable JavaScript as part of core app behavior.
- Do not use `WKWebView` or `JavaScriptCore` as the production API client without a separate approved prototype/spec.
- Do not hide decoding or server errors in a way that makes API drift hard to diagnose.
- Do not allow duplicate event streams for the same connection.
- Do not mutate SwiftUI-observed state from unsafe concurrency contexts.
- Do not remove existing session/message/permission/question/diff/file/terminal flows during cleanup.

## Approval Gate

This spec should be reviewed and approved before proceeding to `/plan`. The next step after approval is to generate an implementation plan with atomic tasks, dependencies, files, acceptance criteria, and estimates.
