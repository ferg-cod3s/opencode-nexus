# E2E Test Strategy - OpenCode Nexus Client

## Overview

This directory contains end-to-end tests for the OpenCode Nexus client application using Playwright. The tests are organized around the actual client-based architecture after the pivot from server management.

## OpenCode Server Integration

### Running Tests with a Real OpenCode Server

For integration testing with a real OpenCode server (instead of mocks), we use `opencode serve` to start a headless HTTP server.

**Docs:** https://opencode.ai/docs/server/

1. **Install opencode-ai globally:**
   ```bash
   npm i -g opencode-ai
   ```

2. **Run tests with OpenCode server:**
   ```bash
   USE_OPENCODE_SERVER=true npm run test:e2e
   ```

This will:
- Run `opencode serve --port 4096 --hostname 127.0.0.1` to start the server
- Run all E2E tests against the real server at `http://127.0.0.1:4096`
- Automatically shut down the server when tests complete

### Manual Server Start

You can also start the server manually:

```bash
# Start server in one terminal
opencode serve --port 4096 --hostname 127.0.0.1

# Run tests in another terminal
USE_OPENCODE_SERVER=true OPENCODE_SERVER_URL=http://127.0.0.1:4096 npm run test:e2e
```

### Using OpenCode Server in Tests

```typescript
import { isOpencodeServerAvailable, getOpencodeServerUrl } from './helpers/opencode-server';

test('chat with real server', async ({ page }) => {
  // Skip test if no real server is available
  if (!isOpencodeServerAvailable()) {
    test.skip();
    return;
  }
  
  const serverUrl = getOpencodeServerUrl();
  // ... test with real server
});
```

### Available Helper Functions

