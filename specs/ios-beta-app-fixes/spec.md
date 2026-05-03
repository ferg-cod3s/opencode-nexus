# iOS Beta App Fixes Specification

## Overview

This specification defines the next stabilization pass for the OpenCode Nexus iOS beta focused on five user-visible issues: session archiving persistence, real-time message streaming behavior, cross-session permission handling, chat input action layout, and broader beta test coverage.

The target user is a developer using the native iOS client to manage and continue OpenCode sessions without losing state, needing to trust that session actions persist, chat updates appear live, and the composer remains readable on iPhone-sized screens.

## Context

### User Personas

- Beta tester: validating whether the iOS client is reliable enough for daily use.
- Developer using OpenCode on mobile: needs session continuity, live streaming, and fast chat interaction on a narrow screen.

### System Context

- This work applies to the native iOS app under `ios-app/OpenCodeNexus/`.
- Session loading, selection, archive actions, and SSE updates are primarily owned by `ViewModels/ChatViewModel.swift`.
- API contracts are owned by `Services/OpenCodeClient.swift`.
- The chat action layout spans `Views/MessageInputView.swift`, `Views/MessageListView.swift`, and `Views/ChatView.swift`.
- Existing app conventions to preserve: SwiftUI, iOS 26 Liquid Glass styling, 44pt minimum touch targets, async/await, and `@Observable` state.

### Research Context

Code inspection of the current iOS implementation found the following relevant behavior:

- Archived sessions are filtered out during `loadSessions()`, and archive success currently removes the session from the in-memory list immediately.
- `unarchiveSession()` currently depends on resolving the session directory from the active session list, which may fail after archiving removes the session from that list.
- SSE handling is heavily scoped to `selectedSessionId`, which increases the chance that non-selected session metadata becomes stale.
- Permission presentation is also scoped to `selectedSessionId` in the current SwiftUI flow, which means a permission request from another session can arrive, block server-side progress, and never surface as a visible modal unless the user manually switches contexts.
- Message delta handling relies on message and part records already existing locally; buffered deltas help, but update propagation is still sensitive to event ordering and selected-session state.
- The attached screenshot confirms the current horizontal composer layout leaves too little room for readable text entry on iPhone screens because the terminal and attachment icons sit in the same row as the text composer on the leading side, forcing the text field into a narrow central area.
- The screenshot also shows the model, agent, and reasoning chips already occupy a separate row above the composer, so the requested change should target the terminal and attachment controls specifically rather than assuming the full input area needs to be rebuilt.

## User Stories

### US-001: Persist Archived Sessions

**As a** beta user
**I want** archived sessions to stay archived after refresh and relaunch
**So that** I can clean up my session list without archived sessions reappearing unexpectedly

#### Acceptance Criteria

- [ ] Archiving a session persists after pull-to-refresh of the session list.
- [ ] Archiving a session persists after app relaunch and reconnecting to the same server.
- [ ] A successfully archived session is not shown in the active session list unless the user opens the dedicated Archived section in the session list.
- [ ] The app does not recreate or reinsert an archived session into the active list due only to local cache or refresh logic.
- [ ] Archive failures surface an actionable error and leave the current list state consistent.

### US-002: Recover Archived Sessions

**As a** beta user
**I want** a supported way to view and restore archived sessions
**So that** archiving remains reversible and trustworthy

#### Acceptance Criteria

- [ ] The session list includes a discoverable dedicated Archived section that lists archived sessions separately from active sessions.
- [ ] Users can restore a session directly from the Archived section.
- [ ] Unarchive succeeds even when the archived session is no longer present in the active in-memory session list.
- [ ] Restored sessions return to the active session list in the correct workspace grouping and sort order.
- [ ] Unarchive failure surfaces an actionable error without corrupting list state.

### US-003: Stream Messages Live in the Open Chat

**As a** beta user
**I want** messages to stream live in the currently open chat
**So that** I do not need to leave the chat or refresh the main session list to see updates

