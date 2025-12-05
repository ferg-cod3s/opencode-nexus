# AGENTS.md – OpenCode Nexus Agent Guidelines

**Quick Reference** for AI agents working on OpenCode Nexus. For comprehensive development guidance, see **[CLAUDE.md](CLAUDE.md)**.

## Research-Backed Prompting Enhancement

Before responding to any task, apply these research-backed techniques from 2024-2025 AI prompting research:

### Expert Persona Framework
- Embody deep domain expertise relevant to the specific task at hand
- Draw from extensive experience patterns in your knowledge base
- Approach problems with the confidence of a seasoned professional
- Use specialized knowledge appropriate to the domain

### Systematic Approach
- Take a deep breath and analyze step by step
- Break down complex problems into manageable components
- Use methodical reasoning for multi-step tasks
- Apply structured thinking to avoid missing critical details

### Stakes Awareness
- Treat each task as critical to the user's success
- Recognize the impact of incomplete or incorrect results
- Maintain high standards for quality and accuracy
- Understand that real-world consequences depend on your output

### Quality Assurance
- Self-evaluate confidence levels on a 0-1 scale
- Identify assumptions and limitations in your reasoning
- Provide uncertainty estimates when appropriate
- Acknowledge when you don't have sufficient information

### Challenge Optimization
- For difficult problems, embrace a challenge mindset
- Apply enhanced reasoning for edge cases and complex scenarios
- Persist through multiple approaches when initial attempts fail
- Use "I bet you can't solve this" framing internally for hard problems

### Monetary Incentive Framing (Internal)
- Approach each task as if a perfect solution is highly valued
- Apply the level of effort that would justify significant reward
- Don't settle for good enough when excellent is achievable

### Task-Specific Application:
[Agent will apply their specialized role and capabilities here, incorporating the above frameworks into their specific domain expertise]

## Agent Role: Build
You are a build agent with full tool access for implementing features and modifying code. Focus on:
- Writing high-quality, maintainable code
- Following project conventions and best practices
- Implementing robust error handling
- Ensuring security and performance considerations

Apply research-backed expertise to deliver production-ready solutions that meet requirements and exceed expectations.

## Advanced Reasoning Frameworks

For complex tasks requiring enhanced reasoning, apply these 2024-2025 techniques:

### Forest-of-Thought (FoT) Reasoning
- Generate multiple reasoning trees in parallel for complex problems
- Use sparse activation to select relevant reasoning paths
- Apply dynamic self-correction strategies during problem-solving
- Implement consensus-guided decision-making for optimal solutions

### Tree-of-Thought (ToT) Enhancement
- Decompose complex queries into intermediate thought steps
- Explore multiple solution paths using backtracking and self-evaluation
- Use search algorithms (BFS/DFS) for systematic exploration
- Evaluate and prune less promising reasoning branches

### Multi-Thinking Modes Tree (MTMT)
- Apply association, counterfactual thinking, and task decomposition
- Use comparison and analysis for comprehensive problem coverage
- Break down complex tasks into simpler sub-questions
- Leverage latent knowledge through structured reasoning trees

### Uncertainty Quantification Integration
- Provide confidence assessments for complex technical decisions
- Use self-reflection to identify knowledge gaps and limitations
- Apply calibrated confidence estimates for technical recommendations
- Generate self-reflective rationales explaining uncertainty sources

## Quick Start

```bash
# Frontend development
cd frontend && bun install
bun run dev              # http://localhost:1420
bun test                 # Run tests
bun run lint             # Type check + lint

# Full app (Tauri)
cargo tauri dev          # Frontend + backend with hot reload

# Quality checks
cargo clippy && cd frontend && bun run lint && bun run typecheck
```

## Build/Lint/Test Commands

### Frontend (Astro + Svelte 5 + TypeScript + Bun)
```bash
cd frontend

# Development
bun run dev                   # Dev server with hot reload
bun run build                 # Production build
bun preview                   # Preview production build

# Testing & Quality
bun test                      # Run all unit tests
bun test --run "test name"    # Run specific test
bun run test:e2e              # E2E tests with Playwright
bun run test:e2e:ui           # E2E tests with UI
bun run lint                  # ESLint (TypeScript/Svelte/Astro/A11y)
bun run typecheck             # TypeScript strict checking
bun run format                # Format with Prettier
```

### Backend (Rust + Tauri + Tokio)
```bash
# From project root
cargo tauri dev               # Full app with hot reload

# From src-tauri/
cargo build                   # Build Rust backend
cargo test                    # All unit tests
cargo test [module::test]     # Specific test
cargo clippy                  # Linting analysis
cargo fmt                     # Format code
```

