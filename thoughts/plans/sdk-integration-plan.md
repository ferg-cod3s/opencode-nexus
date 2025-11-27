# OpenCode SDK Integration Plan

**Date**: November 27, 2025
**Status**: Proposed
**Recommendation**: Use @opencode-ai/sdk in Frontend (Option 1)

## Executive Summary

Replace manual Rust HTTP client implementation with the official `@opencode-ai/sdk` (TypeScript) in the Astro/Svelte frontend. This eliminates ~90% of current backend HTTP code while providing better type safety, automatic updates, and reduced maintenance burden.

## Current vs. Proposed Architecture

### Current Architecture (Manual Implementation)
```
Frontend (Astro/Svelte)
    ↓ (Tauri IPC)
Rust Backend
    - connection_manager.rs (600+ lines)
    - api_client.rs (200+ lines)
    - chat_client.rs (900+ lines)
    - message_stream.rs (SSE handling)
    ↓ (Manual HTTP with reqwest)
OpenCode Server
```

### Proposed Architecture (SDK Integration)
```
Frontend (Astro/Svelte)
    ↓ (Direct usage)
@opencode-ai/sdk v1.0.35
    - Type-safe client
    - Session management
    - SSE streaming
    - File operations
    ↓ (HTTP handled by SDK)
OpenCode Server

Minimal Tauri Backend (only for):
    - Secure credential storage (OS keychain)
    - Connection persistence
    - Native notifications
```

## Benefits Analysis

### Code Reduction
- **Remove**: ~1,700 lines of Rust HTTP client code
- **Add**: ~200 lines of TypeScript SDK integration
- **Net savings**: ~1,500 lines of code to maintain

### Type Safety
- **Current**: Manual JSON parsing with custom types
- **Proposed**: Auto-generated TypeScript types from OpenCode API spec

### Maintenance
- **Current**: Must manually update when OpenCode API changes
- **Proposed**: `npm update @opencode-ai/sdk` brings new features

### Real-time Streaming
- **Current**: Manual SSE parsing with custom event handling
- **Proposed**: SDK handles SSE via `client.event.subscribe()`

### Testing
- **Current**: Mock Rust HTTP responses in tests
- **Proposed**: Use SDK in frontend tests with proper TypeScript support

## Implementation Plan

### Phase 1: SDK Integration in Frontend (Week 1)

#### 1.1 Create SDK Client Wrapper
**File**: `frontend/src/lib/opencode-client.ts`

```typescript
import { createOpencodeClient } from '@opencode-ai/sdk';
import type { Client } from '@opencode-ai/sdk';

export interface ServerConnection {
  name: string;
  hostname: string;
  port: number;
  secure: boolean;
}

export class OpencodeClientManager {
  private client: Client | null = null;
  private currentConnection: ServerConnection | null = null;

  async connect(connection: ServerConnection): Promise<void> {
    const protocol = connection.secure ? 'https' : 'http';
    const baseUrl = `${protocol}://${connection.hostname}:${connection.port}`;

    const { client } = await createOpencodeClient({ baseUrl });
    this.client = client;
    this.currentConnection = connection;
  }

  async disconnect(): Promise<void> {
    this.client = null;
    this.currentConnection = null;
  }

  getClient(): Client {
    if (!this.client) {
      throw new Error('Not connected to a server');
    }
    return this.client;
  }

  isConnected(): boolean {
    return this.client !== null;
  }

  getCurrentConnection(): ServerConnection | null {
    return this.currentConnection;
  }
}

