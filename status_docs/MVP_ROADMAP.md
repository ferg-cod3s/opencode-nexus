# MVP Roadmap - OpenCode Nexus Client

**Current Status**: 30% Complete (Core Infrastructure Ready)
**Target**: 80%+ E2E test pass rate + production-ready client
**Timeline**: 1-2 weeks with focused effort

---

## 🎯 What's Completed (Session: Nov 27, 2025)

### ✅ Phase 1: SDK Integration (Complete)
- Frontend SDK client wrapper (`OpencodeClientManager`)
- SDK API layer with type-safe functions
- Connection state management (Svelte store)
- Backward compatible chat API adapter
- Tauri persistence commands
- 24 comprehensive E2E tests

### ✅ Phase 2: Backend Cleanup (Complete)
- Removed ~1,500 lines of manual HTTP/SSE code
- Deleted deprecated modules (api_client, message_stream, chat_client)
- Removed 7 chat-related Tauri commands (now SDK-based)
- Cleaned up Cargo.toml dependencies
- Simplified backend focus

### ✅ Phase 3: Error Handling & Retry Logic (Complete)
- 14 error type classifications
- User-friendly error messages
- Exponential backoff retry (1s → 2s → 4s → 8s → 16s)
- Centralized error handler with event emission
- Recovery suggestions for each error type
- 35+ unit tests (error-handler, retry-handler)
- All SDK API functions enhanced with retry support

### ✅ Phase 4: E2E Test Modernization (Complete)
- Analyzed and categorized 19 E2E test files
- Created modern app-flows.spec.ts (18+ tests)
- Documented E2E strategy and best practices
- Marked deprecated tests as skipped
- Test organization aligned with current architecture

---

## 🚀 Remaining Work to Reach MVP (6-10 hours)

### **PRIORITY 1: Error UI Components** (2-3 hours)
**Status**: BLOCKED - Need to implement UI
**Impact**: CRITICAL for user experience
**Estimated**: 2-3 hours

#### What to Build:
1. **Error Toast Component** (`frontend/src/components/ErrorToast.svelte`)
   - Display error message with friendly text
   - Auto-dismiss after 5-10 seconds
   - Show retry button for retryable errors
   - Different styling for error severity
   - Accessibility: ARIA labels, keyboard navigation

2. **Connection Status Component** (`frontend/src/components/ConnectionStatus.svelte`)
   - Show current connection state (Connected/Disconnected/Connecting)
   - Display reconnection attempts
   - Show network quality indicator (if available)
   - Update in real-time as connection state changes

3. **Error Recovery UI** (in Chat Page)
   - Retry button for failed message sends
   - Show recovery suggestions from error handler
   - Clear error state when user takes action

#### Integration Points:
```typescript
// In chat.astro or main layout
import { errorEmitter } from '../lib/error-handler';

const unsubscribe = errorEmitter.subscribe((error) => {
  showErrorToast(error);
});
```

#### Success Criteria:
- [ ] Toast displays errors from SDK API calls
- [ ] Retry button works for transient failures
- [ ] Connection status updates in real-time
- [ ] Recovery suggestions visible to users
- [ ] Accessibility compliant (WCAG 2.2 AA)
- [ ] Tests for error UI interaction

---

### **PRIORITY 2: Network Status Indicators** (1-2 hours)
**Status**: DEPENDENT on error toast
**Impact**: HIGH for reliability perception
**Estimated**: 1-2 hours

#### What to Build:
1. **Connection State Tracking**
   - Monitor connection health in background
   - Emit events: connected, disconnected, reconnecting
   - Show visual indicator (green dot, yellow loading, red error)

2. **Offline Detection**
   - Detect when browser loses internet
   - Show "You are offline" banner
   - Queue messages locally when offline
   - Auto-sync when reconnected

3. **Reconnection UI**
   - Show "Reconnecting..." with retry count
   - Allow manual reconnect button
   - Show exponential backoff timing if needed

#### Integration Points:
```typescript
// Enhanced connection store
export const connectionStatus = derived(connectionState, ($state) => ({
  isConnected: $state.isConnected,
  isReconnecting: $state.reconnectAttempts > 0,
  lastError: $state.lastError,
  offlineMode: !navigator.onLine
}));
```

#### Success Criteria:
- [ ] Real-time connection status display
- [ ] Offline banner shows when disconnected
- [ ] Auto-reconnect with visual feedback
- [ ] Prevent message send when offline
- [ ] Queue messages for later delivery
- [ ] Tests for connection state transitions

---

### **PRIORITY 3: Run & Fix E2E Tests** (2-3 hours)
**Status**: READY to execute
**Impact**: CRITICAL for MVP validation
**Estimated**: 2-3 hours

#### What to Do:
1. **Run app-flows.spec.ts**
   ```bash
   cd frontend
   bun run test:e2e app-flows.spec.ts
   ```

