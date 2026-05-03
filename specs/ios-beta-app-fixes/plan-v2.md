# iOS Beta App Fixes — Plan v2

**Status**: Active (in progress)
**Author**: Generated 2026-05-03 from session investigation
**Supplements**: `specs/ios-beta-app-fixes/plan.md`
**Target**: `ios-app/OpenCodeNexus/`
**Reference baseline**: `~/Github/opencode/packages/{app,ui,sdk/js,opencode}` — opencode v2 is the canonical behavior we mirror.
**Goal**: Ship a TestFlight-ready build that fixes user-reported regressions in archive, question replies, message streaming, workspace creation, and session presentation.

---

## How to read this document

Each fix below has six sections:

1. **Symptom** — what the user sees
2. **Root cause** — what's actually wrong (with file:line)
3. **Canonical reference** — what opencode does (with file:line)
4. **Fix** — the smallest change that resolves it
5. **Acceptance criteria** — verifiable conditions
6. **Tests** — what to add/update

The plan is intentionally tight: every item is a real bug verified against either the opencode SDK schema, the opencode server source, or the opencode app source. There are no speculative refactors.

---

## Bug index

| ID | Severity | Area | Symptom | Status |
|---|---|---|---|---|
| V2-001 | High | API client | Archive doesn't persist; session reappears after refresh | ✅ Fixed |
| V2-002 | High | UI | "Submit" on a question reports "no response was sent" even after filling form | ✅ Fixed |
| V2-003 | High | Streaming | Streamed assistant messages truncate / restart mid-stream | ⏳ Pending |
| V2-004 | Low | Streaming | Stream silently ends on a non-existent "done" event | ⏳ Pending |
| V2-005 | Medium | Streaming | Stream "freezes" after Wi-Fi/cellular handoff or backgrounding | ⏳ Pending |
| V2-006 | Low | UI | New sessions show cryptic ID slugs instead of dates | ⏳ Pending |
| V2-007 | Medium | UI | Active session list grows unbounded with old/abandoned sessions | ⏳ Pending |
| V2-008 | High | API client | Create workspace fails with HTTP 400 ("expected null, received undefined") | ⏳ Pending |

---

## V2-001 — Archive endpoint does not exist

### Symptom
User swipe-archives a session. The row visually slides away. After pull-to-refresh (or app relaunch), the session reappears in the active list. No error toast.

### Root cause
`Services/OpenCodeClient.swift:404-412` (pre-fix) called `POST /session/{id}/archive` and `POST /session/{id}/unarchive`. These routes do not exist on the opencode server. The 404 response throws inside `client.archiveSession`, which is caught in `ChatViewModel.archiveSession` and assigned to `errorMessage` — but the `withAnimation { sessions.removeAll(...) }` block is unreachable, so the data never updates.

The illusion of a successful archive comes from SwiftUI's `swipeActions` row animation, which animates regardless of whether the data source changes. Once the next render runs (pull-to-refresh), the unchanged data re-renders the row.

### Canonical reference
The opencode server only supports archiving via `PATCH /session/{sessionID}` with a `time.archived` field in the body:

- Route handler: `packages/opencode/src/server/routes/instance/session.ts:289-317`
  ```ts
  validator("json", z.object({
    title: z.string().optional(),
    permission: Permission.Ruleset.zod.optional(),
    time: z.object({ archived: z.number().optional() }).optional(),
  })),
  async (c) => jsonRequest("SessionRoutes.update", c, function* () {
    const updates = c.req.valid("json")
    if (updates.time?.archived !== undefined) {
      yield* session.setArchived({ sessionID, time: updates.time.archived })
    }
  })
  ```

- Web client usage: `packages/app/src/pages/layout.tsx:994-998`
  ```ts
  await globalSDK.client.session.update({
    sessionID: session.id,
    directory: session.directory,
    time: { archived: Date.now() },
  })
  ```

