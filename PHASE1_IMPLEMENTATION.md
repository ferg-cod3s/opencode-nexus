# Phase 1 Implementation - Quick Reference Guide

**Status**: Ready to Start
**Timeline**: 2-3 weeks (14-21 days)
**Goal**: Complete Backend Integration → Frontend Connection → 80%+ E2E Tests
**Current**: 20% overall (38% E2E tests) → Target: 40% overall (80%+ E2E tests)

---

## 🎯 THE CRITICAL PROBLEM

The backend components exist but **aren't wired together**:

```
✅ ConnectionManager (manages server connections)
   ↓ BROKEN CONNECTION
❌ ChatClient (doesn't use ConnectionManager's server_url)
   ↓ BROKEN CONNECTION
❌ MessageStream (isn't integrated with ChatClient)
   ↓ BROKEN CONNECTION
❌ Frontend UI (doesn't call backend commands)

RESULT: 75 E2E tests failing (62% of suite) - Chat doesn't work
```

---

## 📋 QUICK WINS (Start Here)

### Immediate Actions (Next 2 Hours)
1. **Run the test suite** - Establish baseline
   ```bash
   cargo test --all
   cd frontend && bun test && bun run test:e2e
   ```

2. **Read the key files** - Understand current state
   - `src-tauri/src/connection_manager.rs` (lines 1-50)
   - `src-tauri/src/chat_client.rs` (lines 1-50)
   - `src-tauri/src/lib.rs` (lines 500-585)

3. **Identify the wiring issues** - Document what's not connected
   - Does ChatClient receive server_url from ConnectionManager?
   - Does MessageStream initialize with ChatClient's api_client?
   - Does lib.rs wire these together in Tauri commands?

---

## 🗺️ THE IMPLEMENTATION PATH (14 Days)

### Week 1: Backend Integration (Days 1-7)

#### Day 1: Connection Manager (4-5 hours)
**Goal**: Ensure ConnectionManager properly stores and retrieves server URL

**Tasks**:
- [ ] Write failing tests for connection_manager.rs
- [ ] Verify `connect_to_server()` stores server_url correctly
- [ ] Verify `test_server_connection()` makes HTTP GET to correct endpoint
- [ ] Test health monitoring background task spawns
- [ ] Run: `cargo test connection_manager`

**Expected Outcome**: ✅ Connection manager tests passing

---

#### Day 2: Chat Client Integration (4-5 hours)
**Goal**: Wire ChatClient to use ConnectionManager's server_url

**Tasks**:
- [ ] Write failing tests for chat_client.rs
- [ ] Update `create_chat_session` command in lib.rs (line 500-514)
- [ ] Make ChatClient accept server_url from ConnectionManager
- [ ] Verify ApiClient initializes with correct base URL
- [ ] Run: `cargo test chat_client`

**Expected Outcome**: ✅ ChatClient receives server_url from ConnectionManager

---

#### Day 3: Message Streaming (4-5 hours)
**Goal**: Activate SSE streaming integration

**Tasks**:
- [ ] Write failing tests for message_stream.rs
- [ ] Review MessageStream::start_streaming() (message_stream.rs:49-73)
- [ ] Verify SSE client connects to `/event` endpoint
- [ ] Test event parsing from server responses
- [ ] Ensure ChatEvent::MessageChunk emitted correctly
- [ ] Run: `cargo test message_stream`

**Expected Outcome**: ✅ Messages stream from server in real-time

---

#### Day 4: Session Persistence (3-4 hours)
**Goal**: Sessions survive app restart

**Tasks**:
- [ ] Write tests for chat persistence
- [ ] Review save_sessions() (chat_client.rs:290-299)
- [ ] Review load_sessions() (chat_client.rs:301-320)
- [ ] Implement sync_sessions_with_server() (chat_client.rs:324-344)
- [ ] Run: `cargo test chat_persistence`

**Expected Outcome**: ✅ Sessions persist to disk and reload

---

#### Day 5: Event Bridge Testing (3-4 hours)
**Goal**: Tauri event system working

**Tasks**:
- [ ] Write tests for event emission
- [ ] Verify `start_message_stream` command (lib.rs:565-585)
- [ ] Test event loop spawning (lib.rs:578-583)
- [ ] Verify `app_handle.emit("chat-event", ...)` works
- [ ] Manual test with `cargo tauri dev`

**Expected Outcome**: ✅ Events emit from backend to frontend

---

#### Day 6-7: Testing & Refactoring (8 hours)
**Goal**: Backend fully functional and tested

**Tasks**:
- [ ] Run full backend test suite: `cargo test --all`
- [ ] Fix any failing tests
- [ ] Add edge case testing
- [ ] Manual integration testing
- [ ] Code cleanup and documentation
- [ ] Format and lint: `cargo fmt && cargo clippy`

**Expected Outcome**: ✅ All backend tests passing, backend complete

---

### Week 2: Frontend Integration (Days 8-14)

