# Phase 2: E2E Test Completion Plan

**Date:** 2025-12-05  
**Status:** Ready for Implementation  
**Priority:** P1 - Improves Test Coverage  
**Target:** 80%+ pass rate (96+ tests from 121 total)

---

## Executive Summary

The E2E test suite needs cleanup and updates after the client-only architecture pivot. Many tests reference deprecated server management features, authentication flows, and UI elements that no longer exist. This plan organizes tests into actionable categories and provides implementation guidance.

---

## Current State Analysis

### Test File Inventory (21 files)

| File | Lines | Status | Action |
|------|-------|--------|--------|
| `server-management.spec.ts` | 450 | ⛔ Already skipped | **DELETE** |
| `critical-flows.spec.ts` | 588 | ⛔ Already skipped | **DELETE** |
| `chat.spec.ts` | 355 | ⛔ Already skipped | **DELETE** |
| `connection.spec.ts` | 427 | ✅ Mostly passing | **KEEP & FIX** |
| `chat-interface.spec.ts` | 464 | 🟡 Partial (2/14) | **UPDATE** |
| `chat-functionality.spec.ts` | ~300 | 🟡 Needs review | **UPDATE** |
| `chat-full-flow.spec.ts` | ~200 | 🟡 Needs review | **UPDATE** |
| `chat-connection-test.spec.ts` | ~150 | 🟡 Needs review | **UPDATE** |
| `chat-debug.spec.ts` | ~100 | 🟡 Debug utilities | **REVIEW** |
| `chat-manual-test.spec.ts` | ~100 | 🟡 Manual tests | **REVIEW** |
| `sdk-integration.spec.ts` | ~200 | ✅ SDK tests | **KEEP** |
| `model-selector.spec.ts` | ~150 | 🟡 Needs review | **UPDATE** |
| `settings.spec.ts` | ~200 | 🟡 Needs review | **UPDATE** |
| `dashboard.spec.ts` | ~200 | ⛔ Server-related | **DELETE OR REFACTOR** |
| `app-flows.spec.ts` | ~150 | 🟡 Needs review | **UPDATE** |
| `full-flow.spec.ts` | ~150 | ⛔ Server flows | **DELETE OR REFACTOR** |
| `web-flow-test.spec.ts` | ~100 | 🟡 Needs review | **REVIEW** |
| `performance.spec.ts` | 640 | ⛔ Server metrics | **REFACTOR** |
| `mobile/chat-mobile.spec.ts` | ~200 | 🟡 Mobile tests | **UPDATE** |
| `debug-initialization.spec.ts` | ~50 | ✅ Debug utilities | **KEEP** |
| `environment-debug.spec.ts` | ~50 | ✅ Debug utilities | **KEEP** |

### Test Categories

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           E2E TEST CATEGORIES                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  🗑️ DELETE (3 files, ~1,400 lines)                                         │
│  └─ Already skipped, test deprecated server management                     │
│     • server-management.spec.ts                                            │
│     • critical-flows.spec.ts                                               │
│     • chat.spec.ts                                                         │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ✅ KEEP AS-IS (4 files, ~700 lines)                                        │
│  └─ Working tests for current architecture                                 │
│     • connection.spec.ts (27 tests for connection flow)                    │
│     • sdk-integration.spec.ts                                              │
│     • debug-initialization.spec.ts                                         │
│     • environment-debug.spec.ts                                            │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  🔧 UPDATE (8 files, ~1,800 lines)                                          │
│  └─ Update for client-only architecture                                    │
│     • chat-interface.spec.ts (remove server deps, update selectors)        │
│     • chat-functionality.spec.ts                                           │
│     • chat-full-flow.spec.ts                                               │
│     • chat-connection-test.spec.ts                                         │
│     • model-selector.spec.ts                                               │
│     • settings.spec.ts                                                     │
│     • app-flows.spec.ts                                                    │
│     • mobile/chat-mobile.spec.ts                                           │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  🔄 REFACTOR (3 files, ~1,000 lines)                                        │
│  └─ Significant changes needed                                             │
│     • dashboard.spec.ts → connection-dashboard.spec.ts                     │
│     • full-flow.spec.ts → connection-flow.spec.ts                          │
│     • performance.spec.ts (remove server metrics, keep client perf)        │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  🔍 REVIEW (3 files, ~300 lines)                                            │
│  └─ Evaluate if still needed                                               │
│     • chat-debug.spec.ts                                                   │
│     • chat-manual-test.spec.ts                                             │
│     • web-flow-test.spec.ts                                                │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Cleanup (15 min)
**Delete deprecated test files**

```bash
# Files to delete (already skipped, no value)
rm frontend/e2e/server-management.spec.ts
rm frontend/e2e/critical-flows.spec.ts
rm frontend/e2e/chat.spec.ts

# Expected reduction: ~1,400 lines of dead code
```

**Justification:**
- `server-management.spec.ts`: Tests `ServerHelper` which manages local OpenCode server - deprecated
- `critical-flows.spec.ts`: Tests onboarding → server start → chat flow - deprecated
- `chat.spec.ts`: Duplicate of chat-interface.spec.ts, already marked deprecated