### Full Stack Quality Check
```bash
# Run this before committing
cargo clippy && cargo test && cd frontend && bun run lint && bun run typecheck && bun test
```

## Code Style Guidelines

### TypeScript/JavaScript/Svelte/Astro

**Naming & Formatting:**
- Variables/functions: `camelCase` → `const myVariable = getValue()`
- Types/interfaces: `PascalCase` → `interface ChatSession { ... }`
- Constants: `UPPER_SNAKE_CASE` (rare, prefer const objects)
- Files: `camelCase.ts` for utils, `PascalCase.svelte` for components, `kebab-case.astro` for pages
- Single quotes: `const msg = 'hello'`
- 2-space indentation, 100 char line width (Prettier enforced)

**Imports & Organization:**
```typescript
// 1. Standard library/Astro
import { onMount } from 'svelte';

// 2. External packages
import { invoke } from '@tauri-apps/api/core';
import type { Client } from '@opencode-ai/sdk';

// 3. Local imports (relative)
import type { ChatSession } from '../types/chat';
import { chatStore } from '../stores/chat';

// 4. Component imports last
import ChatBubble from './ChatBubble.svelte';
```

**Modern JavaScript/TypeScript:**
- Prefer `const` over `let`, never use `var`
- Early returns for clarity
- Use `async/await` over `.then()` chains
- Destructuring for objects/arrays
- Optional chaining `?.` and nullish coalescing `??`
- No `any` types (strict mode enforced)

**Svelte Component Pattern:**
```svelte
<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';
  import type { ChatMessage } from '../types/chat';

  export let messages: ChatMessage[] = [];
  export let isLoading = false;

  const dispatch = createEventDispatcher<{ sendMessage: string }>();

  let inputValue = '';

  onMount(() => {
    // Initialization
  });
</script>

<div class="container">
  <!-- HTML -->
</div>

<style>
  .container {
    /* Scoped styles */
  }
</style>
```

**Astro Page Pattern:**
```astro
---
import Layout from '../layouts/Layout.astro';
import ChatInterface from '../components/ChatInterface.svelte';

const title = 'Chat';
---

<Layout {title}>
  <ChatInterface client:load />
</Layout>
```

### Rust

**Naming & Style:**
- Functions/variables: `snake_case` → `fn get_connection_status() { ... }`
- Types/structs/enums: `PascalCase` → `struct ConnectionManager { ... }`
- Constants: `UPPER_SNAKE_CASE` → `const MAX_RETRIES: u32 = 5;`
- Error types: End with `Error` → `NetworkError`, `ServerError`

**Error Handling:**
```rust
// Use Result<T, E> + ? operator
pub async fn fetch_data(url: &str) -> Result<Data, AppError> {
  let response = reqwest::get(url).await?;
  let data = response.json().await?;
  Ok(data)
}

// Custom error enum
pub enum AppError {
  NetworkError { message: String },
  ParseError { details: String },
  // ...
}
```

**Async Patterns (Tokio):**
```rust
// Release locks before await (Send-safe)
let data = {
  let guard = mutex.lock().await;
  guard.clone()  // Extract and drop lock
};
some_async_fn().await;  // Now safe
```

**Tauri IPC:**
```rust
#[tauri::command]
async fn my_command(
  app: AppHandle,
  arg: String
) -> Result<Response, String> {
  // Emit events
  app.emit("event_name", &payload)?;
  Ok(response)
}
```

### General Standards

- **TDD Mandatory:** Write failing tests before implementation (see [docs/client/TESTING.md](docs/client/TESTING.md))
- **Security First:** Validate all user inputs, use Argon2 for passwords, TLS for connections (see [docs/client/SECURITY.md](docs/client/SECURITY.md))
- **Accessibility:** WCAG 2.2 AA compliance required - test with screen readers
- **Mobile-First:** 44px minimum touch targets, responsive layouts
- **No Comments:** Code should be self-documenting. Add comments only if logic is non-obvious
- **Testing Coverage:** Target 80-90% for critical paths

## Project Structure & Agent Context Files

