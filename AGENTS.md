# AGENTS.md – OpenCode Nexus Agent Guidelines

## Build/Lint/Test Commands

**Frontend (Astro + Svelte + TypeScript):**
- `cd frontend && bun run dev` - Development server
- `cd frontend && bun run build` - Production build
- `cd frontend && bun run lint` - ESLint with accessibility checks
- `cd frontend && bun run typecheck` - TypeScript checking
- `cd frontend && bun test` - Run all tests
- `cd frontend && bun test --run "test name"` - Run single test

**Backend (Rust + Tauri):**
- `cargo build` - Build Rust backend
- `cargo test` - Run all unit tests
- `cargo test -- --test test_name` - Run single test
- `cargo clippy` - Linting
- `cargo fmt` - Code formatting
- `cargo tauri dev` - Run full Tauri app

## Code Style Guidelines

**TypeScript/JavaScript:**
- Strict TypeScript mode enabled - no `any` types
- `camelCase` for variables/functions, `PascalCase` for types/classes
- Single quotes, 2 spaces indentation, 100 char line width
- Group imports: stdlib → external → local
- Prefer `const` over `let`, early returns, async/await over promises

**Rust:**
- `snake_case` for variables/functions, `PascalCase` for types/structs
- Use `Result<T, E>` and `?` operator for error handling
- Prefer `&str` over `String` for function parameters
- Use `Arc<Mutex<T>>` for shared state across async boundaries

**General:**
- **TDD Required:** Write failing tests before implementation
- **Security First:** All inputs validated, secure password storage
- **Accessibility:** WCAG 2.2 AA compliance mandatory
- **No Comments:** Do not add comments unless explicitly requested</content>
<parameter name="filePath">AGENTS.md