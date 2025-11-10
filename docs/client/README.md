# OpenCode Nexus - Mobile Client Documentation

## Documentation Structure

This documentation has been completely rewritten to reflect the mobile-first client pivot. The app is now a client that connects to existing OpenCode servers, not a server management tool.

### 📱 Mobile-First Client Vision

**Before:** Desktop server management application
**After:** Mobile-first client connecting to OpenCode servers

### 📁 Documentation Organization

```
docs/client/
├── README.md           # This file - documentation overview
├── AUTH_SETUP.md      # 🔐 Authentication setup guide with step-by-step instructions
├── PRD.md             # Product requirements for mobile client
├── ARCHITECTURE.md    # Client-only architecture (no server management)
├── USER-FLOWS.md      # Mobile touch interactions and offline flows
├── TESTING.md         # Mobile testing strategies and touch testing
└── SECURITY.md        # Client connection security and data protection
```

### 🔄 Key Changes from Previous Version

#### Product Focus
- **Client-Only:** Connects to OpenCode servers started with `opencode serve` (no local server management)
- **Cross-Platform:** iOS, Android, Desktop, PWA support
- **Chat-Focused:** Real-time AI conversation interface
- **Secure:** Connects to authenticated OpenCode server instances

#### Technical Architecture
- **Connection Manager:** Replaces server manager for client-server communication
- **Chat Client:** Direct API integration instead of local process management
- **Offline Storage:** IndexedDB-based conversation caching
- **Mobile UI:** Touch-optimized components with responsive design

#### Security Model
- **Connection Security:** SSL validation and server trust verification
- **Data Protection:** Local encryption for cached conversations
- **Platform Integration:** iOS Keychain, Android Keystore integration
- **Privacy First:** Minimal data collection with user consent

### 🎯 Implementation Status

#### ✅ Completed
- iOS TestFlight deployment setup and IPA generation
- Security vulnerability fixes (6 → 0 vulnerabilities)
- Dependency updates for mobile compatibility
- Documentation updated for client-only architecture
- Dashboard removed, app simplified to chat client
- Server connection setup documented (`opencode serve`)

#### 🚧 In Progress
- Connection manager implementation (replaces server manager)
- Mobile UI redesign for touch interactions
- Offline conversation caching system
- Real-time message streaming from servers

#### 📋 Next Priorities
1. **Server Connection:** Update chat client to connect to remote OpenCode servers
2. **Authentication:** Implement server authentication flow
3. **Real-time Streaming:** Server-Sent Events for message streaming
4. **Cross-Platform Builds:** Android, Desktop, PWA builds

### 🧪 Testing Strategy

#### Mobile-Specific Testing
- **Touch Interaction Testing:** Gesture recognition and touch targets
- **Offline Capability Testing:** Network transition handling
- **Platform Testing:** iOS simulator, Android emulator, PWA browsers
- **Performance Testing:** Startup time, memory usage, battery impact

#### Accessibility Compliance
- **WCAG 2.2 AA:** 44px touch targets, screen reader support
- **Motor Impairment:** Keyboard navigation, gesture alternatives
- **Visual Impairment:** High contrast, text scaling support

### 🔐 Security & Authentication

OpenCode Nexus supports multiple authentication methods for securing connections to OpenCode servers. **Start here: [Authentication Setup Guide](./AUTH_SETUP.md)**

#### Supported Authentication Methods

