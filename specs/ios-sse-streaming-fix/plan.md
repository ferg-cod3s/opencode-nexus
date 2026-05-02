# iOS SSE and Streaming Fix Plan

## Status: Ready for Implementation
**Created**: 2026-05-01
**Based on**: Investigation of workspace creation error, message streaming failure, duplicate messages, and queue behavior.

---

## Problem Summary

The iOS client receives SSE events but **silently drops every single one** as malformed. This breaks:
- Message streaming (deltas never apply)
- Auto-refresh (session/message lists don't update)
- Question prompts (don't appear automatically)
- Status changes ("Thinking" persists until timeout)

Duplicated messages occur because optimistic messages aren't cleaned up until a manual refresh triggers `loadMessages()`.

---

## Root Cause

### Server Event Format vs. Client Expectation

**The server sends:**
```json
{
  "directory": "/project",
  "project": "proj_123",
  "workspace": "wrk_456",
  "payload": {
    "type": "message.part.delta",
    "properties": {
      "sessionID": "ses_123",
      "messageID": "msg_456",
      "partID": "prt_789",
      "field": "text",
      "delta": "Hello"
    }
  }
}
```

**The iOS client expects:**
```json
{
  "type": "message.part.delta",
  "properties": {
    "sessionID": "ses_123",
    "messageID": "msg_456",
    "partID": "prt_789",
    "field": "text",
    "delta": "Hello"
  }
}
```

Because the server wraps the event in `payload` and adds metadata (`directory`, `project`, `workspace`), `JSONDecoder` fails to decode `SSEEvent`. The `SSEParser` logs it as malformed and continues.

### Sync Events Are Also Ignored

The server sends database sync events with a different structure:
```json
{
  "directory": "/project",
  "project": "proj_123",
  "workspace": "wrk_456",
  "payload": {
    "type": "sync",
    "syncEvent": {
      "type": "message.updated.1",
      "id": "evt_123",
      "seq": 42,
      "aggregateID": "sessionID",
      "data": {
        "sessionID": "ses_123",
        "info": { ... }
      }
    }
  }
}
```

These hit `default: break` in `ChatViewModel.handleEvent()` because the outer `type` is `"sync"`, not a known event type.

### Impact

| Feature | Expected | Actual | Cause |
|---------|----------|--------|-------|
| Streaming text | Real-time delta updates | Nothing until manual refresh | All `message.part.delta` events dropped |
| Thinking indicator | Stops when response done | Stays until 120s timeout | `session.status` events dropped |
| Question prompts | Auto-appear when asked | Don't appear | `question.asked` events dropped |
| Session list refresh | Auto-update on changes | Stale until manual refresh | `session.updated` events dropped |
| Duplicated messages | Optimistic removed when server msg arrives | Both visible | `loadMessages` never auto-called |

---

## Implementation Plan

### Phase 1: Fix SSE Event Model

**File**: `ios-app/OpenCodeNexus/Models/SSEEvent.swift`

**Current structure**:
```swift
struct SSEEvent: Decodable, Sendable, Equatable {
    let type: String
    let properties: [String: JSONValue]?
}
```

**New structure**:
```swift
struct SSEEvent: Decodable, Sendable, Equatable {
    let directory: String?
    let project: String?
    let workspace: String?
    let payload: Payload?
    
    struct Payload: Decodable, Sendable, Equatable {
        let type: String
        let properties: [String: JSONValue]?
    }
    
    // Computed for backward compatibility
    var type: String { payload?.type ?? "unknown" }
    var properties: [String: JSONValue]? { payload?.properties }
}
```

**Also handle sync events**:
```swift
struct SSEEvent: Decodable, Sendable, Equatable {
    let directory: String?
    let project: String?
    let workspace: String?
    let payload: Payload?
    let syncEvent: SyncEvent?
    
    struct Payload: Decodable, Sendable, Equatable {
        let type: String
        let properties: [String: JSONValue]?
    }
    
    struct SyncEvent: Decodable, Sendable, Equatable {
        let type: String
        let data: [String: JSONValue]?
    }
    
    var type: String { payload?.type ?? syncEvent?.type ?? "unknown" }
    var properties: [String: JSONValue]? { payload?.properties ?? syncEvent?.data }
}
```

**Custom decoder**: Use `init(from decoder:)` to try both formats for backward compatibility with older servers or mock data.

**Acceptance criteria**:
- [ ] `SSEEvent` decodes server format correctly
- [ ] `SSEEvent` still decodes flat format (for tests/fixtures)
- [ ] `type` and `properties` computed properties return correct values
- [ ] Sync events expose their inner `data` as `properties`
- [ ] Build succeeds

---

### Phase 2: Handle Sync Events in ChatViewModel

**File**: `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`

**Current handler**:
```swift
func handleEvent(_ event: SSEEvent) {
    switch event.type {
    case "message.part.delta":
        // ...
    case "message.updated", "message.part.updated":
        // ...
    case "session.status":
        // ...
    // ...
    default:
        break  // <-- sync events hit here
    }
}
```

**Sync event types to handle** (strip `.1` suffix):
- `message.updated.1` → same as `message.updated`
- `message.part.updated.1` → same as `message.part.updated`
- `session.created.1` → same as `session.created`
- `session.updated.1` → same as `session.updated`
- `session.deleted.1` → same as `session.deleted`

**Implementation**:
1. Extract a helper that normalizes event types:
   ```swift
   private func normalizedEventType(_ type: String) -> String {
       type.replacingOccurrences(of: ".1", with: "", options: [.anchored], range: type.range(of: ".1"))
   }
   ```
   Or better: `String(type.dropLast(2))` if suffix is exactly `.1`.

2. Update `handleEvent` to use normalized type for routing.

3. Handle sync events that don't have direct equivalents (log them for now).

**Acceptance criteria**:
- [ ] `message.updated.1` triggers `loadMessages`
- [ ] `message.part.updated.1` applies part update
- [ ] `session.updated.1` triggers `loadSessions`
- [ ] `session.created.1` triggers `loadSessions`
- [ ] `session.deleted.1` triggers `loadSessions`
- [ ] Build succeeds

---

### Phase 3: Harden SSE Parser

**File**: `ios-app/OpenCodeNexus/Services/SSEParser.swift`

**Current issues**:
- Ignores `event:` lines (server doesn't use them for data events, but heartbeats/comments might)
- Doesn't handle `id:` or `retry:` lines
- Silent on malformed events

**Changes**:
1. Parse `event:` lines and store event name
2. Parse `id:` and `retry:` lines
3. Include event name in parsed `SSEEvent` (though server doesn't use it)
4. Better logging: log event type when successfully parsed, log first 200 chars when malformed

**Note**: The server uses `streamSSE` from Hono, which writes `{ data: json }` without `event:` lines. But handling them defensively is good practice.

**Acceptance criteria**:
- [ ] Parser handles `event:` lines
- [ ] Parser handles `id:` and `retry:` lines
- [ ] Malformed events log their content (first 200 chars)
- [ ] Successful events log their type
- [ ] Build succeeds

---

### Phase 4: Fix Duplicate Message Reconciliation

**File**: `ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift`

**Current logic** in `reconciledMessages`:
1. Remove expired optimistic messages (>5 min old)
2. Remove optimistic messages whose ID matches a server message ID
3. Remove optimistic messages whose text matches a server user message within 60 seconds
4. Keep remaining optimistic messages in the list

**Problem**: When SSE is broken, step 2 never runs until manual refresh. When it does run, the server may have assigned a different ID than the optimistic `msg_ios_...` ID.

**Fix**: The reconciliation logic is actually correct. The fix is ensuring `loadMessages` is called automatically (via SSE). However, add a safety net:

1. **Always remove optimistic messages on `session.status = idle`**: When the session goes idle, we know the server has finished processing. Call `loadMessages` immediately (already done in the idle handler) and also clear any optimistic messages for that session.

2. **Improve matching in `reconciledMessages`**:
   - Also match by `sessionID` + role == `.user` + text content, regardless of timestamp
   - This catches cases where the server message has a different ID but same content

**Acceptance criteria**:
- [ ] Optimistic messages are removed when matching server messages are found
- [ ] Text-content matching works across any time window
- [ ] No duplicate messages visible after streaming completes
- [ ] Build succeeds

---

### Phase 5: Tests and Verification

**Files**:
- `ios-app/OpenCodeNexusTests/SSEParserTests.swift`
- `ios-app/OpenCodeNexusTests/ChatViewModelTests.swift`

**Tests to add**:

1. **SSEEvent decoding**:
   - Test server format with `payload` wrapper
   - Test sync event format
   - Test backward compatibility with flat format
   - Test `type` and `properties` computed properties

2. **ChatViewModel event handling**:
   - Test `message.part.delta` updates message text
   - Test `message.updated` triggers `loadMessages`
   - Test sync `message.updated.1` triggers `loadMessages`
   - Test `session.status` idle stops `isSending`
   - Test `session.status` idle calls `loadMessages`

3. **Message reconciliation**:
   - Test optimistic message removed when server message with different ID but same text arrives
   - Test no duplicates after reconciliation

**Integration verification**:
- Build app: `bun run ios:build`
- Run tests: `bun run ios:test`

**Acceptance criteria**:
- [ ] All new tests pass
- [ ] Existing tests still pass
- [ ] App builds successfully
- [ ] No compiler warnings

---

## Dependencies

```
Phase 1 (SSEEvent model)
    │
    ▼
Phase 2 (Sync events) ──► Phase 4 (Reconciliation)
    │                         │
    ▼                         ▼
Phase 3 (Parser)          Phase 5 (Tests)
```

Phase 1 must come first. Phases 2, 3, and 4 can be done in parallel after Phase 1. Phase 5 (tests) depends on all previous phases.

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Server event format changes again | High | Use custom decoder that handles both flat and wrapped formats |
| Sync event handling double-triggers | Medium | Normalize type by stripping `.1` suffix; reuse same handler |
| Breaking existing tests | Medium | Keep flat format compatibility; update test fixtures if needed |
| Performance: too many `loadMessages` calls | Low | The 300ms debounce already exists; sync events may add more calls but are necessary |

---

## Rollback

Each phase is a separate file change. If issues arise:
1. Revert the specific phase files
2. Phase 1 is the most critical — without it, streaming won't work
3. Phase 2-4 are additive and can be reverted independently

---

## References

- Server event emission: `/Users/johnferguson/Github/opencode/packages/opencode/src/bus/index.ts:94-99`
- Server SSE stream: `/Users/johnferguson/Github/opencode/packages/opencode/src/server/routes/global.ts:23-70`
- Sync events: `/Users/johnferguson/Github/opencode/packages/opencode/src/sync/index.ts:160-181`
- iOS SSE parser: `/Users/johnferguson/Github/opencode-nexus/feature-parity/ios-app/OpenCodeNexus/Services/SSEParser.swift`
- iOS event model: `/Users/johnferguson/Github/opencode-nexus/feature-parity/ios-app/OpenCodeNexus/Models/SSEEvent.swift`
- iOS event handling: `/Users/johnferguson/Github/opencode-nexus/feature-parity/ios-app/OpenCodeNexus/ViewModels/ChatViewModel.swift:1161-1305`