#### Acceptance Criteria

- [ ] Sending a prompt in the selected session shows assistant output incrementally while generation is in progress.
- [ ] Streaming updates appear in the open chat without requiring manual refresh, session re-selection, or app relaunch.
- [ ] Final message content matches server state once the session returns to idle.
- [ ] The app tolerates out-of-order SSE events such as `message.created`, `message.updated`, `message.part.updated`, and `message.part.delta` without losing content.
- [ ] Streaming errors or aborted sessions stop cleanly and surface understandable UI feedback.

### US-004: Keep Session State Fresh During and After Streaming

**As a** beta user
**I want** session state to stay accurate while messages are streaming
**So that** the sidebar and selected session remain trustworthy during active use

#### Acceptance Criteria

- [ ] When the selected session becomes busy, the UI reflects that state promptly.
- [ ] When the selected session returns to idle, sending state, optimistic state, and final message state reconcile correctly.
- [ ] Switching away from a streaming session and back does not duplicate, drop, or stale the visible conversation.
- [ ] While streaming, the selected chat updates live, and sidebar freshness for other sessions stays current enough to reflect active use without requiring full background transcript streaming.
- [ ] Refresh logic does not overwrite newer in-memory message state with stale data.

### US-005: Improve Composer Readability on iPhone

**As a** beta user
**I want** attachment and terminal controls to use a column layout
**So that** the text input has more horizontal space and is easier to read while typing

#### Acceptance Criteria

- [ ] The attachment and terminal controls no longer consume the same horizontal row as the main text entry area on compact-width iPhone layouts.
- [ ] The text input field gains visibly more horizontal reading space than the current beta layout shown in the attached screenshot.
- [ ] The terminal and attachment controls are stacked vertically as a compact leading-side action column adjacent to the text composer.
- [ ] Existing actions for terminal mode and attachments remain available and discoverable.
- [ ] Model, agent, and reasoning chips remain on their existing separate row above the composer.
- [ ] The send or abort action remains reachable with one-handed use on iPhone.
- [ ] The revised layout preserves 44pt minimum touch targets, accessibility labels, and keyboard usability.

### US-006: Surface Cross-Session Permission Requests

**As a** beta user
**I want** permission requests from any active session to appear in the iOS app
**So that** a background session cannot get stuck waiting for approval that is only visible in the TUI

#### Acceptance Criteria

- [ ] A permission request from a non-selected session becomes visible in the iOS app without requiring the user to open the TUI.
- [ ] The app provides enough context to identify which session and workspace the permission request belongs to.
- [ ] The user can navigate to, approve, or reject the pending permission from the app even when it originated from another session.
- [ ] Cross-session permission presentation does not hide or overwrite a pending permission request for the currently selected session.
- [ ] If multiple sessions have pending permissions, the app makes those requests discoverable and actionable rather than leaving them silently blocked.

### US-007: Validate Broader Beta Stability

**As a** beta user and maintainer
**I want** a clear list of adjacent workflows to test
**So that** regressions around sessions, streaming, permissions, and attachments are found before a wider rollout

#### Acceptance Criteria

- [ ] The specification includes a prioritized test matrix covering core chat, session, permissions, attachments, terminal, and UI reliability workflows.
- [ ] Each test item includes the recommended test method: automated unit or integration, simulator manual test, or real-device beta validation.
- [ ] The test matrix covers both happy paths and failure or interruption scenarios.

## Non-Functional Requirements

### Security

- Session archive, unarchive, send, abort, and streaming flows must continue using the authenticated `OpenCodeClient` request path without weakening existing auth behavior.
- Permission approval and rejection flows must remain scoped to the correct originating session and request ID.
- Errors must not leak secrets, credentials, or full attachment payloads into user-visible messages.
- Attachment handling must preserve current safety expectations for data URLs and uploaded content.

### Performance

