# Client Architecture Overview
**Project:** OpenCode Nexus - Mobile Client
**Version:** 1.0.0
**Last Updated:** 2025-12-05
**Status:** SDK Integration Complete - Production Ready

## 1. System Architecture Overview

OpenCode Nexus is a mobile-first client application that connects to remote OpenCode servers. The architecture emphasizes lightweight client-side processing, offline capabilities, and seamless server communication.

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenCode Nexus                          │
│                Mobile-First Client App                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   Tauri Shell   │    │        Mobile UI                │ │
│  │   (Rust)        │◄──►│      (Astro + Svelte)          │ │
│  │                 │    │         (Bun Runtime)          │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │ Connection      │    │      SDK Integration           │ │
│  │ Manager         │    │   (@opencode-ai/sdk)           │ │
│  │ (HTTP/SSE)      │    │   (Chat & Sessions)            │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   Offline       │    │      Sync Engine               │ │
│  │   Storage       │    │   (Background Sync)            │ │
│  │   (IndexedDB)   │    │                                 │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Network Layer                             │
│  │         (TLS 1.3 + Certificate Validation)            │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              OpenCode Server                            │
│  │              (Remote Instance)                          │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 2. Core Components

### 2.1 Connection Manager (`src-tauri/src/connection_manager.rs`)
**Purpose:** Manages connections to remote OpenCode servers
**Responsibilities:**
- HTTP client for server communication
- SSL/TLS certificate validation
- Connection health monitoring
- Auto-reconnection with exponential backoff
- Server compatibility verification

**Key Methods:**
```rust
pub async fn connect_to_server(&self, host: &str, port: u16) -> Result<(), ConnectionError>
pub async fn test_connection(&self) -> Result<ServerInfo, ConnectionError>
pub async fn disconnect(&self) -> Result<(), ConnectionError>
```

### 2.2 SDK Integration (`frontend/src/lib/sdk-api.ts`)
**Purpose:** Official @opencode-ai/sdk integration for AI conversation interactions
**Responsibilities:**
- Type-safe API communication with OpenCode servers
- Real-time streaming via Server-Sent Events
- Conversation session management
- File/code context sharing
- Error handling and recovery with retry logic

**Key Methods:**
```typescript
export async function sendMessage(content: string, sessionId?: string): Promise<ReadableStream<MessageChunk>>
export async function createSession(): Promise<Session>
export async function getSessionHistory(sessionId: string): Promise<Message[]>
export async function listSessions(): Promise<Session[]>
```

### 2.3 Offline Storage (`frontend/src/stores/offline.ts`)
**Purpose:** Local conversation caching and offline capabilities
**Responsibilities:**
- IndexedDB-based conversation storage
- Message queuing for offline composition
- Automatic sync when connection restored
- Storage quota management (50MB limit)
- Data compression and cleanup

**Key Features:**
- Conversation persistence across app restarts
- Offline message composition
- Background sync engine
- Storage optimization and cleanup

### 2.4 Mobile UI Layer (`frontend/src/components/`)
**Purpose:** Touch-optimized user interface
**Components:**
- `MobileChatInterface.svelte` - Main chat UI with touch gestures
- `ServerConnection.svelte` - Server setup and connection management
- `OfflineIndicator.svelte` - Online/offline status display
- `TouchKeyboard.svelte` - Mobile keyboard handling

**Mobile Optimizations:**
- 44px minimum touch targets
- Swipe gestures for navigation
- Responsive text sizing
- Haptic feedback integration

## 3. Data Flow

### 3.1 Message Sending Flow
```
User Input → Mobile UI → SDK API Layer → Connection Manager → OpenCode Server
                      ↓
              Offline Storage (cache) ← Background Sync ← Server Response
```

### 3.2 Connection Management Flow
```
App Launch → Load Saved Servers → Connection Manager → Health Check
    ↓                                                            ↓
Auto Reconnect ← Connection Lost ← Network Issues ← Server Response
```

