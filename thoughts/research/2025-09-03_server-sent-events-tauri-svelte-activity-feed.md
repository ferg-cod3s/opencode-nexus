---
date: 2025-09-04T04:28:02Z
researcher: Claude
git_commit: a49c901455f76ebecb499ba526a3fdcb0bf2d6fb
branch: main
repository: opencode-nexus
topic: "server sent events and tauri event emissions and svelte activity feed"
tags: [research, codebase, tauri, svelte, event-streaming, activity-feed, accessibility]
status: complete
last_updated: 2025-09-03
last_updated_by: Claude
---

## Ticket Synopsis
Research the implementation and best practices for server-sent events, Tauri event emission, and Svelte activity feed integration in OpenCode Nexus.

## Summary
OpenCode Nexus implements real-time activity feed updates by emitting events from the Rust backend (Tauri) and subscribing to these events in the Svelte frontend. The backend uses Tauri's event system (`emit`, `emit_all`) to push events to the frontend, which listens for these events, updates a Svelte store, and displays them in a reactive activity feed component. The architecture is accessibility-first and minimizes polling, relying on event-driven updates for performance and inclusivity.

## Detailed Findings

### Backend: Event Emission (Rust/Tauri)
- Uses `tokio::sync::broadcast` for internal event fan-out ([src-tauri/src/server_manager.rs:121,148,215-681]).
- Emits events to the frontend using `app_handle.emit_all("server_event", event)` ([src-tauri/src/server_manager.rs:494-497]).
- Events are emitted at all major server lifecycle transitions (start, stop, error, config change, health check, session update).
- Tauri command handlers in `src-tauri/src/lib.rs` invoke these event emissions as part of server management actions.

### Frontend: Svelte Activity Feed
- Svelte store (`activity.ts`) holds the activity feed state and subscribes to Tauri events using `listen` from `@tauri-apps/api/event` ([frontend/src/stores/activity.ts]).
- On receiving a `server_event`, the store prepends a new activity item, capping the feed at 10 items for performance.
- The `ActivityFeed.svelte` component subscribes to the store and renders the feed with ARIA live regions and keyboard navigation ([frontend/src/components/ActivityFeed.svelte]).
- The dashboard page (`dashboard.astro`) includes the activity feed and sets up event listeners for real-time updates ([frontend/src/pages/dashboard.astro:663-1187]).

### Event Streaming Patterns
- **Preferred**: Use Tauri's event system for backend-to-frontend real-time communication. SSE is not used; Tauri's IPC is more efficient for desktop apps.
- **Fallback**: Polling is only used for metrics not available via events (e.g., resource usage), and at a reduced frequency.
- **Accessibility**: All activity feed updates are announced to screen readers using ARIA live regions and proper roles.

### Best Practices (2024-2025)
- Use `emit_all` in Rust to broadcast events to all frontend windows.
- Use Svelte stores for reactive state management and UI updates.
- Limit the number of displayed events for performance.
- Use ARIA live regions and keyboard navigation for accessibility ([Smashing Magazine, 2024]).
- No major breaking changes in Tauri or Svelte event APIs since 2024.

## Code References
- `src-tauri/src/server_manager.rs:494-497` – Emits events to frontend via Tauri
- `src-tauri/src/server_manager.rs:121,148,215-681` – Event broadcasting and subscription
- `frontend/src/stores/activity.ts` – Svelte store for activity feed, event subscription
- `frontend/src/components/ActivityFeed.svelte` – Activity feed UI, accessibility
- `frontend/src/pages/dashboard.astro:663-1187` – Event listener setup and feed integration
- `docs/ARCHITECTURE.md` – Describes event-driven architecture

## Architecture Insights
- **Event-driven updates**: Backend emits events for all major state changes; frontend listens and updates UI reactively.
- **Svelte store as event sink**: Centralizes activity feed logic and enables testable, maintainable updates.
- **Accessibility-first**: ARIA live regions, keyboard navigation, and screen reader support are built-in.
- **Performance**: Feed length is capped, and polling is minimized.
- **Type safety**: Event payloads are typed in both Rust and TypeScript.

## Historical Context (from thoughts/)
- `thoughts/plans/message-streaming-display-improvement.md` – Plan to migrate from polling to real-time event streaming, Svelte store, and accessibility improvements.
- `thoughts/plans/opencode-apis-first-implementation.md` – Describes integrating OpenCode server APIs and event streaming.
- `thoughts/plans/opencode-nexus-mvp-implementation.md` – Mentions extending event system for metrics and real-time updates.
- `thoughts/research/2025-09-03_message-streaming-display.md` – Research on polling-based system, event emission, and Svelte feed.

## Related Research
- `thoughts/research/2025-09-03_message-streaming-display.md` – Analysis of message streaming and event emission.

## Open Questions
- How to handle event loss or missed events if the frontend is temporarily disconnected?
- What fallback strategies should be used if Tauri event system fails?
- Should event payload formats be further standardized for all event types?

