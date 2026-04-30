# iOS Client Stabilization Implementation Plan

**Status**: Draft
**Created**: 2026-04-29
**Specification**: specs/ios-client-stabilization/spec.md
**Estimated Effort**: 6-8 days
**Complexity**: Medium-High

## Overview

Stabilize the OpenCode Nexus iOS client by fixing API parity gaps, hardening SSE/streaming, tightening ViewModel state ownership, adding contract tests, extracting large views, and fixing known bugs including the question-not-clearing issue. All changes preserve current user-facing behavior unless a bug fix explicitly changes it.

## Question Bug Root Cause

The OpenCode server emits `question.replied` and `question.rejected` SSE events (packages/opencode/src/question/index.ts:98-99) but the iOS client only handles `question.asked` (ChatViewModel.swift:1138). After answering a question:
1. `answerQuestion()` calls `client.replyQuestion()` then `removeQuestion()` locally.
2. The server emits `question.replied`, which the iOS client ignores (falls into `default: break`).
3. If the SSE event arrives before `removeQuestion` completes, or if a new `question.asked` event re-merges the same question ID, the question reappears.
4. `ChatView` tracks `presentedQuestionIDs` but `showQuestionSheet` may already be `true`, preventing re-presentation for new questions.

Fix: handle `question.replied` and `question.rejected` SSE events, and clean up `presentedQuestionIDs` when questions are resolved.

## Architecture

```
SwiftUI Views
  └── ViewModels (ConnectionManager, ChatViewModel)
       └── OpenCodeClient (protocol-based for testability)
            └── URLSession + SSE parser
                 └── OpenCode Server API
```

No new layers. Changes are incremental within existing architecture.

## Phase 1: API Parity and Decoding Resilience

**Goal**: Align Swift models and endpoints with OpenCode server contract.
**Duration**: 1 day

### Task 1.1: Audit Swift endpoints against TypeScript SDK
- **ID**: PARITY-001
- **Depends On**: None
- **Files**:
  - `ios-app/OpenCodeNexus/Services/OpenCodeClient.swift` (modify)
  - Reference: `/Users/johnferguson/Github/opencode/packages/sdk/js/src/v2/gen/client/client.gen.ts` (read-only)
- **Acceptance Criteria**:
  - [ ] Every endpoint path in `OpenCodeClient.swift` matches the TS SDK paths
  - [ ] HTTP methods match (GET/POST/DELETE)
  - [ ] Request body shapes match server expectations
  - [ ] All endpoints from spec contract list are present
  - [ ] App builds
- **Spec Reference**: API Client contract areas
- **Time**: 60 min
- **Complexity**: Medium

### Task 1.2: Harden Codable models for unknown/optional fields
- **ID**: PARITY-002
- **Depends On**: None
- **Files**:
  - `ios-app/OpenCodeNexus/Models/*.swift` (modify)
  - Reference: `/Users/johnferguson/Github/opencode/packages/sdk/js/src/v2/gen/types.gen.ts` (read-only)
- **Acceptance Criteria**:
  - [ ] All Codable structs use `CodingKeys` where needed
  - [ ] Unknown JSON fields do not crash decoding
  - [ ] Optional server fields decode as nil instead of throwing
  - [ ] Required-but-missing fields log actionable diagnostics in debug
  - [ ] App builds
- **Spec Reference**: Response model behavioral contracts
- **Time**: 60 min
- **Complexity**: Medium

### Task 1.3: Categorize and surface API errors clearly
- **ID**: PARITY-003
- **Depends On**: PARITY-002
- **Files**:
  - `ios-app/OpenCodeNexus/Services/OpenCodeClient.swift` (modify)
- **Acceptance Criteria**:
  - [ ] Distinct error types or cases for: invalid URL, unreachable, non-2xx, decoding failure, stream failure, cancellation
  - [ ] Non-2xx errors include status code and response body snippet
  - [ ] Cancellation errors are not shown to user as failures
  - [ ] App builds
- **Spec Reference**: Error handling conventions
- **Time**: 45 min
- **Complexity**: Medium

## Phase 2: SSE and Event Stream Robustness

**Goal**: One reliable event stream per connection with correct parsing and no leaks.
**Duration**: 1 day

