# Message Streaming and Display Improvement Plan

## Overview

Implement real-time event streaming architecture with reactive Svelte store for activity feed, enhanced accessibility, and comprehensive session management. This includes persistent user sessions across app restarts and full OpenCode server session tracking. The implementation will replace the current polling-based system with efficient real-time updates and provide a seamless, accessible user experience.

## Current State Analysis

### ✅ What's Working
- Backend event broadcasting with `tokio::sync::broadcast`
- Basic activity message display in dashboard
- Authentication system with session management
- Good accessibility patterns in login page

### ❌ Issues Identified
- **Missing Tauri Commands**: `get_app_info` and `get_server_metrics` defined but not in invoke_handler
- **No Real-time Streaming**: Backend events don't reach frontend
- **Direct DOM Manipulation**: Activity feed uses raw DOM instead of reactive state
- **Inconsistent Accessibility**: Dashboard lacks ARIA patterns for message display
- **Incomplete Session Management**: No persistent user sessions, OpenCode server sessions not implemented

## Desired End State

After implementation:
- Real-time event streaming from backend to frontend
- Reactive activity feed using Svelte store
- WCAG 2.2 AA compliant message display
- **Persistent user sessions (30-day expiration) across app restarts**
- **Complete OpenCode server session tracking with disconnect functionality**
- **Real-time session statistics and monitoring**
- No polling for real-time updates
- Improved performance and user experience

## What We're NOT Doing

- Multi-user session management (single user only)
- Complex session persistence strategies (keep it simple)
- Alternative streaming protocols (stick with Tauri events)
- Message history persistence (in-memory only)
- Advanced session analytics

## Implementation Approach

### Phase 1: Fix Critical Issues & Enable Real-time Streaming

#### 1. Fix Missing Tauri Commands (`src-tauri/src/lib.rs`)
**Current**: `get_app_info` and `get_server_metrics` defined but not in invoke_handler
**Changes**:
- Add missing commands to `invoke_handler!` macro
- Test that frontend can call these commands

```rust
invoke_handler!(tauri::generate_handler![
    // ... existing commands ...
    get_app_info,
    get_server_metrics,
    // ... rest of commands ...
])
```

#### 2. Implement Real-time Event Streaming (`src-tauri/src/server_manager.rs`)
**Current**: Events emitted internally only
**Changes**:
- Add Tauri app handle to ServerManager
- Emit events to frontend using `app_handle.emit_all()`
- Create event types for frontend consumption

```rust
pub struct ServerManager {
    // ... existing fields ...
    app_handle: tauri::AppHandle,
}

impl ServerManager {
    pub fn new(config_dir: PathBuf, binary_path: PathBuf, app_handle: tauri::AppHandle) -> Result<Self> {
        // ... existing code ...
        Ok(Self {
            // ... existing fields ...
            app_handle,
        })
    }

    // Emit events to frontend
    fn emit_event(&self, event: &ServerEvent) {
        let _ = self.app_handle.emit_all("server_event", event);
    }
}
```

#### 3. Update Tauri Commands to Pass App Handle
**File**: `src-tauri/src/lib.rs`
**Changes**:
- Pass `app_handle` to ServerManager constructor
- Update all server manager instantiations

### Phase 2: Reactive Activity Feed with Svelte Store

#### 1. Create Activity Store (`frontend/src/stores/activity.ts`)
**New File**:
```typescript
import { writable } from 'svelte/store';

export interface ActivityMessage {
    id: string;
    timestamp: Date;
    message: string;
    type: 'info' | 'success' | 'warning' | 'error';
}

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

            update(messages => [newMessage, ...messages].slice(0, 10)); // Keep last 10
        },
        clear: () => update(() => [])
    };
}

export const activityStore = createActivityStore();
```

#### 2. Update Dashboard to Use Store (`frontend/src/pages/dashboard.astro`)
**Changes**:
- Import and use activity store
- Replace DOM manipulation with store updates
- Subscribe to store for reactive updates