---

### Phase 2: Fix Connection Tests (30 min)
**File:** `connection.spec.ts` (27 tests)

**Current Issues:**
1. Some tests rely on mock localStorage that doesn't persist
2. Connection status indicator selectors may not match actual components
3. Some tests check for `.icon` and `.label` classes that might not exist

**Fixes Needed:**

```typescript
// Issue 1: Connection status indicator selectors
// BEFORE (lines 269-292):
const statusIcon = page.locator('[class*="connection-status"] .icon');
const statusLabel = page.locator('[class*="connection-status"] .label');

// AFTER: Use data-testid selectors
const statusIcon = page.getByTestId('connection-status-icon');
const statusLabel = page.getByTestId('connection-status-label');
```

```typescript
// Issue 2: Mock status via localStorage doesn't affect component
// BEFORE (lines 277-280):
await page.evaluateHandle(() => {
  localStorage.setItem('mockConnectionStatus', 'Connected');
});

// AFTER: Mock via Tauri command interception or component props
// Option A: Skip these tests until proper mock infrastructure
// Option B: Test actual connection flow instead of mocking
```

**Action Items:**
- [ ] Update selectors to use `data-testid` attributes
- [ ] Add missing `data-testid` attributes to ConnectionStatus component
- [ ] Skip tests that require Tauri command mocking until infrastructure ready
- [ ] Verify working tests still pass

---

### Phase 3: Update Chat Interface Tests (45 min)
**File:** `chat-interface.spec.ts` (14 tests, 2 passing)

**Current Issues:**
1. Tests call `loginAndStartServer()` which is deprecated
2. UI tests are skipped because Playwright can't mount Svelte components
3. Tests expect `data-testid` selectors that may not exist

**Strategy: Keep API tests, skip UI tests**

The file already has a good strategy documented:
- ✅ API Integration Tests (2 passing)
- ⏭️ UI Component Tests (12 skipped)

**Fixes Needed:**

```typescript
// Issue 1: Replace deprecated loginAndStartServer
// BEFORE:
await chat.loginAndStartServer();

// AFTER: Use connection-based approach
async setupTestConnection() {
  await this.page.goto('/connect');
  await this.page.getByTestId('server-url-input').fill('http://localhost:4096');
  await this.page.getByTestId('connection-name-input').fill('Test Server');
  await this.page.getByTestId('connect-button').click();
  // Wait for connection or mock it
}
```

```typescript
// Issue 2: Update ChatHelper for client-only architecture
// File: helpers/chat.ts

// REMOVE loginAndStartServer method entirely
// ADD setupMockConnection method

async setupMockConnection() {
  await this.page.goto('/');
  await this.page.evaluate(() => {
    localStorage.setItem('active_connection', JSON.stringify({
      id: 'test-connection',
      name: 'Mock Server',
      url: 'http://localhost:4096',
      status: 'connected'
    }));
  });
  await this.page.goto('/chat');
  await this.page.waitForLoadState('networkidle');
}
```

**Action Items:**
- [ ] Update `ChatHelper` class to remove server management
- [ ] Update API integration tests to use mock connection
- [ ] Keep UI tests skipped with clear documentation
- [ ] Add TODO for Vitest component tests

---

### Phase 4: Refactor Dashboard Tests (30 min)
**File:** `dashboard.spec.ts`

**Current State:** Tests server status, controls, and metrics - all deprecated

**New Purpose:** Test saved connections, connection switching, settings

**New Tests:**

```typescript
test.describe('Connection Dashboard', () => {
  test('should display saved connections', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.getByTestId('saved-connections-list')).toBeVisible();
  });

  test('should allow adding new connection', async ({ page }) => {
    await page.goto('/dashboard');
    await page.getByTestId('add-connection-button').click();
    await expect(page).toHaveURL(/\/connect/);
  });

  test('should allow editing connection', async ({ page }) => {
    await page.goto('/dashboard');
    await page.getByTestId('edit-connection-button').first().click();
    await expect(page.getByTestId('connection-edit-modal')).toBeVisible();
  });

  test('should allow deleting connection', async ({ page }) => {
    await page.goto('/dashboard');
    const initialCount = await page.getByTestId('connection-card').count();
    await page.getByTestId('delete-connection-button').first().click();
    await page.getByTestId('confirm-delete-button').click();
    await expect(page.getByTestId('connection-card')).toHaveCount(initialCount - 1);
  });
});
```

---

### Phase 5: Update Performance Tests (45 min)
**File:** `performance.spec.ts`

**Current State:** Tests server metrics, memory usage, startup time - deprecated

**New Purpose:** Test client-side performance metrics

**Metrics to Test:**
- Page load time (< 2s)
- Chat message send time (< 200ms)
- Navigation between pages (< 500ms)
- Connection establishment (< 3s)
- Message rendering (< 100ms for 100 messages)

**New Tests:**

