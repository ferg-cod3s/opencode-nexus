# AGENTS.md – Frontend (Astro + Svelte 5)

**Quick commands** for frontend development. See [../AGENTS.md](../AGENTS.md) for full project context.

## Build/Test/Lint Commands

```bash
# Development
bun run dev              # Start dev server (http://localhost:1420)
bun run build            # Production build
bun preview              # Preview production build

# Testing
bun test                 # Run unit tests
bun test --watch        # Watch mode
bun run test:e2e         # Playwright E2E tests
bun run test:e2e:ui      # E2E with UI
bun run test:ios         # iOS-specific tests

# Quality
bun run lint             # ESLint + accessibility checks
bun run lint:fix         # Auto-fix lint errors
bun run typecheck        # TypeScript strict checking
bun run format           # Prettier formatting
bun run format:check     # Check formatting
```

## Code Style

### TypeScript/Svelte
- **Variables:** `camelCase` → `const chatMessage = getMessage()`
- **Types:** `PascalCase` → `type ChatSession = { ... }`
- **Imports:** Standard lib → external → local → components
- **Svelte:** Use `<script lang="ts">`, reactive bindings, event dispatchers
- **No `any` types** (strict mode enforced)

### File Organization
```
src/
├── pages/          # File-based routes (.astro)
├── components/     # Reusable .svelte components
├── layouts/        # Layout wrappers
├── stores/         # Svelte stores (state management)
├── lib/            # Business logic (opencode-client.ts, sdk-api.ts)
├── utils/          # Helper functions
├── types/          # TypeScript interfaces
└── tests/          # Unit & E2E tests
```

### Key Modules
- **[lib/opencode-client.ts](src/lib/opencode-client.ts)** – OpenCode SDK wrapper
- **[lib/sdk-api.ts](src/lib/sdk-api.ts)** – Chat API integration
- **[lib/error-handler.ts](src/lib/error-handler.ts)** – Error handling + user feedback
- **[lib/retry-handler.ts](src/lib/retry-handler.ts)** – Retry logic for network failures

## Testing Patterns

**Unit Tests (Bun):**
```typescript
import { describe, test, expect } from 'bun:test';

test('should validate input', () => {
  expect(validateInput('test')).toBe(true);
});
```

**E2E Tests (Playwright):**
```typescript
test('chat flow', async ({ page }) => {
  await page.goto('/chat');
  await page.fill('input', 'Hello');
  await page.click('button');
});
```

## Integration Points

- **Tauri Backend:** Use `invoke()` from `@tauri-apps/api` for IPC commands
- **OpenCode SDK:** Configured in `lib/opencode-client.ts`
- **Svelte Stores:** Global state in `stores/` (chat, auth, UI state)
- **SSE Events:** Listen via `lib/sdk-api.ts` for real-time updates

## Mobile-First Standards

- **Touch targets:** 44px minimum (CSS: `min-height: 2.75rem`)
- **Responsive:** Mobile-first media queries (no desktop-only features)
- **Accessibility:** WCAG 2.2 AA (tested with screen readers)
- **Performance:** Keep bundles < 1MB

## Common Issues

| Issue | Solution |
|-------|----------|
| Type errors in Svelte | Run `bun run typecheck` |
| Imports not resolving | Check `tsconfig.json` path aliases |
| Component not updating | Ensure using Svelte reactive bindings |
| E2E tests timeout | Check dev server is running, increase timeout in playwright.config.ts |

## Useful References

- [Frontend PRD](../docs/client/PRD.md) – Feature requirements
- [Architecture](../docs/client/ARCHITECTURE.md) – System design
- [Testing Guide](../docs/client/TESTING.md) – TDD approach (MANDATORY)
- [User Flows](../docs/client/USER-FLOWS.md) – Mobile interaction patterns

---

**Note:** Changes here affect iOS/Android builds. Always run E2E tests before committing.