2. **Fix Failing Tests**
   - Document specific failures
   - Create fixes for:
     - Form validation issues
     - Element selector mismatches
     - Navigation/redirect issues
     - Accessibility compliance gaps

3. **Improve Test Data Coverage**
   - Add mock server responses
   - Test error scenarios
   - Test mobile viewports
   - Test keyboard navigation

#### Expected Issues & Fixes:
| Issue | Likely Fix |
|-------|-----------|
| Element not found | Add data-testid to components |
| Navigation timeout | Handle connection errors gracefully |
| Form validation fails | Ensure proper error messages |
| Mobile layout broken | Update CSS for mobile viewport |
| Accessibility fails | Add ARIA labels to interactive elements |

#### Success Criteria:
- [ ] app-flows.spec.ts: 15+/18 tests passing
- [ ] connection.spec.ts: 24/24 passing ✅
- [ ] sdk-integration.spec.ts: 24/24 passing ✅
- [ ] Total: 63+/66 passing (95%+)
- [ ] Zero skipped tests in active suites
- [ ] All failures documented with fixes

---

### **PRIORITY 4: Real OpenCode Server Testing** (1-2 hours)
**Status**: VALIDATION PHASE
**Impact**: CRITICAL for production readiness
**Estimated**: 1-2 hours

#### What to Test:
1. **Manual End-to-End Flow**
   ```bash
   # Start real OpenCode server
   opencode serve --port 4096

   # Run the app
   cargo tauri dev

   # Manual testing:
   # 1. Connect to localhost:4096
   # 2. Create new session
   # 3. Send message: "Hello, OpenCode!"
   # 4. Verify streaming response
   # 5. Send follow-up message
   # 6. Verify session persistence
   ```

2. **Connection Methods Testing**
   - [ ] Localhost connection (localhost:4096)
   - [ ] Network connection (if available)
   - [ ] Error handling (disconnect server mid-session)
   - [ ] Reconnection (restart server)

3. **Message Streaming**
   - [ ] Verify SSE event reception
   - [ ] Check message chunk accumulation
   - [ ] Validate streaming UI updates
   - [ ] Test long messages

4. **Error Scenarios**
   - [ ] Server timeout
   - [ ] Invalid API key
   - [ ] Session not found
   - [ ] Network disconnection

#### Success Criteria:
- [ ] Connection established without errors
- [ ] Chat session created successfully
- [ ] Messages sent and streamed correctly
- [ ] Error handling works as expected
- [ ] Can recover from connection failures
- [ ] Session persists across app restart

---

### **PRIORITY 5: Mobile Testing (Optional, Nice-to-Have)** (1-2 hours)
**Status**: AFTER MVP
**Impact**: MEDIUM for platform launch
**Estimated**: 1-2 hours

#### What to Test:
1. **iOS TestFlight**
   - Install on real device
   - Test connection flow
   - Test chat flow
   - Check touch responsiveness
   - Verify network handling

2. **Android (if available)**
   - Similar testing as iOS
   - Check platform-specific issues

#### Success Criteria:
- [ ] App installs and launches
- [ ] Connection flow works on mobile
- [ ] Chat interface responsive
- [ ] Touch targets 44px minimum
- [ ] No platform-specific errors

---

## 📊 Task Summary & Effort

| Task | Priority | Status | Effort | Blocker |
|------|----------|--------|--------|---------|
| Error Toast Component | 🔴 HIGH | PENDING | 2-3h | None |
| Network Status Indicators | 🔴 HIGH | PENDING | 1-2h | Error Toast |
| E2E Test Fixes | 🔴 HIGH | PENDING | 2-3h | None (parallel) |
| Real Server Testing | 🔴 HIGH | PENDING | 1-2h | None (parallel) |
| Mobile Testing | 🟡 MEDIUM | PENDING | 1-2h | After MVP |
| **TOTAL** | — | — | **6-10h** | — |

---

## 🎯 Success Criteria for MVP

### Code Quality
- [ ] 80%+ E2E test pass rate (66+/82 tests)
- [ ] Zero critical bugs
- [ ] All errors handled gracefully
- [ ] User-friendly error messages shown
- [ ] Mobile responsive (375px viewport works)
- [ ] Accessibility compliant (WCAG 2.2 AA)

### Functionality
- [ ] User can connect to OpenCode server
- [ ] User can create chat sessions
- [ ] User can send messages and receive responses
- [ ] Messages stream in real-time
- [ ] Connection state visible to user
- [ ] Errors show with recovery suggestions
- [ ] Offline mode gracefully degraded

### User Experience
- [ ] No technical error messages visible
- [ ] Friendly UI for common errors
- [ ] Clear connection status
- [ ] Responsive to touch (mobile)
- [ ] Keyboard navigable
- [ ] Fast startup (<2 seconds)

### Testing
- [ ] connection.spec.ts: 24/24 ✅
- [ ] sdk-integration.spec.ts: 24/24 ✅
- [ ] app-flows.spec.ts: 15+/18 ✅
- [ ] Real server testing: Validated ✅
- [ ] No test flakiness

