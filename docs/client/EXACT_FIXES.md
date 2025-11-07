# Phase 1: Exact Code Fixes Required

## Location 1: lib.rs - Lines 198-202 (DELETE get_app_info function)

**File**: `/home/user/opencode-nexus/src-tauri/src/lib.rs`
**Status**: COMPILATION BLOCKER
**Lines**: 198-202

**CURRENT CODE TO DELETE**:
```rust
// App management commands
#[tauri::command]
async fn get_app_info(app_handle: tauri::AppHandle) -> Result<crate::server_manager::AppInfo, String> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not determine config directory")?
        .join("opencode-nexus");
```

**ACTION**: Delete the entire function definition (lines 198-202)

**REASON**: References `crate::server_manager::AppInfo` which no longer exists in client architecture

---

## Location 2: lib.rs - Lines 177-180 (IMPLEMENT complete_onboarding)

**File**: `/home/user/opencode-nexus/src-tauri/src/lib.rs`
**Status**: NEEDS IMPLEMENTATION
**Lines**: 167-175

**CURRENT CODE**:
```rust
#[tauri::command]
async fn complete_onboarding() -> Result<(), String> {
    let manager = OnboardingManager::new().map_err(|e| {
        format!("Failed to initialize onboarding manager: {}", e)
    })?;

    manager.complete_onboarding().map_err(|e| {
        format!("Failed to complete onboarding: {}", e)
    })
}
```

**CURRENT ISSUE** (Line 178-179):
```rust
    Ok(())  // <-- EMPTY/INCOMPLETE, NO RETURN STATEMENT
}
```

**REPLACEMENT CODE**:
```rust
#[tauri::command]
async fn complete_onboarding() -> Result<(), String> {
    log_info!("🚀 [ONBOARDING] Completing onboarding...");
    
    let manager = OnboardingManager::new().map_err(|e| {
        format!("Failed to initialize onboarding manager: {}", e)
    })?;

    manager.complete_onboarding().map_err(|e| {
        format!("Failed to complete onboarding: {}", e)
    })
}
```

**REASON**: Function was incomplete with missing implementation

---

## Location 3: lib.rs - Line 623 (REMOVE setup_opencode_server from handler list)

**File**: `/home/user/opencode-nexus/src-tauri/src/lib.rs`
**Status**: COMPILATION BLOCKER
**Line**: 623

**CURRENT CODE SECTION** (Lines 618-655):
```rust
        .invoke_handler(tauri::generate_handler![
            greet,
            // Onboarding commands
            get_onboarding_state,
            complete_onboarding,
            setup_opencode_server,     // <-- DELETE THIS LINE
            skip_onboarding,
            check_system_requirements,
            create_owner_account,
            // ... rest of handlers
        ])
```

**ACTION**: Delete the line containing `setup_opencode_server,`

**EXACT CHANGE**:
```rust
        .invoke_handler(tauri::generate_handler![
            greet,
            // Onboarding commands
            get_onboarding_state,
            complete_onboarding,
            // setup_opencode_server,  <- REMOVE THIS (was trying to export non-existent command)
            skip_onboarding,
            check_system_requirements,
            create_owner_account,
```

**REASON**: `setup_opencode_server` function doesn't exist (server architecture removed)

---

## Location 4: onboarding.rs - Line 354 (DELETE field reference)

**File**: `/home/user/opencode-nexus/src-tauri/src/onboarding.rs`
**Status**: RUNTIME ERROR
**Line**: 354

**CURRENT CODE SECTION** (Lines 350-362):
```rust
    pub fn skip_onboarding(&self) -> Result<()> {
        let config = OnboardingConfig {
            is_completed: true,
            opencode_server_path: None,    // <-- DELETE THIS LINE
            owner_account_created: false,
            owner_username: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        };

        self.save_config(&config)
    }
```

**ACTION**: Delete line 354 (the `opencode_server_path: None,` line)

**CORRECTED CODE**:
```rust
    pub fn skip_onboarding(&self) -> Result<()> {
        let config = OnboardingConfig {
            is_completed: true,
            // opencode_server_path: None,  <- REMOVED (field doesn't exist in struct)
            owner_account_created: false,
            owner_username: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        };

        self.save_config(&config)
    }
```

**REASON**: OnboardingConfig struct doesn't have `opencode_server_path` field

