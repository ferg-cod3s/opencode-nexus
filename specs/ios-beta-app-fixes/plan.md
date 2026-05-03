# iOS Beta App Fixes Implementation Plan

**Status**: Draft  
**Spec**: `specs/ios-beta-app-fixes/spec.md`  
**Target**: `ios-app/OpenCodeNexus/`

## Phase 1 — Archive persistence and recovery

### IOS-BETA-001 — Make archived session state a first-class source of truth
- **Depends**: None
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`
  - `ios-app/OpenCodeNexus/Services/OpenCodeClient.swift`
- **Acceptance**:
  - [ ] Session loading keeps enough state to distinguish active vs archived sessions without losing archived metadata needed for restore.
  - [ ] Archive/unarchive directory lookup works even after a session is removed from the active list.
  - [ ] Refresh and reconnect do not reinsert archived sessions into the active list from stale local state.
  - [ ] Archive/unarchive failures leave in-memory state consistent and surface actionable errors.
- **Complexity**: Medium
- **Estimate**: 45 min
- **Verify**:
  - [ ] Unit test archive, refresh, reconnect, and restore flows with mocked session payloads.

### IOS-BETA-002 — Add a dedicated Archived section with restore actions
- **Depends**: IOS-BETA-001
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`
  - `ios-app/OpenCodeNexus/Views/ChatView.swift`
  - `ios-app/OpenCodeNexus/Views/SessionHierarchyRow.swift`
- **Acceptance**:
  - [ ] Sidebar shows archived sessions in a discoverable dedicated section separate from active workspace groups.
  - [ ] Archived sessions can be restored directly from the Archived section.
  - [ ] Restored sessions reappear in the correct workspace grouping and sort order.
  - [ ] Active session selection clears cleanly when that session is archived.
- **Complexity**: Medium
- **Estimate**: 45 min
- **Verify**:
  - [ ] Manual simulator check for archive, refresh, restore, and grouping order.

### IOS-BETA-003 — Add archive lifecycle regression coverage
- **Depends**: IOS-BETA-002
- **Files**:
  - `ios-app/OpenCodeNexusTests/ChatViewModelExtendedTests.swift`
  - `ios-app/OpenCodeNexusTests/ChatViewModelTests.swift`
- **Acceptance**:
  - [ ] Tests cover archive persistence across reload.
  - [ ] Tests cover unarchive when the session is absent from the active list.
  - [ ] Tests cover archive/unarchive error handling without list corruption.
- **Complexity**: Low
- **Estimate**: 30 min
- **Verify**:
  - [ ] `bun run ios:test`

## Phase 2 — Live streaming and session freshness

### IOS-BETA-004 — Make selected-session streaming deterministic under out-of-order SSE
- **Depends**: None
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`
- **Acceptance**:
  - [ ] `message.created`, `message.updated`, `message.part.updated`, and `message.part.delta` reconcile even when events arrive out of order.
  - [ ] Selected-session assistant output updates incrementally during generation.
  - [ ] Final message state matches server state after idle.
  - [ ] Abort and error events stop streaming cleanly and clear optimistic state correctly.
- **Complexity**: High
- **Estimate**: 60 min
- **Verify**:
  - [ ] Event-sequence unit tests cover delta-before-create and update-before-part scenarios.

### IOS-BETA-005 — Keep sidebar and selected session fresh without stale reload overwrite
- **Depends**: IOS-BETA-004
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`
- **Acceptance**:
  - [ ] Selected session busy/idle state updates promptly.
  - [ ] Non-selected sessions receive lightweight freshness updates for status and recency metadata.
  - [ ] Switching away from a streaming session and back does not duplicate or drop messages.
  - [ ] Refresh logic does not overwrite newer in-memory selected-session message state with older server loads.
- **Complexity**: High
- **Estimate**: 60 min
- **Verify**:
  - [ ] Unit tests cover session switching during streaming and post-idle reconciliation.

### IOS-BETA-006 — Add streaming and status regression coverage
- **Depends**: IOS-BETA-005
- **Files**:
  - `ios-app/OpenCodeNexusTests/ChatViewModelTests.swift`
  - `ios-app/OpenCodeNexusIntegrationTests/SSEStreamTests.swift`
- **Acceptance**:
  - [ ] Tests cover live selected-session streaming.
  - [ ] Tests cover status transitions busy → idle and error/abort handling.
  - [ ] Tests cover non-selected session freshness without background transcript streaming.
- **Complexity**: Medium
- **Estimate**: 45 min
- **Verify**:
  - [ ] `bun run ios:test`

## Phase 3 — Cross-session permission handling

