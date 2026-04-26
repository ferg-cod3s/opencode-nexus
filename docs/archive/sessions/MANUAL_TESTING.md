# Manual Testing Checklist - OpenCode Nexus

**Version**: Phase 3 (55% Complete)
**Date**: November 12, 2025
**Branch**: `claude/phase1-next-steps-011CV32DaRoZ7LBZ4hiDxh3p`

## Prerequisites

### Environment Setup
- [ ] **OpenCode Server** installed and running
  ```bash
  opencode serve --port 4096
  ```
- [ ] **Build Tools** installed:
  - Node.js 18+ or Bun
  - Rust 1.75+
  - Platform-specific dependencies (see below)

### Platform-Specific Dependencies

**macOS:**
- [ ] Xcode Command Line Tools
- [ ] No additional dependencies (WebKit built-in)

**Linux:**
- [ ] GTK 3.22+
- [ ] WebKit2GTK
- [ ] Install command: `sudo apt install libwebkit2gtk-4.0-dev build-essential curl wget libssl-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev`

**Windows:**
- [ ] Microsoft Edge WebView2 Runtime
- [ ] Visual Studio Build Tools 2019+

### Build Commands

```bash
# Frontend build
cd frontend
bun install
bun run build

# Backend build (from project root)
cargo tauri build

# Development mode
cargo tauri dev
```

---

## Phase 1: Connection Tests

### Basic Connection
- [ ] **Test 1.1: Localhost Connection**
  - Start OpenCode server: `opencode serve --port 4096`
  - Launch OpenCode Nexus
  - Navigate to connection page
  - Enter: `localhost:4096` (HTTP)
  - Click "Test Connection"
  - **Expected**: Green success message, server version displayed
  - **Error Handling**: If fails, should show user-friendly error with retry button

- [ ] **Test 1.2: Invalid Server Connection**
  - Enter: `localhost:9999` (invalid port)
  - Click "Test Connection"
  - **Expected**: Network error toast appears with "Network error: Failed to connect to server"
  - **Expected**: Retry button present (44px touch target)
  - **Error Handling**: Auto-retry 3 times with exponential backoff (1s, 2s, 4s)
  - **Expected**: Error auto-dismisses after 8 seconds

- [ ] **Test 1.3: Timeout Handling**
  - Enter: `httpstat.us:4096` (slow endpoint)
  - Click "Test Connection"
  - **Expected**: Timeout error after 30 seconds
  - **Expected**: "Operation timed out: HTTP request" message
  - **Expected**: Retry button functional

- [ ] **Test 1.4: HTTPS Connection**
  - If you have HTTPS OpenCode server setup:
  - Enter: `your-domain.com:4096` (HTTPS)
  - **Expected**: Successful HTTPS connection
  - **Expected**: TLS validation passes

### Connection Persistence
- [ ] **Test 1.5: Connection History**
  - Connect to a server successfully
  - Close app, reopen
  - **Expected**: Connection listed in saved connections
  - **Expected**: Can reconnect with one click
  - **Location**: Check `~/.config/opencode-nexus/server_connections.json`

- [ ] **Test 1.6: Multiple Connections**
  - Save 3 different server connections
  - Switch between them
  - **Expected**: Each connection remembered
  - **Expected**: Current connection highlighted

---

## Phase 2: Chat Functionality

### Session Management
- [ ] **Test 2.1: Create Session**
  - Connect to OpenCode server
  - Click "Start Your First Chat" or "New Session"
  - **Expected**: Session created via `POST /session`
  - **Expected**: Session ID displayed
  - **Expected**: Ready to receive messages

- [ ] **Test 2.2: Session Metadata Caching**
  - Create 3 sessions
  - Check local storage: `~/.config/opencode-nexus/session_metadata.json`
  - **Expected**: File contains metadata ONLY (IDs, titles, counts)
  - **Expected**: File size under 2KB (not 500KB+)
  - **Expected**: NO full message history in file (server is source of truth)

- [ ] **Test 2.3: Session List**
  - Create multiple sessions
  - **Expected**: All sessions listed in sidebar
  - **Expected**: Can switch between sessions
  - **Expected**: Each session shows title and message count

### Message Sending
- [ ] **Test 2.4: Send Simple Message**
  - In active session, type: "Hello, what's your name?"
  - Click send
  - **Expected**: Message appears in chat (user role)
  - **Expected**: Loading indicator shows
  - **Expected**: AI response streams in real-time