### Task 2.1: Handle question.replied and question.rejected SSE events
- **ID**: SSE-001
- **Depends On**: None
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift` (modify)
  - `ios-app/OpenCodeNexus/Views/ChatView.swift` (modify)
- **Acceptance Criteria**:
  - [ ] `question.replied` SSE event removes matching question from `questionsBySession`
  - [ ] `question.rejected` SSE event removes matching question from `questionsBySession`
  - [ ] After answering, question disappears from sheet and banner
  - [ ] `presentedQuestionIDs` is cleaned up when questions are resolved
  - [ ] Sheet dismisses when no questions remain
  - [ ] New questions arriving after answering still trigger the sheet
  - [ ] App builds
- **Spec Reference**: SSE Event Contract, Question behavioral contract
- **Time**: 45 min
- **Complexity**: Medium

### Task 2.2: Harden SSE parser for multi-line and malformed events
- **ID**: SSE-002
- **Depends On**: None
- **Files**:
  - `ios-app/OpenCodeNexus/Services/OpenCodeClient.swift` (modify)
- **Acceptance Criteria**:
  - [ ] Multi-line `data:` fields concatenate correctly
  - [ ] Events with empty `data:` do not crash
  - [ ] Malformed events are logged and skipped, not crash
  - [ ] Stream termination handles `event: done` cleanly
  - [ ] App builds
- **Spec Reference**: SSE Event Contract
- **Time**: 45 min
- **Complexity**: Medium

### Task 2.3: Prevent duplicate and stale event streams
- **ID**: SSE-003
- **Depends On**: SSE-002
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift` (modify)
- **Acceptance Criteria**:
  - [ ] `startEventStream()` cancels any existing stream before starting new one
  - [ ] `stopEventStream()` fully cancels the task
  - [ ] Events for non-selected sessions do not mutate selected session state
  - [ ] View `.onDisappear` calls `stopEventStream()`
  - [ ] App builds
- **Spec Reference**: SSE Event Contract - no duplicate listeners
- **Time**: 30 min
- **Complexity**: Low

## Phase 3: ViewModel State Ownership

**Goal**: Clear async task ownership and main-actor-safe state.
**Duration**: 1 day