### 3.3 Offline Sync Flow
```
Offline Mode → Queue Messages → Detect Connection → Sync Engine → Server
    ↓              ↓                     ↓                    ↓
Storage Full → Cleanup Old → Connection Restored → Batch Send → Success
```

## 4. Security Architecture

### 4.1 Connection Security
- **SSL/TLS Validation:** Certificate pinning and validation
- **Server Trust:** User verification of server certificates
- **API Key Security:** Secure storage and transmission
- **Request Signing:** HMAC-based request authentication

### 4.2 Data Protection
- **Local Encryption:** AES-256 encryption for cached conversations
- **Secure Storage:** Platform-specific secure storage for credentials
- **Memory Safety:** Rust guarantees for sensitive data handling
- **Privacy Controls:** Granular permission management

### 4.3 Mobile Security
- **App Sandboxing:** Platform-provided application isolation
- **Network Security:** Certificate validation and man-in-the-middle protection
- **Data Minimization:** Only necessary data collection
- **Audit Logging:** Security event logging for compliance

## 5. Performance Considerations

### 5.1 Mobile Performance Targets
- **Cold Start:** <2 seconds
- **Warm Start:** <500ms
- **Memory Usage:** <50MB RAM
- **Storage:** <100MB total
- **Battery Impact:** <5% per hour in background

### 5.2 Optimization Strategies
- **Lazy Loading:** Components loaded on demand
- **Image Optimization:** Compressed assets and responsive images
- **Caching Strategy:** Aggressive caching with smart invalidation
- **Background Sync:** Efficient background data synchronization

## 6. Platform-Specific Architecture

### 6.1 iOS Implementation
- **Native Backend:** Tauri iOS runtime
- **UI Framework:** UIKit integration via Tauri
- **Distribution:** TestFlight → App Store
- **Security:** iOS Keychain integration

### 6.2 Android Implementation (Planned)
- **Native Backend:** Tauri Android runtime
- **UI Framework:** Android integration
- **Distribution:** Google Play Store
- **Security:** Android Keystore integration

### 6.3 Desktop Implementation (Secondary)
- **Native Backends:** macOS, Windows, Linux
- **UI Framework:** System webviews
- **Distribution:** Direct downloads
- **Security:** Platform-specific secure storage

## 7. Error Handling & Recovery

### 7.1 Connection Errors
- **Network Issues:** Auto-retry with exponential backoff
- **Server Down:** Graceful degradation with offline mode
- **SSL Errors:** Clear user messaging for certificate issues
- **Timeout Handling:** Configurable timeouts with user feedback

### 7.2 Data Synchronization
- **Sync Conflicts:** Last-write-wins with user notification
- **Partial Sync:** Resume interrupted synchronizations
- **Data Corruption:** Automatic recovery and re-sync
- **Quota Exceeded:** Smart cleanup of old conversations

### 7.3 Mobile-Specific Errors
- **Low Storage:** Warning and cleanup suggestions
- **Low Battery:** Reduced functionality to preserve battery
- **Network Switching:** Seamless transition between WiFi/cellular
- **App Backgrounding:** State preservation and background sync

## 8. Testing Strategy

### 8.1 Unit Testing
- **Connection Manager:** Mock HTTP client testing
- **Chat Client:** Message handling and streaming tests
- **Offline Storage:** IndexedDB operation testing
- **UI Components:** Touch interaction testing

### 8.2 Integration Testing
- **End-to-End Flows:** Complete user journeys
- **Network Conditions:** Offline/online transitions
- **Platform Testing:** iOS simulator and device testing
- **Performance Testing:** Startup time and memory usage

### 8.3 Mobile-Specific Testing
- **Touch Gestures:** Swipe, tap, and multi-touch testing
- **Orientation Changes:** Portrait/landscape transitions
- **Network Switching:** WiFi to cellular transitions
- **Background Testing:** App backgrounding and foregrounding

---

**Architecture Status:** Client-only design finalized
**Implementation Focus:** Connection manager and offline capabilities</content>
<parameter name="filePath">docs/client/ARCHITECTURE.md