---

## 📋 Detailed Task Breakdown

### Error Toast Component

**Files to Create/Modify:**
- ✨ `frontend/src/components/ErrorToast.svelte` (NEW)
- 📝 `frontend/src/layouts/Layout.astro` (MODIFY - add ErrorToast)
- ✨ `frontend/src/tests/components/ErrorToast.test.ts` (NEW - unit tests)

**Implementation Steps:**
1. Create ErrorToast.svelte with:
   - Error message display
   - Auto-dismiss (5-10 seconds)
   - Retry button (if retryable)
   - Error icon/styling
   - Close button

2. Subscribe to error emitter:
   ```typescript
   import { errorEmitter } from '../lib/error-handler';

   let errors: AppError[] = [];

   onMount(() => {
     const unsubscribe = errorEmitter.subscribe((error) => {
       errors = [...errors, error];
       setTimeout(() => {
         errors = errors.filter(e => e.timestamp !== error.timestamp);
       }, 5000);
     });
   });
   ```

3. Add to main Layout.astro:
   ```astro
   <ErrorToast />
   ```

4. Style with mobile-first approach:
   - Bottom-center positioning
   - 44px+ touch targets
   - Dark background with good contrast
   - Smooth animations

---

### Connection Status Component

**Files to Create/Modify:**
- ✨ `frontend/src/components/ConnectionStatus.svelte` (NEW)
- 📝 `frontend/src/layouts/Layout.astro` (MODIFY - add ConnectionStatus)
- 📝 `frontend/src/lib/stores/connection.ts` (MODIFY - add status tracking)

**Implementation Steps:**
1. Enhance connection store to track:
   - isConnected: boolean
   - isReconnecting: boolean
   - reconnectAttempts: number
   - lastConnectedTime: Date
   - nextRetryTime: Date

2. Create ConnectionStatus component:
   ```svelte
   <script>
     import { connectionStatus } from '../lib/stores/connection';
   </script>

   {#if $connectionStatus.isReconnecting}
     <div class="reconnecting">
       Reconnecting... (Attempt {$connectionStatus.reconnectAttempts})
     </div>
   {:else if $connectionStatus.isConnected}
     <div class="connected">✓ Connected</div>
   {:else}
     <div class="disconnected">✗ Disconnected</div>
   {/if}
   ```

3. Add status indicator styling:
   - Green dot when connected
   - Yellow when reconnecting
   - Red when disconnected
   - Show in header or sidebar

---

### E2E Test Fixes

**Process:**
1. Run tests: `bun run test:e2e app-flows.spec.ts`
2. Document failures
3. Fix each failure:
   - Add missing data-testid attributes
   - Fix element selectors
   - Handle navigation timing
   - Update accessibility
4. Re-run until passing

**Common Fixes:**
- Add `data-testid` attributes to form fields
- Use `page.waitForURL()` instead of timeouts
- Handle graceful redirects on error
- Ensure proper ARIA labels

---

## 🔗 Related Documentation

- [Error Handler Documentation](../frontend/src/lib/error-handler.ts)
- [Retry Handler Documentation](../frontend/src/lib/retry-handler.ts)
- [E2E Testing Guide](../frontend/e2e/README.md)
- [SDK Integration Guide](../docs/SDK_INTEGRATION_MIGRATION.md)
- [Architecture Documentation](../docs/client/ARCHITECTURE.md)

---

## 📝 Notes for PR

When creating the PR for error UI components:

1. **Branch**: Should be based on `claude/sdk-integration-refactor-012oE9a13B92eB5KPN5w2zKz`
2. **Title**: `feat: add error UI components and network status indicators`
3. **Description**: Include:
   - Error Toast component implementation
   - Connection Status component implementation
   - E2E test results (66+/82 passing)
   - Real server testing results
   - Screenshots of error handling in action

4. **Testing**:
   - Run all tests before PR
   - Document any test failures and fixes
   - Include E2E test results
   - Note any known issues

5. **Checklist**:
   - [ ] Error toast displays correctly
   - [ ] Connection status updates in real-time
   - [ ] All tests passing (80%+)
   - [ ] No console errors
   - [ ] Mobile responsive
   - [ ] Accessibility verified
   - [ ] Real server tested

---

## ⏭️ Post-MVP Features

After reaching MVP (80% test pass rate):

1. **Mobile UI Polish**
   - Optimize touch interactions
   - Refine mobile layout
   - Add swipe gestures

2. **Offline Support Enhancement**
   - Robust offline queuing
   - Smart sync strategy
   - Offline indication

3. **Advanced Features**
   - File sharing in chat
   - Model selection
   - Session search
   - Dark mode

4. **Performance Optimization**
   - Bundle size reduction
   - Startup time optimization
   - Memory profiling
   - CPU optimization

---

**Last Updated**: November 27, 2025
**Next Review**: After error UI implementation
**Target Completion**: Early December 2025
