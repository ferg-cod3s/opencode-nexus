# OpenCode Nexus — Release Plan

## Current State Assessment

### What Exists
- **Tauri v2 app** targeting iOS, macOS (desktop), and potentially Android
- **Bundle ID:** `com.agentic-codeflow.opencode-nexus`
- **Version chaos:** `tauri.conf.json` says `0.1.30`, `package.json` says `0.0.0-dev002`, `Cargo.toml` says `0.1.30`
- **Development Team:** `PCJU8QD9FN` (already configured)
- **65 root markdown files** — session notes, status reports, build docs from prior agent sessions. These are noise and should be archived.
- **~15 root shell scripts** — overlapping iOS build scripts (`build-ios.sh`, `build-ios-enhanced.sh`, `build-ios-reliability.sh`, `build-ios-testflight.sh`, etc.). No clear canonical build path.
- **Xcode project** already generated in `src-tauri/gen/apple/` with iOS target, entitlements, and project.yml
- **CI/CD:** `.github/` exists but likely broken (per user report)
- **Test certs/keys committed** (`AuthKey_J94Q923ZNG.p8`, `test_cert.pem`, `test_key.pem`, `.mobileprovision`) — **SECURITY ISSUE**

### What Works (Likely)
- Frontend Svelte UI renders — chat interface, session management, model selector, connection management
- Frontend connects to `opencode serve` via `@opencode-ai/sdk` (HTTP-based REST API)
- Streaming via SSE (through SDK)
- Offline storage via IndexedDB (PWA-style fallbacks)
- Tauri desktop build probably works

### What's Broken / Risky
- iOS build/signing — user has hit permissioning issues
- iOS entitlements in `gen/apple/` are empty (`<dict/>`) while the real ones are in `src-tauri/ios-config/` — likely mismatch
- `MARKETING_VERSION: 0.0.0` in project.yml despite `0.1.30` in tauri.conf.json
- Mobile provisioning profile committed to repo
- CI/CD is in unknown state
- Excessive Rust backend that duplicates what the SDK does

---

## Architecture Decision: Rust Backend

### What the Rust Backend Does (~7,500 LOC across 10 modules)
The Rust backend in `src-tauri/src/` exposes **27 Tauri commands**:

| Category | Commands |
|----------|----------|
| **Connection** | `connect_to_server`, `test_server_connection`, `get_connection_status`, `get_current_connection`, `disconnect_from_server`, `get_saved_connections`, `save_connection`, `get_last_used_connection` |
| **Chat/Sessions** | `list_sessions`, `create_session`, `send_message`, `get_session_messages`, `subscribe_to_chat_events`, `delete_session`, `update_session_title`, `get_session_stats` |
| **Streaming** | `start_message_stream`, `stop_message_stream`, `get_active_streams` |
| **Models** | `get_available_models`, `get_model_preferences`, `set_model_preferences`, `set_default_model` |
| **Utility** | `greet`, `get_application_logs`, `log_frontend_error`, `clear_application_logs` |

### What the Frontend SDK Does
The frontend already imports and uses `@opencode-ai/sdk` directly:
- `frontend/src/lib/opencode-client.ts` — wraps `createOpencodeClient` from SDK
- `frontend/src/lib/sdk-api.ts` — chat operations using SDK directly
- `frontend/src/stores/chat.ts` — Svelte stores managing sessions, messages, streaming

**The frontend only calls `invoke()` 4 times** (all for connection persistence: `save_connection`, `get_saved_connections`, `get_last_used_connection`). Everything else goes through the JS SDK.

### Verdict: **CUT THE RUST BACKEND (mostly)**

**Justification:**
1. The `@opencode-ai/sdk` already provides type-safe HTTP clients for all chat/session/streaming operations
2. The Rust backend *duplicates* SDK functionality — connection manager, session manager, streaming client, model manager, API client — all reimplemented in Rust for no gain
3. The frontend already prefers the SDK path; Rust commands are barely invoked
4. Keeping 7,500 LOC of Rust that shadows the SDK creates a maintenance nightmare
5. iOS builds are faster with less Rust code to compile

**What to keep:**
- Connection persistence (save/load connections) — 3-4 simple Tauri commands using `tauri-plugin-store` or a small custom store
- Logging utility — trivial
- `greet` — remove