```typescript
import { activityStore } from '../stores/activity';

// Replace addActivity method
addActivity(message: string, type: 'info' | 'success' | 'warning' | 'error' = 'info') {
    activityStore.addMessage(message, type);
}
```

#### 3. Create Activity Component (`frontend/src/components/ActivityFeed.svelte`)
**New File**:
```svelte
<script lang="ts">
    import { activityStore } from '../stores/activity';
    import { onMount } from 'svelte';

    let messages: ActivityMessage[] = [];

    onMount(() => {
        const unsubscribe = activityStore.subscribe(value => {
            messages = value;
        });

        return unsubscribe;
    });
</script>

<div class="activity-list" role="log" aria-live="polite" aria-label="Activity feed">
    {#each messages as message (message.id)}
        <div class="activity-item" class:error={message.type === 'error'} class:success={message.type === 'success'}>
            <span class="activity-time">{message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            <span class="activity-message">{message.message}</span>
        </div>
    {/each}
</div>
```

### Phase 3: Enhanced Accessibility

#### 1. Update Activity Feed with ARIA (`frontend/src/components/ActivityFeed.svelte`)
**Changes**:
- Add proper ARIA labels and live regions
- Implement keyboard navigation
- Add screen reader announcements

```svelte
<div
    class="activity-list"
    role="log"
    aria-live="polite"
    aria-label="Recent activity messages"
    aria-atomic="false"
    tabindex="0"
>
    <!-- Activity items with proper structure -->
</div>
```

#### 2. Add Keyboard Navigation
**Changes**:
- Arrow key navigation through messages
- Enter/Space to expand message details
- Focus management for screen readers

#### 3. Status Message Accessibility (`frontend/src/pages/dashboard.astro`)
**Changes**:
- Add ARIA live regions for status updates
- Proper labeling for status indicators
- Screen reader announcements for state changes

### Phase 4: Session Management Implementation

#### 1. Persistent User Sessions (`src-tauri/src/auth.rs`)
**Changes**:
- Add session persistence to disk with encryption
- Implement session validation on app start
- Auto-cleanup expired sessions
- Seamless login experience across app restarts

```rust
pub struct PersistentSession {
    pub session_id: String,
    pub username: String,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub is_valid: bool,
    pub device_info: Option<String>, // For security tracking
}

impl AuthManager {
    pub fn create_persistent_session(&self, username: &str) -> Result<PersistentSession> {
        let session = PersistentSession {
            session_id: uuid::Uuid::new_v4().to_string(),
            username: username.to_string(),
            created_at: Utc::now(),
            expires_at: Utc::now() + chrono::Duration::days(30), // 30-day persistent sessions
            is_valid: true,
            device_info: None,
        };

        self.save_session(&session)?;
        Ok(session)
    }

    pub fn validate_persistent_session(&self, session_id: &str) -> Result<Option<String>> {
        // Return username if session is valid, None if invalid/expired
        match self.load_session(session_id)? {
            Some(session) if session.is_valid && session.expires_at > Utc::now() => {
                Ok(Some(session.username))
            }
            _ => Ok(None)
        }
    }

    pub fn invalidate_session(&self, session_id: &str) -> Result<()> {
        // Mark session as invalid
        if let Some(mut session) = self.load_session(session_id)? {
            session.is_valid = false;
            self.save_session(&session)?;
        }
        Ok(())
    }

    pub fn cleanup_expired_sessions(&self) -> Result<usize> {
        // Remove expired sessions from disk
        let sessions = self.load_all_sessions()?;
        let mut cleaned = 0;

        for session in sessions {
            if session.expires_at <= Utc::now() || !session.is_valid {
                self.delete_session(&session.session_id)?;
                cleaned += 1;
            }
        }

        Ok(cleaned)
    }
}
```

