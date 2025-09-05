# Event Loss Handling, Fallback Strategies, and Payload Standardization Implementation Plan

## Overview

Implement robust event loss handling, graceful fallback strategies, and standardized event payloads for OpenCode Nexus's real-time event system. This plan addresses the three open questions from the initial research by adding backend event buffering with persistence, frontend fallback detection with silent polling, and discriminated union payloads with versioning and automated type generation.

## Current State Analysis

### ✅ What's Working
- **Event Streaming**: Backend uses `tokio::sync::broadcast` with 100-event buffer, frontend listens via `@tauri-apps/api/event.listen`
- **Basic Payload Structure**: `ServerEvent` struct with `ServerEventType` enum, Serde serialization
- **Fallback Patterns**: API fallbacks to stubbed data, user notifications via `addActivity()` and screen reader announcements
- **Persistence Infrastructure**: Session persistence pattern exists in `auth.rs` using JSON file storage
- **Buffer Management**: Frontend keeps last 10 messages, backend has 100-event buffer

### ❌ Issues Identified
- **No Event Persistence**: Critical events (errors, server stops) are not persisted for guaranteed delivery
- **No Fallback Detection**: No heartbeat mechanism to detect Tauri event system failures
- **No Versioning**: Event payloads lack version fields for backwards compatibility
- **No Type Generation**: No automated Rust→TypeScript type synchronization
- **Hardcoded Buffers**: No configuration for buffer sizes (frontend: 10, backend: 100)

## Desired End State

After implementation:
- **Event Loss Prevention**: Critical events persisted to disk with guaranteed delivery
- **Graceful Degradation**: Silent fallback to polling when event system fails, user notification only for critical issues
- **Type Safety**: Automated Rust→TypeScript type generation with discriminated unions and versioning
- **Configurable Buffers**: User-configurable buffer sizes with sensible defaults
- **Robust Recovery**: Automatic reconnection with exponential backoff and state synchronization

### Verification Criteria
- Critical events (errors, server stops) persist across app restarts
- Event system failures trigger silent polling fallback
- TypeScript types automatically generated from Rust definitions
- Buffer sizes configurable via settings
- No user disruption during event system failures

## What We're NOT Doing

- **Full Event History**: Only critical events persisted, not all events
- **Complex Recovery**: Simple reconnection logic, not complex state synchronization
- **Multiple Type Generators**: Single tool selection, not multiple options
- **Event Compression**: No compression for persisted events
- **Advanced Analytics**: Basic event logging, no detailed analytics

## Implementation Approach

### Guiding Principles
- **Silent Fallbacks**: Event system failures should be transparent to users unless critical
- **Minimal Persistence**: Only persist what's necessary for critical functionality
- **Type Safety First**: Automated type generation to prevent runtime errors
- **Configurable but Sensible**: Allow customization but provide good defaults
- **Incremental Implementation**: Each feature can be implemented and tested independently

---

## Phase 1: Event Loss Handling & Persistence

### Overview
Implement backend event buffering with persistence for critical events, following the existing session persistence pattern.

### Changes Required

#### 1. Event Buffer with Persistence (`src-tauri/src/server_manager.rs`)
**Current**: Basic broadcast channel with 100-event buffer
**Changes**:
- Add `EventBuffer` struct with ring buffer and critical event persistence
- Persist critical events (Error, Stopped) to JSON file
- Load persisted events on startup for guaranteed delivery

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersistedEvent {
    pub id: String,
    pub event: ServerEvent,
    pub persisted_at: SystemTime,
}

pub struct EventBuffer {
    buffer: VecDeque<ServerEvent>,
    critical_events: HashMap<String, PersistedEvent>,
    max_size: usize,
    config_dir: PathBuf,
}

impl EventBuffer {
    pub fn new(config_dir: PathBuf, max_size: usize) -> Result<Self> {
        let mut buffer = Self {
            buffer: VecDeque::new(),
            critical_events: HashMap::new(),
            max_size,
            config_dir,
        };
        buffer.load_persisted_events()?;
        Ok(buffer)
    }

