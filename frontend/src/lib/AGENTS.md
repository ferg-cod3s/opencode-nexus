# AGENTS.md – Frontend Business Logic (TypeScript)

Core libraries and utilities for OpenCode client functionality.

## Modules Overview

### `opencode-client.ts`
- **Purpose:** OpenCode SDK wrapper and initialization
- **Exports:** `openCodeClient`, `initializeClient()`
- **Usage:** Provides unified interface to OpenCode API
- **Dependencies:** `@opencode-ai/sdk`, `lib/error-handler.ts`

### `sdk-api.ts`
- **Purpose:** Chat API operations and session management
- **Key Functions:** `sendMessage()`, `fetchChatHistory()`, `subscribeToEvents()`
- **Integration:** Uses `opencode-client.ts` for API calls
- **Async:** All functions return Promises

### `error-handler.ts`
- **Purpose:** Centralized error handling and user feedback
- **Handles:** Network errors, API errors, validation errors
- **Output:** User-friendly error messages
- **Pattern:** Error boundaries in components

### `retry-handler.ts`
- **Purpose:** Automatic retry logic for failed requests
- **Strategies:** Exponential backoff, jitter, max retries
- **Config:** Configurable per request type
- **Usage:** Automatically wrapped around API calls

## Code Patterns

### API Call Pattern
```typescript
import { openCodeClient } from './opencode-client';
import { handleError } from './error-handler';
import { withRetry } from './retry-handler';

export async function sendMessage(text: string) {
  try {
    return await withRetry(async () => {
      return await openCodeClient.sendMessage(text);
    });
  } catch (error) {
    handleError(error, 'Failed to send message');
    throw error;
  }
}
```

### SSE Streaming
```typescript
export function subscribeToMessages(callback: (msg: Message) => void) {
  const unsubscribe = openCodeClient.on('message', callback);
  return unsubscribe;
}
```

## Type System

All functions strongly typed:
- **Input parameters:** Validate at function entry
- **Return types:** Explicit Promise<T> or Result<T>
- **Error types:** Custom AppError interface
- **Strict mode:** `noImplicitAny: true` in tsconfig

## Testing

```typescript
// Mock pattern for tests
import { vi } from 'vitest';
const mockClient = vi.mock('./opencode-client');

test('sends message', async () => {
  mockClient.sendMessage.mockResolvedValue({ id: '1' });
  const result = await sendMessage('hello');
  expect(result.id).toBe('1');
});
```

## Performance Considerations

- Lazy load SDK modules (import only when needed)
- Cache API responses in Svelte stores
- Stream large responses (chat history pagination)
- Debounce rapid API calls (typing indicators)

## Security

- ✅ Input validation (sanitize text, validate URLs)
- ✅ Token management (secure storage, refresh logic)
- ✅ Error messages (don't leak sensitive info)
- ✅ Rate limiting (respect server limits)

---

See [../../AGENTS.md](../../AGENTS.md) for full frontend context and [../../docs/client/ARCHITECTURE.md](../../docs/client/ARCHITECTURE.md) for system design.