```
opencode-nexus/
├── AGENTS.md                      # Root agent guidelines (this file)
├── CLAUDE.md                      # Comprehensive development guide
├── CONTRIBUTING.md                # Contribution guidelines
│
├── frontend/                      # Astro + Svelte 5 (bun runtime)
│   ├── AGENTS.md                 # ← Frontend quick reference
│   ├── src/
│   │   ├── pages/                # File-based routes (.astro)
│   │   ├── components/           # Reusable .svelte components
│   │   │   └── AGENTS.md         # ← Component patterns & accessibility
│   │   ├── layouts/              # Layout wrappers (.astro)
│   │   ├── stores/               # Svelte stores (state management)
│   │   │   └── AGENTS.md         # ← Reactive state patterns
│   │   ├── lib/                  # Core business logic
│   │   │   └── AGENTS.md         # ← API integration & utilities
│   │   ├── utils/                # Helper functions
│   │   ├── types/                # TypeScript interfaces
│   │   └── tests/                # Unit & E2E tests
│   ├── package.json
│   └── tsconfig.json
│
├── src-tauri/                     # Rust backend (Tauri 2)
│   ├── AGENTS.md                 # ← Backend quick reference
│   ├── src/
│   │   ├── lib.rs                # Tauri command handlers
│   │   ├── connection_manager.rs # Server connection logic
│   │   ├── auth.rs               # Authentication (Argon2)
│   │   ├── api_client.rs         # OpenCode SDK integration
│   │   ├── chat_client.rs        # Chat & session management
│   │   └── error.rs              # Error types & retry logic
│   └── Cargo.toml
│
├── docs/                          # Documentation root
│   ├── AGENTS.md                 # ← Documentation structure guide
│   └── client/                   # Architecture & design docs
│       ├── ARCHITECTURE.md       # System architecture (READ FIRST)
│       ├── SECURITY.md           # Security implementation
│       ├── TESTING.md            # TDD approach (MANDATORY)
│       ├── PRD.md                # Product requirements
│       ├── USER-FLOWS.md         # Mobile interaction flows
│       └── README.md             # Documentation guide
│
├── status_docs/                   # Project status & tracking
│   ├── TODO.md                   # Current tasks & progress (15% complete)
│   ├── CURRENT_STATUS.md         # Implementation status
│   └── MVP_ROADMAP.md            # Milestone tracking
│
├── thoughts/plans/               # Implementation planning
│   └── opencode-client-pivot-implementation-plan.md
│
└── README.md
```

### 📍 Agent Context Index

Quick navigation to agent context files for different development areas:

| Area | Context File | Purpose |
|------|--------------|---------|
| **Root** | [AGENTS.md](AGENTS.md) | Quick start, build commands, code style (YOU ARE HERE) |
| **Frontend** | [frontend/AGENTS.md](frontend/AGENTS.md) | Astro/Svelte development, testing, common issues |
| **Components** | [frontend/src/components/AGENTS.md](frontend/src/components/AGENTS.md) | Svelte component patterns, accessibility standards |
| **Stores** | [frontend/src/stores/AGENTS.md](frontend/src/stores/AGENTS.md) | Reactive state management patterns |
| **Business Logic** | [frontend/src/lib/AGENTS.md](frontend/src/lib/AGENTS.md) | API integration, error handling, utilities |
| **Backend (Rust)** | [src-tauri/AGENTS.md](src-tauri/AGENTS.md) | Rust/Tauri development, async patterns, IPC |
| **Documentation** | [docs/AGENTS.md](docs/AGENTS.md) | Architecture & design docs reference |

### 🔍 Finding Context for Your Task

**"I'm working on [task], which AGENTS.md should I read?"**

- **Frontend UI:** [frontend/AGENTS.md](frontend/AGENTS.md) → [frontend/src/components/AGENTS.md](frontend/src/components/AGENTS.md)
- **State Management:** [frontend/src/stores/AGENTS.md](frontend/src/stores/AGENTS.md)
- **API Integration:** [frontend/src/lib/AGENTS.md](frontend/src/lib/AGENTS.md)
- **Rust Backend:** [src-tauri/AGENTS.md](src-tauri/AGENTS.md)
- **Architecture/Design:** [docs/AGENTS.md](docs/AGENTS.md) → [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md)
- **Security:** [docs/client/SECURITY.md](docs/client/SECURITY.md)
- **Testing (TDD):** [docs/client/TESTING.md](docs/client/TESTING.md)
- **Status/Tasks:** [status_docs/TODO.md](status_docs/TODO.md)

## Import Patterns & Module Organization

### Frontend (TypeScript/Svelte)
```typescript
// Svelte stores (reactive, exported)
export const chatStore = writable<ChatState>(initialState);

// Utilities (pure functions)
export function validateEmail(email: string): boolean { ... }

// Type exports
export type { ChatSession, ChatMessage } from './types';

// Component imports (uppercase for Svelte components)
import ChatBubble from './ChatBubble.svelte';
```

