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
├── PRD.md             # Product requirements for mobile client
├── ARCHITECTURE.md    # Client-only architecture (no server management)
├── USER-FLOWS.md      # Mobile touch interactions and offline flows
├── TESTING.md         # Mobile testing strategies and touch testing
└── SECURITY.md        # Client connection security and data protection
```

### 🔄 Key Changes from Previous Version

#### Product Focus
- **Client-Only:** Connects to OpenCode servers started with `opencode serve` (no local server management)
- **iOS Mobile App:** Native iOS experience with future cross-platform potential
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
- **Platform Integration:** iOS Keychain integration (primary), extensible to other platforms
- **Privacy First:** Minimal data collection with user consent

### 🎯 Implementation Status

#### ✅ Completed
- **SDK Integration Complete:** @opencode-ai/sdk fully integrated (November 27, 2025)
- **iOS TestFlight Deployment:** App in beta testing with successful uploads
- **Security Hardening:** Zero vulnerabilities, TLS 1.3, encrypted storage
- **Error Handling:** Comprehensive retry logic and user-friendly messages
- **E2E Testing:** 24 SDK integration tests, performance validation
- **Documentation:** All docs updated for SDK-powered client architecture
- **Production Ready:** Mobile-optimized chat with real-time streaming

#### 🚧 In Progress
- Mobile platform beta testing (iOS TestFlight)
- Real-world load testing with OpenCode servers
- Performance optimization and monitoring

#### 📋 Next Priorities
1. **Beta Testing:** Collect user feedback from TestFlight users
2. **iOS Enhancements:** Advanced iOS features and optimizations
3. **Cross-Platform Expansion:** Android and desktop support (future)
4. **PWA Support:** Enhanced progressive web app features

### 🧪 Testing Strategy

#### Mobile-Specific Testing
- **Touch Interaction Testing:** Gesture recognition and touch targets
- **Offline Capability Testing:** Network transition handling
- **Platform Testing:** iOS simulator and device testing (primary), PWA for development
- **Performance Testing:** Startup time, memory usage, battery impact

#### Accessibility Compliance
- **WCAG 2.2 AA:** 44px touch targets, screen reader support
- **Motor Impairment:** Keyboard navigation, gesture alternatives
- **Visual Impairment:** High contrast, text scaling support

### 🔐 Security Implementation

#### Connection Security
- **SSL/TLS Validation:** Certificate verification and pinning
- **Server Authentication:** Hostname verification and trust establishment
- **API Security:** HMAC request signing and rate limiting

#### Data Protection
- **Local Encryption:** AES-256 for cached conversations
- **Platform Security:** iOS Keychain integration for secure credential storage
- **Sync Security:** End-to-end encrypted synchronization

### 📱 Platform Support

#### iOS (Primary)
- **TestFlight Ready:** IPA generated and ready for upload
- **Native Performance:** Tauri iOS runtime optimization
- **Platform Integration:** Face ID, iCloud sync (optional)

#### Future Platforms (Planned)
- **Android:** Tauri Android support for additional mobile platform
- **Desktop:** macOS, Windows, Linux builds for development use

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
- **iOS Focus:** Primary iOS compatibility with PWA development support
- **Accessibility:** WCAG 2.2 AA compliance verification

#### Quality Gates
- **Security Audit:** Zero vulnerabilities, secure connections
- **Performance:** <2s startup, <50MB memory, <5% battery drain
- **Accessibility:** Full compliance with screen readers and touch
- **Testing:** 90%+ coverage for critical mobile paths

### 📋 Implementation Checklist

#### ✅ Phase 1-3: SDK Integration Complete (November 27, 2025)
- [x] **SDK Integration:** @opencode-ai/sdk fully integrated with type safety
- [x] **Connection Management:** HTTP/SSE communication with health monitoring
- [x] **Chat Operations:** Real-time streaming via Server-Sent Events
- [x] **Session Management:** Metadata-only caching with server sync
- [x] **Error Handling:** Retry logic with exponential backoff
- [x] **Testing:** 24 E2E tests, performance validation complete
- [x] **Mobile Optimization:** Touch targets, responsive design
- [x] **Security:** TLS 1.3, encrypted storage, zero vulnerabilities

#### 🚀 Phase 4: Production & Expansion (Current)
- [x] **iOS TestFlight:** Beta deployment successful
- [ ] Complete iOS testing and optimization
- [ ] Implement PWA support enhancements
- [ ] Add advanced offline capabilities
- [ ] Final security and performance validation
- [ ] User feedback integration and polish

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

**Documentation Status:** ✅ SDK integration documentation complete
**Implementation Status:** SDK Integration Phase 1-3 complete - production ready
**Next Milestone:** iOS beta testing and mobile app optimization</content>
<parameter name="filePath">docs/client/README.md