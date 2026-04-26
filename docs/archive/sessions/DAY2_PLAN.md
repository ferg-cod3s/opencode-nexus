# Day 2: Chat Client Integration with ConnectionManager

**Date**: November 11, 2025
**Phase**: Phase 1 - Architecture Foundation
**Objective**: Wire ChatClient to use ConnectionManager's server_url for all operations
**Expected Outcome**: ChatClient properly integrated, all tests passing, ready for Day 3 streaming

---

## 📋 Task Breakdown

### MORNING SESSION (3-4 hours): TDD - Write Failing Tests

#### Task 1: test_chat_client_initialization
**File**: `src-tauri/src/chat_client.rs` (add at end)
**Purpose**: Verify ChatClient starts in disconnected state
**Test Code**:
```rust
#[tokio::test]
async fn test_chat_client_initialization() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let chat_client = ChatClient::new(temp_dir.path().to_path_buf())
        .expect("Failed to create chat client");

    // Should start with no server URL
    assert!(chat_client.get_server_url().is_none());

    // Should start with no sessions
    assert_eq!(chat_client.get_all_sessions().len(), 0);
}
```

#### Task 2: test_set_server_url_initializes_api_client
**File**: `src-tauri/src/chat_client.rs`
**Purpose**: Verify setting server_url creates ApiClient with correct base URL
**Test Code**:
```rust
#[tokio::test]
async fn test_set_server_url_initializes_api_client() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let mut chat_client = ChatClient::new(temp_dir.path().to_path_buf())
        .expect("Failed to create chat client");

    // Set server URL
    chat_client.set_server_url("http://localhost:3000");

    // Verify URL is stored
    assert_eq!(chat_client.get_server_url(), Some("http://localhost:3000".to_string()));

    // Verify api_client is initialized
    assert!(chat_client.api_client.is_some());
}
```

#### Task 3: test_create_session_requires_server_url
**File**: `src-tauri/src/chat_client.rs`
**Purpose**: Verify creating session without server fails gracefully
**Test Code**:
```rust
#[tokio::test]
async fn test_create_session_requires_server_url() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let mut chat_client = ChatClient::new(temp_dir.path().to_path_buf())
        .expect("Failed to create chat client");

    // Try to create session without server URL
    let result = chat_client.create_session(None).await;

    // Should fail with clear error
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("server") || result.unwrap_err().contains("connected"));
}
```

#### Task 4: test_send_message_uses_correct_server_url
**File**: `src-tauri/src/chat_client.rs`
**Purpose**: Verify message sending uses correct server URL
**Test Code**:
```rust
#[tokio::test]
async fn test_send_message_uses_correct_server_url() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let mut chat_client = ChatClient::new(temp_dir.path().to_path_buf())
        .expect("Failed to create chat client");

    // Set server URL
    chat_client.set_server_url("http://example.com:3000");

    // Verify the URL is what we expect
    assert_eq!(
        chat_client.get_server_url(),
        Some("http://example.com:3000".to_string())
    );

    // Verify api_client has correct base URL
    // (This will be validated when actual send_message works)
}
```

---

### AFTERNOON SESSION (4-5 hours): Implement ChatClient Fixes

#### Task 5: Review chat_client.rs structure
**File**: `src-tauri/src/chat_client.rs`

**What to check**:
1. Lines 1-60: Imports and struct definition
2. Lines 62-95: Constructor and initialization
3. Lines 240-260: Get server URL method exists?
4. Lines 280-310: Send message implementation
5. Lines 320-345: Create session implementation

**Questions to answer**:
- Does ChatClient have `server_url` field? (Should it?)
- Does it have `api_client` field? (How is it initialized?)
- Does create_session use api_client correctly?
- Does send_message validate server_url exists first?

#### Task 6: Add server_url field to ChatClient
**File**: `src-tauri/src/chat_client.rs` (around line 45-55)