    pub fn add_event(&mut self, event: ServerEvent) -> Result<()> {
        // Add to ring buffer
        self.buffer.push_back(event.clone());
        if self.buffer.len() > self.max_size {
            self.buffer.pop_front();
        }

        // Persist critical events
        if matches!(event.event_type, ServerEventType::Error | ServerEventType::Stopped) {
            let persisted = PersistedEvent {
                id: uuid::Uuid::new_v4().to_string(),
                event,
                persisted_at: SystemTime::now(),
            };
            self.critical_events.insert(persisted.id.clone(), persisted);
            self.save_persisted_events()?;
        }

        Ok(())
    }

    pub fn get_critical_events(&self) -> Vec<&PersistedEvent> {
        self.critical_events.values().collect()
    }

    pub fn clear_delivered_events(&mut self, event_ids: &[String]) -> Result<()> {
        for id in event_ids {
            self.critical_events.remove(id);
        }
        self.save_persisted_events()
    }

    fn load_persisted_events(&mut self) -> Result<()> {
        let path = self.config_dir.join("critical_events.json");
        if !path.exists() {
            return Ok(());
        }

        let data = std::fs::read_to_string(&path)?;
        let events: Vec<PersistedEvent> = serde_json::from_str(&data)?;
        for event in events {
            self.critical_events.insert(event.id.clone(), event);
        }
        Ok(())
    }

    fn save_persisted_events(&self) -> Result<()> {
        let events: Vec<&PersistedEvent> = self.critical_events.values().collect();
        let data = serde_json::to_string_pretty(&events)?;
        let path = self.config_dir.join("critical_events.json");
        std::fs::write(&path, data)?;
        Ok(())
    }
}
```

#### 2. Update ServerManager to Use EventBuffer
**Changes**:
- Replace basic broadcast channel with EventBuffer
- Add methods for critical event management
- Update event emission to use buffer

```rust
pub struct ServerManager {
    // ... existing fields ...
    event_buffer: EventBuffer,
    event_sender: broadcast::Sender<ServerEvent>,
}

impl ServerManager {
    pub fn new(config_dir: PathBuf, binary_path: PathBuf, app_handle: Option<tauri::AppHandle>) -> Result<Self> {
        // ... existing code ...
        let event_buffer = EventBuffer::new(config_dir.clone(), 100)?;
        let (event_sender, _) = broadcast::channel(100);

        Ok(Self {
            // ... existing fields ...
            event_buffer,
            event_sender,
        })
    }

    pub fn emit_event(&mut self, event: ServerEvent) -> Result<()> {
        // Add to buffer (handles persistence)
        self.event_buffer.add_event(event.clone())?;

        // Send to broadcast channel
        let _ = self.event_sender.send(event.clone());

        // Emit to frontend
        if let Some(app_handle) = &self.app_handle {
            let _ = app_handle.emit("server_event", event);
        }

        Ok(())
    }

    pub fn get_critical_events(&self) -> Vec<ServerEvent> {
        self.event_buffer.get_critical_events()
            .into_iter()
            .map(|pe| pe.event.clone())
            .collect()
    }

    pub fn clear_delivered_critical_events(&mut self, event_ids: &[String]) -> Result<()> {
        self.event_buffer.clear_delivered_events(event_ids)
    }
}
```

#### 3. Frontend Critical Event Delivery (`frontend/src/pages/dashboard.astro`)
**Changes**:
- Request critical events on startup
- Mark events as delivered after processing
- Handle missed critical events

```typescript
async loadCriticalEvents() {
    try {
        const criticalEvents = await invoke('get_critical_events');
        for (const event of criticalEvents) {
            this.handleServerEvent(event);
        }

        // Mark as delivered
        const eventIds = criticalEvents.map(e => e.id);
        if (eventIds.length > 0) {
            await invoke('clear_delivered_critical_events', { eventIds });
        }
    } catch (error) {
        console.warn('Failed to load critical events:', error);
    }
}
```

### Success Criteria

#### Automated Verification
- [ ] Critical events (Error, Stopped) persist to `critical_events.json`
- [ ] Persisted events load on app restart
- [ ] Frontend receives critical events on startup
- [ ] Delivered events are cleared from persistence
- [ ] Buffer size configurable via constructor parameter

#### Manual Verification
- [ ] Server errors persist across app restarts
- [ ] Stop events are guaranteed to be delivered
- [ ] No duplicate critical events after restart
- [ ] File size remains reasonable with event accumulation

---

## Phase 2: Fallback Strategies & Heartbeat Detection

### Overview
Implement heartbeat detection and silent polling fallback when the Tauri event system fails.

### Changes Required

#### 1. Event System Health Monitoring (`frontend/src/pages/dashboard.astro`)
**Current**: Basic event listening without failure detection
**Changes**:
- Add heartbeat mechanism with ping/pong events
- Detect event system failures
- Implement silent polling fallback
- User notification only for critical issues

```typescript
class EventManager {
    private eventSystemHealthy = true;
    private lastHeartbeat = Date.now();
    private heartbeatInterval: number;
    private reconnectAttempts = 0;
    private maxReconnectAttempts = 5;