- `isOpencodeServerAvailable()` - Check if an OpenCode server is running
- `getOpencodeServerUrl()` - Get the server URL
- `waitForOpencodeServer(timeout)` - Wait for server to be ready (checks /app endpoint)
- `getOpencodeClientConfig()` - Get client configuration for SDK
- `getOpencodeDocUrl()` - Get OpenAPI spec URL (http://host:port/doc)

## Test Organization

### ✅ Active Tests (Modern Architecture)

#### 1. `app-flows.spec.ts` - Core User Flows
Tests the actual end-to-end workflows in the current client architecture:
- **Startup routing**: No connection → /connect, has connection → /chat
- **Connection workflow**: Enter URL → test → connect to server
- **Form validation**: Validate empty fields, accept valid config
- **Error handling**: Show friendly errors for unreachable servers
- **Error recovery**: Retry after connection failures
- **Mobile responsiveness**: Touch targets 44px minimum
- **Accessibility**: Proper labels, heading hierarchy
- **Offline behavior**: Connection status indicators
- **Session persistence**: Store connection settings

**Status**: ✅ Ready for implementation
**Expected**: 18+ tests covering core functionality

#### 2. `connection.spec.ts` - Connection Page Tests
Tests the connection form UI and interactions:
- Connection method selection (localhost, Cloudflare tunnel, reverse proxy)
- URL/hostname input validation
- API key handling for different connection types
- Form field visibility and placeholders
- Integration with connection persistence

**Status**: ✅ 24/24 passing (100%)
**Quality**: Comprehensive coverage of connection form

#### 3. `sdk-integration.spec.ts` - SDK Integration Tests
Tests the @opencode-ai/sdk integration:
- Client initialization and connection
- Session management (create, list, delete)
- Message sending and streaming
- Event handling and subscriptions
- Offline mode and reconnection
- Performance metrics

**Status**: ✅ 24/24 tests
**Quality**: Full SDK coverage

### ⏭️ Deprecated/Skipped Tests (Old Architecture)

These tests are marked with `test.describe.skip()` because they test the old server management architecture which is no longer applicable:

#### Skipped Test Files
- `critical-flows.spec.ts` - Server management flows (deprecated)
- `dashboard.spec.ts` - Dashboard (removed in client architecture)
- `server-management.spec.ts` - Server lifecycle management (removed)
- `settings.spec.ts` - Server settings (removed)
- `chat-*.spec.ts` - Various chat test files (incomplete/redundant)
- `performance.spec.ts` - Performance for old architecture
- `model-selector.spec.ts` - Old model selection UI
- `full-flow.spec.ts`, `web-flow-test.spec.ts` - Old architecture flows
- Debug/manual test files (`chat-debug.spec.ts`, `chat-manual-test.spec.ts`, etc.)

**Reason**: These test features that no longer exist in the client-only architecture
**Action**: Properly skipped to avoid test count confusion

## Running Tests

### Run All Tests
```bash
cd frontend
bun run test:e2e
```

### Run Specific Test File
```bash
bun run test:e2e app-flows.spec.ts
```

### Run with UI
```bash
bun run test:e2e:ui
```

### Run in Debug Mode
```bash
bun run test:e2e -- --debug
```

## Test Results Summary

### Current Status (November 27, 2025)

| Test Suite | Tests | Status | Notes |
|-----------|-------|--------|-------|
| connection.spec.ts | 24 | ✅ Passing 100% | Connection form tests |
| sdk-integration.spec.ts | 24 | ✅ Passing 100% | SDK integration tests |
| app-flows.spec.ts | 18+ | ⏳ Pending | Modern architecture flows |
| Deprecated (skip) | ~50 | ⏭️ Skipped | Old server management |
| **Total** | **116+** | **38%** | **Including skipped** |

### Passing Test Categories
- ✅ Connection management (24/24)
- ✅ SDK integration (24/24)
- ✅ Startup routing (covered by app-flows)

### Tests to Implement
- ⏳ Complete app-flows.spec.ts
- ⏳ Create error handling E2E tests
- ⏳ Create offline behavior tests
- ⏳ Create mobile responsiveness tests

## Architecture Alignment

### Current Client Architecture
```
User Opens App
  ↓
[Startup Router]
  ├→ No saved connection → /connect
  └→ Has saved connection → /chat (auto-reconnect)
  ↓
[Connection Page]
  ├→ Select connection method (localhost, tunnel, proxy)
  ├→ Enter server URL
  ├→ Test connection
  └→ Save connection
  ↓
[Chat Page]
  ├→ Load sessions (SDK)
  ├→ Create session (SDK)
  ├→ Send message (SDK with retry)
  └→ Receive streaming response (SDK SSE)
```

### Test Coverage Map
```
app-flows.spec.ts
├── Startup routing
├── Connection form
├── Connection validation
├── Error handling
├── Error recovery
├── Mobile responsiveness
├── Accessibility
├── Offline indicators
└── Session persistence

connection.spec.ts
├── Form fields visibility
├── Method selection
├── Input validation
└── Placeholder updates

sdk-integration.spec.ts
├── Client initialization
├── Session management
├── Message streaming
├── Event handling
├── Offline behavior
└── Performance
```

## Test Patterns

### Page Interactions
Tests use Playwright's recommended patterns:
- `page.goto(url)` - Navigate to page
- `page.locator()` - Find elements by selector or testid
- `getByTestId()` - Recommended pattern for testable code
- `getByRole()` - Accessible element finding
- `getByPlaceholder()` - Form field finding

### Error Scenarios
Tests expect friendly error messages (not technical errors):
- ❌ Don't show: `ECONNREFUSED`, `ETIMEDOUT`, `ERR_`
- ✅ Do show: "Connection failed", "Server unreachable", etc.

### Mobile Testing
- Viewport: 375x667 (iPhone SE)
- Touch target minimum: 44px
- Responsive layout validation

## Best Practices

### Test Naming
✅ Good
```typescript
test('Startup - should redirect to connect page when no saved connection', async ({ page }) => {
```

❌ Bad
```typescript
test('startup test', async ({ page }) => {
```

### Assertions
✅ Good
```typescript
await expect(page.locator('h1')).toContainText('Connect to OpenCode Server');
```

❌ Bad
```typescript
const text = await page.locator('h1').textContent();
if (text === 'Connect to OpenCode Server') { /* ... */ }
```

### Waiting for Elements
✅ Good
```typescript
await expect(page.locator('[data-testid="button"]')).toBeVisible();
await page.waitForURL(/\/chat/);
```

❌ Bad
```typescript
await page.waitForTimeout(5000); // Fixed waits
```

## Common Issues & Solutions

### Issue: "Cannot find test ID"
**Solution**: Ensure the component has `data-testid` attribute set correctly

### Issue: "Element not clickable"
**Solution**: Wait for visibility first with `await expect(...).toBeVisible()`

### Issue: "Navigation timeout"
**Solution**: Server may not be running; tests should handle this gracefully

### Issue: "Flaky test timing"
**Solution**: Use event-based waits (`waitForURL`, `waitForSelector`) instead of timeouts

## Future Improvements

1. **Visual Testing**: Add Playwright Visual Comparisons
2. **API Mocking**: Mock OpenCode server for faster tests
3. **Performance Metrics**: Track page load times and resource usage
4. **Accessibility Audit**: Automated a11y testing with Axe
5. **Mobile Testing**: Test on actual mobile devices/emulators
6. **Load Testing**: Simulate multiple concurrent users
7. **Test Data Management**: Create reusable test fixtures
8. **CI Integration**: GitHub Actions for automated testing

## Related Documentation

- [Playwright Documentation](https://playwright.dev/)
- [Testing Documentation](../docs/client/TESTING.md)
- [App Architecture](../docs/client/ARCHITECTURE.md)
- [Connection Setup](../docs/client/CONNECTION-SETUP.md)

## Questions?

- Check test files for examples
- Review Playwright best practices
- See connection.spec.ts for working examples
