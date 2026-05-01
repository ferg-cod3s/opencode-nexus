# iOS Client Stabilization Fixes Plan

## Status: Complete (Batch 1)
## Date: 2026-04-30
## Last Updated: 2026-04-30 22:27

---

## Critical Fixes (Must Do)

### 1. Question Lifecycle Bug (SSE-001) ✅ PARTIALLY DONE
**Problem**: Questions reappear after answering because `presentedQuestionIDs` in ChatView.swift isn't cleaned up when questions are removed.

**Current State**: 
- `question.replied` and `question.rejected` SSE events are now handled in ChatViewModel
- ChatView still tracks `presentedQuestionIDs` but doesn't clear them when questions disappear

**Remaining Fix**:
- [ ] Add cleanup of `presentedQuestionIDs` when `pendingQuestions` becomes empty
- [ ] Ensure sheet dismisses properly when no questions remain
- [ ] Test the full flow: asked → answered → removed → new question arrives

**Files**: `ChatView.swift`, `ChatViewModel.swift`

---

### 2. Connection Task Cancellation (STATE-001) ✅ DONE
**Problem**: `ConnectionManager.connect(to:)` could leave stale connections or race conditions.

**Fix Applied**: 
- Added `connectTask` to ConnectionManager
- Cancel previous task before starting new one
- Check `Task.isCancelled` after async operations
- Cancel task in `disconnect()`

**Files**: `ConnectionManager.swift`

---

### 3. SSE Parser Robustness (SSE-002) ✅ DONE
**Problem**: SSE parser couldn't handle multi-line data, malformed events, or stream termination.

**Fix Applied**:
- Extracted `SSEParser` struct with proper event buffering
- Handles multi-line `data:` concatenation
- Skips SSE comments (`:` lines)
- Logs malformed events instead of crashing
- Handles `done` event for clean termination
- Added 10 comprehensive parser tests

**Files**: `SSEParser.swift` (new), `OpenCodeClient.swift`, `SSEParserTests.swift` (new)

---

### 4. Error Handling (PARITY-003) ✅ DONE
**Problem**: API errors weren't categorized or informative.

**Fix Applied**:
- Expanded `OpenCodeError` with `httpError(Int, String?)` for body snippets
- Updated `validateResponse` to capture response data
- Fixed test to match new error signature

**Files**: `OpenCodeClient.swift`, `OpenCodeClientTests.swift`

---

## Medium Priority Fixes

### 5. ServerStore Warning Fix ✅ DONE
**Problem**: Unused variable `first` in `removeServer()`.

**Fix Applied**: Replaced with `!servers.isEmpty` check.

**Files**: `ServerStore.swift`

---

### 6. Accessibility Labels (A11Y-001) ✅ DONE
**Problem**: Input controls lacked accessibility labels.

**Fix Applied**:
- Attach button: "Attach file or photo"
- Send/Abort button: Contextual labels
- Remove attachment: "Remove attachment"
- Autocomplete chips: "Command: X" / "Agent: X"
- Tool call buttons: Min 44pt height + contextual labels
- Reasoning buttons: Min 44pt height + contextual labels

**Files**: `MessageInputView.swift`, `MessageBubble.swift`

---

### 7. ViewModel Tests (TEST-004) ❌ NOT STARTED
**Problem**: No tests for ChatViewModel state transitions.

**Needed**:
- Mock client protocol for testability
- Test: load sessions success/failure
- Test: select session loads messages
- Test: send message with optimistic UI
- Test: abort cancels and resets state
- Test: answer question removes from pending
- Test: SSE question.replied removes from pending
- Test: delta application and buffering

**Challenge**: `ChatViewModel` uses concrete `OpenCodeClient` instead of protocol.

**Approach**: 
Option A: Extract `OpenCodeClientProtocol` (large refactor)
Option B: Use subclassing or method swizzling for tests (brittle)
Option C: Start with integration-style tests using real client + mock server

**Recommendation**: Option A for long-term, but defer to after critical fixes.

---