// Singleton instance
export const opcodeClient = new OpencodeClientManager();
```

#### 1.2 Update Chat Interface
**File**: `frontend/src/pages/chat.astro`

```typescript
<script>
  import { opcodeClient } from '../lib/opencode-client';
  import { invoke } from '@tauri-apps/api/core';

  // Connect to server (connection details from Tauri storage)
  async function initializeConnection() {
    const savedConnection = await invoke('get_last_used_connection');
    if (savedConnection) {
      await opcodeClient.connect(savedConnection);
    }
  }

  // Create new chat session
  async function createSession(title?: string) {
    const client = opcodeClient.getClient();
    const session = await client.session.create({ title });
    return session;
  }

  // Send message
  async function sendMessage(sessionId: string, content: string) {
    const client = opcodeClient.getClient();
    await client.session.prompt(sessionId, {
      parts: [{ type: 'text', text: content }]
    });
  }

  // Subscribe to real-time events
  async function subscribeToEvents() {
    const client = opcodeClient.getClient();
    const eventStream = await client.event.subscribe();

    for await (const event of eventStream) {
      console.log('Received event:', event);
      // Update UI based on event type
      handleServerEvent(event);
    }
  }

  function handleServerEvent(event: any) {
    // Update UI state based on event
    switch (event.type) {
      case 'message.chunk':
        // Update streaming message in UI
        break;
      case 'session.created':
        // Add new session to list
        break;
      // ... handle other events
    }
  }

  // Initialize on page load
  onMount(async () => {
    await initializeConnection();
    await subscribeToEvents();
  });
</script>
```

#### 1.3 Create Connection State Store
**File**: `frontend/src/lib/stores/connection.ts`

```typescript
import { writable } from 'svelte/store';
import type { ServerConnection } from '../opencode-client';

interface ConnectionState {
  isConnected: boolean;
  currentServer: ServerConnection | null;
  error: string | null;
}

export const connectionState = writable<ConnectionState>({
  isConnected: false,
  currentServer: null,
  error: null,
});
```

### Phase 2: Simplify Rust Backend (Week 1)

#### 2.1 Remove Unnecessary HTTP Code
**Files to Remove**:
- `src-tauri/src/api_client.rs` ❌ (SDK handles this)
- `src-tauri/src/message_stream.rs` ❌ (SDK handles SSE)

**Files to Simplify**:
- `src-tauri/src/connection_manager.rs` - Keep only connection persistence
- `src-tauri/src/chat_client.rs` - Remove (SDK handles all chat logic)

#### 2.2 Minimal Rust Backend
**File**: `src-tauri/src/connection_manager.rs` (simplified)

```rust
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConnection {
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
        Ok(Self {
            config_dir,
            connections: HashMap::new(),
        })
    }

    // Only persist connection history - SDK handles actual connection
    pub fn save_connection(&mut self, connection: ServerConnection) -> Result<(), String> {
        self.connections.insert(connection.name.clone(), connection);
        self.save_to_disk()
    }

    pub fn get_saved_connections(&self) -> Vec<ServerConnection> {
        self.connections.values().cloned().collect()
    }

    pub fn get_last_used_connection(&self) -> Option<ServerConnection> {
        // Return most recently used connection
        self.connections.values()
            .max_by_key(|c| c.last_connected.as_ref())
            .cloned()
    }

    fn save_to_disk(&self) -> Result<(), String> {
        let json = serde_json::to_string_pretty(&self.connections)
            .map_err(|e| format!("Failed to serialize: {}", e))?;
        std::fs::write(self.config_dir.join("connections.json"), json)
            .map_err(|e| format!("Failed to write: {}", e))
    }
}
```

#### 2.3 Update Tauri Commands
**File**: `src-tauri/src/lib.rs`

```rust
// Simplified commands - SDK handles complex logic
#[tauri::command]
async fn save_connection(
    state: State<'_, AppState>,
    connection: ServerConnection
) -> Result<(), String> {
    let mut manager = state.connection_manager.lock().await;
    manager.save_connection(connection)
}

#[tauri::command]
async fn get_saved_connections(
    state: State<'_, AppState>
) -> Result<Vec<ServerConnection>, String> {
    let manager = state.connection_manager.lock().await;
    Ok(manager.get_saved_connections())
}

#[tauri::command]
async fn get_last_used_connection(
    state: State<'_, AppState>
) -> Result<Option<ServerConnection>, String> {
    let manager = state.connection_manager.lock().await;
    Ok(manager.get_last_used_connection())
}