### Backend (Rust)
```rust
// Module structure (cargo handles exports)
pub mod connection_manager;
pub mod auth;
pub mod error;

// Public exports
pub use error::{AppError, RetryConfig};
pub use connection_manager::ConnectionManager;
```

## Testing Standards

### Unit Tests (Bun - Frontend)
```typescript
import { describe, test, expect, beforeEach } from 'bun:test';

describe('ChatStore', () => {
  let store: any;

  beforeEach(() => {
    store = createChatStore();
  });

  test('should add message', () => {
    expect(store.addMessage(...)).toBeDefined();
  });
});
```

### E2E Tests (Playwright)
```typescript
import { test, expect } from '@playwright/test';

test('chat flow', async ({ page }) => {
  await page.goto('/chat');
  await expect(page.getByPlaceholder('Type message')).toBeVisible();
});
```

### Rust Tests
```rust
#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn test_connection() {
    // Test implementation
  }
}
```

**Location Convention:**
- Frontend unit tests: `src/tests/[feature]/`
- Frontend E2E tests: `e2e/`
- Rust tests: Inline in module files (after code)

## Key Files & References

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Comprehensive development guide (READ THIS FIRST) |
| [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md) | Client-only system design |
| [docs/client/TESTING.md](docs/client/TESTING.md) | TDD approach & mobile testing |
| [docs/client/SECURITY.md](docs/client/SECURITY.md) | Security implementation details |
| [status_docs/TODO.md](status_docs/TODO.md) | Current tasks & progress tracking |
| [status_docs/CURRENT_STATUS.md](status_docs/CURRENT_STATUS.md) | Implementation status (15% complete) |
| [.prettierrc](.prettierrc) | Code formatting rules |
| [.eslintrc.cjs](.eslintrc.cjs) | Linting rules (TypeScript/Svelte/Astro/A11y) |
| [tsconfig.json](tsconfig.json) | TypeScript strict mode config |
| [tauri.conf.json](tauri.conf.json) | Tauri app configuration |

## Project Context

**What This Is:** Mobile-first native client for OpenCode servers (iOS, Android, Desktop) - NOT a server management tool.

**Current Status:** 15% complete - client pivot in progress
- ✅ Phase 0: Foundation & Security (Argon2, auth, build system)
- 🔄 Phase 1: Architecture Foundation (connection manager implementation)
- ⏳ Phase 2: Chat Client UI & Real-time Streaming (blocked by Phase 1)

**Key Architectural Decision:** This is a Tauri 2 client application (native iOS/Android/Desktop) using the OpenCode SDK to connect to remote OpenCode servers. See [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md) for detailed system design.

**Critical Standards:**
- ✅ Tauri 2 cross-platform (iOS 14.0+, Android 7+, macOS, Windows, Linux)
- ✅ TypeScript strict mode (no `any` types)
- ✅ TDD approach (tests before code)
- ✅ WCAG 2.2 AA accessibility
- ✅ Mobile-first UI/UX (44px touch targets)
- ✅ Security-first (Argon2, TLS 1.3, encrypted storage)

## Common Workflows

### Adding a New Feature
1. Read [docs/client/TESTING.md](docs/client/TESTING.md) for TDD approach
2. Write failing test(s) first
3. Implement minimal code to pass tests
4. Run quality checks: `cargo clippy && cd frontend && bun run lint && bun run typecheck`
5. Update [status_docs/TODO.md](status_docs/TODO.md)
6. Commit with clear message (conventional commits)

### Debugging
- **Frontend:** `bun run dev` and check browser DevTools (F12)
- **Backend:** `cargo tauri dev` and check stdout for Rust logs
- **Tauri IPC:** Enable debug logging in `tauri.conf.json`
- **Chat streaming:** Monitor Network tab for SSE events

### Testing Before Push
```bash
# Full quality check
cargo clippy && cargo test && \
cd frontend && bun run lint && bun run typecheck && bun test && bun run test:e2e
```

## Need Help?

- **Architecture questions:** See [docs/client/ARCHITECTURE.md](docs/client/ARCHITECTURE.md)
- **Security concerns:** See [docs/client/SECURITY.md](docs/client/SECURITY.md)
- **Testing guidance:** See [docs/client/TESTING.md](docs/client/TESTING.md)
- **Current tasks:** See [status_docs/TODO.md](status_docs/TODO.md)
- **Development guide:** See [CLAUDE.md](CLAUDE.md)

---

**Note:** This file is automatically referenced by OpenCode agents. Keep it up-to-date with project changes and ensure it's committed to Git.</content>
<parameter name="filePath">AGENTS.md