- [ ] **Test 2.5: Streaming Response**
  - Send message: "Write a haiku about coding"
  - **Expected**: Response appears word-by-word (not all at once)
  - **Expected**: No flickering or UI jumps
  - **Expected**: Chunks accumulate smoothly via SSE `/event` endpoint

- [ ] **Test 2.6: Failed Message Send**
  - Disconnect from server (stop OpenCode)
  - Try to send message
  - **Expected**: Error toast: "Network error: Failed to send message"
  - **Expected**: Retry button appears
  - **Expected**: Auto-retry attempts (3x with backoff: 1s, 2s, 4s)
  - Restart server, click retry
  - **Expected**: Message sends successfully

### Mobile Storage Verification
- [ ] **Test 2.7: Metadata-Only Storage**
  - Send 50 messages in a session
  - Check `session_metadata.json` file size
  - **Expected**: File stays under 5KB regardless of message count
  - **Expected**: message_count incremented to 50
  - **Expected**: NO message content stored locally

- [ ] **Test 2.8: Fetch Messages from Server**
  - Create session, send messages
  - Close app, reopen
  - Select session
  - **Expected**: Messages fetched from server via `GET /session/{id}/messages`
  - **Expected**: Full conversation history displayed
  - **Expected**: Local metadata synced with server

---

## Phase 3: Error Handling

### Network Errors
- [ ] **Test 3.1: Connection Loss During Chat**
  - Start chat session
  - Stop OpenCode server mid-conversation
  - Try to send message
  - **Expected**: "Network error: Failed to connect to server" toast
  - **Expected**: Retry button present
  - **Expected**: 3 automatic retry attempts
  - Restart server
  - **Expected**: Next message send succeeds

- [ ] **Test 3.2: Timeout During Streaming**
  - Send message that triggers long response
  - **Expected**: Response streams continuously
  - If timeout occurs:
  - **Expected**: "Operation timed out" error
  - **Expected**: Retry option available

- [ ] **Test 3.3: Multiple Errors**
  - Trigger 3 different errors (connection fail, timeout, invalid input)
  - **Expected**: Multiple error toasts stack vertically
  - **Expected**: Each dismisses after 8 seconds
  - **Expected**: Can manually close any toast

### Error Message Quality
- [ ] **Test 3.4: User-Friendly Messages**
  - Trigger various errors
  - **Expected**: NO technical jargon (e.g., "reqwest::Error")
  - **Expected**: Clear messages like "Network error: Failed to connect to server"
  - **Expected**: Actionable guidance (retry, check connection, etc.)

- [ ] **Test 3.5: Rate Limiting (429)**
  - If server implements rate limiting:
  - Send many messages rapidly
  - **Expected**: "Too many requests. Please wait a moment and try again."
  - **Expected**: Retry button waits 60 seconds before enabling

- [ ] **Test 3.6: Server Error (500)**
  - If server returns 500 error:
  - **Expected**: "Server error: Internal server error"
  - **Expected**: Retry button available
  - **Expected**: Auto-retry with 5s delay

---

## Phase 4: UI/UX Testing

### Accessibility (WCAG 2.2 AA)
- [ ] **Test 4.1: Keyboard Navigation**
  - Use TAB key to navigate all interactive elements
  - **Expected**: Visible focus indicators on all buttons/inputs
  - **Expected**: Logical tab order (top-to-bottom, left-to-right)

- [ ] **Test 4.2: Screen Reader Support**
  - Enable screen reader (VoiceOver/NVDA/JAWS)
  - Navigate connection page
  - **Expected**: All form labels announced
  - **Expected**: Error messages announced via aria-live
  - **Expected**: Button states announced (disabled, loading, etc.)

- [ ] **Test 4.3: Touch Targets (Mobile)**
  - Test on mobile device or touch screen
  - **Expected**: All buttons minimum 44x44px
  - **Expected**: Error toast close button easily tappable
  - **Expected**: No accidental taps

### Responsive Design
- [ ] **Test 4.4: Mobile View (375px)**
  - Resize browser to iPhone SE size (375x667)
  - **Expected**: Layout adapts without horizontal scroll
  - **Expected**: Error toasts 95vw width
  - **Expected**: Text remains readable

- [ ] **Test 4.5: Tablet View (768px)**
  - Resize to iPad size
  - **Expected**: UI scales appropriately
  - **Expected**: Session sidebar visible
  - **Expected**: Touch-friendly controls

