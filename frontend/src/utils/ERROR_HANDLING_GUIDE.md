# Error Handling & User Feedback Guide

This document describes the error handling architecture and patterns used throughout the OpenCode Nexus client application.

## Overview

The application uses a **store-based error management system** that separates error state from UI components. This allows:
- Centralized error state that all components can subscribe to
- Automatic error propagation from backend to frontend
- Consistent error display across the application
- Recovery mechanisms for temporary failures

## Architecture

### Error State Flow

```
Backend Command Error
        ↓
chatStore.setError(message)  [Update chat state store]
        ↓
GlobalOfflineBanner displays error  [Subscribed to $chatError]
MessageInput disables sending         [Subscribed to $isOnline]
SessionPanel shows local errors       [Local error state]
```

### Core Components

#### 1. **Chat State Store** (`src/stores/chat.ts`)

The central store manages all error and status states:

```typescript
export const chatError = derived(
  chatStateStore,
  $chatState => $chatState.error
);

export const isOnline = derived(
  chatStateStore,
  $chatState => $chatState.isOnline
);

export const syncInProgress = derived(
  chatStateStore,
  $chatState => $chatState.syncInProgress
);

export const hasQueuedMessages = derived(
  chatStateStore,
  $chatState => $chatState.hasQueuedMessages
);
```

**Usage**: Components subscribe to `$chatError`, `$isOnline`, `$syncInProgress`, `$hasQueuedMessages` and react automatically.

#### 2. **GlobalOfflineBanner** (`src/components/GlobalOfflineBanner.svelte`)

Global notification banner at the top of the chat page displaying:
- **Offline status**: When connection is lost
- **Sync progress**: While sending queued messages
- **Queued messages**: Count of messages waiting to send
- **Error messages**: Connection or API errors
- **Connection quality**: Signal bars indicating connection strength

**Features**:
- Auto-dismisses successful notifications after 3 seconds
- Shows duration for offline state
- Accessible with `aria-live="assertive"` for screen readers
- 44px minimum touch targets for mobile
- Responsive design (mobile, tablet, desktop)
- Dark mode support
- High contrast mode support
- Reduced motion support

**Mount Location**: `src/pages/chat.astro` (line 9)

#### 3. **SessionPanel** (`src/components/SessionPanel.svelte`)

Local error handling for session management operations:

```typescript
let error: string | null = null;

async function handleCreateSession() {
  try {
    isCreating = true;
    error = null;
    const newSession = await chatStore.actions.createSession(...);
    chatStore.actions.selectSession(newSession);
  } catch (err) {
    error = `Failed to create session: ${err.message}`;
    console.error('❌ [SESSION PANEL]', error);
  } finally {
    isCreating = false;
  }
}
```

**Error Display**: Inline error banner with dismiss button (44px touch target)

#### 4. **MessageInput** (`src/components/MessageInput.svelte`)

Input-level error and status feedback:

```typescript
// Offline indicator
{#if !$isOnline}
  <span class="offline-indicator" aria-live="polite">
    📴 Offline - Message will be queued
  </span>
{:else if $queuedMessageCount > 0}
  <span class="queued-indicator" aria-live="polite">
    {$queuedMessageCount} queued message{$queuedMessageCount === 1 ? '' : 's'}
  </span>
{/if}
```

**Features**:
- Shows "Message will be queued for sending..." placeholder when offline
- Displays queued message count
- 44px touch target for send button
- Font size 16px prevents iOS auto-zoom
- Proper ARIA labels for accessibility

## Error Handling Patterns

### Pattern 1: Store-Based Error (Global)

Use for errors that affect the entire application (connection loss, auth failure, server errors).

```typescript
// In chat store action
try {
  const sessions = await sessionLoader();
  sessionsStore.setSessions(sessions);
} catch (error) {
  chatStateStore.setError(`Failed to load sessions: ${error}`);
  // GlobalOfflineBanner will automatically display the error
}
```

**Advantages**:
- Automatic UI display via GlobalOfflineBanner
- Single source of truth for app-wide errors
- Auto-dismisses on success
- Accessible with proper ARIA attributes