#### Day 8: API Wrapper (3-4 hours)
**Goal**: Frontend can invoke backend commands

**Files**: `frontend/src/utils/chat-api.ts`

**Tasks**:
- [ ] Create wrapper functions around Tauri `invoke()` calls
- [ ] sessionLoader() → get_chat_sessions
- [ ] sessionCreator(title) → create_chat_session
- [ ] messageSender(sessionId, content) → send_chat_message
- [ ] historyLoader(sessionId) → get_chat_session_history
- [ ] initializeChat(onEvent) → setup event listener
- [ ] Write tests for API wrapper
- [ ] Run: `bun test frontend/src/utils/__tests__/chat-api.test.ts`

**Expected Outcome**: ✅ Frontend can call backend commands

---

#### Day 9: Store Integration (3-4 hours)
**Goal**: Chat state management reactive

**Files**: `frontend/src/stores/chat.ts`

**Tasks**:
- [ ] Write tests for chat store
- [ ] Implement loadSessions() action
- [ ] Implement createSession() action
- [ ] Implement handleChatEvent() for all event types
- [ ] Verify reactive updates work
- [ ] Run: `bun test frontend/src/stores/__tests__/chat.test.ts`

**Expected Outcome**: ✅ Store properly manages chat state

---

#### Day 10: ChatInterface Component (3-4 hours)
**Goal**: Chat UI connected to backend

**Files**: `frontend/src/pages/chat.astro`, `frontend/src/components/ChatInterface.svelte`

**Tasks**:
- [ ] Write tests for ChatInterface component
- [ ] Wire onSendMessage callback to invoke messageSender
- [ ] Verify message input flows through backend
- [ ] Add error handling
- [ ] Test component props and events
- [ ] Run: `bun test frontend/src/components/__tests__/ChatInterface.test.ts`

**Expected Outcome**: ✅ User messages flow to backend

---

#### Day 11: Streaming Display (3-4 hours)
**Goal**: AI responses display as they stream

**Files**: `frontend/src/stores/chat.ts`, `frontend/src/components/MessageBubble.svelte`

**Tasks**:
- [ ] Update store to handle MessageChunk events
- [ ] Add streaming message state
- [ ] Create streaming indicator animation
- [ ] Update MessageBubble to show streaming cursor
- [ ] Test auto-scroll following new messages
- [ ] Test message replacement when complete

**Expected Outcome**: ✅ Real-time message display with streaming

---

#### Day 12: Connection Status (3-4 hours)
**Goal**: Show server connection status

**Files**: `frontend/src/components/ConnectionStatus.svelte`, `frontend/src/pages/settings.astro`

**Tasks**:
- [ ] Create ConnectionStatus component
- [ ] Display current connection state
- [ ] Show server info when connected
- [ ] Add server connection form in settings
- [ ] Test hostname/port input
- [ ] Test connection validation
- [ ] Wire connect button to backend

**Expected Outcome**: ✅ Users can see and manage connections

---

#### Day 13: E2E Testing (4 hours)
**Goal**: Tests passing, bugs fixed

**Tasks**:
- [ ] Run full E2E suite: `bun run test:e2e`
- [ ] Debug failing tests one by one
- [ ] Check for timing issues, missing listeners, etc.
- [ ] Add proper wait conditions
- [ ] Fix DOM selector issues
- [ ] Verify event flow in tests
- [ ] Target: 75+ tests passing (80%+)

**Expected Outcome**: ✅ E2E test pass rate improves to 80%+

---

#### Day 14: Documentation & Commit (4 hours)
**Goal**: Phase 1 complete and documented

**Tasks**:
- [ ] Update `status_docs/TODO.md` - mark Phase 1 complete
- [ ] Update `docs/client/ARCHITECTURE.md` with actual implementation
- [ ] Update `CLAUDE.md` with current status
- [ ] Add inline code documentation
- [ ] Run full lint/format: `cargo fmt && cargo clippy && bun run lint`
- [ ] Create final comprehensive commit

**Expected Outcome**: ✅ Phase 1 documented and committed

---

## 📊 EXPECTED PROGRESS

| Metric | Before | After |
|--------|--------|-------|
| Overall Completion | 20% | 40% |
| E2E Test Pass Rate | 38% (46/121) | 80%+ (97/121) |
| Backend Tests | 29 passing | 35+ passing |
| Frontend Tests | ~0 | 20+ passing |
| Chat Functionality | None | Fully working |
| Chat UI Display | UI only | Streaming messages |
| Session Persistence | Coded | Tested & working |
| Connection Management | Exists | Integrated |

---

## 🚀 UNBLOCKING STRATEGY

**The order matters**. Follow this sequence:

```
Day 1: Connection Manager
   ↓
Day 2: ChatClient Integration (now has server_url)
   ↓
Day 3: Message Streaming (SSE works)
   ↓
Day 4-5: Persistence & Event Bridge (backend complete)
   ↓
Days 8-12: Frontend wiring (UI connects to backend)
   ↓
Day 13: E2E Testing (validate everything works)
   ↓
Day 14: Documentation (record what was built)
```

