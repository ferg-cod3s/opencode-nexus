# AGENTS.md – Frontend Components (Svelte 5)

Reusable UI components for the OpenCode client.

## Quick Pattern

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { ChatMessage } from '../types/chat';

  export let messages: ChatMessage[] = [];
  export let isLoading = false;

  const dispatch = createEventDispatcher<{ sendMessage: string }>();

  function handleSend(text: string) {
    dispatch('sendMessage', text);
  }
</script>

<div class="container">
  {#each messages as msg (msg.id)}
    <div class="message">{msg.text}</div>
  {/each}
</div>

<style>
  .container {
    /* Scoped styles */
  }
</style>
```

## Component Standards

### File Naming
- **Components:** `PascalCase.svelte` → `ChatBubble.svelte`
- **Exported:** `export let prop: Type = defaultValue`

### Accessibility
- Semantic HTML (`<button>`, `<label>`, `<article>`)
- ARIA attributes for complex widgets
- 44px minimum touch targets
- Keyboard navigation (Tab, Enter, Escape)
- Screen reader text for icons

### Styling
- Scoped styles only (no global CSS in components)
- CSS variables for theming
- REM units for responsive sizing
- Mobile-first media queries

### Events
- Use `createEventDispatcher` for custom events
- Type event payloads: `<{ eventName: Type }>`
- Document exported events in JSDoc

## Component Categories

| Type | Examples | Notes |
|------|----------|-------|
| **Layout** | `Layout.astro`, `ChatLayout.svelte` | Structure, not state |
| **Feature** | `ChatInterface.svelte`, `LoginForm.svelte` | Stateful, business logic |
| **UI** | `Button.svelte`, `Input.svelte`, `Card.svelte` | Reusable, no logic |
| **Page** | `pages/chat.astro`, `pages/login.astro` | File-based routes |

## Testing Components

```typescript
// Unit test pattern
import { render, screen } from '@testing-library/dom';
import ChatBubble from './ChatBubble.svelte';

test('renders message', () => {
  render(ChatBubble, { props: { message: 'Hello' } });
  expect(screen.getByText('Hello')).toBeInTheDocument();
});
```

## Reactive State in Components

```svelte
<!-- Reactive variables -->
<script lang="ts">
  let count = 0;
  $: doubled = count * 2;  // Auto-recomputes
</script>

<!-- Reactive component props -->
<script lang="ts">
  export let items: Item[] = [];
  $: hasItems = items.length > 0;
</script>
```

---

See [../../AGENTS.md](../../AGENTS.md) for full frontend context and [../types](../types) for type definitions.