// Optional: Secure credential storage
#[tauri::command]
async fn store_server_credentials(
    hostname: String,
    token: String
) -> Result<(), String> {
    // Use OS keychain for secure storage
    // Implementation depends on your security requirements
    Ok(())
}
```

### Phase 3: Testing & Migration (Week 2)

#### 3.1 Frontend Tests
**File**: `frontend/src/tests/sdk-integration.test.ts`

```typescript
import { describe, it, expect, beforeEach } from 'bun:test';
import { OpencodeClientManager } from '../lib/opencode-client';

describe('OpencodeClientManager', () => {
  let manager: OpencodeClientManager;

  beforeEach(() => {
    manager = new OpencodeClientManager();
  });

  it('should connect to a server', async () => {
    const connection = {
      name: 'Test Server',
      hostname: 'localhost',
      port: 4096,
      secure: false,
    };

    await manager.connect(connection);
    expect(manager.isConnected()).toBe(true);
  });

  it('should create a session', async () => {
    // Connect to test server first
    await manager.connect({
      name: 'Test',
      hostname: 'localhost',
      port: 4096,
      secure: false,
    });

    const client = manager.getClient();
    const session = await client.session.create({ title: 'Test Session' });
    expect(session.id).toBeTruthy();
    expect(session.title).toBe('Test Session');
  });
});
```

#### 3.2 E2E Tests
Update Playwright tests to use SDK:

```typescript
// frontend/e2e/chat.spec.ts
test('should connect and send message', async ({ page }) => {
  await page.goto('/chat');

  // SDK handles connection in background
  await expect(page.getByText('Connected')).toBeVisible();

  // Send message
  await page.fill('[data-testid="message-input"]', 'Hello AI!');
  await page.click('[data-testid="send-button"]');

  // Wait for AI response (streamed via SDK)
  await expect(page.getByText(/Hello/)).toBeVisible();
});
```

## Migration Checklist

### Week 1: SDK Integration
- [ ] Install SDK dependencies (already done - v1.0.35)
- [ ] Create `frontend/src/lib/opencode-client.ts` wrapper
- [ ] Update `chat.astro` to use SDK
- [ ] Create connection state store
- [ ] Update UI components to use SDK events

### Week 2: Rust Simplification
- [ ] Remove `api_client.rs`
- [ ] Remove `message_stream.rs`
- [ ] Simplify `connection_manager.rs`
- [ ] Update Tauri commands
- [ ] Update `lib.rs` to use simplified commands

### Week 3: Testing & Documentation
- [ ] Write frontend tests for SDK integration
- [ ] Update E2E tests
- [ ] Update documentation
- [ ] Test offline functionality
- [ ] Verify type safety with TypeScript

## Risks & Mitigations

### Risk 1: SDK Breaking Changes
**Mitigation**: Pin SDK version, test before upgrading

### Risk 2: Offline Functionality
**Mitigation**: Implement local caching in frontend for connection history

### Risk 3: Platform-Specific Issues (iOS/Android)
**Mitigation**: Test on all platforms, use Tauri's platform APIs if needed

## Success Criteria

### Code Metrics
- [ ] Remove >1,500 lines of Rust HTTP code
- [ ] Add <300 lines of TypeScript SDK integration
- [ ] Maintain or improve test coverage

### Functionality
- [ ] Connect to remote OpenCode servers
- [ ] Create and manage sessions
- [ ] Send messages with real-time streaming
- [ ] Persist connection history
- [ ] Handle reconnection gracefully

### Performance
- [ ] Page load <2s
- [ ] Message streaming <100ms latency
- [ ] Memory usage <50MB for SDK

## Alternative Considered: Rust SDK

**Why Not Create Rust Bindings?**
- Would require maintaining SDK wrapper in two languages
- TypeScript SDK is official and well-maintained
- Tauri apps naturally bridge TypeScript ↔ Rust
- No performance benefit (network I/O is the bottleneck)

## Conclusion

**Recommendation**: Proceed with Option 1 (SDK in Frontend)

This approach:
- ✅ Reduces code complexity significantly
- ✅ Leverages official, maintained SDK
- ✅ Improves type safety
- ✅ Simplifies testing
- ✅ Enables faster feature development

The minimal Rust backend will focus on:
- Secure credential storage
- Connection persistence
- Native platform features

All chat/session logic moves to the frontend using `@opencode-ai/sdk`.