| Method | Security Level | Best For | Setup Time |
|--------|---------------|----------|------------|
| **No Auth** | ❌ Unsecured | Development only | 1 min |
| **[Cloudflare Access](./AUTH_SETUP.md#method-2-cloudflare-access-service-tokens)** | ✅✅✅ High | Internet exposure | 15 min |
| **[API Key](./AUTH_SETUP.md#method-3-api-key-authentication)** | ✅✅ Medium | Self-hosted production | 10 min |
| **[Custom Header](./AUTH_SETUP.md#method-4-custom-header-authentication)** | ✅✅✅ High | Enterprise SSO | Varies |

#### Quick Setup Links

- **[Cloudflare Access Setup](./AUTH_SETUP.md#method-2-cloudflare-access-service-tokens)** - Free, automatic DDoS protection, device-based auth
- **[nginx/Caddy API Key Setup](./AUTH_SETUP.md#method-3-api-key-authentication)** - Self-hosted, simple configuration
- **[Custom Header Setup](./AUTH_SETUP.md#method-4-custom-header-authentication)** - Enterprise SSO integration

#### Connection Security Features
- **SSL/TLS Validation:** Certificate verification and pinning
- **Authentication:** Multiple methods with encrypted credential storage
- **Server Trust:** Hostname verification and trust establishment

#### Data Protection
- **Local Encryption:** AES-256 for cached conversations
- **Platform Security:** iOS Keychain, Android Keystore integration
- **Sync Security:** End-to-end encrypted synchronization

### 📱 Platform Support

#### iOS (Primary)
- **TestFlight Ready:** IPA generated and ready for upload
- **Native Performance:** Tauri iOS runtime optimization
- **Platform Integration:** Face ID, iCloud sync (optional)

#### Android (Planned)
- **Tauri Android:** Cross-platform mobile support
- **Material Design:** Native Android UI patterns
- **Biometric Auth:** Fingerprint and face unlock

#### PWA (Web)
- **Progressive Web App:** Installable web application
- **Offline Support:** Service worker caching
- **Responsive Design:** Mobile-first web interface

### 🚀 Development Workflow

#### Branch Strategy
- `main`: Production-ready code
- `client-docs-rewrite`: Documentation rewrite branch
- Feature branches for implementation work

#### Testing Requirements
- **TDD Mandatory:** Write tests before implementation
- **Mobile Testing:** Touch gestures, offline scenarios
- **Cross-Platform:** iOS, Android, PWA compatibility
- **Accessibility:** WCAG 2.2 AA compliance verification

#### Quality Gates
- **Security Audit:** Zero vulnerabilities, secure connections
- **Performance:** <2s startup, <50MB memory, <5% battery drain
- **Accessibility:** Full compliance with screen readers and touch
- **Testing:** 90%+ coverage for critical mobile paths

### 📋 Implementation Checklist

#### Phase 1: Architecture Foundation (Current)
- [ ] Replace server manager with connection manager
- [ ] Implement HTTP client for server communication
- [ ] Add SSL/TLS certificate validation
- [ ] Create connection health monitoring

#### Phase 2: Chat Client Core
- [ ] Update chat backend for remote server integration
- [ ] Implement real-time Server-Sent Events
- [ ] Add session management via API calls
- [ ] Create offline conversation caching

#### Phase 3: Mobile UI Optimization
- [ ] Redesign chat interface for touch interactions
- [ ] Implement swipe gestures and touch targets
- [ ] Add mobile keyboard handling
- [ ] Create responsive layouts for all orientations

#### Phase 4: Production Readiness
- [ ] Complete cross-platform testing
- [ ] Implement PWA support
- [ ] Add advanced offline capabilities
- [ ] Final security and performance validation

### 🤝 Contributing

#### Documentation Standards
- **Mobile-First:** All features designed for mobile use first
- **Accessibility:** WCAG 2.2 AA compliance mandatory
- **Security:** Zero-trust approach to server connections
- **Testing:** TDD with comprehensive mobile test coverage

#### Code Standards
- **Touch Targets:** Minimum 44px for all interactive elements
- **Performance:** Mobile-optimized with battery awareness
- **Security:** End-to-end encryption for sensitive data
- **Privacy:** Minimal data collection with user control

---

**Documentation Status:** ✅ Mobile-first client documentation complete
**Implementation Status:** Phase 1 in progress - connection manager development
**Next Milestone:** Chat client core implementation</content>
<parameter name="filePath">docs/client/README.md