- [ ] **Test 4.6: Desktop View (1920px)**
  - Full desktop size
  - **Expected**: Content centered or properly distributed
  - **Expected**: No elements stretched awkwardly

### Dark Mode / High Contrast
- [ ] **Test 4.7: High Contrast Mode**
  - Enable system high contrast mode
  - **Expected**: Error toast borders thicker (3px)
  - **Expected**: All text remains readable
  - **Expected**: Focus indicators visible

- [ ] **Test 4.8: Reduced Motion**
  - Enable system reduced motion preference
  - **Expected**: Error toast animations disabled
  - **Expected**: No distracting transitions

---

## Phase 5: Performance Testing

### Startup Time
- [ ] **Test 5.1: Cold Start**
  - Close app completely
  - Launch app
  - **Expected**: App starts in under 2 seconds
  - **Expected**: UI interactive immediately

- [ ] **Test 5.2: Connection Latency**
  - Time connection test
  - **Expected**: Test completes in under 1 second (localhost)
  - **Expected**: Test completes in under 5 seconds (remote)

### Memory Usage
- [ ] **Test 5.3: Session Metadata Growth**
  - Create 100 sessions
  - **Expected**: `session_metadata.json` stays under 50KB
  - **Expected**: No memory leaks
  - **Expected**: App remains responsive

- [ ] **Test 5.4: Long Chat Session**
  - Have 200+ message conversation
  - **Expected**: UI remains smooth
  - **Expected**: Scrolling performant
  - **Expected**: No lag when sending new messages

### Network Resilience
- [ ] **Test 5.5: Slow Network**
  - Simulate 2G network (browser DevTools)
  - **Expected**: Timeouts increase appropriately
  - **Expected**: Retry logic still functional
  - **Expected**: Error messages clear

- [ ] **Test 5.6: Intermittent Connection**
  - Toggle WiFi on/off during chat
  - **Expected**: Errors displayed when offline
  - **Expected**: Reconnects when back online
  - **Expected**: No data loss

---

## Phase 6: Data Integrity

### Local Storage
- [ ] **Test 6.1: Server Connections File**
  - Check: `~/.config/opencode-nexus/server_connections.json`
  - **Expected**: Valid JSON format
  - **Expected**: Contains hostname, port, secure flag
  - **Expected**: Timestamp for last_connected

- [ ] **Test 6.2: Session Metadata File**
  - Check: `~/.config/opencode-nexus/session_metadata.json`
  - **Expected**: Array of SessionMetadata objects
  - **Expected**: Only contains: id, title, created_at, updated_at, message_count
  - **Expected**: NO message content (server is source of truth)

### Server Sync
- [ ] **Test 6.3: Metadata Sync on Startup**
  - Create sessions in app
  - Close app
  - Create new sessions directly via OpenCode CLI
  - Reopen app
  - **Expected**: All sessions (app + CLI) appear
  - **Expected**: Server metadata synced to local cache

- [ ] **Test 6.4: Message Count Accuracy**
  - Send 10 messages
  - Check session metadata
  - **Expected**: message_count = 10
  - **Expected**: updated_at timestamp recent

---

## Phase 7: Edge Cases

### Unusual Inputs
- [ ] **Test 7.1: Very Long Messages**
  - Send 10,000 character message
  - **Expected**: Message sends successfully
  - **Expected**: UI handles long text gracefully

- [ ] **Test 7.2: Special Characters**
  - Send message with emojis: "🚀 Let's code! 💻"
  - **Expected**: Displays correctly
  - **Expected**: No encoding issues

- [ ] **Test 7.3: Empty Messages**
  - Try to send empty message
  - **Expected**: Send button disabled or validation error

### Concurrent Operations
- [ ] **Test 7.4: Multiple Windows**
  - Open two instances of OpenCode Nexus
  - Send messages from both
  - **Expected**: Both work independently
  - **Expected**: File locks prevent corruption

- [ ] **Test 7.5: Rapid Message Sending**
  - Send 10 messages as fast as possible
  - **Expected**: All messages queued and sent
  - **Expected**: Responses stream correctly
  - **Expected**: No UI freezing

---

## Phase 8: Integration Testing

