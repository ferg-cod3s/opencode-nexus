# Chat UI Component Testing Implementation Plan

**Status**: 🔄 Not Started  
**Priority**: Medium (Post-MVP Enhancement)  
**Created**: 2025-10-01  
**Context**: Resolves E2E test limitations with Svelte component rendering

---

## Background

### Current Testing Status
- ✅ **2 API Integration Tests Passing** (14% of chat test suite)
  - `send message and receive streaming response (API integration)`
  - `message history persists across sessions (API integration)`
- ⏭️ **12 UI Component Tests Skipped** (86% of chat test suite)
- ✅ **Backend 100% Complete and Functional**

### Root Cause of Skipped Tests
Playwright E2E tests run in a browser context that cannot resolve ES module imports like `'svelte/store'` or dynamic Svelte component imports. The browser in `page.evaluate()` doesn't have access to:
- `node_modules` for module resolution
- Vite/Astro build pipeline for bundling
- TypeScript compilation

**Error encountered:**
```
Failed to resolve module specifier 'svelte/store'
```

### What Works ✅
- Backend Tauri commands (`create_chat_session`, `send_chat_message`, etc.)
- API integration between frontend and Rust backend
- Message persistence and session management
- SSE streaming infrastructure

### What Doesn't Work ❌
- Mounting Svelte components in E2E test browser context
- Testing UI interactions (clicks, keyboard shortcuts, etc.)
- Visual regression testing
- Accessibility testing within components

---

## Solution: Vitest + @testing-library/svelte

### Why Vitest?
1. **Native Bun Support** - Already using Bun as runtime
2. **Svelte Integration** - Built-in Svelte component testing support
3. **Fast** - Leverages Vite's dev server for instant HMR
4. **Test Isolation** - Proper component mounting with full module resolution
5. **Compatible with Testing Library** - Standard React/Vue/Svelte testing patterns

---

## Implementation Plan

### Phase 1: Setup Vitest Infrastructure ⏳

#### 1.1 Install Dependencies
```bash
cd frontend
bun add -d vitest @vitest/ui @testing-library/svelte @testing-library/jest-dom @testing-library/user-event
```

#### 1.2 Create Vitest Configuration
**File: `frontend/vitest.config.ts`**
```typescript
import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte({ hot: !process.env.VITEST })],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/tests/setup.ts'],
    include: ['src/**/*.{test,spec}.{js,ts}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['src/components/**/*.svelte'],
      exclude: [
        'src/components/**/*.test.ts',
        'src/components/**/*.spec.ts'
      ]
    }
  }
});
```

#### 1.3 Create Test Setup File
**File: `frontend/src/tests/setup.ts`**
```typescript
import '@testing-library/jest-dom';
import { vi } from 'vitest';

// Mock Tauri API for component tests
vi.mock('@tauri-apps/api/core', () => ({
  invoke: vi.fn()
}));

// Mock window.__TAURI_INTERNALS__
globalThis.__TAURI_INTERNALS__ = {
  invoke: vi.fn(),
  transformCallback: vi.fn()
};
```

#### 1.4 Update package.json Scripts
```json
{
  "scripts": {
    "test:unit": "vitest",
    "test:unit:ui": "vitest --ui",
    "test:unit:coverage": "vitest --coverage",
    "test:e2e": "playwright test",
    "test:all": "bun run test:unit && bun run test:e2e"
  }
}
```

---

### Phase 2: Migrate UI Tests to Component Tests ⏳

#### 2.1 Create Component Test Structure
```
frontend/src/
├── components/
│   ├── ChatInterface.svelte
│   ├── ChatInterface.test.ts          # ← New component test
│   ├── MessageBubble.svelte
│   ├── MessageBubble.test.ts          # ← New component test
│   ├── MessageInput.svelte
│   ├── MessageInput.test.ts           # ← New component test
│   └── SessionSidebar.svelte
│       └── SessionSidebar.test.ts     # ← New component test
```

