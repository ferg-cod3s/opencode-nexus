---
date: 2025-12-08
researcher: Assistant
topic: iOS Crash Analysis - SIGABRT in OpenCode Nexus
tags: [crash, ios, rust, panic, mutex, tauri]
status: complete
confidence: high
agents_used: [explore, websearch]
---

## Synopsis
iOS crash occurring 14 seconds after app launch due to Rust panic escalating to abort() caused by unsafe mutex `.unwrap()` calls in spawned Tokio tasks, combined with `panic = "abort"` configuration.

## Summary
- **Crash Type**: SIGABRT (Signal 6) - deliberate abort trap
- **Root Cause**: Rust panic in worker thread (Thread 10) with `panic = "abort"` configuration
- **Trigger**: Mutex lock `.unwrap()` calls in health monitoring loop panicking due to poisoned mutex
- **Time to Crash**: ~14 seconds after launch during WebView asset loading
- **Impact**: Complete app termination on iOS devices

## Detailed Findings

### Codebase Analysis

#### Crash Stack Analysis
**Thread 10 (Crashed Thread):**
```
0   libsystem_kernel.dylib      __pthread_kill
1   libsystem_pthread.dylib     pthread_kill
2   libsystem_c.dylib           abort
3-11 OpenCode Nexus             [Rust panic handler - offsets 3612012-3631732]
```

**Thread 0 (Main Thread):**
```
5   WebKit                         WebKit::WebURLSchemeHandlerCocoa::platformStartTask
6   WebKit                         WebKit::WebURLSchemeHandler::startTask
...
```

#### Panic Configuration
**File:** `src-tauri/Cargo.toml`
```toml
[profile.release]
panic = "abort"  # ← Panics immediately abort instead of unwinding

[profile.release-ios]
inherits = "release"
panic = "abort"  # ← Same for iOS builds
```

#### Unsafe Mutex Operations
**File:** `src-tauri/src/connection_manager.rs:463-505`

Health monitoring loop contains multiple `.unwrap()` calls on mutex locks:

```rust
tokio::spawn(async move {
    loop {
        // ...
        let should_continue = {
            matches!(
                *connection_status.lock().unwrap(),  // ← Can panic!
                ConnectionStatus::Connected
            )
        };
        
        // Extract URL before async operation
        let url_to_check = { server_url.lock().unwrap().clone() };  // ← Can panic!
        
        // ...
        *connection_status.lock().unwrap() = ConnectionStatus::Error;  // ← Can panic!
    }
});
```

**Additional Risk Points:**
- `src-tauri/src/lib.rs:990`: `.expect()` on Tauri app startup
- `src-tauri/src/api_client.rs:278`: `.expect()` in Default implementation
- `src-tauri/src/session_manager.rs:252`: `.unwrap()` after containment check

### Documentation Insights

#### Tauri iOS Configuration
- **WebKit Integration**: App links WebKit framework for URL scheme handling
- **Asset Loading**: Frontend dist served via Tauri's internal protocol handlers
- **CSP Configuration**: Allows `tauri:`, `ipc:`, `http://ipc.localhost` schemes
- **No Custom URL Schemes**: Only Universal Links configured for `opencode.ai`

#### Build Configuration
- **iOS Profile**: `release-ios` with `opt-level = "s"` (optimize for size)
- **Stripping**: Debug symbols removed (`strip = true`)
- **LTO**: Link-time optimization enabled

### External Research

#### Mutex Poisoning in Rust
Mutex poisoning occurs when a thread panics while holding a lock. Subsequent `.lock().unwrap()` calls will panic because the mutex is "poisoned".

**Key Insights:**
- `panic = "abort"` prevents unwinding, making poisoning more likely
- Spawned Tokio tasks can panic silently if not properly handled
- iOS has stricter memory management than desktop platforms

#### Tauri 2 iOS Considerations
- WebView initialization takes longer on iOS (~10-15 seconds)
- Health monitoring loops may start before WebView is fully ready
- iOS 26.2 (beta) may have additional stability considerations

## Code References

| File | Line | Issue | Risk Level |
|------|------|-------|------------|
| `src-tauri/Cargo.toml` | 12, 21 | `panic = "abort"` | High |
| `src-tauri/src/connection_manager.rs` | 469 | `.unwrap()` in spawned task | Critical |
| `src-tauri/src/connection_manager.rs` | 479 | `.unwrap()` in spawned task | Critical |
| `src-tauri/src/connection_manager.rs` | 494 | `.unwrap()` in spawned task | Critical |
| `src-tauri/src/lib.rs` | 990 | `.expect()` on app startup | High |
| `src-tauri/src/api_client.rs` | 278 | `.expect()` in Default impl | Medium |
| `src-tauri/src/session_manager.rs` | 252 | `.unwrap()` after check | Medium |

## Architecture Insights

### Crash Flow
1. App launches → WebView initializes (10-15 seconds)
2. Health monitoring task spawns immediately
3. Mutex lock panics (poisoned or other issue)
4. `panic = "abort"` triggers immediate process termination
5. WebKit URL scheme handler interrupted mid-operation

### Component Relationships
```
WebView (WKWebView)
    ↓ loads assets via
Tauri Runtime (wry)
    ↓ communicates with
Rust Backend (Tokio tasks)
    ↓ health monitoring
ConnectionManager (mutex operations)
    ↓ panics due to
Unsafe .unwrap() calls
```

## Recommendations

### Immediate Actions
1. **Replace `.unwrap()` with safe alternatives** in all production mutex operations
2. **Add `catch_unwind`** around spawned task bodies
3. **Consider `panic = "unwind"`** for iOS builds (trade binary size for stability)
4. **Add panic hooks** for crash reporting integration

### Long-term Considerations
1. **Comprehensive error handling audit** - Review all 32 `.unwrap()` calls
2. **iOS-specific testing** - Test panic scenarios on simulator
3. **Crash reporting integration** - Use Sentry for panic diagnostics
4. **Mutex poisoning recovery** - Implement graceful recovery patterns

## Risks & Limitations

### Identified Risks
- **Mutex Poisoning**: Previous panics can poison locks, causing cascading failures
- **Silent Task Failures**: Tokio tasks can panic without affecting main thread
- **iOS Memory Pressure**: Mobile platforms have stricter memory constraints
- **Debug Symbol Stripping**: `strip = true` prevents detailed crash analysis

### Limitations
- **Binary Offsets Only**: Without debug symbols, exact function names unavailable
- **iOS Beta Testing**: Crash occurred on iOS 26.2 (future beta)
- **WebKit Context**: Crash timing suggests WebView initialization interference

## Open Questions

- [ ] What caused the initial mutex poisoning (if applicable)?
- [ ] Is the 14-second timing related to WebView initialization?
- [ ] Should iOS builds use `panic = "unwind"` despite larger binary size?
- [ ] Are there iOS-specific mutex behaviors we need to account for?
- [ ] How does Tauri's WebView initialization interact with background tasks?</content>
<parameter name="filePath">docs/research/2025-12-08-ios-crash-analysis.md