```typescript
test.describe('Client Performance', () => {
  test('page load time is under 2 seconds', async ({ page }) => {
    const startTime = Date.now();
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - startTime;
    expect(loadTime).toBeLessThan(2000);
  });

  test('navigation is responsive', async ({ page }) => {
    await page.goto('/chat');
    const startTime = Date.now();
    await page.goto('/settings');
    await page.waitForLoadState('networkidle');
    const navTime = Date.now() - startTime;
    expect(navTime).toBeLessThan(500);
  });

  test('large message list renders efficiently', async ({ page }) => {
    await page.goto('/chat');
    // Inject 100 mock messages
    await page.evaluate(() => {
      const messages = Array.from({ length: 100 }, (_, i) => ({
        id: `msg-${i}`,
        content: `Test message ${i}`,
        role: i % 2 === 0 ? 'user' : 'assistant',
        timestamp: new Date().toISOString()
      }));
      localStorage.setItem('mock_messages', JSON.stringify(messages));
    });
    await page.reload();
    
    // Verify messages render
    const messageCount = await page.getByTestId('chat-message').count();
    expect(messageCount).toBe(100);
  });
});
```

---

### Phase 6: Mobile Tests Update (30 min)
**File:** `mobile/chat-mobile.spec.ts`

**Focus Areas:**
- Touch targets (44px minimum)
- Responsive layout
- Viewport adaptations
- Gesture support (if any)

**Keep mobile-specific tests, remove server management**

---

## Helper File Updates

### Update `helpers/chat.ts`

```typescript
// Remove deprecated methods
- loginAndStartServer()
- waitForServerRunning()

// Update methods for client-only architecture
+ setupMockConnection()
+ setupRealConnection(url: string, apiKey?: string)
+ verifyConnectionStatus()

// Keep working methods
+ sendMessage(message: string)
+ waitForResponse()
+ getMessageCount()
+ navigateToChat()
```

### Remove `helpers/server-management.ts`

This helper is entirely deprecated and should be deleted.

---

## Validation Strategy

### Pre-Implementation Check
```bash
# Count current test state
cd frontend
bun run test:e2e --reporter=list 2>&1 | grep -E "(passed|failed|skipped)" | tail -5
```

### Post-Implementation Check
```bash
# Verify improvements
cd frontend
bun run test:e2e --reporter=list 2>&1 | tee test-results.txt
grep -E "(\d+) passed" test-results.txt
```

### Success Criteria
- [ ] 80%+ test pass rate (96+ of 121 tests)
- [ ] No deprecated server management references
- [ ] All connection flow tests passing
- [ ] Chat API integration tests passing
- [ ] Clear documentation for skipped UI tests

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking working tests | Run tests before and after each change |
| Missing test coverage | Track removed vs added tests |
| Selector mismatches | Add `data-testid` attributes to components |
| Mock infrastructure gaps | Skip tests that need complex mocking |

---

## Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Cleanup | 15 min | None |
| Phase 2: Connection Tests | 30 min | None |
| Phase 3: Chat Interface | 45 min | Phase 2 |
| Phase 4: Dashboard | 30 min | None |
| Phase 5: Performance | 45 min | None |
| Phase 6: Mobile | 30 min | Phase 3 |
| **Total** | **~3.5 hours** | |

---

## Checklist

### Phase 1: Cleanup
- [ ] Delete `server-management.spec.ts`
- [ ] Delete `critical-flows.spec.ts`
- [ ] Delete `chat.spec.ts`
- [ ] Delete `helpers/server-management.ts`
- [ ] Run tests to verify no regressions

### Phase 2: Connection Tests
- [ ] Update selectors to use `data-testid`
- [ ] Add missing `data-testid` to components
- [ ] Skip mock-dependent tests
- [ ] Verify 27 connection tests pass

### Phase 3: Chat Interface
- [ ] Update `ChatHelper` class
- [ ] Fix API integration tests
- [ ] Document skipped UI tests
- [ ] Verify 2+ chat tests pass

### Phase 4: Dashboard
- [ ] Rename to `connection-dashboard.spec.ts`
- [ ] Rewrite for connection management
- [ ] Add 4-5 new tests

### Phase 5: Performance
- [ ] Remove server metric tests
- [ ] Add client performance tests
- [ ] Verify 5+ performance tests pass

### Phase 6: Mobile
- [ ] Update for client-only architecture
- [ ] Verify mobile-specific tests pass

---

## Files Modified Summary

| Action | Files | Lines Changed |
|--------|-------|---------------|
| DELETE | 4 | -1,800 |
| UPDATE | 8 | ~500 |
| REFACTOR | 3 | ~400 |
| KEEP | 6 | 0 |

**Net Result:** Cleaner, focused test suite aligned with client-only architecture

---

## Next Steps After Completion

1. **Create GitHub Issue** for remaining UI component tests (Vitest setup)
2. **Update CI/CD** to run E2E tests on PR
3. **Add test coverage reporting** to track improvements
4. **Document testing strategy** in `docs/testing/E2E_STRATEGY.md`
