# AGENTS.md – Frontend Stores (Svelte Reactive State)

State management for the OpenCode client using Svelte stores.

## Quick Reference

```typescript
// Store pattern (persistent, reactive)
import { writable } from 'svelte/store';
export const chatStore = writable<ChatState>({ messages: [] });

// Using in components
import { chatStore } from '../stores/chat';
$: messages = $chatStore.messages;  // Reactive binding

// Updating
chatStore.update(state => ({
  ...state,
  messages: [...state.messages, newMessage]
}));
```

## Store Modules

| Store | Purpose | Key State |
|-------|---------|-----------|
| `chat.ts` | Chat messages & session | `messages`, `sessionId`, `isLoading` |
| `auth.ts` | User authentication | `isAuthenticated`, `user`, `token` |
| `ui.ts` | UI state | `sidebarOpen`, `darkMode`, `notifications` |

## Best Practices

- **Immutable updates:** Always create new objects (don't mutate state)
- **Subscriptions:** Use `$store` syntax in components for reactivity
- **Persistence:** Save critical state to localStorage
- **Types:** All stores typed with TypeScript interfaces
- **Cleanup:** Unsubscribe manually in JavaScript (not needed in Svelte components)

## Integration

- Stores auto-sync with Tauri backend via IPC commands
- SSE events update stores in real-time
- localStorage persists sessions across browser restarts

---

See [../../AGENTS.md](../../AGENTS.md) for full frontend context.