**What to cut:**
- `api_client.rs`, `chat_client.rs`, `connection_manager.rs`, `event_bridge.rs`, `model_manager.rs`, `session_manager.rs`, `streaming_client.rs` — all dead/duplicate code
- `chat_client_example.rs` — obviously

---

## iOS Build & Signing Requirements

### Prerequisites
1. **Apple Developer Account** ($99/year) — already enrolled (team ID `PCJU8QD9FN`)
2. **Xcode 16+** on a Mac (already have)
3. **Rust iOS targets:**
   ```bash
   rustup target add aarch64-apple-ios
   rustup target add aarch64-apple-ios-sim  # for simulator
   ```

### Step-by-Step Signing Setup

#### Option A: Automatic Signing (Recommended for development)
1. Open Xcode → Settings → Accounts → add Apple ID
2. In `project.yml`, ensure `developmentTarget` and `DEVELOPMENT_TEAM` are set (they are)
3. Xcode will auto-manage provisioning profiles

#### Option B: Manual Signing (Required for CI/CD)
1. Create an **Apple Distribution Certificate** in [Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Export as `.p12` from Keychain Access → base64 encode:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```
3. Create a **Provisioning Profile** in [Profiles](https://developer.apple.com/account/resources/profiles/list)
   - Type: App Store Distribution
   - App: `com.agentic-codeflow.opencode-nexus`
   - Certificate: the one from step 1
4. Download profile → base64 encode
5. Set CI environment variables:
   - `IOS_CERTIFICATE` — base64 of .p12
   - `IOS_CERTIFICATE_PASSWORD` — password used during export
   - `IOS_MOBILE_PROVISION` — base64 of .mobileprovision

#### For App Store Connect API (CI/CD):
1. App Store Connect → Users & Access → Integrations → Add API Key (Admin role)
2. Note Issuer ID, Key ID, download .p8 file
3. Set environment variables:
   - `APPLE_API_ISSUER`
   - `APPLE_API_KEY`
   - `APPLE_API_KEY_PATH`

### Build Commands
```bash
# Development (simulator)
bun run tauri ios dev

# Release build (device)
bun run tauri ios build --release

# Xcode route (more control)
open src-tauri/gen/apple/src-tauri.xcodeproj
# Then Product → Archive → Distribute App
```

### Known Issues to Fix First
1. **Empty entitlements in gen/apple** — the real entitlements are in `src-tauri/ios-config/` but `gen/apple/src-tauri_iOS/src-tauri_iOS.entitlements` is empty `<dict/>`. Need to sync or regenerate.
2. **MARKETING_VERSION 0.0.0** — should match `tauri.conf.json` version
3. **ExportOptions.plist** has `method: debugging` — should be `app-store` for distribution

---

## Feature Scope for v0.1.0 MVP

### ✅ Include
| Feature | Status | Notes |
|---------|--------|-------|
| Connect to `opencode serve` | Works via SDK | HTTP REST + SSE streaming |
| Chat interface | Built | Svelte components exist |
| Session management | Built | List, create, switch sessions |
| Message streaming | Built | SSE via SDK |
| Model selector | Built | Component exists |
| Connection management | Built | Save/switch servers |
| Offline indicator | Built | Component exists |
| Basic settings page | Built | Page exists |

### ❌ Cut from v0.1.0
| Feature | Reason |
|---------|--------|
| PWA/Service Worker | Not needed for native iOS app |
| QR setup flow | Nice-to-have, manual connection entry is fine for v0.1 |
| Sync controls/history | Premature optimization |
| Activity feed | Nice-to-have |
| Sentry crash reporting | Can add post-launch |
| Android support | Focus iOS first |
| File upload in chat | Complex, defer |

---

## Technical Implementation Plan

### Phase 0: Cleanup (1-2 days)
- [ ] Archive 65 root markdown files into `docs/archive/`
- [ ] Consolidate 15 iOS build scripts into one canonical `scripts/build-ios.sh`
- [ ] Remove committed secrets (`.p8`, `.pem`, `.mobileprovision`) — add to `.gitignore`
- [ ] Unify version: set everything to `0.1.0`
- [ ] Remove `chat.js`, `login.js` (dead JS files in `frontend/src/`)

### Phase 1: Rust Backend Simplification (2-3 days)
- [ ] Remove 7 duplicate Rust modules (api_client, chat_client, connection_manager, event_bridge, model_manager, session_manager, streaming_client)
- [ ] Keep only: `lib.rs` (simplified), `error.rs`, connection persistence commands
- [ ] Add `tauri-plugin-store` for connection persistence
- [ ] Update `Cargo.toml` — remove unused deps (tokio, reqwest, futures, sysinfo, sentry, etc.)
- [ ] Verify all frontend paths still work

### Phase 2: iOS Build Fixes (1-2 days)
- [ ] Regenerate Xcode project: `bun run tauri ios init` (or update `project.yml`)
- [ ] Fix entitlements — copy proper entitlements to gen/apple location or add to project.yml
- [ ] Fix `MARKETING_VERSION` in project.yml
- [ ] Fix `ExportOptions.plist` method
- [ ] Test simulator build: `bun run tauri ios dev`
- [ ] Test device build: `bun run tauri ios build --release`

### Phase 3: UI Polish for Mobile (3-5 days)
- [ ] Mobile-responsive layouts (Svelte + Tailwind or whatever CSS is used)
- [ ] Touch-friendly input area
- [ ] Proper iOS safe area handling (notch, home indicator)
- [ ] Splash screen / launch screen
- [ ] App icon (proper iOS icon set)
- [ ] Remove PWA components (ServiceWorkerRegistration, PWAInstallPrompt)
- [ ] Test on physical device

### Phase 4: TestFlight & Distribution (2-3 days)
- [ ] Create app record in App Store Connect
- [ ] Upload build via Xcode Organizer or `xcrun altool`
- [ ] Configure TestFlight testers
- [ ] Write App Store description, screenshots, privacy policy URL
- [ ] Submit for TestFlight beta review

**Total estimate: 9-15 days of focused work**

---

## Distribution Plan

### TestFlight (Recommended First Step)
1. Upload archive to App Store Connect
2. Add internal testers (up to 100 by email)
3. No App Store review needed for internal testing
4. External testing requires a brief beta app review (1-2 days)
5. Can distribute builds rapidly for dogfooding

### App Store
**Requirements:**
- App Store Connect record with description, keywords, screenshots, privacy policy URL
- Privacy policy required (the app connects to user-hosted servers, so relatively simple)
- App Review Guidelines compliance
- The app must do something useful standalone — since it connects to user-run `opencode serve`, App Review may flag this. Be prepared to explain it's a client for self-hosted servers.

**Privacy considerations for App Store:**
- No data collection by the app itself (connects to user's own server)
- Need privacy policy URL stating this
- Apple may require an "onboarding" screen explaining the app needs an `opencode serve` endpoint

### Alternative: Ad-Hoc / Enterprise Distribution
- Ad-hoc: up to 100 devices per year, registered by UDID
- Enterprise: requires Enterprise Developer account ($299/year)
- Not recommended — App Store is the path

---

## Known Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **App Review rejection** — "app requires external server" | High | Build a demo/mock mode that works without a server. Add clear onboarding explaining the app is a client for self-hosted opencode. |
| **Rust compile time on iOS** | Medium | Cutting the dead Rust backend code will help significantly. Use `release-ios` profile. |
| **SSE/streaming on iOS background** | Medium | iOS kills background network connections. App should handle reconnection gracefully. |
| **opencode SDK breaking changes** | Medium | Pin SDK version. The SDK is at v1.14.20 and actively maintained by anomalyco. |
| **Tauri v2 iOS stability** | Medium | Tauri v2 iOS support is relatively new but production-ready per Tauri docs. Community is actively using it. |
| **Signing/provisioning complexity** | Low | Use automatic signing for dev. Manual only needed for CI. Team ID is already configured. |
| **65 root markdown files making repo unmaintainable** | Low | Archive them in Phase 0. |

---

## Appendix: How opencode serve Works

The `@opencode-ai/sdk` connects to an HTTP server (default `http://localhost:4096`) that's started by `opencode serve`. Key API surfaces:

- **Sessions:** CRUD for chat sessions
- **Messages/Prompt:** Send messages, receive streaming responses via SSE
- **Models:** List available models, get/set model preferences
- **Files:** Read/write project files

The SDK (`@opencode-ai/sdk`) provides:
- `createOpencode()` — starts server + creates client
- `createOpencodeClient({ baseUrl })` — client-only, connects to existing server
- Type-safe methods: `client.session.*`, `client.chat.*`, etc.

For Nexus mobile, we use `createOpencodeClient` with a user-provided URL pointing to their `opencode serve` instance (possibly tunneled via Cloudflare/Tailscale).