    constructor() {
        this.startHeartbeat();
    }

    private startHeartbeat() {
        // Send heartbeat every 30 seconds
        this.heartbeatInterval = setInterval(async () => {
            try {
                await this.sendHeartbeat();
            } catch (error) {
                console.warn('Heartbeat failed:', error);
                this.handleEventSystemFailure();
            }
        }, 30000);
    }

    private async sendHeartbeat() {
        const pingId = crypto.randomUUID();
        const timeout = 5000; // 5 second timeout

        return new Promise<void>((resolve, reject) => {
            const timeoutId = setTimeout(() => {
                reject(new Error('Heartbeat timeout'));
            }, timeout);

            // Listen for pong response
            const unlisten = listen('pong', (event) => {
                if (event.payload.id === pingId) {
                    clearTimeout(timeoutId);
                    unlisten();
                    this.lastHeartbeat = Date.now();
                    resolve();
                }
            });

            // Send ping
            invoke('send_ping', { id: pingId }).catch(reject);
        });
    }

    private handleEventSystemFailure() {
        if (this.eventSystemHealthy) {
            this.eventSystemHealthy = false;
            console.log('Event system failure detected, switching to polling fallback');

            // Start polling fallback (silent)
            this.startPollingFallback();

            // Attempt recovery
            this.attemptReconnection();
        }
    }

    private startPollingFallback() {
        // Increase polling frequency for critical updates
        setInterval(async () => {
            if (!this.eventSystemHealthy) {
                await this.updateAppInfo();
                await this.refreshSessions();
            }
        }, 10000); // 10 seconds instead of 30
    }

    private async attemptReconnection() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            // Only notify user after multiple failures
            this.addActivity('Real-time updates unavailable. Using periodic updates.', 'warning');
            return;
        }

        this.reconnectAttempts++;
        const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);

        setTimeout(async () => {
            try {
                await this.testEventSystem();
                this.eventSystemHealthy = true;
                this.reconnectAttempts = 0;
                this.addActivity('Real-time updates restored!', 'success');
                await this.syncMissedState();
            } catch (error) {
                this.attemptReconnection();
            }
        }, delay);
    }

    private async testEventSystem(): Promise<void> {
        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => reject(new Error('Test timeout')), 5000);

            const unlisten = listen('test_response', () => {
                clearTimeout(timeout);
                unlisten();
                resolve();
            });

            invoke('send_test_event').catch(reject);
        });
    }

    private async syncMissedState() {
        // Sync any missed state after reconnection
        await this.updateAppInfo();
        await this.refreshSessions();
        await this.loadCriticalEvents();
    }
}
```

#### 2. Backend Heartbeat Support (`src-tauri/src/server_manager.rs`)
**Changes**:
- Add ping/pong command handlers
- Add test event command for connection testing

```rust
#[tauri::command]
async fn send_ping(id: String, state: State<'_, AppState>) -> Result<(), String> {
    let mut server_manager = state.server_manager.lock().unwrap();

    // Send pong response
    if let Some(app_handle) = &server_manager.app_handle {
        let _ = app_handle.emit("pong", serde_json::json!({ "id": id }));
    }

    Ok(())
}

