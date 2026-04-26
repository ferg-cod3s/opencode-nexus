# Phase 2: Frontend Integration - Implementation Plan

**Date Created**: November 12, 2025
**Status**: Starting Phase 2
**Goal**: Connect frontend UI to backend (Rust + Tauri), achieve 80%+ E2E test pass rate
**Duration**: 7 days (Days 8-14)

---

## 📊 Current Status Assessment

### ✅ What's Already Built

**Backend (Phase 1 - COMPLETE)**:
- ✅ ConnectionManager with 9 tests
- ✅ ChatClient with 11 tests (integration + persistence)
- ✅ MessageStream with 10 tests (SSE streaming)
- ✅ Event Bridge with 6 tests (Tauri commands)
- ✅ **36 total backend tests passing**
- ✅ All Tauri commands registered and working

**Frontend Infrastructure (COMPLETE)**:
- ✅ `chat-api.ts` - Full API wrapper with all functions
  - loadChatSessions(), createChatSession(), sendChatMessage()
  - startChatEventListener(), initializeChat()
- ✅ `chat.ts` store - Comprehensive state management
  - Sessions, active session, chat state, composition
  - Offline storage integration
  - Message streaming support
- ✅ `tauri-api.ts` - Tauri invoke/listen wrappers with browser fallbacks
- ✅ Components exist: ChatInterface, MessageBubble, ConnectionStatus, etc.

**E2E Tests**:
- ✅ 46/121 passing (38%)
- ✅ Auth tests: 19/19 passing (100%)
- ✅ Dashboard tests: 2/2 passing (100%)
- ❌ Chat tests: 2/14 passing (mostly blocked)
- ❌ ~75 tests blocked by missing backend integration

### 🎯 What Needs to Be Done

**Primary Blockers**:
1. **Wire ChatInterface component to chat-api** - Component exists but not calling backend
2. **Initialize chat event listener on app load** - Events not being listened to
3. **Connect MessageInput to sendChatMessage** - Send button not wired
4. **Wire SessionPanel to loadSessions** - Sessions not loading from backend
5. **Test and fix E2E integration** - Many tests timing out waiting for backend

---

## 📅 Phase 2 Daily Plan

### **Day 8: Component Integration** (3-4 hours)
**Goal**: Wire existing components to backend API

**Files to Modify**:
- `frontend/src/pages/chat.astro`
- `frontend/src/components/ChatInterface.svelte`
- `frontend/src/components/SessionPanel.svelte`

**Tasks**:
1. ✅ Review chat-api.ts and confirm all functions work
2. Initialize chat system in chat.astro (call initializeChat on mount)
3. Wire ChatInterface onSendMessage to chatActions.sendMessage
4. Wire SessionPanel to load sessions on mount
5. Test basic message flow: compose → send → backend → response

**Success Criteria**:
- User can send a message and it reaches the backend
- Backend response events are received by frontend
- Sessions load from backend on page load

**Test Command**: `bun test frontend/src/components/__tests__/ChatInterface.test.ts`

---

### **Day 9: Event Handling & Streaming** (3-4 hours)
**Goal**: Real-time message streaming works end-to-end

**Files to Modify**:
- `frontend/src/stores/chat.ts` (chatActions.handleChatEvent)
- `frontend/src/components/MessageBubble.svelte`
- `frontend/src/components/StreamingIndicator.svelte`

**Tasks**:
1. Verify handleChatEvent processes all event types correctly
   - SessionCreated → add to sessions
   - MessageReceived → add complete message
   - MessageChunk → append to streaming message
   - Error → show error state
2. Test MessageBubble shows streaming indicator
3. Test message chunks append correctly
4. Add auto-scroll when new messages arrive
5. Test streaming animation works

**Success Criteria**:
- AI responses stream in real-time (chunk by chunk)
- Streaming indicator shows while message is being received
- Messages auto-scroll to bottom as they arrive
- Complete message replaces streaming placeholder

**Test Command**: `bun test frontend/src/stores/__tests__/chat.test.ts`

---

### **Day 10: Connection Management UI** (3-4 hours)
**Goal**: Users can connect to OpenCode servers via UI

**Files to Modify**:
- `frontend/src/components/ConnectionStatus.svelte`
- `frontend/src/components/ServerConnection.svelte`
- `frontend/src/pages/settings.astro` (if exists, or create)

**Tasks**:
1. Wire ServerConnection component to connect_to_server command
2. Add form validation for hostname/port input
3. Show connection status (Connecting → Connected → Disconnected)
4. Display server info when connected (version, status)
5. Add disconnect button
6. Test connection error handling
7. Add saved connections list (recent servers)

**Success Criteria**:
- User can input server hostname:port and connect
- Connection status updates in real-time
- Server info displays when connected
- Error messages show for failed connections
- Saved connections persist across restarts

**Test Command**: `bun test frontend/src/components/__tests__/ConnectionStatus.test.ts`

---

### **Day 11: Session Management** (2-3 hours)
**Goal**: Session creation, switching, and deletion work

**Files to Modify**:
- `frontend/src/components/SessionPanel.svelte`
- `frontend/src/components/ChatSessionCard.svelte`
- `frontend/src/stores/chat.ts`