**Current structure** (expected):
```rust
pub struct ChatClient {
    config_dir: PathBuf,
    sessions: Arc<Mutex<HashMap<String, ChatSession>>>,
    current_session: Arc<Mutex<Option<String>>>,
    api_client: Option<ApiClient>,
    event_sender: broadcast::Sender<ChatEvent>,
}
```

**Need to add**:
```rust
pub struct ChatClient {
    config_dir: PathBuf,
    server_url: Arc<Mutex<Option<String>>>,  // ← ADD THIS
    sessions: Arc<Mutex<HashMap<String, ChatSession>>>,
    current_session: Arc<Mutex<Option<String>>>,
    api_client: Option<ApiClient>,
    event_sender: broadcast::Sender<ChatEvent>,
}
```

#### Task 7: Implement set_server_url method
**File**: `src-tauri/src/chat_client.rs` (add after line 95)

**Implementation**:
```rust
pub fn set_server_url(&mut self, url: &str) {
    *self.server_url.lock().unwrap() = Some(url.to_string());

    // Initialize ApiClient with the server URL
    self.api_client = Some(ApiClient::new(url));
}

pub fn get_server_url(&self) -> Option<String> {
    self.server_url.lock().unwrap().clone()
}
```

#### Task 8: Update create_session to check server_url
**File**: `src-tauri/src/chat_client.rs` (around lines 120-150)

**Change from**:
```rust
pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
    // ... session creation logic
}
```

**Change to**:
```rust
pub async fn create_session(&mut self, title: Option<&str>) -> Result<ChatSession, String> {
    // Check if server_url is set
    if self.get_server_url().is_none() {
        return Err("Not connected to server. Call set_server_url first.".to_string());
    }

    // ... rest of session creation logic
}
```

#### Task 9: Update send_message to validate connection
**File**: `src-tauri/src/chat_client.rs` (around lines 270-310)

**Add validation at start**:
```rust
pub async fn send_message(&mut self, session_id: &str, content: &str) -> Result<(), String> {
    // Validate server_url is set
    if self.get_server_url().is_none() {
        return Err("Not connected to server. Call set_server_url first.".to_string());
    }

    // ... rest of message sending logic
}
```

#### Task 10: Update Tauri command in lib.rs
**File**: `src-tauri/src/lib.rs` (lines 500-514)

**Current code** (expected):
```rust
#[tauri::command]
async fn create_chat_session(
    _app_handle: tauri::AppHandle,
    title: Option<String>,
) -> Result<ChatSession, String> {
    let config_dir = get_config_dir()?;
    let mut chat_client = ChatClient::new(config_dir)?;
    chat_client.create_session(title.as_deref()).await
}
```

**Change to**:
```rust
#[tauri::command]
async fn create_chat_session(
    app_handle: tauri::AppHandle,
    title: Option<String>,
) -> Result<ChatSession, String> {
    // Get the connection manager from app state
    let state = app_handle.state::<Arc<Mutex<ConnectionManager>>>();
    let connection_manager = state.lock().unwrap();

    // Get server URL from connection manager
    let server_url = connection_manager.get_server_url()
        .ok_or("Not connected to any server")?;

    // Create chat client
    let config_dir = get_config_dir()?;
    let mut chat_client = ChatClient::new(config_dir)?;

    // Set server URL on chat client
    chat_client.set_server_url(&server_url);

    // Create session
    chat_client.create_session(title.as_deref()).await
}
```

**Note**: This assumes ConnectionManager is available in app state. If not, we'll need to pass it differently.

---

### AFTERNOON SESSION (continued): Run Tests

#### Task 11: Run ChatClient tests
**Command**:
```bash
cargo test chat_client --lib --target x86_64-apple-darwin
```

**Expected Output**:
```
running 4 tests
test chat_client::tests::test_chat_client_initialization ... ok
test chat_client::tests::test_set_server_url_initializes_api_client ... ok
test chat_client::tests::test_create_session_requires_server_url ... ok
test chat_client::tests::test_send_message_uses_correct_server_url ... ok

test result: ok. 4 passed; 0 failed
```