#[tauri::command]
async fn send_test_event(state: State<'_, AppState>) -> Result<(), String> {
    let mut server_manager = state.server_manager.lock().unwrap();

    // Send test response
    if let Some(app_handle) = &server_manager.app_handle {
        let _ = app_handle.emit("test_response", serde_json::json!({}));
    }

    Ok(())
}
```

### Success Criteria

#### Automated Verification
- [ ] Heartbeat ping/pong works correctly
- [ ] Event system failure detection triggers polling fallback
- [ ] Reconnection attempts use exponential backoff
- [ ] Silent operation (no user notification for routine failures)
- [ ] State synchronization after reconnection

#### Manual Verification
- [ ] Event system failures don't disrupt user experience
- [ ] Polling fallback provides adequate updates
- [ ] User notified only after multiple reconnection failures
- [ ] Real-time updates resume automatically when connection restored
- [ ] No duplicate events during reconnection

---

## Phase 3: Payload Standardization & Type Generation

### Overview
Implement discriminated unions with versioning and automated Rust→TypeScript type generation using `typeshare`.

### Changes Required

#### 1. Standardized Event Payloads (`src-tauri/src/server_manager.rs`)
**Current**: Basic `ServerEvent` struct
**Changes**:
- Convert to discriminated union with versioning
- Add version field to all payloads
- Support multiple versions for backwards compatibility

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum StandardizedEvent {
    #[serde(rename = "server_status")]
    ServerStatus {
        version: u8,
        status: ServerStatus,
        timestamp: SystemTime,
        message: String,
    },

    #[serde(rename = "activity_message")]
    ActivityMessage {
        version: u8,
        level: ActivityLevel,
        message: String,
        timestamp: SystemTime,
    },

    #[serde(rename = "session_update")]
    SessionUpdate {
        version: u8,
        session_id: String,
        action: SessionAction,
        timestamp: SystemTime,
    },

    #[serde(rename = "error_event")]
    ErrorEvent {
        version: u8,
        error_type: ErrorType,
        message: String,
        details: Option<String>,
        timestamp: SystemTime,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[typeshare]
pub struct EventEnvelope {
    pub id: String,
    pub timestamp: SystemTime,
    pub event: StandardizedEvent,
}
```

#### 2. Type Generation Setup
**Changes**:
- Add `typeshare` dependency to Cargo.toml
- Configure build script for TypeScript generation
- Generate types automatically during build

```toml
# Cargo.toml
[dependencies]
typeshare = "1.0"

[build-dependencies]
typeshare = "1.0"
```

```rust
// build.rs
fn main() {
    typeshare::generate_typeshare_types(
        &["src/server_manager.rs"],
        "typescript",
        Some("frontend/src/types/generated.ts"),
    ).unwrap();
}
```

#### 3. Frontend Type Integration (`frontend/src/stores/activity.ts`)
**Changes**:
- Import generated types
- Update store to use standardized payloads
- Add version handling for backwards compatibility

```typescript
// frontend/src/types/generated.ts (auto-generated)
export type StandardizedEvent =
  | { type: "server_status"; payload: { version: number; status: ServerStatus; timestamp: string; message: string } }
  | { type: "activity_message"; payload: { version: number; level: ActivityLevel; message: string; timestamp: string } }
  | { type: "session_update"; payload: { version: number; session_id: string; action: SessionAction; timestamp: string } }
  | { type: "error_event"; payload: { version: number; error_type: ErrorType; message: string; details?: string; timestamp: string } };

export interface EventEnvelope {
  id: string;
  timestamp: string;
  event: StandardizedEvent;
}

// frontend/src/stores/activity.ts
import type { StandardizedEvent, EventEnvelope } from '../types/generated';

function createActivityStore() {
    const { subscribe, update } = writable<ActivityMessage[]>([]);

    return {
        subscribe,
        addMessage: (message: string, type: ActivityMessage['type'] = 'info') => {
            const newMessage: ActivityMessage = {
                id: crypto.randomUUID(),
                timestamp: new Date(),
                message,
                type
            };

            update(messages => [newMessage, ...messages].slice(0, 10));
        },

        handleStandardizedEvent: (envelope: EventEnvelope) => {
            // Handle version compatibility
            if (envelope.event.payload.version > 1) {
                console.warn(`Unsupported event version: ${envelope.event.payload.version}`);
                return;
            }

            // Convert to activity message based on event type
            const activityMessage = convertToActivityMessage(envelope);
            if (activityMessage) {
                this.addMessage(activityMessage.message, activityMessage.type);
            }
        },

        clear: () => update(() => [])
    };
}
```