- Streaming updates in the open chat should appear with near-real-time perceived latency during normal network conditions.
- Frequent SSE events should not require excessive full-list or full-message reloads that cause visible stutter on iPhone.
- Session refreshes triggered by archive, unarchive, and streaming completion should complete fast enough to feel immediate to users.

### Availability & Reliability

- The app must recover from transient SSE disconnects by reconnecting without corrupting session or message state.
- Archive and streaming flows must remain correct across pull-to-refresh, session switching, disconnect/reconnect, and app relaunch.
- Cross-session permission requests must remain visible and actionable even when they arrive while another session is selected.
- Optimistic message state must reconcile correctly after success, timeout, abort, and server error cases.

### Maintainability

- Session lifecycle rules for archived vs active sessions must be explicit and test-covered.
- SSE event handling must remain deterministic enough to test with mock event sequences.
- Permission presentation rules for selected-session vs non-selected-session requests must be explicit and test-covered.
- UI layout changes should prefer minimal restructuring and preserve current app architecture.

### Compliance

- No additional regulatory requirements are identified for this spec.

### Accessibility

- The revised composer layout must remain usable with Dynamic Type, VoiceOver, and keyboard-visible states.
- Custom controls must retain accurate accessibility labels and predictable reading order.
- Compact-width behavior must remain legible in portrait orientation on supported iPhones.

## Test Matrix

### Priority 1: Core Regressions to Validate

1. Archive a session, pull to refresh, and verify it stays archived.
Best method: automated `ChatViewModel` unit test plus manual simulator verification.

2. Archive a session, fully relaunch the app, reconnect, and verify it does not return to the active list.
Best method: real-device beta validation because it exercises app lifecycle and persisted connection state.

3. Unarchive a previously archived session and confirm it returns to the correct workspace group.
Best method: automated client or ViewModel test plus manual simulator validation.

4. Verify the dedicated Archived section lists archived sessions separately from active sessions and supports restoring them.
Best method: automated ViewModel test plus manual simulator and real-device validation.

5. Send a long prompt and verify assistant output streams live in the open chat without refreshing the main session list.
Best method: manual simulator and real-device validation against a real `opencode serve` instance.

6. Confirm final streamed content matches the server after the session reaches idle.
Best method: integration test with mock SSE ordering plus manual beta validation.

7. Start streaming, switch to another session, then return and verify the original session did not lose or duplicate content.
Best method: `ChatViewModel` event-sequence unit tests plus manual simulator validation.

### Priority 2: High-Value Adjacent Session Tests

1. Create, rename, delete, fork, and share sessions after archive-related changes.
Best method: automated ViewModel tests for state transitions plus manual smoke test.

2. Verify child session hierarchy still expands, selects correctly, and reflects updates.
Best method: manual simulator validation and targeted unit tests where selection logic is isolated.

3. Confirm pull-to-refresh does not clear the selected session unexpectedly during or after send.
Best method: `ChatViewModel` regression test plus simulator validation.

4. Verify session busy or idle indicators stay accurate during live generation.
Best method: integration-style SSE event tests plus simulator manual test.

5. Verify non-selected sessions receive sidebar freshness updates such as busy or idle state and recency metadata without attempting full background transcript streaming.
Best method: unit or integration tests around session update handling plus manual simulator validation.

6. Trigger a permission request from a different session and verify the app surfaces it without requiring a TUI fallback.
Best method: unit or integration tests around `permission.asked` handling plus manual simulator and real-device validation.

### Priority 3: Message and Composer Tests

1. Send normal text, slash commands, shell commands, and queued follow-up prompts.
Best method: automated ViewModel tests for send paths and manual simulator verification for UI behavior.

2. Attach an image or file and verify the composer remains readable and usable in portrait orientation.
Best method: manual simulator and real-device UI validation.

3. Verify the new column layout keeps terminal and attachment controls easy to reach with the keyboard open.
Best method: real-device validation on compact-width iPhone screens.