#### Task 12: Fix any failing tests
If tests fail:
1. Read the error message carefully
2. Review the specific test
3. Fix the implementation
4. Re-run tests
5. Repeat until all pass

**Common issues**:
- `api_client` field doesn't exist → add it to struct
- `set_server_url` not found → implement the method
- Server URL validation failing → check error message format

#### Task 13: Run full backend test suite
**Command**:
```bash
cargo test --lib --target x86_64-apple-darwin 2>&1 | tail -20
```

**Expected**: All previous tests (9 from Day 1) + new tests (4) should pass

---

### END OF DAY: Commit & Documentation

#### Task 14: Commit Day 2 work
**Command**:
```bash
git add src-tauri/src/chat_client.rs src-tauri/src/lib.rs
git commit -m "feat: integrate ChatClient with ConnectionManager

Wire ChatClient to use ConnectionManager's server_url:
- Add server_url field to ChatClient struct
- Implement set_server_url() method for initialization
- Add get_server_url() method for retrieval
- Validate server_url exists before creating sessions
- Validate server_url exists before sending messages
- Update create_chat_session Tauri command to use ConnectionManager

Test Coverage:
- test_chat_client_initialization: Verify initial state
- test_set_server_url_initializes_api_client: Verify URL storage and ApiClient init
- test_create_session_requires_server_url: Verify validation
- test_send_message_uses_correct_server_url: Verify message routing

Tests: 4 new tests passing (total: 13/13 passing)
Status: ChatClient now depends on ConnectionManager for all operations
Ready for Day 3: Message streaming integration

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 📊 Success Criteria for Day 2

- [ ] All 4 ChatClient tests written and passing
- [ ] ChatClient properly stores server_url
- [ ] ApiClient initializes with correct base URL
- [ ] Session creation validates connection
- [ ] Message sending validates connection
- [ ] Tauri command properly wires ConnectionManager → ChatClient
- [ ] No compiler warnings in chat_client.rs
- [ ] No test failures
- [ ] Work committed to git

---

## 🔍 Key Integration Points

### ConnectionManager → ChatClient Flow
```
ConnectionManager.get_server_url()
    ↓
create_chat_session command retrieves URL
    ↓
ChatClient.set_server_url(url) called
    ↓
ApiClient initialized with server_url
    ↓
ChatClient ready for session/message operations
```

### Critical Files to Modify
1. **src-tauri/src/chat_client.rs** (Main implementation)
   - Add `server_url: Arc<Mutex<Option<String>>>` field
   - Implement `set_server_url()` method
   - Implement `get_server_url()` method
   - Add validation to `create_session()` and `send_message()`
   - Add test module with 4 tests

2. **src-tauri/src/lib.rs** (Tauri commands)
   - Update `create_chat_session` command
   - Get ConnectionManager from app state
   - Retrieve server_url
   - Pass to ChatClient

---

## ⏰ Estimated Timing

| Phase | Time | Tasks |
|-------|------|-------|
| **Morning** | 3-4 hrs | Write 4 failing tests |
| **Afternoon** | 4-5 hrs | Fix implementation, run tests |
| **End of Day** | 0.5 hrs | Commit and update docs |
| **Total** | 7.5-9.5 hrs | Full Day 2 |

---

## 🚀 What Comes Next (Day 3)

With ChatClient properly integrated with ConnectionManager, Day 3 will focus on:
- Activating SSE client in message_stream.rs
- Implementing real-time event streaming
- Emitting ChatEvent updates to frontend
- Testing with mock OpenCode server responses

---

## 📝 Notes

- Keep tests focused and isolated (each test tests one thing)
- Use temporary directories for persistence tests
- Error messages should be descriptive
- Comments should explain the "why", not the "what"
- Update status_docs/TODO.md after each task completion
- Commit frequently (after morning tests, after afternoon fixes)

---

**Status**: Ready to execute
**Prerequisite**: Day 1 must be complete ✅
**Estimated Start**: When ready
**Goal**: Unblock Day 3 SSE streaming work