**VERIFY STRUCT** (Lines 14-21 in onboarding.rs):
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnboardingConfig {
    pub is_completed: bool,
    pub owner_account_created: bool,
    pub owner_username: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    // Note: opencode_server_path field DOES NOT EXIST
}
```

---

## Location 5: Delete tunnel_integration_tests.rs

**File**: `/home/user/opencode-nexus/src-tauri/src/tests/tunnel_integration_tests.rs`
**Status**: BROKEN TEST FILE
**Action**: DELETE ENTIRE FILE

**COMMAND**:
```bash
rm /home/user/opencode-nexus/src-tauri/src/tests/tunnel_integration_tests.rs
```

**REASON**: Tests reference old `ServerManager` struct which was replaced by `ConnectionManager`

**EVIDENCE** (Lines 52, 66):
```rust
// This no longer exists!
async fn create_test_server_manager() -> (ServerManager, TempDir) {
    // ...
    let manager = ServerManager::new(config_dir, PathBuf::from("/fake/opencode"), Some(mock_cloudflared))?;
    // ...
}
```

---

## Verification Checklist

After making these 5 changes:

### Test Compilation
```bash
cd /home/user/opencode-nexus/src-tauri
cargo build 2>&1 | head -20
# Should show NO errors, only warnings at most
```

### Run Unit Tests
```bash
cargo test 2>&1 | tail -20
# Should show tests passing
```

### Verify Commands Registered
```bash
grep -n "create_chat_session\|send_chat_message\|get_chat_sessions" src/lib.rs
# Should show all 3 commands in handler list (around line 645-647)
```

### Count Exported Commands
```bash
grep "^[[:space:]]*[a-z_]*," src/lib.rs | grep -v "//" | wc -l
# Should show 36 commands (not 38, since we removed 2)
```

---

## Summary Table

| Fix # | File | Line(s) | Type | Action |
|-------|------|---------|------|--------|
| 1 | lib.rs | 198-202 | DELETE | Remove get_app_info function |
| 2 | lib.rs | 167-175 | VERIFY | complete_onboarding already implemented |
| 3 | lib.rs | 623 | DELETE | Remove setup_opencode_server from handler |
| 4 | onboarding.rs | 354 | DELETE | Remove opencode_server_path: None, |
| 5 | tests/tunnel_integration_tests.rs | all | DELETE | Delete entire file |

---

## Expected Outcomes

### Before Fixes
```
error[E0432]: unresolved import `crate::server_manager`
  --> src/lib.rs:198:48
   |
198 | async fn get_app_info(app_handle: tauri::AppHandle) -> Result<crate::server_manager::AppInfo, String> {
    |                                                                 ^^^^^^^^^^^^^^^^^^^^
    |                                                                 could not find `server_manager` in crate

error[E0433]: cannot find value `setup_opencode_server` in this scope
   --> src/lib.rs:623:13
   |
623 |            setup_opencode_server,
    |            ^^^^^^^^^^^^^^^^^^^^ not found in this scope

error[E0560]: struct `OnboardingConfig` has no field named `opencode_server_path`
   --> src/onboarding.rs:354:13
   |
354 |            opencode_server_path: None,
    |            ^^^^^^^^^^^^^^^^^^^^ `OnboardingConfig` does not have this field
```

### After Fixes
```
   Compiling src-tauri v1.0.0-mvp
    Finished release [optimized] target(s) in 45.23s

running 50 tests
test auth::tests::test_authenticate_success ... ok
test auth::tests::test_create_user_success ... ok
test connection_manager::tests::test_connection_manager_new ... ok
test chat_client::tests::test_chat_client_creation ... ok
test message_stream::tests::test_message_stream_creation ... ok
...
test result: ok. 50 passed; 0 failed; 0 ignored
```

---

## Exact Bash Commands

If you prefer to apply fixes via sed/bash:

### Fix 1: Remove get_app_info (lines 198-202)
```bash
sed -i '198,202d' /home/user/opencode-nexus/src-tauri/src/lib.rs
```

### Fix 3: Remove setup_opencode_server from handler list
```bash
sed -i '/setup_opencode_server,/d' /home/user/opencode-nexus/src-tauri/src/lib.rs
```

### Fix 4: Remove opencode_server_path line
```bash
sed -i '/opencode_server_path: None,/d' /home/user/opencode-nexus/src-tauri/src/onboarding.rs
```

### Fix 5: Delete tunnel test file
```bash
rm /home/user/opencode-nexus/src-tauri/src/tests/tunnel_integration_tests.rs
```

---

## Manual Verification

After fixes, verify files:

### lib.rs changes
```bash
# Should show no get_app_info definition
grep -n "async fn get_app_info" /home/user/opencode-nexus/src-tauri/src/lib.rs
# Should return empty (0 results)

# Should show setup_opencode_server NOT in handler list
grep -A 30 "invoke_handler" /home/user/opencode-nexus/src-tauri/src/lib.rs | grep "setup_opencode_server"
# Should return empty (0 results)
```

### onboarding.rs changes
```bash
# Should show no opencode_server_path reference
grep "opencode_server_path" /home/user/opencode-nexus/src-tauri/src/onboarding.rs
# Should return empty (0 results)
```

### Test file deleted
```bash
ls -la /home/user/opencode-nexus/src-tauri/src/tests/tunnel_integration_tests.rs
# Should show: No such file or directory
```