#### 2.2 Test Categories to Implement

##### Core Functionality Tests
- [ ] **Message sending** - Form submission, API calls
- [ ] **Message display** - Render user/AI messages correctly
- [ ] **Streaming updates** - Real-time message updates
- [ ] **Session management** - Create, switch, delete sessions

##### Interaction Tests
- [ ] **Keyboard shortcuts** - Enter to send, Escape to clear
- [ ] **Button clicks** - Send button, new session button
- [ ] **Input validation** - Empty message prevention, max length
- [ ] **Scroll behavior** - Auto-scroll to latest message

##### Accessibility Tests (WCAG 2.2 AA)
- [ ] **Keyboard navigation** - Tab order, focus management
- [ ] **Screen reader support** - ARIA labels, live regions
- [ ] **Color contrast** - Verify ratios meet standards
- [ ] **Focus indicators** - Visible focus states

##### Error Handling Tests
- [ ] **Server disconnection** - Graceful degradation
- [ ] **Retry mechanism** - Failed message retries
- [ ] **Long messages** - Truncation or warnings

##### Performance Tests
- [ ] **Response time** - Fast message rendering
- [ ] **Streaming responsiveness** - UI remains interactive
- [ ] **Memory usage** - No leaks with many messages

---

### Phase 3: Example Test Implementation ⏳

#### Example: MessageBubble Component Test
**File: `frontend/src/components/MessageBubble.test.ts`**
```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import MessageBubble from './MessageBubble.svelte';

describe('MessageBubble', () => {
  it('renders user message correctly', () => {
    render(MessageBubble, {
      props: {
        message: {
          id: '1',
          content: 'Hello, AI!',
          role: 'user',
          timestamp: new Date().toISOString()
        }
      }
    });

    expect(screen.getByText('Hello, AI!')).toBeInTheDocument();
    expect(screen.getByTestId('user-message')).toHaveClass('message-user');
  });

  it('renders AI message with markdown', () => {
    render(MessageBubble, {
      props: {
        message: {
          id: '2',
          content: '```python\nprint("Hello")\n```',
          role: 'assistant',
          timestamp: new Date().toISOString()
        }
      }
    });

    expect(screen.getByTestId('ai-message')).toBeInTheDocument();
    expect(screen.getByText(/print/)).toBeInTheDocument();
  });

  it('displays timestamp correctly', () => {
    const timestamp = new Date('2025-01-09T12:00:00Z');
    render(MessageBubble, {
      props: {
        message: {
          id: '3',
          content: 'Test message',
          role: 'user',
          timestamp: timestamp.toISOString()
        }
      }
    });

    expect(screen.getByTestId('message-time')).toBeInTheDocument();
  });

  it('is keyboard accessible', async () => {
    render(MessageBubble, {
      props: {
        message: {
          id: '4',
          content: 'Accessible message',
          role: 'user',
          timestamp: new Date().toISOString()
        }
      }
    });

    const bubble = screen.getByTestId('user-message');
    expect(bubble).toHaveAttribute('role', 'article');
    expect(bubble).toHaveAttribute('aria-label');
  });
});
```

#### Example: ChatInterface Integration Test
**File: `frontend/src/components/ChatInterface.test.ts`**
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import ChatInterface from './ChatInterface.svelte';
import { invoke } from '@tauri-apps/api/core';

vi.mock('@tauri-apps/api/core');

