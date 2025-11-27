# SDK Integration Migration Guide

**Date**: November 27, 2025
**Status**: In Progress
**Component**: Frontend chat API refactoring to use @opencode-ai/sdk

## Overview

This document describes the migration of the OpenCode Nexus frontend from manual Rust HTTP client implementation to using the official `@opencode-ai/sdk` TypeScript package.

## What Changed

### Frontend (TypeScript/Astro)

#### New Files Created
1. **`frontend/src/lib/opencode-client.ts`**
   - `OpencodeClientManager` class wrapping the SDK client
   - Manages SDK client lifecycle (connect/disconnect)
   - Persists connection to Tauri backend storage
   - Auto-reconnect support

2. **`frontend/src/lib/stores/connection.ts`**
   - Svelte store for connection state management
   - Tracks connection status, current server, errors
   - Derived stores for status and health monitoring

3. **`frontend/src/lib/sdk-api.ts`**
   - High-level API functions using the SDK
   - Type-safe session management
   - Event subscription support
   - Available models fetching

#### Modified Files
1. **`frontend/src/utils/chat-api.ts`**
   - Updated all functions to use SDK instead of Tauri IPC
   - Added `initializeSdkConnection` for automatic reconnection
   - Event listener now uses SDK SSE instead of Tauri events
   - Backward compatible with existing chat store

### Backend (Rust)

#### New Commands
1. **`save_connection`** - Persist a connection to storage
   - Takes: `ServerConnection`
   - Returns: `Result<(), String>`

2. **`get_last_used_connection`** - Retrieve last used server
   - Takes: None
   - Returns: `Result<Option<ServerConnection>, String>`

#### Modified Files
1. **`src-tauri/src/connection_manager.rs`**
   - Added `save_connection()` method for persisting connections

2. **`src-tauri/src/lib.rs`**
   - Added `save_connection` and `get_last_used_connection` Tauri commands
   - Registered commands in handler

## Migration Path

### Phase 1: Foundation (✅ Completed)
- [x] Create SDK client wrapper
- [x] Create connection state store
- [x] Add Tauri persistence commands
- [x] Create SDK API functions

### Phase 2: API Adaptation (✅ Completed)
- [x] Update chat-api.ts to use SDK
- [x] Implement SDK connection initialization
- [x] Add event subscription adapter

### Phase 3: Testing (⏳ In Progress)
- [ ] Unit tests for SDK client wrapper
- [ ] Integration tests for chat API
- [ ] E2E tests for chat flow
- [ ] Connection persistence tests

### Phase 4: Cleanup (⏳ Pending)
- [ ] Remove `api_client.rs` (Rust HTTP client)
- [ ] Remove `message_stream.rs` (SSE parsing)
- [ ] Simplify `chat_client.rs` or remove if unused
- [ ] Update Rust dependencies

## Key Benefits

### Code Reduction
- Eliminates ~1,700 lines of manual HTTP/SSE handling
- Reduces maintenance burden
- Automatic SDK updates bring new features

### Type Safety
- SDK provides auto-generated TypeScript types
- Full IDE support and autocomplete
- No manual JSON parsing

### Reliability
- Official SDK is battle-tested
- Automatic error handling
- Built-in retry logic

### Developer Experience
- Cleaner code patterns
- Better debugging support
- Comprehensive SDK documentation

## Breaking Changes

⚠️ **None for users** - The chat interface remains unchanged

Internal API changes:
- Chat operations now route through SDK instead of Tauri backend
- Event format may differ slightly (transparent mapping)
- Connection management moved to frontend

## Testing Checklist

### Before Deployment
- [ ] Frontend unit tests pass
- [ ] E2E chat tests pass
- [ ] Connection persistence works
- [ ] Event streaming works
- [ ] Offline storage still functions
- [ ] No memory leaks in SDK client
- [ ] Performance metrics acceptable

### Manual Testing
1. **Connection Flow**
   - [ ] Create new connection
   - [ ] Save connection persists
   - [ ] Restore connection on app start
   - [ ] Handle connection errors

2. **Chat Flow**
   - [ ] Load sessions list
   - [ ] Create new session
   - [ ] Send message
   - [ ] Receive streaming response
   - [ ] Delete session

3. **Event Handling**
   - [ ] Real-time message updates
   - [ ] Session creation events
   - [ ] Error events
   - [ ] Connection state changes

## Rollback Plan

If issues arise:

1. Revert SDK API changes in chat-api.ts back to Tauri commands
2. Keep new Tauri commands (they're backward compatible)
3. Revert connection_manager.rs changes
4. Delete new SDK wrapper files if needed

## Future Improvements

1. **Offline Support**
   - Cache SDK responses in IndexedDB
   - Queue messages during offline periods
   - Auto-sync on reconnection

2. **Performance**
   - Lazy load SDK only when needed
   - Connection pooling
   - Request deduplication

3. **SDK Features**
   - File upload/download support
   - Context window management
   - Custom model parameters

## Questions & Support

For issues during migration, refer to:
- `docs/client/ARCHITECTURE.md` - System architecture
- `docs/client/TESTING.md` - TDD approach
- `@opencode-ai/sdk` official docs

