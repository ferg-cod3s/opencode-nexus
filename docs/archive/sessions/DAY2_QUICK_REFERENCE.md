# Day 2 Quick Reference - Chat Client Integration

**Status**: Ready to Execute
**Duration**: 7.5-9.5 hours
**Outcome**: ChatClient integrated with ConnectionManager, 4 tests passing

---

## 🎯 One-Liner
Wire ChatClient to use ConnectionManager's server_url so chat operations work through the connected server.

---

## ⚡ Quick Start

### Before You Begin
```bash
# Verify Day 1 is complete
cargo test connection_manager --lib --target x86_64-apple-darwin
# Expected: 9 tests passing ✅

# Open the detailed plan
cat DAY2_PLAN.md
```

### Morning Session Checklist
- [ ] Open `src-tauri/src/chat_client.rs`
- [ ] Add test module with 4 tests (copy from DAY2_PLAN.md)
- [ ] Run: `cargo test chat_client --lib --target x86_64-apple-darwin`
- [ ] Expect: 4 tests FAIL (that's correct for TDD!)
- [ ] Commit: `git add ... && git commit -m "test: add ChatClient integration tests [failing]"`

### Afternoon Session Checklist
- [ ] Review chat_client.rs structure (lines 40-95)
- [ ] Add `server_url: Arc<Mutex<Option<String>>>` field
- [ ] Implement `set_server_url()` method
- [ ] Implement `get_server_url()` method
- [ ] Update `create_session()` to validate server_url
- [ ] Update `send_message()` to validate server_url
- [ ] Update `create_chat_session` command in lib.rs
- [ ] Run tests again: `cargo test chat_client --lib --target x86_64-apple-darwin`
- [ ] Expect: 4 tests PASS ✅
- [ ] Commit: Comprehensive commit message

---

## 📍 Key Files & Line Numbers

| File | Task | Lines | What To Do |
|------|------|-------|-----------|
| `src-tauri/src/chat_client.rs` | Add struct field | ~50 | Add `server_url: Arc<Mutex<Option<String>>>` |
| `src-tauri/src/chat_client.rs` | Add methods | ~100+ | Implement `set_server_url()` and `get_server_url()` |
| `src-tauri/src/chat_client.rs` | Validation | ~120-150 | Update `create_session()` validation |
| `src-tauri/src/chat_client.rs` | Validation | ~270-310 | Update `send_message()` validation |
| `src-tauri/src/chat_client.rs` | Tests | ~600+ | Add test module with 4 tests |
| `src-tauri/src/lib.rs` | Command | ~500-514 | Update `create_chat_session` command |

---

## 🧪 The 4 Tests (Copy-Paste Ready)

See **DAY2_PLAN.md** sections under "MORNING SESSION" for complete test code.

**Test Names**:
1. `test_chat_client_initialization`
2. `test_set_server_url_initializes_api_client`
3. `test_create_session_requires_server_url`
4. `test_send_message_uses_correct_server_url`

---

## 💡 Key Implementation Patterns

### Pattern 1: Server URL Storage
```rust
pub fn set_server_url(&mut self, url: &str) {
    *self.server_url.lock().unwrap() = Some(url.to_string());
    self.api_client = Some(ApiClient::new(url));
}
```

### Pattern 2: Validation Before Operation
```rust
pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
    if self.get_server_url().is_none() {
        return Err("Not connected to server...".to_string());
    }
    // ... rest of logic
}
```

### Pattern 3: Wiring in Tauri Commands
```rust
#[tauri::command]
async fn create_chat_session(app_handle: tauri::AppHandle, title: Option<String>) -> Result<ChatSession, String> {
    let state = app_handle.state::<Arc<Mutex<ConnectionManager>>>();
    let server_url = state.lock().unwrap().get_server_url().ok_or("Not connected")?;

    let mut chat_client = ChatClient::new(get_config_dir()?)?;
    chat_client.set_server_url(&server_url);
    chat_client.create_session(title.as_deref()).await
}
```

---

## 🚦 Execution Flow

```
Start Day 2
    ↓
Write 4 failing tests (MORNING - 3-4 hrs)
    ↓
Run tests, verify they FAIL (expected)
    ↓
Implement 5 fixes (AFTERNOON - 4-5 hrs)
    ↓
Run tests, verify they PASS (13/13 total)
    ↓
Commit comprehensive message (30 mins)
    ↓
Day 2 Complete ✅
```

---

## 🐛 Common Issues & Fixes

| Problem | Solution |
|---------|----------|
| Tests won't compile | Check imports at top of test module |
| `server_url` not found | Add field to struct around line 50 |
| `set_server_url` not found | Implement method in impl block |
| `api_client` init fails | Verify ApiClient::new(url) exists in api_client.rs |
| Tauri command fails | Verify ConnectionManager is in app state |
| Tests pass but command fails | Check app state initialization in main.rs |

---

## 📊 Expected Outputs

### After Writing Tests (Should FAIL)
```
error[E0308]: cannot find `server_url` in this scope
error[E0599]: no method named `set_server_url` found
```

### After Implementation (Should PASS)
```
running 4 tests
test chat_client::tests::test_chat_client_initialization ... ok
test chat_client::tests::test_set_server_url_initializes_api_client ... ok
test chat_client::tests::test_create_session_requires_server_url ... ok
test chat_client::tests::test_send_message_uses_correct_server_url ... ok

test result: ok. 4 passed; 0 failed; 0 ignored
```

---

## ✅ Success Criteria

- [ ] 4 tests written and documented
- [ ] All 4 tests passing
- [ ] `server_url` field added to ChatClient
- [ ] `set_server_url()` and `get_server_url()` methods implemented
- [ ] Validation added to `create_session()` and `send_message()`
- [ ] Tauri command properly wires ConnectionManager to ChatClient
- [ ] No compiler warnings
- [ ] Code committed with comprehensive message
- [ ] Total: 13 tests passing (9 from Day 1 + 4 from Day 2)

---

## 🚀 Ready?

**When You're Ready to Start**:
1. Open DAY2_PLAN.md (full details)
2. Open src-tauri/src/chat_client.rs
3. Start Morning Session
4. Copy test code from plan
5. Follow afternoon implementation steps
6. Run tests and commit

**Questions?** Review the detailed plan in DAY2_PLAN.md

---

**Estimated Completion**: 7.5-9.5 hours
**Next Milestone**: Day 3 - Message Streaming (SSE)