### Task 3.1: Add explicit task ownership for long-lived async work
- **ID**: STATE-001
- **Depends On**: SSE-003
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift` (modify)
  - `ios-app/OpenCodeNexus/ViewModels/ConnectionManager.swift` (modify)
- **Acceptance Criteria**:
  - [ ] `eventTask`, `sessionReloadTask`, `messageReloadTask` are explicitly owned and cancelled
  - [ ] `ConnectionManager` disconnect cancels any in-flight connect/health-check tasks
  - [ ] Send/abort operations have clear task references
  - [ ] Guard against stale task completions (check session ID still matches)
  - [ ] App builds
- **Spec Reference**: ViewModel Contract - explicit task ownership
- **Time**: 60 min
- **Complexity**: High

### Task 3.2: Ensure main-actor safety for UI state mutations
- **ID**: STATE-002
- **Depends On**: STATE-001
- **Files**:
  - `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift` (modify)
- **Acceptance Criteria**:
  - [ ] All `@Observable` property mutations happen on main actor
  - [ ] No Swift concurrency warnings in build output
  - [ ] Async methods that update UI state use `@MainActor` or explicit dispatch
  - [ ] App builds
- **Spec Reference**: ViewModel Contract - main actor safety
- **Time**: 45 min
- **Complexity**: Medium

## Phase 4: Contract Tests

**Goal**: Lock API, SSE, and ViewModel behavior before UI refactors.
**Duration**: 1-2 days

### Task 4.1: Create test fixtures for API payloads
- **ID**: TEST-001
- **Depends On**: PARITY-002
- **Files**:
  - `ios-app/OpenCodeNexusTests/Fixtures/session.json` (create)
  - `ios-app/OpenCodeNexusTests/Fixtures/message.json` (create)
  - `ios-app/OpenCodeNexusTests/Fixtures/provider.json` (create)
  - `ios-app/OpenCodeNexusTests/Fixtures/event-asked.json` (create)
  - `ios-app/OpenCodeNexusTests/Fixtures/event-replied.json` (create)
- **Acceptance Criteria**:
  - [ ] JSON fixtures represent real server response shapes
  - [ ] Fixtures include edge cases: optional fields, unknown fields
  - [ ] Fixtures load from test bundle
- **Spec Reference**: Testing Strategy - Codable fixture tests
- **Time**: 45 min
- **Complexity**: Low

### Task 4.2: Write Codable decoding tests
- **ID**: TEST-002
- **Depends On**: TEST-001
- **Files**:
  - `ios-app/OpenCodeNexusTests/OpenCodeClientTests.swift` (create/modify)
- **Acceptance Criteria**:
  - [ ] Session, Message, Provider models decode fixtures correctly
  - [ ] Unknown fields do not cause failures
  - [ ] Missing required fields produce clear errors
  - [ ] Optional fields decode as nil when absent
  - [ ] Tests pass: `bun run ios:test`
- **Spec Reference**: Testing Strategy - Codable fixture tests
- **Time**: 60 min
- **Complexity**: Medium

### Task 4.3: Write SSE parser tests
- **ID**: TEST-003
- **Depends On**: TEST-001
- **Files**:
  - `ios-app/OpenCodeNexusTests/SSEParserTests.swift` (create/modify)
- **Acceptance Criteria**:
  - [ ] Normal single-line events parse correctly
  - [ ] Multi-line `data:` concatenates
  - [ ] Malformed events do not crash
  - [ ] Stream termination handled
  - [ ] Empty event type handled
  - [ ] Tests pass: `bun run ios:test`
- **Spec Reference**: Testing Strategy - SSE parser tests
- **Time**: 60 min
- **Complexity**: Medium

### Task 4.4: Write ViewModel tests with mock client
- **ID**: TEST-004
- **Depends On**: STATE-002, TEST-002
- **Files**:
  - `ios-app/OpenCodeNexusTests/ChatViewModelTests.swift` (create/modify)
- **Acceptance Criteria**:
  - [ ] Mock client protocol or struct allows injecting responses
  - [ ] Test: load sessions success and failure
  - [ ] Test: select session loads messages
  - [ ] Test: send message
  - [ ] Test: abort cancels and resets state
  - [ ] Test: answer question removes it from pending
  - [ ] Test: SSE question.replied removes from pending
  - [ ] Tests pass: `bun run ios:test`
- **Spec Reference**: Testing Strategy - ViewModel tests
- **Time**: 90 min
- **Complexity**: High

## Phase 5: ChatView Extraction

**Goal**: Reduce ChatView.swift from 397 lines to a composition shell.
**Duration**: 0.5-1 day

### Task 5.1: Extract SessionSidebar view
- **ID**: REFACTOR-001
- **Depends On**: STATE-002
- **Files**:
  - `ios-app/OpenCodeNexus/Views/ChatView.swift` (modify)
  - `ios-app/OpenCodeNexus/Views/SessionSidebar.swift` (create)
- **Acceptance Criteria**:
  - [ ] Sidebar logic extracted into `SessionSidebar.swift`
  - [ ] `SessionSidebar` accepts explicit inputs and action closures
  - [ ] ChatView passes data down, behavior unchanged
  - [ ] App builds and sidebar renders identically
- **Spec Reference**: Project Structure - new files
- **Time**: 45 min
- **Complexity**: Medium

### Task 5.2: Extract SessionDetailView
- **ID**: REFACTOR-002
- **Depends On**: STATE-002
- **Files**:
  - `ios-app/OpenCodeNexus/Views/ChatView.swift` (modify)
  - `ios-app/OpenCodeNexus/Views/SessionDetailView.swift` (create)
- **Acceptance Criteria**:
  - [ ] Detail pane logic extracted into `SessionDetailView.swift`
  - [ ] Sheet routing may remain in ChatView or move to extracted view
  - [ ] ChatView becomes mainly NavigationSplitView + composition
  - [ ] App builds and detail pane renders identically
- **Spec Reference**: Project Structure - new files
- **Time**: 45 min
- **Complexity**: Medium

## Phase 6: Modal State Simplification

**Goal**: Single source of truth for sheet presentation.
**Duration**: 0.5 day

### Task 6.1: Consolidate sheet booleans into enum-backed state
- **ID**: REFACTOR-003
- **Depends On**: REFACTOR-001, REFACTOR-002
- **Files**:
  - `ios-app/OpenCodeNexus/Views/ChatView.swift` (modify)
  - `ios-app/OpenCodeNexus/Views/ChatModalDestination.swift` (create)
- **Acceptance Criteria**:
  - [ ] Multiple `@State var showXSheet` booleans replaced with single enum or optional
  - [ ] Only one modal can present at a time
  - [ ] Permission, question, diff, file browser, file viewer, terminal, new session all work
  - [ ] No accidental double-sheet presentations
  - [ ] App builds, all sheet flows work
- **Spec Reference**: Modal state simplification
- **Time**: 60 min
- **Complexity**: Medium

## Phase 7: MessageInputView Cleanup

**Goal**: Reduce duplication and improve accessibility.
**Duration**: 0.5 day

### Task 7.1: Simplify autocomplete palette rendering
- **ID**: REFACTOR-004
- **Depends On**: None
- **Files**:
  - `ios-app/OpenCodeNexus/Views/MessageInputView.swift` (modify)
- **Acceptance Criteria**:
  - [ ] Command and agent palette chips use shared rendering if duplication exists
  - [ ] Autocomplete filtering logic remains correct
  - [ ] No visual regression
  - [ ] App builds
- **Spec Reference**: MessageInputView cleanup
- **Time**: 30 min
- **Complexity**: Low

### Task 7.2: Add accessibility labels to input controls
- **ID**: A11Y-001
- **Depends On**: None
- **Files**:
  - `ios-app/OpenCodeNexus/Views/MessageInputView.swift` (modify)
- **Acceptance Criteria**:
  - [ ] Attach button has `accessibilityLabel`
  - [ ] Send/abort button has contextual label
  - [ ] Remove attachment button has label
  - [ ] Autocomplete chips are accessible
  - [ ] App builds
- **Spec Reference**: Boundaries - accessibility labels
- **Time**: 20 min
- **Complexity**: Low

## Phase 8: Accessibility and Liquid Glass Polish

**Goal**: Full audit pass for touch targets, VoiceOver, Dynamic Type.
**Duration**: 0.5 day

### Task 8.1: Audit custom controls for 44pt targets and VoiceOver
- **ID**: A11Y-002
- **Depends On**: REFACTOR-004
- **Files**:
  - `ios-app/OpenCodeNexus/Views/SessionRow.swift` (modify)
  - `ios-app/OpenCodeNexus/Views/MessageBubble.swift` (modify)
  - `ios-app/OpenCodeNexus/Views/MessageListView.swift` (modify)
  - Other views as needed
- **Acceptance Criteria**:
  - [ ] All custom tap targets >= 44pt
  - [ ] Session actions (delete, share) have VoiceOver labels
  - [ ] Message actions (fork, delete, revert) have VoiceOver labels
  - [ ] Dynamic Type does not break layout on key screens
  - [ ] App builds
- **Spec Reference**: Accessibility and Liquid Glass polish
- **Time**: 45 min
- **Complexity**: Low

## Dependencies

```
PARITY-001 ─┐
PARITY-002 ──┼── PARITY-003
             │