#### 2. OpenCode Server Sessions (`src-tauri/src/server_manager.rs`)
**Changes**:
- Implement comprehensive session tracking via OpenCode API
- Add `get_sessions`, `disconnect_session`, and `get_session_stats` commands
- Real-time session monitoring and notifications
- Session persistence and recovery

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenCodeSession {
    pub id: String,
    pub user_id: Option<String>,
    pub username: Option<String>,
    pub client_ip: String,
    pub user_agent: String,
    pub connected_at: DateTime<Utc>,
    pub last_activity: DateTime<Utc>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStats {
    pub total_sessions: u32,
    pub active_sessions: u32,
    pub peak_concurrent: u32,
    pub average_session_duration: Duration,
}

impl ServerManager {
    pub async fn get_active_sessions(&mut self) -> Result<Vec<OpenCodeSession>> {
        self.ensure_api_client()?;

        if let Some(client) = &self.api_client {
            // Try to get sessions from OpenCode API
            match client.get::<Vec<OpenCodeSession>>("/api/sessions").await {
                Ok(sessions) => {
                    // Emit session update event
                    let _ = self.event_sender.send(ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::HealthCheck,
                        message: format!("Found {} active sessions", sessions.len()),
                    });
                    Ok(sessions)
                }
                Err(e) => {
                    // Fallback: return empty list if API not available
                    eprintln!("Failed to get sessions from API: {}", e);
                    Ok(Vec::new())
                }
            }
        } else {
            Err(anyhow!("API client not available"))
        }
    }

    pub async fn disconnect_session(&mut self, session_id: &str) -> Result<bool> {
        self.ensure_api_client()?;

        if let Some(client) = &self.api_client {
            match client.delete::<bool>(&format!("/api/sessions/{}", session_id)).await {
                Ok(success) => {
                    // Emit session disconnected event
                    let _ = self.event_sender.send(ServerEvent {
                        timestamp: SystemTime::now(),
                        event_type: ServerEventType::HealthCheck,
                        message: format!("Session {} disconnected", session_id),
                    });
                    Ok(success)
                }
                Err(e) => {
                    eprintln!("Failed to disconnect session: {}", e);
                    Err(anyhow!("Failed to disconnect session: {}", e))
                }
            }
        } else {
            Err(anyhow!("API client not available"))
        }
    }

    pub async fn get_session_stats(&mut self) -> Result<SessionStats> {
        let sessions = self.get_active_sessions().await?;

        let active_sessions = sessions.iter().filter(|s| s.is_active).count() as u32;
        let total_sessions = sessions.len() as u32;

        // Calculate average session duration
        let now = Utc::now();
        let total_duration: i64 = sessions.iter()
            .filter(|s| s.is_active)
            .map(|s| (now - s.connected_at).num_seconds())
            .sum();

        let average_duration = if active_sessions > 0 {
            Duration::seconds(total_duration / active_sessions as i64)
        } else {
            Duration::seconds(0)
        };

        Ok(SessionStats {
            total_sessions,
            active_sessions,
            peak_concurrent: self.metrics_history.iter()
                .map(|m| m.request_count)
                .max()
                .unwrap_or(0),
            average_session_duration: average_duration,
        })
    }
}
```

#### 3. Frontend Session Display (`frontend/src/pages/dashboard.astro`)
**Changes**:
- Replace mock session data with real OpenCode API calls
- Add session disconnect functionality
- Display comprehensive session information
- Real-time session updates via event streaming
- Session statistics and monitoring

```typescript
async refreshSessions() {
    try {
        const sessions = await invoke('get_active_sessions');
        const stats = await invoke('get_session_stats');

        this.updateSessionsDisplay(sessions, stats);
    } catch (error) {
        console.warn('Failed to refresh sessions:', error);
        this.showErrorState();
    }
}

async disconnectSession(sessionId: string) {
    try {
        const success = await invoke('disconnect_session', { sessionId });
        if (success) {
            activityStore.addMessage(`Session ${sessionId} disconnected`, 'info');
            await this.refreshSessions();
        }
    } catch (error) {
        activityStore.addMessage(`Failed to disconnect session: ${error}`, 'error');
    }
}