4. Verify the text field shows more readable line width than the screenshot baseline when the terminal and attachment controls are present.
Best method: manual side-by-side simulator or TestFlight comparison using the same prompt length.

5. Verify model, agent, and reasoning chips remain on their current separate row and are not pulled into the new action column.
Best method: manual simulator and real-device UI validation.

6. Validate send, abort, and retry flows after server error and timeout conditions.
Best method: mock-network unit tests plus manual error-path verification.

### Priority 4: Permission, Question, and Diff Flows

1. Trigger a permission request during an active session and verify the prompt appears for the correct session.
Best method: mock-event unit tests plus manual end-to-end validation.

2. Trigger a permission request from a non-selected session and verify the app surfaces the request, identifies the owning session, and allows approval or rejection without going to the TUI.
Best method: unit or integration tests around `permission.asked` handling plus manual simulator and real-device validation.

3. Trigger a question flow and ensure selection, answering, and dismissal remain correct after streaming changes.
Best method: unit tests and manual simulator validation.

4. Verify todo, diff, and file-browser surfaces still update after message completion.
Best method: manual smoke test with a real server session.

5. Confirm terminal tabs still open and shell-mode interaction remains intact after composer layout changes.
Best method: simulator and real-device manual validation.

### Priority 5: Accessibility and Presentation Tests

1. Test the composer with larger Dynamic Type sizes.
Best method: simulator Accessibility settings and manual inspection.

2. Test VoiceOver focus order across terminal control, attachment control, text input, and send button.
Best method: simulator Accessibility Inspector and real-device VoiceOver pass.

3. Verify portrait layout on smaller iPhone sizes remains readable with the keyboard displayed.
Best method: simulator device matrix plus at least one real-device beta pass.

4. Confirm Liquid Glass styling and toolbar behavior remain visually coherent after layout changes.
Best method: manual visual QA on simulator and real device.

## Settled Product Decisions

- Archived sessions are accessed from a dedicated Archived section in the session list.
- Live streaming is required for the selected chat, while non-selected sessions only need sidebar freshness updates such as busy or idle state and recency metadata.
- Permission requests must surface in-app even when they originate from a non-selected session, with enough context to identify and act on the blocked session.
- The layout change is limited to moving the terminal and attachment controls into a vertical stack adjacent to the composer; the rest of the composer structure remains unchanged.

## Success Criteria

- [ ] All reported beta issues in this spec have measurable acceptance criteria.
- [ ] Archived sessions remain archived across refresh and relaunch.
- [ ] Open-chat streaming no longer requires users to refresh from the main session list.
- [ ] The composer layout provides more readable horizontal text space on iPhone.
- [ ] The prioritized beta test matrix is executed before the next wider beta build.
- [ ] The specification contains no unresolved `[NEEDS CLARIFICATION]` markers, and the archived-section, streaming-scope, and layout-scope decisions are recorded as requirements.

## Specification Validation

### Completeness

- [x] All user stories have acceptance criteria.
- [x] Non-functional requirements are defined for security, performance, reliability, maintainability, and accessibility.
- [x] Additional beta testing scope is documented with recommended test methods.

### Clarity

- [x] All currently known requirements are testable.
- [x] No unresolved `[NEEDS CLARIFICATION]` markers remain.
- [x] The screenshot-driven layout issue is translated into explicit UI requirements.

### Alignment

- [x] Aligned with the native Swift iOS app architecture in `ios-app/OpenCodeNexus/`.
- [x] Aligned with the project preference for minimal, testable fixes.
- [x] Aligned with mobile-first and accessibility expectations from project guidance.

### Measurability

- [x] Success criteria are specific enough to validate in beta.
- [x] Acceptance criteria can be verified through unit, integration, manual, or real-device testing.
- [x] Streaming and archive persistence requirements are expressed in observable user outcomes.

## Approval Gate

This specification is ready to feed into `/ai-eng/plan` after user review. The next phase should break the work into implementation tasks for session archiving, SSE reliability, composer layout, and regression testing.
