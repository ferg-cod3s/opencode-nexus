---
date: 2025-09-03T00:00:00Z
researcher: Claude
git_commit: a49c901455f76ebecb499ba526a3fdcb0bf2d6fb
branch: main
repository: opencode-nexus
topic: "message streaming and display for our app"
tags: [research, codebase, message-streaming, message-display, tauri, accessibility]
status: complete
last_updated: 2025-09-03
last_updated_by: Claude
---

## Ticket Synopsis
> message streaming and display for our app

## Summary
Message streaming in OpenCode Nexus is implemented as a polling-based system where the backend (Rust/Tauri) emits server events to an internal broadcast channel, and the frontend (Astro/TypeScript) polls backend state every 5 seconds via Tauri commands to retrieve and display new messages. Message display is handled in the dashboard page via direct DOM manipulation, with new messages prepended to an activity list, timestamped, and capped at 10 items. Global alerts and errors use accessible ARIA live regions and roles, particularly in login.astro. No real-time push/event subscription exists yet; all updates are driven by polling and command responses.

## Detailed Findings

### Backend Message Streaming Components
- **Server Event Broadcasting:** Uses `tokio::sync::broadcast` channels in `ServerManager` for streaming server lifecycle and health events to multiple subscribers.
  - Events are sent at major lifecycle transitions (start, stop, error, config change, health check).
  - `subscribe_to_events()` returns a `broadcast::Receiver<ServerEvent>` for consumers.
- **Background Event Streaming:** Background async tasks periodically emit health check and error events.
- **Tauri Command Handlers:** Tauri commands wrap event-producing actions for frontend integration.
- **Test Subscription:** Tests subscribe to the broadcast channel to verify event emission.

### Frontend Message Display Components
- **Activity/Event Stream Rendering:** `addActivity(message)` in dashboard.astro prepends new messages to an activity list, timestamps them, and keeps only the 10 most recent.
- **State Management and UI Update:** State is fetched from backend via Tauri `invoke`, and UI is updated by direct DOM manipulation.
- **Periodic/Streamed Updates:** Uses polling (`setInterval`) to fetch new state/events and update UI every 5 seconds.
- **Error and Alert Message Display:** Centralized alert system in login.astro for global messages, with ARIA roles and auto-dismiss for success.
- **Loading/Status Messages:** Simple static messages in index.astro.

### Tauri IPC and Command Handlers
- `src-tauri/src/lib.rs`: Main location for Tauri command handlers (`#[tauri::command]`), defines IPC endpoints for backend/frontend communication.
- `src-tauri/src/main.rs`: Registers command handlers, sets up Tauri runtime, event listeners/emitters for real-time communication.
- `src-tauri/src/server_manager.rs`: Manages server processes, may include functions for streaming logs/status/events.
- `src-tauri/src/onboarding.rs`: Handles onboarding logic, possibly real-time progress updates.
- `src-tauri/src/api_client.rs`: Handles backend API requests, may include streaming/real-time communication.
- `src-tauri/tauri.conf.json`: Tauri config, defines allowed IPC commands and event permissions.

### Accessibility Patterns in Message Display
- **ARIA Roles and Live Regions:** Error messages use `role="alert"` and `aria-live="polite"`; global alerts use `role="alert"`, `aria-live="assertive"`, `aria-atomic="true"`.
- **Keyboard Navigation and Focus Management:** Focus styles for interactive elements, programmatic focus management.
- **Screen Reader Support:** `aria-hidden="true"` on decorative icons, `aria-describedby` and `aria-invalid` for context.
- **login.astro:** Implements robust accessibility for message display.
- **dashboard.astro:** Focuses on keyboard navigation but lacks explicit ARIA/live region for status messages.
- **index.astro:** Loading message is accessible as static text but not as a live region.

## Code References
- `src-tauri/src/server_manager.rs:69-326` - Server event broadcasting with tokio::sync::broadcast
- `src-tauri/src/server_manager.rs:457-514` - Background event streaming (health monitoring)
- `src-tauri/src/lib.rs:13-414` - Tauri command handlers for IPC
- `src-tauri/src/server_manager.rs:642-649` - Event subscription in tests
- `frontend/src/pages/dashboard.astro:840-859` - Activity stream rendering (addActivity method)
- `frontend/src/pages/dashboard.astro:598-864` - State management and UI update logic
- `frontend/src/pages/dashboard.astro:861-867` - Periodic polling for updates
- `frontend/src/pages/login.astro:808-825` - Global alert system with ARIA roles
- `frontend/src/pages/index.astro:11-14` - Loading/status message display
- `docs/ARCHITECTURE.md` - High-level architecture, backend/frontend communication patterns, Tauri IPC usage

## Architecture Insights
- **Polling-based Streaming:** Backend emits events internally but does not push them to frontend via Tauri events; frontend polls backend state via Tauri commands.
- **Direct DOM Manipulation:** Activity feed is managed by prepending new messages to a DOM list, not via Svelte stores or reactive state.
- **Command-based IPC:** All frontend-backend communication is via Tauri commands, not event emission.
- **Accessibility:** Robust in login.astro with ARIA roles, live regions, keyboard navigation, and screen reader support; dashboard.astro focuses on keyboard navigation but lacks explicit ARIA for status messages.
- **Event Broadcasting Pattern:** Uses `tokio::sync::broadcast` for multi-subscriber event streaming in backend.
- **No Real-time Push:** All updates are driven by polling and command responses, not real-time event subscription.

## Historical Context (from thoughts/)
- No specific thoughts/ documents on message streaming or display.
- Implementation plan (`thoughts/plans/opencode-nexus-mvp-implementation.md`) emphasizes event-driven architecture, real-time updates, and accessibility as core requirements.
- Research summary (`thoughts/research/opencode-nexus-mvp-research.md`) confirms TDD, accessibility, and security as first-class requirements.
- Architecture overview (`docs/ARCHITECTURE.md`) describes layered architecture with Tauri backend and web interface, including data flow for user interaction and server status.

## Related Research
- `thoughts/plans/opencode-nexus-mvp-implementation.md` - Implementation plan, event-driven architecture, accessibility
- `thoughts/research/opencode-nexus-mvp-research.md` - Research summary, requirements, and constraints
- `docs/ARCHITECTURE.md` - Technical architecture, security, and accessibility guidelines

## Open Questions
- Would real-time push (Tauri event emission) improve UX over polling?
- Should activity feed move to a Svelte store/component for better reactivity?
- Should dashboard.astro add ARIA live regions for activity messages?
- How does the current polling-based system scale with more frequent updates?
- Are there plans to implement real-time event streaming in future phases?