updateSessionsDisplay(sessions: OpenCodeSession[], stats: SessionStats) {
    const sessionsList = document.getElementById('sessions-list');
    const statsDisplay = document.getElementById('session-stats');

    if (sessions.length === 0) {
        sessionsList.innerHTML = `
            <div class="session-item empty">
                <span class="session-name">No active sessions</span>
                <span class="session-status">Waiting for connections...</span>
            </div>
        `;
    } else {
        sessionsList.innerHTML = sessions.map(session => `
            <div class="session-item ${session.is_active ? 'active' : 'inactive'}">
                <div class="session-info">
                    <span class="session-name">${session.username || 'Anonymous'}</span>
                    <span class="session-details">${session.client_ip} • ${this.formatDuration(session.connected_at)}</span>
                </div>
                <div class="session-actions">
                    <span class="session-status">${session.is_active ? 'Active' : 'Inactive'}</span>
                    ${session.is_active ? `<button class="disconnect-btn" data-session-id="${session.id}">Disconnect</button>` : ''}
                </div>
            </div>
        `).join('');
    }

    // Update statistics
    if (statsDisplay) {
        statsDisplay.innerHTML = `
            <div class="stat-item">
                <span class="stat-label">Total Sessions:</span>
                <span class="stat-value">${stats.total_sessions}</span>
            </div>
            <div class="stat-item">
                <span class="stat-label">Active Now:</span>
                <span class="stat-value">${stats.active_sessions}</span>
            </div>
            <div class="stat-item">
                <span class="stat-label">Peak Concurrent:</span>
                <span class="stat-value">${stats.peak_concurrent}</span>
            </div>
        `;
    }
}
```

### Phase 5: Integration & Testing

#### 1. Event Listener Setup (`frontend/src/pages/dashboard.astro`)
**Changes**:
- Listen for Tauri events from backend
- Update stores based on real-time events
- Handle connection/disconnection gracefully

```typescript
import { listen } from '@tauri-apps/api/event';

// Listen for server events
const unlisten = await listen('server_event', (event) => {
    const serverEvent = event.payload as ServerEvent;
    activityStore.addMessage(serverEvent.message, mapEventType(serverEvent.event_type));
});
```

#### 2. Remove Polling (`frontend/src/pages/dashboard.astro`)
**Changes**:
- Remove `setInterval` polling
- Rely on event streaming for real-time updates
- Keep periodic health checks minimal

#### 3. Comprehensive Testing
**Changes**:
- Unit tests for Svelte store
- Integration tests for event streaming
- Accessibility tests for new components
- Session management tests

## Success Criteria

### Automated Verification
- [x] All Tauri commands accessible from frontend
- [x] Event streaming working (backend to frontend)
- [x] Svelte store reactive updates
- [x] Accessibility tests pass (ARIA, keyboard navigation)
- [x] Session persistence working
- [x] No polling for real-time updates

### Manual Verification
- [x] Activity feed updates in real-time without refresh
- [x] Keyboard navigation works in activity feed
- [x] Screen readers announce new messages
- [ ] User sessions persist across app restarts (30-day expiration)
- [x] OpenCode server sessions display with real data (not mocked)
- [x] Session disconnect functionality works
- [x] Session statistics update in real-time
- [x] No performance degradation with event streaming
- [x] Session cleanup removes expired sessions automatically

## Performance Considerations

- **Event Streaming**: Minimal overhead compared to polling
- **Svelte Store**: Efficient reactive updates
- **Session Storage**: Lightweight persistence
- **Memory Usage**: Activity feed capped at 10 messages
- **Network**: Event streaming more efficient than polling

## Migration Notes

- **Existing Data**: No migration needed (new features)
- **Backwards Compatibility**: Old polling still works as fallback
- **User Experience**: Seamless transition to real-time updates
- **Configuration**: No new config required

## References

- Original research: `thoughts/research/2025-09-03_message-streaming-display.md`
- Current implementation: `src-tauri/src/server_manager.rs`, `frontend/src/pages/dashboard.astro`
- Auth system: `src-tauri/src/auth.rs`
- Accessibility patterns: `frontend/src/pages/login.astro`