### Pattern 2: Local Component Error

Use for errors specific to a component (form validation, local operations).

```typescript
// In SessionPanel.svelte
let error: string | null = null;

async function handleCreateSession() {
  try {
    isCreating = true;
    error = null;
    // Operation
  } catch (err) {
    error = `Failed to create session: ${err.message}`;
  } finally {
    isCreating = false;
  }
}

// In template
{#if error}
  <div class="error-banner" role="alert">
    <span>{error}</span>
    <button on:click={() => (error = null)}>×</button>
  </div>
{/if}
```

**Advantages**:
- Scoped to specific component
- Easy to dismiss
- Direct user control
- Doesn't clutter global state

### Pattern 3: Inline Status Feedback

Use for immediate, contextual feedback without error messages.

```typescript
// In MessageInput.svelte
{#if !$isOnline}
  <span class="offline-indicator">📴 Offline - Message will be queued</span>
{/if}
```

**Advantages**:
- Immediate visual feedback
- No error language (more positive)
- Context-specific
- Doesn't require user dismissal

## Error Types and Responses

### Network Errors

**Detection**: Connection lost, timeout, DNS failure

**Response**:
1. Message queued for later sending
2. GlobalOfflineBanner shows "You are offline"
3. MessageInput shows "Message will be queued..."
4. Messages sync automatically when connection restored

**Implementation**: `ConnectionMonitor.addListener()` in `src/stores/chat.ts`

### API Errors

**Detection**: 4xx or 5xx response from OpenCode server

**Response**:
1. Error message shown in GlobalOfflineBanner
2. If send fails: message queued for retry
3. ActionButton available to retry
4. Queued message count displayed

**Implementation**: `messageSender` callback catches errors and calls `chatStateStore.setError()`

### Auth Errors

**Detection**: Unauthorized (401), Forbidden (403)

**Response**:
1. User redirected to login page
2. Session cleared
3. Error logged

**Implementation**: `src/pages/chat.astro` handles 401 response

### Validation Errors

**Detection**: Invalid input (empty message, invalid session ID)

**Response**:
1. Shown in component UI (not GlobalOfflineBanner)
2. Input field highlighted or disabled
3. Help text provides guidance

**Implementation**: Component-level checks before sending

## Implementation Checklist

When adding error handling to a new feature:

- [ ] **Identify error type**: Network, API, validation, or auth?
- [ ] **Choose pattern**: Store-based (global), local, or inline?
- [ ] **Add error messages**: Clear, actionable, user-friendly
- [ ] **Test recovery**: Can user retry? Does retry work?
- [ ] **Accessibility**: ARIA attributes, screen reader announcements
- [ ] **Mobile**: 44px touch targets, responsive layout
- [ ] **Dark mode**: Test error colors in dark mode
- [ ] **Offline**: Simulate network disconnection
- [ ] **Documentation**: Update this guide with new error types

## Testing Error Scenarios

### Simulating Network Failure

```typescript
// In DevTools Console
navigator.onLine = false;  // Simulate offline
// Trigger connection change event
dispatchEvent(new Event('offline'));
```

### Simulating API Error

```typescript
// Mock API response
const result = await fetch('...')
  .then(r => r.status >= 400 ? Promise.reject(new Error(`HTTP ${r.status}`)) : r.json());
```

### Testing Queue and Sync

1. Disconnect from network
2. Send a message (should queue)
3. Verify GlobalOfflineBanner shows queued message count
4. Reconnect to network
5. Verify messages auto-sync and counter decrements

## Best Practices

### ✅ Do's

- **Clear, actionable messages**: "Connection lost - messages will send when online"
- **Auto-dismiss success states**: User doesn't need to dismiss success
- **Provide recovery actions**: Retry button, manual sync
- **Log for debugging**: Console logging with emoji prefixes
- **Test with real devices**: Offline behavior differs by device
- **Test on 4G/slow networks**: Simulate real conditions
- **Use aria-live regions**: For screen reader announcements

### ❌ Don'ts