describe('ChatInterface', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(invoke).mockImplementation((cmd: string, args?: any) => {
      if (cmd === 'create_chat_session') {
        return Promise.resolve({ id: 'session-1', title: 'New Chat' });
      }
      if (cmd === 'send_chat_message') {
        return Promise.resolve({ id: 'msg-1', content: 'Mock response' });
      }
      return Promise.resolve(null);
    });
  });

  it('sends message on Enter key', async () => {
    const user = userEvent.setup();
    render(ChatInterface);

    const input = screen.getByTestId('message-input');
    await user.type(input, 'Test message{Enter}');

    await waitFor(() => {
      expect(invoke).toHaveBeenCalledWith('send_chat_message', 
        expect.objectContaining({ content: 'Test message' })
      );
    });
  });

  it('clears input on Escape key', async () => {
    const user = userEvent.setup();
    render(ChatInterface);

    const input = screen.getByTestId('message-input') as HTMLTextAreaElement;
    await user.type(input, 'This should be cleared{Escape}');

    expect(input.value).toBe('');
  });

  it('shows typing indicator when AI is responding', async () => {
    render(ChatInterface);

    const sendButton = screen.getByTestId('send-button');
    await fireEvent.click(sendButton);

    expect(screen.getByTestId('typing-indicator')).toBeInTheDocument();
  });

  it('creates new session on button click', async () => {
    render(ChatInterface);

    const newSessionBtn = screen.getByTestId('new-session-button');
    await fireEvent.click(newSessionBtn);

    await waitFor(() => {
      expect(invoke).toHaveBeenCalledWith('create_chat_session', expect.any(Object));
    });
  });
});
```

---

## Migration Strategy

### For Each Skipped E2E Test:
1. ✅ Identify the UI behavior being tested
2. ✅ Create corresponding component test in `src/components/`
3. ✅ Mock Tauri `invoke` calls with expected responses
4. ✅ Verify test passes in isolation
5. ✅ Update E2E test skip reason to reference component test
6. ✅ Document in test migration tracking doc

### Test Coverage Goals
- **Unit Tests (Components)**: 80%+ coverage of component logic
- **Integration Tests (E2E)**: Focus on API integration, not UI
- **Manual Testing**: Real device testing for Tauri-specific features

---

## Benefits of This Approach

### ✅ Pros
1. **Proper Component Isolation** - Test components without full app context
2. **Faster Feedback Loop** - Vitest runs in milliseconds, not seconds
3. **Better Debugging** - Clear stack traces and component mounting
4. **Coverage Metrics** - Track untested code paths
5. **Standard Testing Patterns** - Familiar to React/Vue developers

### ⚠️ Considerations
1. **Requires Tauri API Mocking** - Need to mock `invoke()` carefully
2. **Not Full Integration Tests** - Can't test Tauri ↔ Frontend IPC
3. **Different Test Mindset** - Component tests vs E2E tests

---

## Success Criteria

- [ ] Vitest configuration complete and running
- [ ] All 12 skipped UI tests migrated to component tests
- [ ] Component test coverage at 80%+
- [ ] CI/CD pipeline runs both unit and E2E tests
- [ ] Documentation updated with component testing guidelines
- [ ] Developer experience improved (faster test cycles)

---

## Timeline Estimate

- **Phase 1 Setup**: 2-3 hours
- **Phase 2 Migration**: 4-6 hours (12 tests × 20-30 min each)
- **Phase 3 Refinement**: 2-3 hours (edge cases, cleanup)

**Total**: ~8-12 hours of focused development work

---

## References

- [Vitest Documentation](https://vitest.dev/)
- [Testing Library Svelte](https://testing-library.com/docs/svelte-testing-library/intro)
- [Svelte Testing Best Practices](https://svelte.dev/docs/introduction#testing)
- [WCAG 2.2 Testing Guidelines](https://www.w3.org/WAI/WCAG22/Understanding/)

---

## Related Files

- `frontend/e2e/chat-interface.spec.ts` - Current E2E tests (2 passing, 12 skipped)
- `frontend/e2e/chat.spec.ts` - Deprecated E2E tests (all skipped)
- `frontend/src/components/ChatInterface.svelte` - Main component to test
- `frontend/src/stores/chat.ts` - Chat state management (needs mocking)
- `docs/TESTING.md` - Overall testing strategy documentation
