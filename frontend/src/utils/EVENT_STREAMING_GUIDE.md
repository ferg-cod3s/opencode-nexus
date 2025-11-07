# Event Streaming Integration Guide

## Overview

The OpenCode Nexus client implements real-time message streaming using Server-Sent Events (SSE) from the OpenCode server's `/event` endpoint. Messages stream to the frontend through a multi-layered architecture:

```
OpenCode Server (/event endpoint)
    ↓ SSE Connection
Rust Backend (message_stream.rs)
    ↓ ChatEvent broadcast
Tauri IPC (chat-event emission)
    ↓ Frontend listener
chat-api.ts (initializeChat)
    ↓ Store update
chatStore.actions.handleChatEvent
    ↓ Reactive update
Svelte stores (activeSessionStore)
    ↓ Auto-render
ChatInterface.svelte (reactive to activeSession)
    ↓ Display
MessageBubble.svelte components
```

## Key Components

### 1. Backend SSE Streaming (Rust)

**File**: `src-tauri/src/message_stream.rs`

- Connects to OpenCode server's `/event` endpoint with proper headers:
  - `Accept: text/event-stream`
  - `Cache-Control: no-cache`
- Parses incoming SSE events and converts to `ChatEvent` enums
- Broadcasts events to frontend via Tauri's event system
- Implements exponential backoff retry (5s base, up to multiple retries)
- Handles two event types:
  - `MessageChunk`: Partial AI response for streaming display
  - `MessageReceived`: Complete message (final chunk)

**Key Methods**:
```rust
pub async fn start_streaming() -> Result<(), String>
pub async fn stream_events(base_url: &str, event_sender: broadcast::Sender<ChatEvent>)
async fn handle_streaming_message(msg: &StreamingMessage, event_sender: ...)
```

### 2. Chat Client Integration (Rust)

**File**: `src-tauri/src/chat_client.rs`

- Owns a `MessageStream` instance for lifecycle management
- Initializes API client when server URL is set
- `start_event_stream()` returns subscription to event broadcaster
- Events flow: SSE → MessageStream → ChatEvent broadcast → Tauri emit

**Key Methods**:
```rust
pub fn set_server_url(&mut self, url: String)  // Initialize MessageStream
pub async fn start_event_stream(&mut self) -> Result<broadcast::Receiver<ChatEvent>, String>
```

### 3. Tauri Command Handler (Rust)

**File**: `src-tauri/src/lib.rs`

Command: `start_message_stream`
- Initializes ChatClient with server URL
- Starts SSE streaming via ChatClient
- Listens to ChatEvent broadcast
- Emits events to frontend via Tauri's `emit('chat-event', event)`

```rust
#[tauri::command]
async fn start_message_stream(app_handle: tauri::AppHandle) -> Result<(), String>
```

### 4. Chat API Bridge (TypeScript)

**File**: `frontend/src/utils/chat-api.ts`

Bridges Tauri backend to Svelte stores:

- `initializeChat(onChatEvent)`: Starts message stream + event listener
- `startChatEventListener(handler)`: Attaches to `chat-event` via Tauri
- Wraps all chat operations (create, send, delete sessions)
- Works in both Tauri and browser/test environments

**Key Functions**:
```typescript
export const initializeChat = async (
  onChatEvent: (event: ChatEvent) => Promise<void>
): Promise<() => void>

export const startChatEventListener = async (
  handler: (event: ChatEvent) => Promise<void>
): Promise<() => void>
```

### 5. Store Event Handler (TypeScript)

**File**: `frontend/src/stores/chat.ts`

`chatActions.handleChatEvent(event)` processes incoming events:

- **SessionCreated**: Adds new session to store
- **MessageReceived**: Adds complete message to active session
- **MessageChunk**: Appends to last assistant message (streaming)
- **Error**: Sets error state

```typescript
handleChatEvent: async (event: ChatEvent) => {
  if (event.MessageChunk) {
    activeSessionStore.appendToLastMessage(chunk);
  } else if (event.MessageReceived) {
    activeSessionStore.addMessage(message);
  }
  // ... etc
}
```

### 6. Reactive UI Components (Svelte)

**ChatInterface.svelte**:
- Reactively binds to `activeSession` from store
- Auto-scrolls to bottom when `activeSession.messages` changes
- Shows typing indicator when `isLoading` is true
- Virtual scrolling for performance with large conversations

**StreamingIndicator.svelte**:
- Displays "AI is responding..." when `chatStateStore.isStreaming` is true
- Shows animated typing dots
- Accessible with ARIA labels