### IOS-BETA-007 — Track pending permissions across all sessions with stable context
- **Depends**: IOS-BETA-005
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`
- **Acceptance**:
  - [ ] Pending permissions remain indexed by session, not only by the selected session.
  - [ ] Each pending permission exposes enough session/workspace context for presentation.
  - [ ] Multiple concurrent permissions remain discoverable instead of overwriting each other.
  - [ ] Selected-session permissions still behave correctly.
- **Complexity**: Medium
- **Estimate**: 45 min
- **Verify**:
  - [ ] Unit tests cover selected and non-selected `permission.asked` events.

### IOS-BETA-008 — Present and act on cross-session permissions in-app
- **Depends**: IOS-BETA-007
- **Files**:
  - `ios-app/OpenCodeNexus/Views/ChatView.swift`
  - `ios-app/OpenCodeNexus/Views/PermissionSheet.swift`
  - `ios-app/OpenCodeNexus/Views/MessageListView.swift`
- **Acceptance**:
  - [ ] A permission from another session becomes visible without switching to the TUI.
  - [ ] Permission UI shows session and workspace context.
  - [ ] User can navigate to, approve, or reject the owning session’s permission from the app.
  - [ ] A non-selected-session permission does not hide an already pending selected-session permission.
- **Complexity**: Medium
- **Estimate**: 45 min
- **Verify**:
  - [ ] Manual simulator validation with two active sessions.

### IOS-BETA-009 — Add permission presentation regression coverage
- **Depends**: IOS-BETA-008
- **Files**:
  - `ios-app/OpenCodeNexusTests/ChatViewModelTests.swift`
  - `ios-app/OpenCodeNexusTests/ViewBodyTests.swift`
- **Acceptance**:
  - [ ] Tests cover multiple pending permissions from different sessions.
  - [ ] View smoke tests cover permission sheet rendering with cross-session context.
- **Complexity**: Low
- **Estimate**: 30 min
- **Verify**:
  - [ ] `bun run ios:test`

## Phase 4 — Composer layout on iPhone

### IOS-BETA-010 — Move terminal and attachment actions into a compact leading column
- **Depends**: None
- **Files**:
  - `ios-app/OpenCodeNexus/Views/MessageInputView.swift`
  - `ios-app/OpenCodeNexus/Views/MessageListView.swift`
- **Acceptance**:
  - [ ] On compact-width iPhone layouts, terminal and attachment controls no longer share the main text-entry row horizontally.
  - [ ] Terminal and attachment controls appear as a vertical leading action column beside the composer.
  - [ ] Send/abort remains reachable on the trailing side.
  - [ ] Model, agent, and reasoning chips remain on their existing separate row.
- **Complexity**: Medium
- **Estimate**: 45 min
- **Verify**:
  - [ ] Manual simulator comparison on an iPhone-sized device with keyboard shown.

### IOS-BETA-011 — Preserve accessibility and keyboard usability in the revised composer
- **Depends**: IOS-BETA-010
- **Files**:
  - `ios-app/OpenCodeNexus/Views/MessageInputView.swift`
  - `ios-app/OpenCodeNexusTests/ViewBodyTests.swift`
- **Acceptance**:
  - [ ] All controls keep 44pt minimum targets.
  - [ ] Accessibility labels remain accurate.
  - [ ] Dynamic Type and keyboard-visible states remain usable in portrait.
- **Complexity**: Low
- **Estimate**: 30 min
- **Verify**:
  - [ ] View smoke tests pass.
  - [ ] Manual Accessibility Inspector pass.

## Phase 5 — Final regression pass

### IOS-BETA-012 — Run the prioritized beta verification matrix
- **Depends**: IOS-BETA-003, IOS-BETA-006, IOS-BETA-009, IOS-BETA-011
- **Files**:
  - `ios-app/OpenCodeNexusTests/ChatViewModelTests.swift`
  - `ios-app/OpenCodeNexusTests/ChatViewModelExtendedTests.swift`
  - `ios-app/OpenCodeNexusIntegrationTests/SSEStreamTests.swift`
  - `ios-app/OpenCodeNexusTests/ViewBodyTests.swift`
- **Acceptance**:
  - [ ] Automated coverage exists for archive lifecycle, streaming event ordering, status freshness, and permission routing.
  - [ ] Simulator manual pass covers archive, restore, streaming, switching sessions, permissions, attachments, terminal access, and composer layout.
  - [ ] Real-device beta pass covers relaunch persistence, live streaming latency, and compact-width usability.
- **Complexity**: Medium
- **Estimate**: 60 min
- **Verify**:
  - [ ] `bun run ios:test`
  - [ ] Manual simulator pass against `opencode serve`
  - [ ] Real-device beta smoke pass

## Dependency order

1. Phase 1 can start immediately.
2. Phase 2 can start immediately, but Phase 3 should build on Phase 2 session-freshness behavior.
3. Phase 4 can run in parallel with Phases 1–3.
4. Phase 5 runs last.

## Verification checklist

### Automated
- [ ] `bun run ios:test`
- [ ] Archive/unarchive ViewModel tests pass
- [ ] Streaming event-sequence tests pass
- [ ] Permission routing tests pass
- [ ] View body smoke tests pass

### Simulator manual
- [ ] Archive a session, refresh, and confirm it stays archived
- [ ] Relaunch, reconnect, and confirm archived session stays out of the active list
- [ ] Restore from Archived and confirm workspace grouping/order
- [ ] Send a long prompt and watch live streaming in the open chat
- [ ] Switch sessions during streaming and confirm no duplicate or stale transcript
- [ ] Trigger permission requests from selected and non-selected sessions
- [ ] Verify terminal/attachment controls stack vertically on iPhone layout
- [ ] Verify chips stay on the row above the composer

### Real-device beta
- [ ] Relaunch persistence works on device
- [ ] Streaming remains near real time on device
- [ ] Cross-session permissions are actionable on device
- [ ] Composer remains readable and one-hand reachable on compact-width iPhone

## Traceability

| Spec area | Tasks |
|---|---|
| US-001 Persist Archived Sessions | IOS-BETA-001, IOS-BETA-002, IOS-BETA-003 |
| US-002 Recover Archived Sessions | IOS-BETA-001, IOS-BETA-002, IOS-BETA-003 |
| US-003 Stream Messages Live | IOS-BETA-004, IOS-BETA-006 |
| US-004 Keep Session State Fresh | IOS-BETA-005, IOS-BETA-006 |
| US-005 Improve Composer Readability | IOS-BETA-010, IOS-BETA-011 |
| US-006 Surface Cross-Session Permissions | IOS-BETA-007, IOS-BETA-008, IOS-BETA-009 |
| US-007 Validate Broader Beta Stability | IOS-BETA-012 |