### Full User Flow
- [ ] **Test 8.1: New User Experience**
  1. Launch app for first time
  2. Navigate to connection page
  3. Enter OpenCode server details
  4. Test connection
  5. Connect to server
  6. Create new session
  7. Send first message
  8. Receive AI response
  9. Send follow-up question
  10. Close app
  **Expected**: Entire flow smooth, no errors

- [ ] **Test 8.2: Returning User Experience**
  1. Launch app
  2. **Expected**: Previous connection remembered
  3. **Expected**: Previous sessions listed
  4. Click existing session
  5. **Expected**: Message history loads from server
  6. Send new message
  7. **Expected**: Conversation continues

### Server API Compatibility
- [ ] **Test 8.3: OpenCode API Endpoints**
  - Verify all endpoints work:
    - `GET /session` - List sessions
    - `POST /session` - Create session
    - `POST /session/:id/prompt` - Send message
    - `GET /session/:id/messages` - Fetch history
    - `GET /event` - SSE streaming
  - **Expected**: All requests succeed
  - **Expected**: Response formats match expectations

---

## Test Results Summary

### Environment Tested
- **OS**: _____________
- **OpenCode Version**: _____________
- **App Version**: _____________
- **Date**: _____________

### Pass/Fail Summary
- **Phase 1 (Connection)**: ____ / 6 tests passed
- **Phase 2 (Chat)**: ____ / 8 tests passed
- **Phase 3 (Errors)**: ____ / 6 tests passed
- **Phase 4 (UI/UX)**: ____ / 8 tests passed
- **Phase 5 (Performance)**: ____ / 6 tests passed
- **Phase 6 (Data)**: ____ / 4 tests passed
- **Phase 7 (Edge Cases)**: ____ / 5 tests passed
- **Phase 8 (Integration)**: ____ / 3 tests passed

**Total**: ____ / 46 tests passed

### Critical Issues Found
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Non-Critical Issues
1. _______________________________________________
2. _______________________________________________

### Notes
_______________________________________________
_______________________________________________

---

## Debugging Tips

### Check Logs
```bash
# Application logs
tail -f ~/.config/opencode-nexus/application.log

# OpenCode server logs
# (check OpenCode documentation)
```

### Inspect Local Storage
```bash
# Session metadata
cat ~/.config/opencode-nexus/session_metadata.json | jq .

# Server connections
cat ~/.config/opencode-nexus/server_connections.json | jq .
```

### Network Debugging
```bash
# Test OpenCode server directly
curl http://localhost:4096/session

# Monitor SSE stream
curl -N http://localhost:4096/event
```

### Browser DevTools (Development Mode)
- **Console**: Check for JavaScript errors
- **Network Tab**: Inspect API calls and SSE stream
- **Application Tab**: Check localStorage and sessionStorage

---

## Known Limitations (Current Build Environment)

This checklist was created in a Linux environment **without GTK/WebKit dependencies**, so full compilation was not possible. However:

✅ **Verified Working**:
- TypeScript compilation (0 errors)
- Frontend build process
- Error handling module syntax
- Retry logic design

❌ **Not Tested in This Environment**:
- Full Tauri desktop build
- Rust backend compilation
- iOS/Android builds
- Actual runtime behavior

**Recommendation**: Run this checklist in a proper development environment with all system dependencies installed.

---

## CI/CD Build Environment

For reference, a proper CI/CD environment (like GitHub Actions) would have:

### Linux (Ubuntu 22.04)
```bash
sudo apt update
sudo apt install -y \
  libwebkit2gtk-4.0-dev \
  build-essential \
  curl \
  wget \
  libssl-dev \
  libgtk-3-dev \
  libayatana-appindicator3-dev \
  librsvg2-dev \
  libsoup2.4-dev \
  javascriptcoregtk-4.0 \
  patchelf
```

### macOS
```bash
# Xcode Command Line Tools
xcode-select --install
```

### Rust Toolchain
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add x86_64-unknown-linux-gnu  # Linux
rustup target add aarch64-apple-darwin      # macOS ARM
rustup target add x86_64-apple-darwin       # macOS Intel
rustup target add aarch64-apple-ios         # iOS
rustup target add aarch64-linux-android     # Android
```

---

## Next Steps After Manual Testing

1. **Document findings** in GitHub issue or testing report
2. **Update E2E tests** to match new architecture
3. **Fix any critical bugs** discovered
4. **Optimize performance** based on measurements
5. **Prepare for production** deployment

---

**Testing Happy Path**: Connection → Create Session → Send Message → Receive Response → Success! 🎉
