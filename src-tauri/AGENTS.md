# AGENTS.md – Backend (Rust + Tauri 2)

**Quick commands** for Rust backend development. See [../AGENTS.md](../AGENTS.md) for full project context.

## Build/Test/Lint Commands

```bash
# Core development (from src-tauri/ directory)
cargo build              # Build Rust backend
cargo build --release   # Optimized build
cargo test              # Run all unit tests
cargo test [module]     # Run specific test
cargo clippy            # Lint + code analysis
cargo fmt               # Format code

# Full app (from project root)
cargo tauri dev         # Frontend + backend with hot reload
cargo tauri build       # Production binary

# Debugging
RUST_BACKTRACE=1 cargo test  # Full backtrace on panic
RUST_LOG=debug cargo test     # Debug logging
```

## Code Style

### Rust Naming & Structure
- **Functions:** `snake_case` → `async fn fetch_chat_session() { ... }`
- **Types/Structs:** `PascalCase` → `struct ConnectionManager { ... }`
- **Constants:** `UPPER_SNAKE_CASE` → `const MAX_RETRIES: u32 = 5;`
- **Error types:** End with `Error` → `ConnectionError`, `ParseError`

### Error Handling (Result + ? operator)
```rust
pub async fn connect(url: &str) -> Result<Connection, AppError> {
  let response = reqwest::get(url).await?;
  let conn = response.json().await?;
  Ok(conn)
}
```

### Async Patterns (Tokio)
- Release mutex locks BEFORE await (Send-safe)
- Extract data in block scope, then call async functions
- Use `Arc<Mutex<T>>` for shared state across tasks

### Tauri IPC Commands
```rust
#[tauri::command]
async fn my_command(
  app: AppHandle,
  arg: String,
) -> Result<Response, String> {
  // Emit events
  app.emit("event_name", &payload)?;
  Ok(response)
}
```

## Project Structure

```
src-tauri/
├── src/
│   ├── lib.rs              # Tauri command handlers
│   ├── connection_manager.rs  # OpenCode server connection
│   ├── auth.rs             # Authentication (Argon2)
│   ├── api_client.rs       # OpenCode API integration
│   ├── chat_client.rs      # Chat & session management
│   ├── message_stream.rs   # SSE streaming
│   ├── error.rs            # Error types & retry logic
│   └── main.rs             # App entry point
├── Cargo.toml              # Dependencies
└── tests/                  # Integration tests
```

## Key Modules

| Module | Purpose |
|--------|---------|
| [lib.rs](src/lib.rs) | Tauri command handlers + state management |
| [connection_manager.rs](src/connection_manager.rs) | Server connection management (replaces server_manager) |
| [auth.rs](src/auth.rs) | Authentication with Argon2 hashing |
| [chat_client.rs](src/chat_client.rs) | Chat operations + session lifecycle |
| [api_client.rs](src/api_client.rs) | RESTful API integration with OpenCode servers |
| [message_stream.rs](src/message_stream.rs) | SSE event streaming |
| [error.rs](src/error.rs) | Error types + retry configurations |

## Testing Patterns

### 🚨 100% Test Pass Rate Required

All tests must pass at all times. See [../AGENTS.md](../AGENTS.md) for full policy.

- **Never skip tests** with `#[ignore]` or comment them out
- **Update tests** when logic changes break them
- **Remove obsolete tests** when features are removed
- **Run tests before committing:** `cargo test`

```rust
#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn test_connection() {
    let conn = create_test_connection().await;
    assert!(conn.is_connected());
  }

  #[test]
  fn test_error_handling() {
    let err = parse_error("invalid");
    assert!(matches!(err, ParseError { .. }));
  }
}
```

## Critical Async Pattern

**❌ BAD: Holding lock across await**
```rust
let guard = mutex.lock().await;
some_async_fn().await;  // Error! Lock not Send-safe
```

**✅ GOOD: Release lock before await**
```rust
let data = {
  let guard = mutex.lock().await;
  guard.clone()  // Extract and drop lock
};
some_async_fn().await;  // OK!
```

## Dependencies (Key)

| Crate | Purpose |
|-------|---------|
| `tauri` | Desktop/mobile app framework (Tauri 2) |
| `tokio` | Async runtime |
| `reqwest` | HTTP client |
| `serde_json` | JSON serialization |
| `argon2` | Password hashing |
| `uuid` | Unique IDs |
| `chrono` | Date/time handling |

## Security Requirements

- ✅ Argon2 password hashing (implemented in auth.rs)
- ✅ TLS 1.3 for server connections
- ✅ Input validation (all user inputs sanitized)
- ✅ Account lockout after 5 failed attempts
- ✅ AES-256 for local storage (if applicable)

## Common Issues

| Issue | Solution |
|-------|----------|
| `error[E0277]: Future not Send` | Release mutex locks before await |
| `cargo test` fails on macOS | Check Xcode CLT: `xcode-select --install` |
| Connection timeout | Verify server URL in connection config |
| Serde serialization errors | Ensure types implement `Serialize` + `Deserialize` |

## Integration Points

- **Frontend IPC:** Commands in `lib.rs` for Svelte/Astro to invoke
- **OpenCode SDK:** Integration via `api_client.rs` + `connection_manager.rs`
- **Event Streaming:** SSE subscriptions in `message_stream.rs`
- **Authentication:** Session persistence via `auth.rs`

## Performance & Mobile Optimization

- Keep bundle size < 50MB iOS app (current: ~3.2MB)
- Minimize network requests (connection pooling via reqwest)
- Stream large responses (SSE for chat messages)
- Async all I/O (no blocking calls in handlers)

---

**Note:** All changes affect iOS/Android/Desktop builds. Run `cargo test && cargo clippy` before committing.

See [../docs/client/ARCHITECTURE.md](../docs/client/ARCHITECTURE.md) for system design and [../docs/client/SECURITY.md](../docs/client/SECURITY.md) for security implementation.