**MessageBubble.svelte**:
- Renders individual messages with role-specific styling
- User messages on right (blue), Assistant on left (gray)
- Displays timestamp
- Screen reader support via `sr-only` class

## Event Flow Example

### User sends message "Hello":

1. **Frontend**: `chatActions.sendMessage("Hello", messageSender)`
   - Adds user message to store immediately (optimistic update)
   - Calls `messageSender` (sends to backend)
   - Sets `isStreaming = true`

2. **Backend**: `send_chat_message` command
   - Adds user message to session
   - POSTs to OpenCode API: `POST /session/{id}/prompt`
   - API starts processing, returns
   - SSE stream begins emitting chunks

3. **SSE Stream**: OpenCode server sends chunks
   ```
   data: {"id":"msg_123","content":"I","role":"assistant",...,"is_chunk":true}
   data: {"id":"msg_123","content":" can","role":"assistant",...,"is_chunk":true}
   data: {"id":"msg_123","content":" help","role":"assistant",...,"is_chunk":true}
   data: {"id":"msg_123","content":"!","role":"assistant",...,"is_chunk":false}
   ```

4. **MessageStream** (Rust):
   - Parses each SSE line
   - For chunks: Emits `ChatEvent::MessageChunk { session_id, chunk }`
   - For final message: Emits `ChatEvent::MessageReceived { session_id, message }`

5. **Tauri IPC**: Emits to frontend
   ```
   app_handle.emit('chat-event', ChatEvent::MessageChunk { ... })
   ```

6. **Frontend Listener** (chat-api.ts):
   - Receives event via `listen('chat-event', handler)`
   - Calls `chatStore.actions.handleChatEvent(event)`

7. **Store Update** (chat.ts):
   ```
   if (event.MessageChunk) {
     activeSessionStore.appendToLastMessage(chunk);  // "I"
     activeSessionStore.appendToLastMessage(chunk);  // " can"
     // ... etc
   }
   ```

8. **UI Reactivity** (ChatInterface.svelte):
   - `activeSession` store subscriber detects change
   - Re-renders MessageBubble with updated content
   - Auto-scrolls to show new text

## Testing the Flow

### 1. Verify Backend SSE Connection
```rust
// In message_stream.rs tests
#[test]
fn test_message_stream_creation() { ... }
#[test]
fn test_streaming_state() { ... }
```

### 2. Test Store Updates
```typescript
// Create test events and verify store updates
const event = {
  MessageChunk: { session_id: 'test', chunk: 'Hello' }
};
await chatStore.actions.handleChatEvent(event);
// Assert: activeSessionStore has message with "Hello"
```

### 3. Test UI Rendering
```typescript
// E2E test: Send message and verify response appears
await page.fill('[data-testid="message-input"]', 'Hello');
await page.click('[data-testid="send-button"]');
// Wait for AI response to appear
await page.waitForSelector('[data-testid="ai-message"]', { timeout: 5000 });
```

## Debugging

### Enable Logging

All logging prefixed with module names:
- `[CHAT API]` - Frontend API bridge
- `[TAURI API]` - Tauri IPC
- `[MOCK API]` - Browser/test fallback

### Check SSE Connection
```typescript
// In browser console
// Should see events being emitted
await listen('chat-event', (event) => console.log('Got event:', event));
```

### Monitor Message Stream
```rust
// In lib.rs, check console output
println!("[SSE] Stream started");
println!("[SSE] Received chunk: {}", chunk);
```

## Error Handling

Events with `Error` type are caught and displayed:
```typescript
if (event.Error) {
  chatStateStore.setError(event.Error.message);
  // Shows in error banner above chat
}
```

Common errors:
- "Server URL not set" - Connection not initialized
- "Event stream returned status 404" - OpenCode server not running
- "Stream read error" - Network connectivity issue

## Performance Considerations

1. **Virtual Scrolling**: ChatInterface only renders visible messages
   - Efficient with 100+ message conversations
   - Dynamic height estimation

2. **Streaming Chunks**: `appendToLastMessage()` directly modifies last message
   - Avoids creating new message objects per chunk
   - Single store update per chunk

3. **Event Batching**: No artificial batching needed
   - Svelte reactivity is optimized for small updates
   - Browser can handle 100+ updates/second

4. **Memory**: Sessions cached in localStorage
   - Max 50MB quota for offline storage
   - Automatic cleanup of old messages

## Future Enhancements

- [ ] Search within message history
- [ ] Message threading/reactions
- [ ] Typing indicators from AI
- [ ] Connection quality monitoring (latency)
- [ ] Automatic reconnection UI
- [ ] Message export (Markdown/PDF)