### Success Criteria

#### Automated Verification
- [ ] TypeScript types auto-generated from Rust definitions
- [ ] Discriminated unions work correctly with serde
- [ ] Version field included in all event payloads
- [ ] Backwards compatibility maintained for version 1
- [ ] Build process includes type generation

#### Manual Verification
- [ ] TypeScript compilation succeeds with generated types
- [ ] Event payloads properly typed in frontend
- [ ] Version handling works for future event changes
- [ ] No runtime type errors with standardized payloads
- [ ] IDE provides proper autocomplete for event types

---

## Phase 4: Configuration & Testing

### Overview
Add configurable buffer sizes and comprehensive testing for all new features.

### Changes Required

#### 1. Configurable Buffer Sizes
**Changes**:
- Add buffer size configuration to settings
- Update constructors to accept configuration
- Provide sensible defaults

#### 2. Comprehensive Testing
**Changes**:
- Unit tests for event persistence
- Integration tests for fallback mechanisms
- Type generation verification tests
- Performance tests for buffer operations

### Success Criteria

#### Automated Verification
- [ ] Buffer sizes configurable via settings
- [ ] All new features have unit test coverage
- [ ] Integration tests verify end-to-end functionality
- [ ] Performance tests ensure no degradation
- [ ] Type generation tests verify output correctness

#### Manual Verification
- [ ] Configuration UI allows buffer size adjustment
- [ ] Settings persist across app restarts
- [ ] All features work with custom buffer sizes
- [ ] Performance remains acceptable with larger buffers

---

## Performance Considerations

### Backend Performance
- **Event Persistence**: JSON serialization is fast, file I/O is minimal for critical events only
- **Buffer Management**: Ring buffer operations are O(1), no performance impact
- **Type Generation**: Build-time only, no runtime performance impact

### Frontend Performance
- **Heartbeat**: Lightweight ping/pong every 30 seconds, minimal network overhead
- **Fallback Polling**: Only active during failures, 10-second intervals are reasonable
- **Type Safety**: Compile-time type checking, no runtime performance cost

---

## Migration Notes

### Configuration Migration
- **Buffer Sizes**: New settings with defaults (frontend: 10, backend: 100)
- **Event Persistence**: New JSON file created automatically
- **Type Generation**: Build process updated, no user action required

### Backwards Compatibility
- **Existing Events**: Converted to new format during migration
- **Old Payloads**: Version 1 support ensures compatibility
- **Fallback Behavior**: Graceful degradation for older versions

---

## References

- Original research: `thoughts/research/2025-09-03_server-sent-events-tauri-svelte-activity-feed-followup.md`
- Current implementation: `src-tauri/src/server_manager.rs`, `frontend/src/stores/activity.ts`
- Persistence pattern: `src-tauri/src/auth.rs` (session persistence)
- Type generation: `typeshare` documentation
- Fallback patterns: `frontend/src/pages/dashboard.astro` (existing error handling)

---

**Implementation Priority**: Phase 1 (Event Persistence) → Phase 2 (Fallback) → Phase 3 (Type Generation) → Phase 4 (Configuration)
**Estimated Timeline**: 2-3 weeks total
**Risk Level**: Low (incremental changes, comprehensive testing)
**Dependencies**: `typeshare` for type generation, existing JSON persistence infrastructure</content>
</xai:function_call name="todowrite">
<parameter name="todos">[{"content":"Create detailed implementation plan for event loss handling, fallback strategies, and payload standardization","status":"completed","priority":"high","id":"create_implementation_plan"}]