# OpenCode SDK + Tauri v2 Mobile Implementation Plan

**Date**: November 27, 2025
**Status**: Ready for Implementation
**Primary Target**: **iOS Mobile Client** for OpenCode Servers (Android support possible later)

## Executive Summary

This plan integrates the `@opencode-ai/sdk` (TypeScript) with Tauri v2's iOS-native APIs to create a **native iOS mobile client** for connecting to OpenCode servers. The architecture leverages the SDK for all server communication while using Tauri exclusively for iOS-native features like notifications, secure storage (iOS Keychain), and biometric authentication (Touch ID/Face ID).

**Key Principle**: Frontend handles OpenCode logic via SDK, Rust backend handles iOS-native features only.

**Platform Focus**: iOS is the primary target platform. The app is designed for iPhone and iPad, with TestFlight distribution. Android support can be added later using the same architecture since Tauri v2 supports both platforms.

## Architecture Overview

### Simplified Architecture

```
┌─────────────────────────────────────────────────────────┐
│          iOS Mobile App (iPhone/iPad)                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Frontend (Astro/Svelte + TypeScript)                 │
│     ↓                                                   │
│  @opencode-ai/sdk ──────────→ OpenCode Server         │
│     - Session management       (HTTP/SSE)              │
│     - Message streaming                                │
│     - File operations                                  │
│     - Real-time events                                 │
│                                                         │
│     ↓ (Tauri IPC - Native Features Only)              │
│                                                         │
│  Tauri v2 Backend (Rust - iOS Native)                 │
│     - 🔔 Notifications (iOS local notifications)       │
│     - 🔐 Secure Storage (iOS Keychain via keystore)    │
│     - 👆 Biometric Auth (Touch ID/Face ID)             │
│     - 💾 Local Cache (tauri-plugin-store)              │
│     - 📳 Haptics (iOS haptic feedback)                 │
│     - 🔗 Deep Linking (opencode:// URL scheme)         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Separation of Concerns

| Component | Responsibility | Technology | iOS Feature |
|-----------|----------------|------------|-------------|
| **OpenCode Communication** | Sessions, messages, streaming, file ops | `@opencode-ai/sdk` (TypeScript) | N/A (network) |
| **iOS Notifications** | Local notifications for new messages | `tauri-plugin-notification` | iOS Local Notifications API |
| **Secure Storage** | Server credentials, auth tokens | `tauri-plugin-keystore` | **iOS Keychain** |
| **Biometric Auth** | Touch ID, Face ID | `tauri-plugin-biometry` | **Touch ID / Face ID** |
| **Local Cache** | Connection history, preferences | `tauri-plugin-store` | iOS app sandbox storage |
| **Haptic Feedback** | Message sent/received vibrations | `tauri-plugin-haptic` | **iOS Haptic Engine** |
| **Deep Linking** | `opencode://chat/session-id` URLs | `tauri-plugin-deep-link` | iOS URL scheme handling |

## Current State vs. Target State

### Files to REMOVE (SDK Replaces)
- ❌ `src-tauri/src/api_client.rs` (225 lines) - SDK handles HTTP
- ❌ `src-tauri/src/message_stream.rs` (200+ lines) - SDK handles SSE
- ❌ `src-tauri/src/chat_client.rs` (950 lines) - SDK handles sessions

### Files to SIMPLIFY
- 📉 `src-tauri/src/connection_manager.rs` (790 lines → ~150 lines)
  - Remove: All HTTP logic, health checks, retry logic
  - Keep: Connection persistence, credential storage bridge

### Files to ADD
- ✅ `frontend/src/lib/opencode-sdk.ts` - SDK wrapper and state management
- ✅ `src-tauri/src/mobile_features.rs` - Consolidated mobile-native features
- ✅ `src-tauri/capabilities/mobile.json` - Mobile permissions config

**Net Result**: ~1,500 lines removed, ~400 lines added = -1,100 lines total

## Tauri v2 Plugins Required

### 1. Notifications Plugin
**Purpose**: Alert users to new messages when app is backgrounded

**Installation**:
```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-notification = "2.0"
```

```bash
# frontend
npm add @tauri-apps/plugin-notification
```