Note: the route checks `updates.time?.archived !== undefined`. To unarchive, the server reads any defined value (including `0`) and stores it. The iOS-side `isArchived` check then needs to treat `0` as "not archived" since that's the sentinel we use for explicit unarchive.

### Fix (applied)
`Services/OpenCodeClient.swift`:
```swift
func archiveSession(_ sessionId: String, directory: String? = nil) async throws -> Session {
    let archivedAt = Int64(Date().timeIntervalSince1970 * 1000)
    let body = UpdateSessionBody(time: .init(archived: archivedAt))
    return try await patch("session/\(sessionId)", body: body, query: queryItems(directory: directory))
}

func unarchiveSession(_ sessionId: String, directory: String? = nil) async throws -> Session {
    let body = UpdateSessionBody(time: .init(archived: 0))
    return try await patch("session/\(sessionId)", body: body, query: queryItems(directory: directory))
}
```

`UpdateSessionBody` extended with optional `time` field and a custom `encode(to:)` that omits nil keys (so `updateSession(title:)` calls don't accidentally send `time: null`):
```swift
private struct UpdateSessionBody: Encodable {
    let title: String?
    let time: TimeUpdate?
    struct TimeUpdate: Encodable { let archived: Int64? }
    init(title: String? = nil, time: TimeUpdate? = nil) { ... }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let title { try container.encode(title, forKey: .title) }
        if let time { try container.encode(time, forKey: .time) }
    }
}
```

`Models/Session.swift:51-53`:
```swift
var isArchived: Bool { (time.archived ?? 0) > 0 }
```

### Acceptance criteria
- [x] Archive PATCHes `/session/{id}` with body `{"time":{"archived":<unix-ms>}}`.
- [x] Unarchive PATCHes with `archived: 0`.
- [x] `Session.isArchived` returns `false` when `time.archived` is nil OR 0; `true` otherwise.
- [x] `updateSession(title:)` continues to send only `{"title":"..."}` (no `time` key) to avoid clobbering archive state.
- [ ] Manual: archive → pull-to-refresh → session stays in Archived.
- [ ] Manual: relaunch app → archive persists.

### Tests
- Added `testArchiveSessionPatchesWithUnixMillisTimestamp` in `OpenCodeNexusTests/OpenCodeClientTests.swift` — asserts PATCH method, path, and that `time.archived` is a unix-ms within ±1 second of now.
- Added `testUnarchiveSessionPatchesWithZeroTimestamp` — asserts `time.archived == 0` and resulting session has `isArchived == false`.
- Both tests assert `body["title"] == nil` to confirm we don't accidentally clear titles.

---

## V2-002 — Question Submit fires Reject due to SwiftUI List-row tap collision

### Symptom
User opens a question sheet, fills out the form, taps **Submit**. Sheet closes. The LLM tool result reads "no response was sent" or "user dismissed the question without answering."

### Root cause
`Views/QuestionSheet.swift:31-46` (pre-fix) placed two `Button`s — Submit and Reject — inside a `List` row without an explicit `.buttonStyle()`. In SwiftUI, multiple default-style Buttons inside a List/Form row collapse into a single row-level tap target. Tapping anywhere in the row fires *every* button.

So tapping Submit:
1. Fires `onAnswer(question, answers)` → starts `Task { await chatVM.answerQuestion(...) }` → POST `/question/{id}/reply`.
2. *Also* fires `onReject(question)` → starts `Task { await chatVM.rejectQuestion(...) }` → POST `/question/{id}/reject`.
3. Both Tasks run concurrently. Reject has a smaller payload (no JSON body) and typically wins the race. Server records the rejection and emits `question.rejected` over SSE.
4. The LLM tool sees the rejection: "no response was sent."
5. The Reply request lands second; server returns 404 (question already resolved); error caught silently in `ChatViewModel.answerQuestion`.

The option-toggle buttons in the same view (`QuestionSheet.swift:97`) already had `.buttonStyle(.plain)` — whoever wrote those knew the gotcha existed for that case but missed it for Submit/Reject.

### Canonical reference
The opencode web composer (`packages/app/src/pages/session/composer/session-question-dock.tsx:202-241`) renders Submit/Reject as separate `<button>` elements outside of any List structure. Each `<button>` has its own DOM event target by default — no collision is possible. So the web reference doesn't need to deal with this; it's iOS-specific.

### Fix (applied)
`Views/QuestionSheet.swift`: add `.buttonStyle(.borderless)` to both Submit and Reject Buttons. `.borderless` is preferred over `.plain` because it preserves `role: .destructive`'s red tint and the `Label`'s SF Symbol coloring while still isolating the tap target.

### Acceptance criteria
- [x] Submit button has `.buttonStyle(.borderless)`.
- [x] Reject button has `.buttonStyle(.borderless)`.
- [x] Reject still renders with destructive (red) color treatment.
- [ ] Manual: open question sheet, tap Submit → only one network request (`POST /question/{id}/reply`); no rejection request.
- [ ] Manual: tap Reject → only `POST /question/{id}/reject`; no reply request.
- [ ] Manual: tool output in the chat shows the user's answers, not "no response."

### Tests
- Added `testQuestionSheetRendersEmpty` and `testQuestionSheetRendersWithSingleQuestion` in `OpenCodeNexusTests/ViewBodyTests.swift` — smoke tests that the sheet renders without crashing for both states.
- A true tap-isolation test would require ViewInspector or UI tests; deferred. Manual matrix covers it.

---

## V2-003 — 300 ms reload after every message event clobbers live deltas

### Symptom
During an active assistant response, text streams in for ~1 second, then either:
- abruptly truncates and stops growing
- vanishes and re-appears as an earlier (shorter) snapshot
- re-orders parts (tool calls jump ahead of text)

Final state usually settles correctly after `session.status == idle`, but the live experience is broken.

### Root cause
`ViewModels/ChatViewModel.swift:1344-1349` (in `handleEvent`):
```swift
case "message.updated", "message.part.updated":
    ...
    messageReloadTask?.cancel()
    messageReloadTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await loadMessages()  // ← clobbers in-flight deltas
    }
```

Sequence:
1. `message.part.delta` arrives → `applyDelta` appends to `messages[i].parts[j].text`.
2. `message.part.updated` arrives → `applyPartUpdate` replaces the part with the server snapshot.
3. The 300 ms `messageReloadTask` is scheduled.
4. More `message.part.delta` events arrive → text continues to grow locally.
5. 300 ms elapse → `loadMessages()` GETs the server snapshot (which is still mid-stream and behind by hundreds of ms).
6. The slow REST snapshot **overwrites** `messages` with stale data, dropping the in-flight deltas.

Then steps 4–6 repeat as more events arrive. The user sees the assistant text "flickering" between live and stale states.

### Canonical reference
opencode's web app (`packages/app/src/context/global-sync.tsx`) **never** reloads via REST during streaming. It maintains an in-memory event reducer that applies `message.part.updated` and `message.part.delta` events directly to the session state. REST is only used for initial session load and explicit refresh.

The reducer is in `packages/app/src/context/global-sync/event-reducer.ts` and `applyDirectoryEvent`/`applyGlobalEvent`. The full reload path (`fetchSession` etc.) is only invoked on initial mount and explicit user actions, not after every incoming event.

### Fix (planned)
Delete the `messageReloadTask` block from the `message.updated` / `message.part.updated` case. Trust the streamed payload — `applyMessageUpdate` and `applyPartUpdate` already handle the data correctly.

Keep `loadMessages()` calls only at:
- (a) Initial session selection (`selectSession`).
- (b) `session.status == idle` event (for final reconciliation).
- (c) Explicit pull-to-refresh.
- (d) After resuming from background, if the connection was stale.

### Acceptance criteria
- [ ] No `loadMessages()` call inside the `message.updated` / `message.part.updated` event handler.
- [ ] Long-prompt streaming completes without truncation.
- [ ] Final assistant message matches what's served by `GET /session/{id}/message` after `session.status == idle`.

### Tests
- Update `OpenCodeNexusTests/ChatViewModelTests.swift` to assert that handling `message.part.updated` does NOT trigger an additional `getMessages` call.
- Add a test that interleaves `message.part.delta` events between `message.part.updated` events and verifies the final `messages[0].parts[0].text` equals the concatenation of all deltas.

---

## V2-004 — Bogus "done" SSE terminator

### Symptom
Streaming sometimes stops abruptly after a benign event arrives, and the SSE connection enters its reconnect-backoff loop. Recovers in ~1–2 s.

### Root cause
`Services/OpenCodeClient.swift:618-621`:
```swift
if event.eventType == "done" {
    clientLogger.info("SSE: received done event")
    continuation.finish()
    return
}
```

The opencode `/event` endpoint is a **persistent global event bus**. It does not emit a "done" event in the v2 protocol — there's no such type in `packages/sdk/js/src/v2/gen/types.gen.ts`. This special case is dead code from an earlier per-message streaming endpoint.

In practice, the special case rarely fires (no event has `type: "done"`), but if a future opencode build sends a custom event whose type happens to start with that string, or if a malformed event passes the parser with a quirky type, the stream silently dies.

### Canonical reference
opencode's SSE client (`packages/sdk/js/src/v2/gen/core/serverSentEvents.gen.ts`) has no such special case. The stream ends only when:
- the connection closes (network, server shutdown)
- the AbortController is fired
- the read loop hits an exception

Any event type is yielded to the consumer for handling.

### Fix (planned)
Delete lines 618-621. Let `eventStream` only finish on connection close, task cancellation, or thrown error.

### Acceptance criteria
- [ ] `eventStream` does not special-case any event type.
- [ ] No regression in existing SSE tests in `OpenCodeClientTests.swift`.

### Tests
- Existing `testEventStreamIncludesDirectoryAndWorkspaceQuery` covers basic streaming. Add a test that confirms a synthetic event with `type: "done"` is yielded to the consumer (not swallowed) — pinning the behavior change.

---

## V2-005 — No heartbeat / no foreground reconnect

### Symptom
After backgrounding the app for >30 s, or after a Wi-Fi-to-cellular handoff, streaming "freezes." New messages don't appear until the user force-quits and reopens. The loading spinner spins forever.

### Root cause
The iOS `URLSession` SSE read in `OpenCodeClient.eventStream` has no heartbeat. iOS keeps the dead long-poll connection open silently; URLSession doesn't surface a TCP RST until either:
- the OS reaps the socket (can be minutes on cellular)
- a write fails (we never write on a GET)

Result: the AsyncThrowingStream never throws and never finishes. `ChatViewModel.startEventStream`'s reconnect-with-backoff loop is built around catching errors — with no error, it just hangs in `for try await event in client.eventStream()`.

There's also no foreground observer to invalidate stale connections after a background-to-foreground transition.

### Canonical reference
opencode's web app (`packages/app/src/context/global-sdk.tsx:111-125, 216-223`) has both:

```ts
const HEARTBEAT_TIMEOUT_MS = 15_000
let lastEventAt = Date.now()
let heartbeat: ReturnType<typeof setTimeout> | undefined
const resetHeartbeat = () => {
  lastEventAt = Date.now()
  if (heartbeat) clearTimeout(heartbeat)
  heartbeat = setTimeout(() => { attempt?.abort() }, HEARTBEAT_TIMEOUT_MS)
}
...
makeEventListener(document, "visibilitychange", () => {
  if (document.visibilityState !== "visible") return
  if (!started) return
  if (Date.now() - lastEventAt < HEARTBEAT_TIMEOUT_MS) return
  attempt?.abort()
})
```

The heartbeat aborts the `fetch` if 15 s pass with no event, falling through to the reconnect loop. The visibilitychange handler does the same on tab-focus if the last event is stale.

### Fix (planned)
Two changes:

1. `Services/OpenCodeClient.swift::eventStream` — wrap the URLSession read with a heartbeat watchdog. After each yielded event, restart a 15 s timer. If the timer fires before the next event, cancel the URLSession task; the AsyncStream throws a cancellation error; `ChatViewModel`'s existing backoff loop reconnects.

2. `ViewModels/ChatViewModel.swift` — observe `UIApplication.willEnterForegroundNotification`. On fire, cancel `eventTask` so the existing backoff reconnects with a fresh URLSession.

### Acceptance criteria
- [ ] If 15 s pass with no SSE event, `eventStream` throws and `startEventStream` reconnects.
- [ ] On `willEnterForegroundNotification`, the current event task is cancelled and a new one starts.
- [ ] No false-positive heartbeats during normal streaming (events arrive frequently enough).
- [ ] Manual: background app for 30 s → foreground → next message streams in within 1 s of activity.
- [ ] Manual: kill Wi-Fi briefly → reconnects after handoff.

### Tests
- Unit: `MockURLProtocol` returns a small SSE response with no further data and never closes; the iOS `eventStream` should throw a heartbeat-timeout error within ~15 s. Use a configurable timeout for fast testing (e.g., 100 ms in test mode).
- Manual matrix as above.

---

## V2-006 — Cryptic ID slugs for unnamed sessions

### Symptom
A new session that the user hasn't titled shows in the list as "Mch7 Hg2 Pq0" or similar — visually meaningless to the user.

### Root cause
`Models/Session.swift:35-41` slug-decodes the session ID when title is empty or starts with "New session":
```swift
var displayTitle: String {
    if title.hasPrefix("New session") || title.isEmpty {
        let slug = id.hasPrefix("ses_") ? String(id.dropFirst(4)) : id
        return slug.replacingOccurrences(of: "-", with: " ").capitalized
    }
    return title
}
```

Session IDs in opencode are ulid-like, not memorable.

### Canonical reference
opencode's web app uses `time.created` to derive a friendly fallback (`packages/app/src/pages/layout/helpers.ts` and similar). For iOS, a localized date format is the cleanest match.

### Fix (planned)
Replace the slug branch with a formatted creation date:
```swift
var displayTitle: String {
    if title.hasPrefix("New session") || title.isEmpty {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "New Session – \(formatter.string(from: time.createdDate))"
    }
    return title
}
```

The en-dash (`–`) matches macOS conventions for separating titles from metadata.

### Acceptance criteria
- [ ] Empty/`"New session"` titles show as `"New Session – Mar 5, 2:14 PM"` (locale-aware).
- [ ] User-set titles still pass through unchanged.

### Tests
- Add `OpenCodeNexusTests/SessionTests.swift` — assert `displayTitle` for an empty title, a "New session" title, and a custom title under a fixed locale (`en_US_POSIX` or pinned `Locale(identifier: "en_US")`).

---

## V2-007 — Unbounded session list

### Symptom
Power users accumulate hundreds of sessions over weeks. The session sidebar becomes unscrollable; finding a recent session is slow.

### Root cause
No client-side recency filter. `ChatViewModel.loadSessions` returns everything the server has (up to `sessionPageLimit`).

### Canonical reference
opencode's web app does not have a hard time filter (it relies on virtualization for performance), but the user explicitly asked for a 14-day cutoff with an opt-in escape hatch. This is a product decision, not a behavior mirror.

### Fix (planned)
1. Add to `ChatViewModel`:
   - `var showAllSessions: Bool = false` (published)
   - `var hasOlderSessionsHidden: Bool` (computed, published) — true when at least one session was filtered out.
   - Update `sessionGroups` to apply `time.updated ?? time.created >= now - 14 days` unless `showAllSessions`.
   - **Never** hide the currently-selected session (avoids "where did my session go?").

2. Add to `ChatView` session list:
   - When `hasOlderSessionsHidden && !showAllSessions`: footer row labelled "Show older sessions ({count})" that toggles `showAllSessions = true`.
   - When `showAllSessions`: a "Show only recent" toggle in the toolbar or a footer to reverse it.

### Acceptance criteria
- [ ] Default session list shows only sessions with activity in the last 14 days.
- [ ] Currently-selected session is always visible regardless of age.
- [ ] "Show older sessions" footer appears when items are hidden.
- [ ] Toggling reveals all sessions.
- [ ] Filter does not affect `archivedSessions` (Archived section has its own affordance).

### Tests
- Add `OpenCodeNexusTests/ChatViewModelExtendedTests.swift::testRecencyFilterHidesOlderSessions` — load a fixture with 3 recent + 2 old sessions, verify default `sessionGroups` shows 3, `hasOlderSessionsHidden == true`, and toggling shows 5.
- Add a case where the selected session is older than 14 days — verify it's still visible.

---

## V2-008 — Create workspace fails with HTTP 400 (`branch` is undefined)

### Symptom
User taps Create → choose Worktree → toggle "Auto-generate branch name" ON → tap Create. Modal shows a red error block:
```
Server error (HTTP 400): {"data":{"type":"worktree","error":[{"code":"invalid_union","errors":
[[{"expected":"string","code":"invalid_type","path":[],"message":"Invalid input: expected string,
received undefined"}],[{"expected":"null","code":"invalid_type","path":[],"message":"Invalid
input: expected null, received undefined"}]],"path":["branch"],"message":"Invalid input"}],
"success":false}
```

### Root cause
`Services/OpenCodeClient.swift:798-801`:
```swift
private struct CreateWorkspaceBody: Encodable {
    let type: String
    let branch: String?
}
```

Swift's synthesized `Codable` for an optional struct field omits the key when the value is nil — the same behavior as `JSON.stringify` skipping `undefined`. So the on-the-wire body becomes `{"type":"worktree"}` with no `branch` field.

But the server schema requires `branch` to be present and to be a `string` or `null` — never omitted:

- `packages/opencode/src/control-plane/types.ts:11`:
  ```ts
  branch: Schema.NullOr(Schema.String),
  ```
- which compiles to a Zod union `z.union([z.string(), z.null()])` — a `Schema.NullOr` (not `Schema.optional`).
- `packages/opencode/src/control-plane/workspace.ts:76-82` `CreateInput.fields.branch` is `Info.fields.branch` directly, so the field is required.

The server's Zod validator therefore reports both branches of the union failing because `undefined` is neither a string nor `null`. That matches the error payload exactly.

### Canonical reference
The opencode web app sends `branch: null` explicitly when the user opts out:

- Search via `grep -rn "branch.*null\|branch:" packages/app/src/pages/layout.tsx | head` (and similar) shows `branch: null` literals in the workspace creation flow.

The opencode SDK's `Workspace.CreateInput` (`packages/sdk/js/src/v2/gen/types.gen.ts`, search for `WorkspaceCreateInput`) also types `branch` as `string | null`, not `string?`.

### Fix (planned)
Make `CreateWorkspaceBody.encode(to:)` always emit the `branch` key — null when nil, string otherwise:
```swift
private struct CreateWorkspaceBody: Encodable {
    let type: String
    let branch: String?

    enum CodingKeys: String, CodingKey { case type, branch }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        // Server requires branch to be present (string or null), never omitted.
        if let branch {
            try container.encode(branch, forKey: .branch)
        } else {
            try container.encodeNil(forKey: .branch)
        }
    }
}
```

### Acceptance criteria
- [ ] When `branch` is nil in Swift, the JSON body has `"branch": null` (not omitted).
- [ ] When `branch` is set, the JSON body has `"branch": "<value>"`.
- [ ] Manual: create a worktree workspace with auto-generate ON → succeeds.
- [ ] Manual: create with a custom branch name → succeeds and worktree uses that branch.
- [ ] No regression in workspace deletion / listing flows.

### Tests
- Add `testCreateWorkspaceSendsExplicitNullBranchWhenNil` in `OpenCodeNexusTests/OpenCodeClientTests.swift` — assert `body["branch"] is NSNull` (not absent).
- Add `testCreateWorkspaceSendsBranchStringWhenProvided` — assert `body["branch"] as? String == "feat/foo"`.

---

## Order of execution

1. ✅ V2-001 — Archive endpoint
2. ✅ V2-002 — Question button collision
3. ⏳ V2-008 — Create-workspace branch null *(promoted; user-visible blocker)*
4. ⏳ V2-003 — Remove reload-clobber
5. ⏳ V2-004 — Remove "done" terminator *(paired commit with V2-003 — both delete dead code)*
6. ⏳ V2-005 — Heartbeat + foreground reconnect
7. ⏳ V2-006 — Display title formatted date
8. ⏳ V2-007 — 14-day recency filter
9. ⏳ Pre-TestFlight thorough review (next section)

Each step lands as one commit with tests passing. Commit messages use Conventional Commits (`fix:`, `feat:`).

---

## Pre-TestFlight thorough review checklist

Before tagging the next TestFlight build, run the following review against the iOS app to catch additional blockers. The review is structured by area; each item should be scanned even if not explicitly reported.

### A. API surface audit
- [ ] Every method in `Services/OpenCodeClient.swift` is verified against `~/Github/opencode/packages/sdk/js/src/v2/gen/sdk.gen.ts` for path, method, and body shape.
- [ ] All `Encodable` body structs that contain optional fields are reviewed — for each nilable field, decide whether the server wants `null` or omitted, and use a custom `encode(to:)` if needed.
- [ ] Authentication headers (CF Access) are present on every request.
- [ ] All error paths surface to `errorMessage`, not silently swallowed.

### B. Streaming reliability
- [ ] Heartbeat watchdog (V2-005) verified to fire under simulated dropped connections.
- [ ] Foreground notification reconnect verified on real device.
- [ ] No `loadMessages()` invoked from inside SSE event handlers (V2-003).
- [ ] No event types special-cased to terminate the stream (V2-004).
- [ ] Reconnect backoff: cap, jitter, max attempts.

### C. Concurrency / Swift Concurrency hygiene
- [ ] No `MutexGuard` held across `await` (search for `lock().await` patterns).
- [ ] All `@Published`/`@Observable` mutations on `MainActor`.
- [ ] No detached `Task { }` inside views that could leak (audit ChatView callbacks).
- [ ] `eventTask?.cancel()` called on `.onDisappear` (already present at `ChatView.swift:79`).

### D. UI / UX
- [ ] Touch targets ≥ 44pt (especially in QuestionSheet, MessageInputView).
- [ ] All sheet dismissals that affect server state explicitly send a request (no silent close — see V2-002 sibling issue: `QuestionSheet`'s "Close" toolbar button does NOT reject; this should at minimum confirm with user).
- [ ] Long titles and long messages don't break layout (test with a 4 KB pasted block).
- [ ] Dark mode colors meet WCAG 2.2 AA contrast.

### E. Accessibility
- [ ] All interactive elements have `accessibilityLabel`.
- [ ] Dynamic Type from xSmall to AX5 — composer remains usable.
- [ ] VoiceOver navigation order is logical in QuestionSheet, PermissionSheet, ChatSidebar.

### F. Security
- [ ] No secrets in logs (search for `print.*token`, `print.*password`).
- [ ] Keychain-backed credentials never written to UserDefaults.
- [ ] TLS verification not disabled (`URLSessionConfiguration` reviewed).
- [ ] CF Access client secret read from Keychain, not bundle.

### G. Memory and performance
- [ ] No retain cycles in `Task { [weak self] in ... }` patterns (audit ChatViewModel).
- [ ] SSE parser doesn't accumulate unbounded buffer on malformed input.
- [ ] Large session message histories (1000+ messages) don't lock UI on selection.

### H. Build and metadata
- [ ] Bundle ID, version, and build number incremented for TestFlight.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) covers all SDK usage.
- [ ] Icon and launch screen assets present.
- [ ] App Transport Security exceptions (if any) documented.

### I. Test coverage
- [ ] All V2-001 through V2-008 fixes have corresponding unit tests.
- [ ] `xcodebuild test` passes locally.
- [ ] Manual matrix in this plan executed on a real device (not simulator).

### J. Crash reporting
- [ ] Sentry DSN configured (`CrashReporter.swift`).
- [ ] No PII in breadcrumbs (search for breadcrumbs that include message content).
- [ ] Sentry transactions for: connection, session load, message send, event stream.

---

## Verification commands

```bash
# Run unit tests (when running on a Mac with Xcode)
cd ios-app
xcodebuild test \
  -workspace OpenCodeNexus.xcworkspace \
  -scheme OpenCodeNexus \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  -derivedDataPath build/DerivedData/Verify

# Lint Swift (if SwiftLint installed)
swiftlint lint ios-app/OpenCodeNexus

# Verify bundle for TestFlight (after build)
xcodebuild archive ...
xcrun altool --validate-app ...
```

---

## Out of scope (tracked elsewhere)

- Cross-session permission UI rework — Phase 3 of `plan.md` (IOS-BETA-007 through 009).
- Composer layout overhaul — Phase 4 of `plan.md` (IOS-BETA-010 through 011).
- Event coalescer / batching — measure first; the V2-003 fix may make this unnecessary.
- iOS 26 Liquid Glass styling polish — separate design pass.

---

## Appendix A — Schema references

For future-proofing, here are the canonical opencode source files that defined each schema we depend on. If these change in upstream, our iOS client may need updates.

| Concept | Path |
|---|---|
| Session schema | `packages/opencode/src/session/session.ts` (Info type) |
| Session update route | `packages/opencode/src/server/routes/instance/session.ts:289-317` |
| `time.archived` semantics | `packages/opencode/src/session/session.ts:619-621` (setArchived) |
| Workspace schema | `packages/opencode/src/control-plane/types.ts:7-15` |
| Workspace create route | `packages/opencode/src/server/routes/control/workspace.ts:39-71` |
| Worktree schema | `packages/opencode/src/worktree/index.ts:54-63` |
| Question reply route | `packages/opencode/src/server/routes/instance/question.ts` (search) |
| Event stream | `packages/opencode/src/server/routes/instance/events.ts` (search) |
| Event types | `packages/sdk/js/src/v2/gen/types.gen.ts` (search `Event*`) |
| SSE client | `packages/sdk/js/src/v2/gen/core/serverSentEvents.gen.ts` |
| Web app event reducer | `packages/app/src/context/global-sync/event-reducer.ts` |
| Web app heartbeat | `packages/app/src/context/global-sdk.tsx:111-125` |

---

## Appendix B — Why we mirror opencode patterns

The iOS app is a **client** of opencode. The opencode server and web app together define what "correct" looks like:

- **Server** (TypeScript, Hono routes) — the source of truth for routes, schemas, and validation rules.
- **Web app** (SolidJS) — the reference UX implementation: how to handle real-time events, when to reload vs. trust the stream, what to show during transitions.

When fixing a bug, the question is always "what does opencode-the-canonical do here?" If we diverge, we should have a documented reason. This plan documents reasons for each divergence (e.g., V2-007 is a deliberate product decision, not a behavior bug).

This approach has already paid off in this session: V2-001 (archive endpoint) was a place where we'd built our own paths instead of mirroring the SDK; V2-008 (workspace branch) was a place where Swift's nil-omission diverged from the server's requirement of an explicit null. Both bugs would have been caught immediately if we'd cross-referenced opencode's schema first.

---

## Changelog
- 2026-05-03 — Initial plan-v2 written. Bugs V2-001 and V2-002 fixed and tests added. V2-008 added based on user-reported screenshot. V2-003 through V2-007 in queue.