### 8. ChatView Sheet State (REFACTOR-003) ❌ NOT STARTED
**Problem**: Multiple `@State` booleans for sheets can cause double presentations.

**Current State**: Already using `ActiveChatSheet` enum with `sheet(item:)` - this is actually correct!

**Verification**: ChatView.swift uses `.sheet(item: $activeSheet)` which is the proper pattern.

**Status**: Already implemented correctly.

---

## Lower Priority / Future Work

### 9. SessionSidebar Extraction (REFACTOR-001) ❌ NOT STARTED
**Problem**: ChatSidebarView exists but is embedded in ChatView.swift.

**Status**: ChatSidebarView is already a private struct in ChatView.swift. Could be extracted to its own file for better organization, but not critical.

---

### 10. SessionDetailView Extraction (REFACTOR-002) ❌ NOT STARTED
**Problem**: ChatDetailContainer exists but is embedded in ChatView.swift.

**Status**: ChatDetailContainer is already a private struct in ChatView.swift. Could be extracted, but not critical.

---

### 11. Autocomplete Palette (REFACTOR-004) ✅ ALREADY GOOD
**Problem**: Potential duplication in autocomplete rendering.

**Status**: Already uses shared `autocompleteScrollView` and `autocompleteItem` helpers. No action needed.

---

## Testing Checklist

- [x] Build succeeds (simulator)
- [x] Build succeeds (physical device)
- [x] All 374 unit tests pass
- [x] No compiler warnings (except metadata extraction from dependency)
- [x] App installs on physical device
- [x] App launches on physical device
- [ ] Manual testing on device (need user feedback)
- [ ] Question lifecycle test (asked → answered → removed)
- [ ] SSE reconnection test
- [ ] Background/foreground state preservation

---

## Next Steps

1. **Complete question lifecycle fix** - Ensure `presentedQuestionIDs` clears properly
2. **Add ViewModel tests** - Either extract protocol or add integration tests
### 12. Send Timeout Race Condition ✅ DONE (Found during review)
**Problem**: Timeout task in `sendMessage()` could reset state for a newer send operation if user switches sessions or sends multiple messages.

**Fix Applied**: Added `currentSendOperationID: UUID?` to track send operations. Timeout task checks operation ID before resetting state. Cleared on:
- Successful send completion
- Catch block (send failure)
- `session.status` returning to idle
- `session.error` event

**Files**: `ChatViewModel.swift`

---

## Testing Checklist

- [x] Build succeeds (simulator)
- [x] Build succeeds (physical device)
- [x] All 374 unit tests pass
- [x] No compiler warnings (except metadata extraction from dependency)
- [x] App installs on physical device
- [x] App launches on physical device
- [ ] Manual testing on device (need user feedback)
- [ ] Question lifecycle test (asked → answered → removed)
- [ ] SSE reconnection test
- [ ] Background/foreground state preservation

---

## Known Limitations

1. **Simulator testing incomplete** - Could not automate simulator interactions (no UI automation tools available)
2. **No mock client** - ViewModel tests require protocol extraction
3. **Liquid Glass polish** - Visual refinements deferred
4. **Dynamic Type testing** - Not verified on device

---

## Build Status

**Simulator**: ✅ BUILD SUCCEEDED, 0 warnings  
**Physical Device**: ✅ BUILD SUCCEEDED, installed and launched (22:27)  
**Tests**: ✅ 374 tests passed, 0 failures

---

## Summary of Changes This Session

1. **Fixed compilation errors** in `OpenCodeClient.swift` (duplicate method bodies, errorDescription return statements)
2. **Hardened SSE parser** with `SSEParser` struct supporting multi-line data, malformed event handling, and stream termination
3. **Added 10 SSE parser tests** verifying edge cases
4. **Improved error handling** with HTTP response body snippets in `OpenCodeError`
5. **Added task cancellation** to `ConnectionManager` for connect operations
6. **Fixed send timeout race condition** with operation ID tracking
7. **Added accessibility labels** to input controls and tool call buttons
8. **Fixed unused variable warning** in `ServerStore.swift`
9. **Already present**: `question.replied`/`question.rejected` SSE event handling