- **Technical error messages**: "ECONNREFUSED" → "Connection lost"
- **Show errors to unrelated users**: Keep scope narrow
- **Ignore queued messages**: Always synced when possible
- **Use only color for status**: Include icons and text
- **Auto-dismiss errors**: Users need time to read and act
- **Block UI on temporary errors**: Graceful degradation

## Future Enhancements

### Planned Improvements

1. **Retry UI**: Explicit retry button for failed API calls
2. **Error Analytics**: Track error frequency and patterns
3. **Error Recovery Suggestions**: Contextual help for common errors
4. **Notification Center**: Persistent log of recent errors
5. **Exponential Backoff**: Smarter retry logic for sync
6. **Error Boundaries**: Catch React/Svelte component crashes
7. **Network Quality Indicator**: Show signal strength in banner

### Related Documentation

- **[docs/client/SECURITY.md](../../docs/client/SECURITY.md)** - Security error handling
- **[docs/client/USER-FLOWS.md](../../docs/client/USER-FLOWS.md)** - Offline user flows
- **[MOBILE_OPTIMIZATION_GUIDE.md](./MOBILE_OPTIMIZATION_GUIDE.md)** - Mobile error UX
- **[MOBILE_TESTING_CHECKLIST.md](../MOBILE_TESTING_CHECKLIST.md)** - Error testing on devices

## Examples

### Example 1: Session Creation Error

**Scenario**: User clicks Create Session but API returns 500 error

**Flow**:
```
User clicks Create Session
  ↓
SessionPanel.handleCreateSession() called
  ↓
API call fails with 500 error
  ↓
catch block: error = "Failed to create session: Server error"
  ↓
SessionPanel shows error banner inline
  ↓
User sees "Failed to create session: Server error" with × dismiss button
  ↓
User clicks × to dismiss error
  ↓
SessionPanel error state clears
```

### Example 2: Offline Message Send

**Scenario**: User sends message while offline

**Flow**:
```
User types "Hello" and presses Enter
  ↓
MessageInput.handleSubmit() called
  ↓
chatStore.sendMessage() called
  ↓
sendMessage detects isOnline = false
  ↓
Message queued in localStorage
  ↓
compositionStore.setQueuedMessageCount(1)
  ↓
GlobalOfflineBanner shows "1 queued message"
  ↓
MessageInput shows "📴 Offline - Message will be queued"
  ↓
Connection restored
  ↓
ConnectionMonitor fires 'online' event
  ↓
chatStore syncs queued messages
  ↓
GlobalOfflineBanner shows "Syncing queued messages..."
  ↓
Messages sent successfully
  ↓
GlobalOfflineBanner auto-dismisses after 3 seconds
  ↓
queuedMessageCount = 0
```

### Example 3: Network Timeout with Retry

**Scenario**: Message send times out, user clicks retry

**Flow**:
```
User sends message
  ↓
Message times out after 30 seconds
  ↓
GlobalOfflineBanner shows "Connection timeout - tap to retry"
  ↓
User clicks "Retry" button
  ↓
messageSyncManager.startSync() called
  ↓
Message resent and succeeds
  ↓
GlobalOfflineBanner shows "Message sent!"
  ↓
Auto-dismisses after 3 seconds
```

## Troubleshooting

### GlobalOfflineBanner Not Showing

**Check**:
1. Is GlobalOfflineBanner mounted in `src/pages/chat.astro`? (Line 9)
2. Is `client:load` directive present?
3. Are stores being updated with `chatStateStore.setError()`?
4. Check browser console for errors

### Error Messages Not Disappearing

**Check**:
1. SessionPanel errors need manual dismiss (×) button
2. GlobalOfflineBanner auto-dismisses success after 3 seconds
3. Set error to `null` when operation completes successfully

### Offline Queue Not Syncing

**Check**:
1. Is ConnectionMonitor properly detecting connection state?
2. Is `messageSyncManager.startSync()` being called?
3. Check localStorage for queued messages: `console.log(localStorage)`

---

**Last Updated**: Phase 2, Task 7 - Error Handling Implementation
**Status**: Active Development