SSE-001 ────┤
SSE-002 ────┼── SSE-003 ── STATE-001 ── STATE-002 ── TEST-004
             │
TEST-001 ───┤── TEST-002
             └── TEST-003

STATE-002 ──┬── REFACTOR-001 ──┐
             └── REFACTOR-002 ──┼── REFACTOR-003
                                │
REFACTOR-004 ── A11Y-002       │
A11Y-001 (independent)         │
```

Independent tasks (can run in parallel):
- PARITY-001, PARITY-002, SSE-001, SSE-002, TEST-001, REFACTOR-004, A11Y-001

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| OpenCode server API changed since last audit | High | Medium | Compare against TS SDK generated client during PARITY-001 |
| SSE event format differs from assumed format | High | Low | Use fixture-based tests in TEST-003 |
| Question fix introduces race between local remove and SSE event | Medium | Medium | SSE handler checks ID exists before removing; local remove is authoritative |
| View extraction breaks sheet presentation | Medium | Low | Extract views incrementally, build after each, keep behavior unchanged |
| Mock client for ViewModel tests doesn't match real client | Medium | Medium | Protocol-based mock, validate against fixture tests |
| Liquid Glass API changes between iOS 26 betas | Low | Medium | Keep glass effects minimal and consistent with existing patterns |

## Testing Plan

### Unit Tests
- [ ] Codable decoding for all models (TEST-002)
- [ ] SSE parsing for normal, multi-line, malformed, terminal (TEST-003)
- [ ] URL construction and request configuration (TEST-002)
- [ ] ViewModel state transitions with mock client (TEST-004)

### Integration Tests
- [ ] Question lifecycle: asked → replied → removed (TEST-004)
- [ ] Event stream start/stop/switch session (TEST-004)

### Build Verification
- [ ] App builds after every task
- [ ] `bun run ios:test` passes after Phase 4+

### Spec Validation
- [ ] All spec success criteria have corresponding task acceptance criteria
- [ ] All spec contract areas have corresponding parity checks
- [ ] All spec boundaries are respected (no JS bridge, no third-party deps, etc.)

## Rollback Plan

Each phase is incremental and independently buildable. If a phase introduces regressions:
1. Revert the specific files changed in that phase via git.
2. Phases 1-4 do not change UI structure, so visual regressions are unlikely.
3. Phases 5-8 are pure refactors — revert if behavior changes.
4. The question fix (SSE-001) is the most impactful behavioral change and should be validated with manual testing against a real `opencode serve` instance.

## References

- Specification: `specs/ios-client-stabilization/spec.md`
- TS SDK reference: `/Users/johnferguson/Github/opencode/packages/sdk/js/src/v2/gen/`
- Question events source: `/Users/johnferguson/Github/opencode/packages/opencode/src/question/index.ts:96-100`
- iOS SSE handling: `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift:1138`
- Project config: `ios-app/project.yml`