Each day unblocks the next. Don't skip around.

---

## ⚠️ CRITICAL SUCCESS FACTORS

1. **TDD First** - Write failing tests before code
2. **Test Constantly** - Run tests after every task
3. **Manual Testing** - Test with real OpenCode server
4. **Error Handling** - Handle connection failures gracefully
5. **Type Safety** - No `any` types in TypeScript
6. **Documentation** - Update as you go

---

## 🔍 HOW TO DEBUG

### Backend Not Working?
```bash
# 1. Check compilation
cargo check

# 2. Run specific test
cargo test connection_manager -- --nocapture

# 3. Run app with debug logging
RUST_LOG=debug cargo tauri dev

# 4. Check what's being invoked
# Look at console output from frontend
```

### Frontend Not Working?
```bash
# 1. Check TypeScript
bun run typecheck

# 2. Run specific test
bun test -- ChatInterface

# 3. Check browser console (F12)
# Look for invoke() errors and event listener issues

# 4. Debug Tauri IPC
# Add console.log around invoke() calls
```

### E2E Tests Failing?
```bash
# 1. Run specific test with UI
bun run test:e2e -- --headed chat.spec.ts

# 2. Add debug output
// Add waitForSelector with timeout
await page.waitForSelector('[data-testid="message"]', { timeout: 5000 });

# 3. Check element visibility
// Elements might exist but be off-screen
```

---

## 📝 COMMIT STRATEGY

**Commit frequently** after completing each task:

```bash
# Day 1 completion
git commit -m "feat: integrate connection manager

- Verify server_url stored and retrieved correctly
- Health monitoring background task spawned
- Connection tests passing

Tests: connection_manager (6 tests)
Status: Ready for ChatClient integration"

# Day 2 completion
git commit -m "feat: wire chat client to connection manager

- ChatClient receives server_url from ConnectionManager
- ApiClient initializes with correct base URL
- Integration tests passing

Tests: chat_client (8 tests)
Status: Ready for streaming integration"
```

---

## ✅ PHASE 1 COMPLETION CHECKLIST

### Backend (Week 1)
- [ ] ConnectionManager tests passing (Day 1)
- [ ] ChatClient integration complete (Day 2)
- [ ] Message streaming functional (Day 3)
- [ ] Session persistence working (Day 4)
- [ ] Event bridge tested (Day 5)
- [ ] Full backend test suite passing (Days 6-7)
- [ ] Code cleaned, formatted, documented (Day 7)

### Frontend (Week 2)
- [ ] API wrapper implemented and tested (Day 8)
- [ ] Chat store reactive and functional (Day 9)
- [ ] ChatInterface component connected (Day 10)
- [ ] Streaming message display working (Day 11)
- [ ] Connection status UI functional (Day 12)
- [ ] E2E tests at 80%+ pass rate (Day 13)
- [ ] Documentation updated and final commit (Day 14)

### Overall Success Criteria
- [ ] 0 compilation errors
- [ ] 0 linting errors
- [ ] 35+ backend tests passing
- [ ] 20+ frontend tests passing
- [ ] 97+ E2E tests passing (80%+)
- [ ] Zero vulnerabilities
- [ ] WCAG 2.2 AA accessibility maintained
- [ ] Phase 1 documented

---

## 🎓 KEY LEARNINGS

### What You'll Discover

1. **Tauri IPC Design** - How frontend/backend communicate
2. **Rust Async Patterns** - Arc<Mutex<T>>, channels, tokio::spawn
3. **Frontend State Management** - Svelte stores and reactivity
4. **E2E Testing** - Playwright testing patterns
5. **API Integration** - HTTP client, SSE streaming, error handling

### Common Gotchas

1. **Async Lock Deadlocks** - Don't hold locks across await
2. **Event Listener Timing** - Set up listeners before events fire
3. **Component Reactivity** - Update store, not just component state
4. **E2E Timing** - Add explicit waits, don't rely on timeouts
5. **Compilation** - Unused variable warnings can block builds

---

## 📞 WHEN TO ESCALATE

**Stuck for >30 minutes?**

1. Document the problem clearly
2. Check the architecture docs: `/docs/client/ARCHITECTURE.md`
3. Review the implementation plan: This file
4. Search for similar patterns in codebase
5. Create minimal reproduction case
6. Ask for help with context

---

## 🏆 You've Got This!

The architecture is solid. The components are built. You just need to wire them together.

**Current state**: 75 tests failing because chat backend isn't connected
**After Phase 1**: Chat fully functional, 80%+ tests passing

Follow the plan day by day. TDD everything. Test constantly. Document as you go.

Good luck! 🚀

---

**Last Updated**: November 11, 2025
**Status**: Ready to implement
**Next Action**: Start Day 1 - Connection Manager Integration