**Tasks**:
1. Wire "New Session" button to createChatSession
2. Wire session cards to switch active session
3. Load session history when switching sessions
4. Implement session deletion with confirmation
5. Test session persistence across page refresh
6. Add session title editing (optional)

**Success Criteria**:
- User can create new sessions
- Clicking a session loads its messages
- Session list updates in real-time
- Deleted sessions disappear immediately
- Sessions persist across app restart

**Test Command**: `bun test frontend/src/components/__tests__/SessionPanel.test.ts`

---

### **Day 12: Offline & Error Handling** (2-3 hours)
**Goal**: Offline mode and error states work correctly

**Files to Modify**:
- `frontend/src/components/GlobalOfflineBanner.svelte`
- `frontend/src/components/OfflineIndicator.svelte`
- `frontend/src/utils/offline-storage.ts` (verify integration)

**Tasks**:
1. Test offline message queueing works
2. Verify messages sync when connection restored
3. Test offline indicator shows/hides correctly
4. Add retry logic for failed messages
5. Test error messages display correctly
6. Add user-friendly error recovery options

**Success Criteria**:
- User can compose messages while offline
- Messages queue and send when back online
- Offline banner shows/hides based on connection
- Failed messages can be retried
- Error messages are clear and actionable

---

### **Day 13: E2E Testing & Bug Fixes** (4-5 hours)
**Goal**: E2E test pass rate reaches 80%+ (97/121 tests)

**Tasks**:
1. Run full E2E suite: `cd frontend && bun run test:e2e`
2. Document current failures with categories:
   - Timing issues (add proper waits)
   - Missing DOM elements (check selectors)
   - Backend integration (verify Tauri commands)
   - State management (check store updates)
3. Fix tests one category at a time
4. Add proper wait conditions (waitForSelector, waitForEvent)
5. Update selectors if components changed
6. Add test helpers for common operations
7. Verify critical flows work end-to-end

**Success Criteria**:
- ✅ Auth tests: 19/19 passing (already done)
- ✅ Dashboard tests: 2/2 passing (already done)
- ✅ Chat Interface: 12+/14 passing
- ✅ Chat Spec: 10+/13 passing
- ✅ Critical Flows: 6+/8 passing
- **Overall: 80%+ pass rate**

**Test Command**:
```bash
cd frontend
bun run test:e2e --reporter=list
```

---

### **Day 14: Documentation & Polish** (3-4 hours)
**Goal**: Phase 2 complete, documented, and ready for production

**Tasks**:
1. Update STATUS_DOCS/TODO.md with Phase 2 completion
2. Document frontend integration patterns
3. Update CLAUDE.md with current status
4. Add inline code comments for complex logic
5. Run full lint/format:
   ```bash
   cd frontend
   bun run lint
   bun run typecheck
   bun run format
   ```
6. Create comprehensive Phase 2 completion commit
7. Update progress metrics (40% → 60%+)

**Success Criteria**:
- All documentation updated
- Code formatted and linted
- No TypeScript errors
- Commit describes complete Phase 2 work
- TODO.md reflects accurate status

---

## 📈 Expected Progress

| Metric | Before Phase 2 | After Phase 2 |
|--------|----------------|---------------|
| Overall Completion | 40% | 60%+ |
| E2E Test Pass Rate | 38% (46/121) | 80%+ (97/121) |
| Backend Tests | 36 passing | 36 passing |
| Frontend Integration | Scaffolded | Fully wired |
| Chat Functionality | Backend only | End-to-end working |
| Real-time Streaming | Tested | Working in UI |
| Session Management | Backend only | UI + Backend |
| Connection UI | Exists | Functional |

---

## 🎯 Critical Success Factors

1. **Follow TDD**: Test each integration before moving on
2. **One Component at a Time**: Don't try to wire everything at once
3. **Test Frequently**: Run E2E tests after each major change
4. **Debug Systematically**: Use browser DevTools + Tauri logs
5. **Document As You Go**: Update comments and docs inline

---

## 🔧 Development Workflow

### For Each Day:
1. **Morning**: Review plan, identify files to modify
2. **Implement**: Make changes, test locally
3. **Test**: Run unit tests + E2E tests for that feature
4. **Debug**: Fix any failures, check console logs
5. **Commit**: Create descriptive commit with tests passing
6. **Update TODO**: Mark tasks complete in TODO.md

### Testing Strategy:
```bash
# Frontend unit tests
cd frontend
bun test src/components/__tests__/ChatInterface.test.ts

# E2E tests (specific file)
bun run test:e2e tests/e2e/chat-interface.spec.ts

# Full E2E suite
bun run test:e2e

# Run Tauri dev for manual testing
cd ..
cargo tauri dev
```

---

## 📝 Notes

- **Backend is done**: Focus only on frontend integration
- **API exists**: chat-api.ts has all functions needed
- **Store exists**: chat.ts has comprehensive state management
- **Components exist**: UI is built, just needs wiring
- **Main work**: Connect the dots between UI → API → Backend

---

## 🚀 Let's Begin!

**Current Task**: Day 8 - Component Integration
**Next File to Modify**: `frontend/src/pages/chat.astro`
**First Action**: Initialize chat system on page load

---

**Last Updated**: November 12, 2025
**Status**: ✅ Phase 1 Complete, Starting Phase 2
**Progress**: 40% → Target 60%+ by end of Phase 2