**Usage**:
```typescript
// frontend/src/lib/notifications.ts
import { sendNotification, isPermissionGranted, requestPermission } from '@tauri-apps/plugin-notification';

export async function notifyNewMessage(sessionTitle: string, messagePreview: string) {
  if (!(await isPermissionGranted())) {
    await requestPermission();
  }

  sendNotification({
    title: sessionTitle || 'New Message',
    body: messagePreview,
    sound: 'notification.wav',
    // Mobile-only: Action buttons
    actions: [
      { id: 'reply', title: 'Reply' },
      { id: 'view', title: 'View' }
    ]
  });
}
```

**Permissions**:
```json
// src-tauri/capabilities/mobile.json
{
  "permissions": [
    "notification:default",
    "notification:allow-is-permission-granted",
    "notification:allow-request-permission",
    "notification:allow-send"
  ]
}
```

**Sources**: [Tauri v2 Notifications](https://v2.tauri.app/plugin/notification/), [NPM Package](https://www.npmjs.com/package/@tauri-apps/plugin-notification)

### 2. Keystore Plugin (Secure Storage)
**Purpose**: Store server credentials and auth tokens in **iOS Keychain** (Apple's secure credential storage)

**Installation**:
```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-keystore = "0.1"  # Community plugin for native keychain
```

**Usage**:
```rust
// src-tauri/src/mobile_features.rs
use tauri_plugin_keystore::KeystoreExt;

#[tauri::command]
async fn store_server_credentials(
    app: tauri::AppHandle,
    server_id: String,
    credentials: String,
) -> Result<(), String> {
    app.keystore()
        .set(&server_id, credentials.as_bytes())
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
async fn get_server_credentials(
    app: tauri::AppHandle,
    server_id: String,
) -> Result<Option<String>, String> {
    match app.keystore().get(&server_id).await {
        Ok(Some(bytes)) => {
            let creds = String::from_utf8(bytes).map_err(|e| e.to_string())?;
            Ok(Some(creds))
        }
        Ok(None) => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}
```

**Sources**: [tauri-plugin-keystore](https://crates.io/crates/tauri-plugin-keystore), [GitHub Discussion](https://github.com/tauri-apps/tauri/discussions/7846)

### 3. Biometric Plugin
**Purpose**: Secure app access with **Touch ID** (iPhone 8 and earlier) or **Face ID** (iPhone X and later)

**Installation**:
```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-biometry = "0.1"
```

**Usage**:
```typescript
// frontend/src/lib/biometric-auth.ts
import { authenticate } from '@tauri-apps/plugin-biometry';

export async function unlockApp() {
  try {
    const result = await authenticate({
      reason: 'Unlock OpenCode',
      title: 'Authentication Required',
      subtitle: 'Use biometrics to unlock'
    });
    return result.success;
  } catch (error) {
    console.error('Biometric auth failed:', error);
    return false;
  }
}
```

**Sources**: [tauri-plugin-biometry](https://crates.io/crates/tauri-plugin-biometry)

### 4. Store Plugin (Local Cache)
**Purpose**: Cache connection history, UI preferences, session metadata

**Installation**:
```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-store = "2.0"
```

**Usage**:
```typescript
// frontend/src/lib/local-store.ts
import { Store } from '@tauri-apps/plugin-store';

const store = new Store('app-cache.json');

export async function saveConnectionHistory(connections: ServerConnection[]) {
  await store.set('connection_history', connections);
  await store.save();
}

export async function getConnectionHistory(): Promise<ServerConnection[]> {
  return (await store.get('connection_history')) || [];
}
```

**Sources**: [Tauri v2 Store Plugin](https://v2.tauri.app/plugin/store/)

### 5. Haptic Feedback Plugin
**Purpose**: Vibration feedback for message sent/received

**Installation**:
```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-haptic = "2.0"
```

**Usage**:
```typescript
// frontend/src/lib/haptics.ts
import { impact, notification } from '@tauri-apps/plugin-haptic';

export async function messageSentFeedback() {
  await impact('light'); // Light haptic feedback
}

export async function messageReceivedFeedback() {
  await notification('success'); // Success vibration pattern
}
```

**Sources**: [Tauri v2 Features](https://v2.tauri.app/plugin/)

### 6. Deep Link Plugin
**Purpose**: Support `opencode://chat/session-id` URLs for sharing

**Installation**:
```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-deep-link = "2.0"
```

**Usage**:
```rust
// src-tauri/src/lib.rs
use tauri_plugin_deep_link::DeepLinkExt;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_deep_link::init())
        .setup(|app| {
            app.deep_link().register_all()?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

**Sources**: [Tauri v2 Deep Link](https://v2.tauri.app/plugin/)

## Implementation Plan

### Phase 1: Frontend SDK Integration (Week 1)

#### Step 1.1: Create SDK Wrapper
**File**: `frontend/src/lib/opencode-sdk.ts`

```typescript
import { createOpencodeClient } from '@opencode-ai/sdk';
import type { Client } from '@opencode-ai/sdk';
import { writable } from 'svelte/store';

export interface ServerConnection {
  id: string;
  name: string;
  hostname: string;
  port: number;
  secure: boolean;
  lastConnected?: string;
}

export interface SDKState {
  client: Client | null;
  connection: ServerConnection | null;
  isConnected: boolean;
  error: string | null;
}

// Svelte store for reactive state
export const sdkState = writable<SDKState>({
  client: null,
  connection: null,
  isConnected: false,
  error: null,
});

class OpencodeSDKManager {
  private client: Client | null = null;

  async connect(connection: ServerConnection): Promise<void> {
    try {
      const protocol = connection.secure ? 'https' : 'http';
      const baseUrl = `${protocol}://${connection.hostname}:${connection.port}`;

      const { client } = await createOpencodeClient({ baseUrl });
      this.client = client;

      // Update state
      sdkState.set({
        client,
        connection: { ...connection, lastConnected: new Date().toISOString() },
        isConnected: true,
        error: null,
      });

      // Save to Tauri backend (secure storage)
      await this.saveConnection(connection);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : 'Connection failed';
      sdkState.update(s => ({ ...s, error: errorMsg, isConnected: false }));
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    this.client = null;
    sdkState.set({
      client: null,
      connection: null,
      isConnected: false,
      error: null,
    });
  }

  getClient(): Client {
    if (!this.client) {
      throw new Error('Not connected to a server. Call connect() first.');
    }
    return this.client;
  }

  isConnected(): boolean {
    return this.client !== null;
  }

  private async saveConnection(connection: ServerConnection): Promise<void> {
    const { invoke } = await import('@tauri-apps/api/core');
    await invoke('save_connection', { connection });
  }
}

// Singleton instance
export const opencode = new OpencodeSDKManager();
```

#### Step 1.2: Create Chat Interface with SDK
**File**: `frontend/src/lib/chat-sdk.ts`

```typescript
import { opencode } from './opencode-sdk';
import { writable } from 'svelte/store';
import type { ChatMessage, ChatSession } from '@opencode-ai/sdk';

export interface ChatState {
  sessions: ChatSession[];
  currentSession: ChatSession | null;
  messages: ChatMessage[];
  isStreaming: boolean;
}

export const chatState = writable<ChatState>({
  sessions: [],
  currentSession: null,
  messages: [],
  isStreaming: false,
});

export async function createSession(title?: string): Promise<ChatSession> {
  const client = opencode.getClient();
  const session = await client.session.create({ title });

  chatState.update(s => ({
    ...s,
    sessions: [...s.sessions, session],
    currentSession: session,
  }));

  return session;
}

export async function sendMessage(content: string): Promise<void> {
  const client = opencode.getClient();
  const { currentSession } = get(chatState);

  if (!currentSession) {
    throw new Error('No active session');
  }

  chatState.update(s => ({ ...s, isStreaming: true }));

  try {
    await client.session.prompt(currentSession.id, {
      parts: [{ type: 'text', text: content }],
    });

    // Haptic feedback for message sent
    const { messageSentFeedback } = await import('./haptics');
    await messageSentFeedback();
  } finally {
    chatState.update(s => ({ ...s, isStreaming: false }));
  }
}

export async function subscribeToEvents(): Promise<void> {
  const client = opencode.getClient();
  const eventStream = await client.event.subscribe();

  for await (const event of eventStream) {
    handleServerEvent(event);
  }
}

function handleServerEvent(event: any): void {
  switch (event.type) {
    case 'message.chunk':
      // Update streaming message in UI
      chatState.update(s => {
        const lastMessage = s.messages[s.messages.length - 1];
        if (lastMessage?.role === 'assistant') {
          lastMessage.content += event.chunk;
        } else {
          s.messages.push({
            id: event.messageId,
            role: 'assistant',
            content: event.chunk,
            timestamp: new Date().toISOString(),
          });
        }
        return s;
      });
      break;

    case 'message.complete':
      // Message streaming complete
      chatState.update(s => ({ ...s, isStreaming: false }));

      // Haptic feedback for message received
      import('./haptics').then(({ messageReceivedFeedback }) => {
        messageReceivedFeedback();
      });

      // Show notification if app is backgrounded
      import('./notifications').then(({ notifyNewMessage }) => {
        const { currentSession } = get(chatState);
        notifyNewMessage(
          currentSession?.title || 'OpenCode',
          event.preview || 'New message received'
        );
      });
      break;

    case 'session.created':
      chatState.update(s => ({
        ...s,
        sessions: [...s.sessions, event.session],
      }));
      break;

    default:
      console.log('Unhandled event:', event);
  }
}
```

#### Step 1.3: Update Chat UI
**File**: `frontend/src/pages/chat.astro`

```astro
---
// Server-side: No imports needed, all client-side
---

<script>
import { onMount } from 'svelte';
import { opencode, sdkState } from '../lib/opencode-sdk';
import { chatState, createSession, sendMessage, subscribeToEvents } from '../lib/chat-sdk';
import { invoke } from '@tauri-apps/api/core';

let messageInput = '';

onMount(async () => {
  // Restore last connection
  const lastConnection = await invoke('get_last_connection');
  if (lastConnection) {
    try {
      await opencode.connect(lastConnection);
      await subscribeToEvents();
    } catch (error) {
      console.error('Failed to restore connection:', error);
    }
  }
});

async function handleSendMessage() {
  if (!messageInput.trim()) return;

  await sendMessage(messageInput);
  messageInput = '';
}

async function handleCreateSession() {
  await createSession('New Chat');
}
</script>

<div class="chat-container">
  {#if $sdkState.isConnected}
    <div class="messages">
      {#each $chatState.messages as message}
        <div class="message {message.role}">
          <p>{message.content}</p>
        </div>
      {/each}
    </div>

    <div class="input-area">
      <input
        bind:value={messageInput}
        placeholder="Type a message..."
        on:keydown={(e) => e.key === 'Enter' && handleSendMessage()}
      />
      <button on:click={handleSendMessage} disabled={$chatState.isStreaming}>
        Send
      </button>
    </div>
  {:else}
    <div class="not-connected">
      <p>Not connected to a server</p>
      <a href="/connect">Connect to Server</a>
    </div>
  {/if}
</div>
```

### Phase 2: Tauri Mobile Features (Week 2)

#### Step 2.1: Add Tauri Plugins
**File**: `src-tauri/Cargo.toml`

```toml
[dependencies]
# Existing dependencies...
tauri = { version = "2", features = [] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }

# Mobile-native feature plugins
tauri-plugin-notification = "2.0"
tauri-plugin-store = "2.0"
tauri-plugin-haptic = "2.0"
tauri-plugin-deep-link = "2.0"

# Secure storage (community plugin)
tauri-plugin-keystore = "0.1"
tauri-plugin-biometry = "0.1"

# Remove these (SDK handles):
# reqwest - REMOVE
# eventsource-client - REMOVE
```

#### Step 2.2: Simplify Connection Manager
**File**: `src-tauri/src/connection_manager.rs` (simplified from 790 → 150 lines)

```rust
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConnection {
    pub id: String,
    pub name: String,
    pub hostname: String,
    pub port: u16,
    pub secure: bool,
    pub last_connected: Option<String>,
}

pub struct ConnectionManager {
    config_dir: PathBuf,
    connections: HashMap<String, ServerConnection>,
}

impl ConnectionManager {
    pub fn new(config_dir: PathBuf) -> Result<Self, String> {
        let mut manager = Self {
            config_dir,
            connections: HashMap::new(),
        };
        manager.load_connections()?;
        Ok(manager)
    }

    pub fn save_connection(&mut self, connection: ServerConnection) -> Result<(), String> {
        self.connections.insert(connection.id.clone(), connection);
        self.persist_to_disk()
    }

    pub fn get_all_connections(&self) -> Vec<ServerConnection> {
        self.connections.values().cloned().collect()
    }

    pub fn get_last_connection(&self) -> Option<ServerConnection> {
        self.connections.values()
            .filter(|c| c.last_connected.is_some())
            .max_by_key(|c| c.last_connected.as_ref().unwrap())
            .cloned()
    }

    fn persist_to_disk(&self) -> Result<(), String> {
        let json = serde_json::to_string_pretty(&self.connections)
            .map_err(|e| format!("Serialization error: {}", e))?;
        let path = self.config_dir.join("connections.json");
        std::fs::write(&path, json)
            .map_err(|e| format!("Write error: {}", e))
    }

    fn load_connections(&mut self) -> Result<(), String> {
        let path = self.config_dir.join("connections.json");
        if !path.exists() {
            return Ok(());
        }
        let json = std::fs::read_to_string(&path)
            .map_err(|e| format!("Read error: {}", e))?;
        self.connections = serde_json::from_str(&json)
            .map_err(|e| format!("Parse error: {}", e))?;
        Ok(())
    }
}
```

#### Step 2.3: Create Mobile Features Module
**File**: `src-tauri/src/mobile_features.rs` (NEW - consolidates all mobile-native code)

```rust
use tauri_plugin_keystore::KeystoreExt;
use serde::{Deserialize, Serialize};

/// Store server credentials securely in iOS Keychain or Android Keystore
#[tauri::command]
pub async fn store_server_credentials(
    app: tauri::AppHandle,
    server_id: String,
    credentials: String,
) -> Result<(), String> {
    app.keystore()
        .set(&server_id, credentials.as_bytes())
        .await
        .map_err(|e| format!("Keystore error: {}", e))
}

/// Retrieve server credentials from secure storage
#[tauri::command]
pub async fn get_server_credentials(
    app: tauri::AppHandle,
    server_id: String,
) -> Result<Option<String>, String> {
    match app.keystore().get(&server_id).await {
        Ok(Some(bytes)) => {
            let creds = String::from_utf8(bytes)
                .map_err(|e| format!("UTF-8 error: {}", e))?;
            Ok(Some(creds))
        }
        Ok(None) => Ok(None),
        Err(e) => Err(format!("Keystore error: {}", e)),
    }
}

/// Delete credentials from secure storage
#[tauri::command]
pub async fn delete_server_credentials(
    app: tauri::AppHandle,
    server_id: String,
) -> Result<(), String> {
    app.keystore()
        .delete(&server_id)
        .await
        .map_err(|e| format!("Keystore error: {}", e))
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NotificationPayload {
    pub title: String,
    pub body: String,
    pub session_id: Option<String>,
}

/// Send local notification (called from frontend when message arrives)
#[tauri::command]
pub async fn send_local_notification(
    payload: NotificationPayload,
) -> Result<(), String> {
    // Note: Frontend uses @tauri-apps/plugin-notification directly
    // This command is a backup for cases where Rust needs to send notifications
    Ok(())
}
```

#### Step 2.4: Update Main Tauri Entry Point
**File**: `src-tauri/src/lib.rs`

```rust
mod connection_manager;
mod mobile_features;
mod auth; // Keep existing auth module

use connection_manager::ConnectionManager;
use std::sync::Mutex;

pub struct AppState {
    connection_manager: Mutex<ConnectionManager>,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        // Initialize mobile plugins
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_haptic::init())
        .plugin(tauri_plugin_deep_link::init())
        .plugin(tauri_plugin_keystore::init())
        .plugin(tauri_plugin_biometry::init())

        // App state
        .setup(|app| {
            let config_dir = app.path().app_config_dir()
                .expect("Failed to get config dir");

            let connection_manager = ConnectionManager::new(config_dir)
                .expect("Failed to initialize connection manager");

            app.manage(AppState {
                connection_manager: Mutex::new(connection_manager),
            });

            Ok(())
        })

        // Simplified commands - SDK handles OpenCode logic
        .invoke_handler(tauri::generate_handler![
            // Connection persistence (no HTTP)
            save_connection,
            get_all_connections,
            get_last_connection,

            // Secure storage
            mobile_features::store_server_credentials,
            mobile_features::get_server_credentials,
            mobile_features::delete_server_credentials,

            // Keep existing auth commands
            auth::create_account,
            auth::verify_password,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

// Simplified commands

#[tauri::command]
async fn save_connection(
    state: tauri::State<'_, AppState>,
    connection: connection_manager::ServerConnection,
) -> Result<(), String> {
    state.connection_manager.lock().unwrap()
        .save_connection(connection)
}

#[tauri::command]
async fn get_all_connections(
    state: tauri::State<'_, AppState>,
) -> Result<Vec<connection_manager::ServerConnection>, String> {
    Ok(state.connection_manager.lock().unwrap()
        .get_all_connections())
}

#[tauri::command]
async fn get_last_connection(
    state: tauri::State<'_, AppState>,
) -> Result<Option<connection_manager::ServerConnection>, String> {
    Ok(state.connection_manager.lock().unwrap()
        .get_last_connection())
}
```

#### Step 2.5: Configure Mobile Permissions
**File**: `src-tauri/capabilities/mobile.json` (NEW)

```json
{
  "$schema": "https://tauri.app/schema/capabilities.json",
  "identifier": "mobile-features",
  "description": "Permissions for mobile-native features",
  "platforms": ["iOS", "android"],
  "permissions": [
    "notification:default",
    "notification:allow-is-permission-granted",
    "notification:allow-request-permission",
    "notification:allow-send",
    "store:default",
    "store:allow-get",
    "store:allow-set",
    "store:allow-save",
    "haptic:default",
    "haptic:allow-impact",
    "haptic:allow-notification",
    "deep-link:default",
    "keystore:default",
    "biometry:default"
  ]
}
```

### Phase 3: Testing & Integration (Week 3)

#### Step 3.1: Frontend Tests with SDK
**File**: `frontend/src/tests/sdk-integration.test.ts`

```typescript
import { describe, it, expect, beforeEach } from 'bun:test';
import { opencode } from '../lib/opencode-sdk';
import { createSession, sendMessage } from '../lib/chat-sdk';

describe('OpenCode SDK Integration', () => {
  beforeEach(async () => {
    await opencode.disconnect();
  });

  it('should connect to server', async () => {
    await opencode.connect({
      id: 'test-server',
      name: 'Test Server',
      hostname: 'localhost',
      port: 4096,
      secure: false,
    });

    expect(opencode.isConnected()).toBe(true);
  });

  it('should create session', async () => {
    await opencode.connect({
      id: 'test-server',
      name: 'Test',
      hostname: 'localhost',
      port: 4096,
      secure: false,
    });

    const session = await createSession('Test Chat');
    expect(session.id).toBeTruthy();
    expect(session.title).toBe('Test Chat');
  });

  it('should send message', async () => {
    await opencode.connect({
      id: 'test-server',
      name: 'Test',
      hostname: 'localhost',
      port: 4096,
      secure: false,
    });

    await createSession('Test');
    await sendMessage('Hello AI!');
    // Message sending is async, check that it doesn't throw
  });
});
```

#### Step 3.2: E2E Tests
**File**: `frontend/e2e/mobile-chat.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Mobile Chat Flow', () => {
  test('should connect and send message', async ({ page }) => {
    await page.goto('/connect');

    // Connect to server
    await page.fill('[data-testid="hostname-input"]', 'localhost');
    await page.fill('[data-testid="port-input"]', '4096');
    await page.click('[data-testid="connect-button"]');

    // Wait for connection
    await expect(page).toHaveURL('/chat');
    await expect(page.getByText('Connected')).toBeVisible();

    // Send message
    await page.fill('[data-testid="message-input"]', 'Hello AI!');
    await page.click('[data-testid="send-button"]');

    // Wait for AI response (streamed via SDK)
    await expect(page.getByText(/Hello/)).toBeVisible({ timeout: 10000 });
  });

  test('should show notification on background message', async ({ page, context }) => {
    // This test requires special permissions handling for mobile
    await page.goto('/chat');

    // Grant notification permission
    await context.grantPermissions(['notifications']);

    // Background the app (mobile-specific)
    // Message arrives -> notification should appear
    // Implementation depends on Playwright mobile capabilities
  });
});
```

#### Step 3.3: Rust Tests (Simplified)
**File**: `src-tauri/src/connection_manager.rs`

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_save_and_load_connection() {
        let temp_dir = TempDir::new().unwrap();
        let mut manager = ConnectionManager::new(temp_dir.path().to_path_buf()).unwrap();

        let connection = ServerConnection {
            id: "test-1".to_string(),
            name: "Test Server".to_string(),
            hostname: "localhost".to_string(),
            port: 4096,
            secure: false,
            last_connected: Some("2025-11-27T10:00:00Z".to_string()),
        };

        manager.save_connection(connection.clone()).unwrap();

        // Create new manager to test persistence
        let manager2 = ConnectionManager::new(temp_dir.path().to_path_buf()).unwrap();
        let loaded = manager2.get_last_connection().unwrap();

        assert_eq!(loaded.id, "test-1");
        assert_eq!(loaded.hostname, "localhost");
    }
}
```

## Migration Checklist

### Week 1: Frontend SDK Integration
- [ ] Install SDK: `npm add @opencode-ai/sdk` (already done - v1.0.35)
- [ ] Create `frontend/src/lib/opencode-sdk.ts` with SDK wrapper
- [ ] Create `frontend/src/lib/chat-sdk.ts` for session/message handling
- [ ] Create `frontend/src/lib/notifications.ts` for mobile notifications
- [ ] Create `frontend/src/lib/haptics.ts` for haptic feedback
- [ ] Update `frontend/src/pages/chat.astro` to use SDK
- [ ] Update `frontend/src/pages/connect.astro` for server connection
- [ ] Test SDK integration with local OpenCode server

### Week 2: Tauri Mobile Features
- [ ] Add Tauri plugins to `src-tauri/Cargo.toml`
- [ ] Install frontend plugin packages (`@tauri-apps/plugin-*`)
- [ ] Create `src-tauri/src/mobile_features.rs`
- [ ] Simplify `src-tauri/src/connection_manager.rs` (remove HTTP)
- [ ] Update `src-tauri/src/lib.rs` with plugin initialization
- [ ] Create `src-tauri/capabilities/mobile.json`
- [ ] Remove `api_client.rs`, `message_stream.rs`, `chat_client.rs`
- [ ] Test on iOS simulator (Xcode)
- [ ] Test on physical iPhone via TestFlight
- [ ] (Optional) Test on Android emulator for future support

### Week 3: iOS Testing & Polish
- [ ] Write frontend tests for SDK integration
- [ ] Update E2E tests for iOS mobile flows
- [ ] Test notification permissions on iOS
- [ ] Test Touch ID/Face ID on physical iPhone
- [ ] Test deep linking with `opencode://` URLs on iOS
- [ ] Test haptic feedback patterns (Haptic Engine)
- [ ] Performance testing on iPhone (memory, battery, network)
- [ ] Submit TestFlight build
- [ ] Update documentation

## Files Summary

### Files to DELETE
```
src-tauri/src/api_client.rs              ❌ (225 lines)
src-tauri/src/message_stream.rs          ❌ (200 lines)
src-tauri/src/chat_client.rs             ❌ (950 lines)
```

### Files to MODIFY
```
src-tauri/src/connection_manager.rs      📉 (790 → 150 lines)
src-tauri/src/lib.rs                     📝 (plugin init, simplified commands)
src-tauri/Cargo.toml                     📝 (add plugins, remove HTTP deps)
frontend/src/pages/chat.astro            📝 (use SDK instead of Tauri commands)
```

### Files to CREATE
```
frontend/src/lib/opencode-sdk.ts         ✅ (~150 lines)
frontend/src/lib/chat-sdk.ts             ✅ (~200 lines)
frontend/src/lib/notifications.ts        ✅ (~50 lines)
frontend/src/lib/haptics.ts              ✅ (~30 lines)
src-tauri/src/mobile_features.rs         ✅ (~150 lines)
src-tauri/capabilities/mobile.json       ✅ (~50 lines)
frontend/src/tests/sdk-integration.test.ts ✅ (~100 lines)
```

### Net Impact
- **Removed**: ~1,375 lines (Rust HTTP code)
- **Added**: ~730 lines (SDK wrapper + mobile features)
- **Net reduction**: -645 lines
- **Complexity reduction**: Massive (HTTP client → SDK abstraction)

## Success Criteria

### Functional (iOS)
- [ ] Connect to remote OpenCode server via domain/IP
- [ ] Create chat sessions via SDK
- [ ] Send messages with real-time streaming
- [ ] Receive iOS local notifications for background messages
- [ ] Touch ID / Face ID authentication works
- [ ] Credentials stored securely in iOS Keychain
- [ ] iOS haptic feedback on message send/receive
- [ ] Deep links (`opencode://`) open specific chat sessions on iOS

### Performance
- [ ] App launches in <2 seconds
- [ ] Message streaming latency <100ms
- [ ] Memory usage <50MB during active chat
- [ ] Battery drain <5% per hour of active use

### Quality
- [ ] All frontend tests passing (>90% coverage)
- [ ] E2E tests passing on iOS simulator and device
- [ ] No TypeScript errors
- [ ] No Clippy warnings in Rust code
- [ ] WCAG 2.2 AA compliance maintained
- [ ] TestFlight build installs and runs on iPhone

## Benefits of This Architecture

### 1. **Simplified Codebase**
- SDK handles all OpenCode server communication
- Rust backend only does mobile-native features
- Clear separation of concerns

### 2. **Type Safety**
- SDK provides auto-generated TypeScript types
- Compiler catches API mismatches

### 3. **Maintainability**
- SDK updates bring new features automatically
- Less custom HTTP code to maintain
- Easier to onboard new developers

### 4. **iOS-Native Experience**
- **iOS Keychain** for secure credential storage
- **Touch ID / Face ID** for biometric authentication
- iOS local notifications with action buttons
- **iOS Haptic Engine** for tactile feedback
- Native iOS UI patterns and navigation

### 5. **Future-Proof**
- SDK evolves with OpenCode server
- Tauri plugins maintained by community
- Easy to add new mobile features

## Risks & Mitigations

### Risk 1: SDK Breaking Changes
**Mitigation**: Pin SDK version, test before upgrading

### Risk 2: Plugin Compatibility
**Mitigation**: Test on iOS 14+ targets (iPhone 8 and later), ensure TestFlight builds work

### Risk 3: Network Reliability
**Mitigation**: SDK should handle reconnection, add offline mode

### Risk 4: Performance on Older iPhones
**Mitigation**: Profile on iPhone 8/X (oldest supported), optimize bundle size for iOS constraints

## Resources & References

### Tauri v2 Documentation
- [Tauri v2 Stable Release](https://v2.tauri.app/blog/tauri-20/)
- [Mobile Plugin Development](https://v2.tauri.app/develop/plugins/develop-mobile/)
- [Features & Recipes](https://v2.tauri.app/plugin/)

### Tauri Plugins
- [Notifications Plugin](https://v2.tauri.app/plugin/notification/)
- [Store Plugin](https://v2.tauri.app/plugin/store/)
- [Stronghold Plugin](https://v2.tauri.app/plugin/stronghold/)
- [tauri-plugin-keystore](https://crates.io/crates/tauri-plugin-keystore)
- [tauri-plugin-biometry](https://crates.io/crates/tauri-plugin-biometry)

### OpenCode SDK
- [SDK Documentation](https://opencode.ai/docs/sdk)
- [Server API](https://opencode.ai/docs/server)
- NPM: `@opencode-ai/sdk` (v1.0.35 already installed)

### Community Resources
- [GitHub Discussions - Secure Storage](https://github.com/tauri-apps/tauri/discussions/7846)
- [Push Notifications Issue](https://github.com/tauri-apps/tauri/issues/11651)

## Next Steps

1. **Review this plan** and provide feedback
2. **Create PR** with this plan document
3. **Execute with Haiku** using step-by-step implementation
4. **Test incrementally** after each phase

This plan is ready for implementation with Claude Haiku for efficient, cost-effective execution.
