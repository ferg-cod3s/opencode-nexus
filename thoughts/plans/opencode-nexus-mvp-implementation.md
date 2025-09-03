# OpenCode Nexus MVP – Implementation Plan

## Guiding Principles
- **TDD-First:** Write failing tests for each feature before implementation ✅
- **Security & Accessibility:** All features must meet security and accessibility standards ✅
- **Documentation:** Update docs and user-facing help as features are added ✅

---

## 1. Onboarding & Setup Wizard ✅ COMPLETED

**Goal:** Guide user through initial setup: detect OpenCode server, set password,
configure Cloudflared

**Tests to Write First:** ✅ COMPLETED
- [x] On first launch, onboarding wizard appears if not configured
- [x] Detects absence/presence of OpenCode server
- [x] Prompts for and validates password creation (min length, confirmation)
- [x] Cloudflared config: prompts for path, validates executable, handles errors
- [x] Onboarding completion persists config and disables wizard on next launch

**Implementation:** ✅ COMPLETED
- [x] UI: `frontend/src/pages/onboarding.astro` - Complete 6-step wizard with accessibility features
- [x] Backend: Tauri commands for detection, config persistence (`src-tauri/src/onboarding.rs`)
- [x] System requirements checking (memory, disk, network, permissions) with platform-specific implementations
- [x] OpenCode server detection with common paths checking
- [x] Configuration persistence with JSON storage in user config directory
- [x] Full test coverage with failing tests (TDD approach) - 24 frontend tests, 5 backend tests
- [x] Comprehensive accessibility features (WCAG 2.2 AA compliant)
- [x] Error handling and graceful degradation
- [x] Cross-platform support (macOS, Linux, Windows)

---

## 2. Password Authentication

**Goal:** Restrict access to dashboard with a password set during onboarding

**Tests to Write First:**
- Dashboard access denied without correct password
- Password entry UI is accessible (keyboard, screen reader)
- Password stored securely (never plaintext)
- Password reset flow (if in scope for MVP)

**Implementation:**
- UI: Login page/component
- Backend: Password verification, secure storage (hashed, salted)

---

## 3. OpenCode Server Process Management

**Goal:** Start, monitor, and stop the user's OpenCode server process

**Tests to Write First:**
- Can start OpenCode server with user-supplied path
- Detects if server is already running
- Handles process errors gracefully (bad path, port in use, etc.)
- Can stop/restart server from dashboard

**Implementation:**
- Backend: Tauri process management
- UI: Server status and controls

---

## 4. Cloudflared Tunnel Integration

**Goal:** Allow user to start/stop a Cloudflared tunnel for remote access

**Tests to Write First:**
- Can start Cloudflared tunnel with correct config
- Detects and displays tunnel status (running, error, etc.)
- Handles Cloudflared errors (missing binary, auth failure)
- Can stop tunnel from dashboard

**Implementation:**
- Backend: Tauri process management for Cloudflared
- UI: Tunnel status and controls

---

## 5. Dashboard UI & Settings

**Goal:** Provide a unified dashboard for server/tunnel management and settings

**Tests to Write First:**
- Dashboard displays server and tunnel status
- All controls are accessible and keyboard-navigable
- Settings page allows updating config (paths, password, etc.)
- Help/about section links to docs

**Implementation:**
- UI: Main dashboard page/component
- Backend: Config management

---

## 6. Continuous Documentation & Accessibility

**Goal:** Ensure all features are documented and accessible

**Tasks:**
- Update README and in-app help as features are added
- Run accessibility checks for all UI components
- Ensure all error messages are clear and actionable

---

## 7. File/Directory Map ✅ UPDATED
- **Research:** `thoughts/research/opencode-nexus-mvp-research.md` ✅
- **Plan:** `thoughts/plans/opencode-nexus-mvp-implementation.md` ✅
- **Backend:** 
  - [x] `src-tauri/src/main.rs` - Application entry point
  - [x] `src-tauri/src/lib.rs` - Tauri command handlers
  - [x] `src-tauri/src/onboarding.rs` - Onboarding system implementation
  - [x] `src-tauri/Cargo.toml` - Dependencies configuration
- **Frontend:**
  - [x] `frontend/src/layouts/Layout.astro` - Base layout with accessibility features
  - [x] `frontend/src/pages/index.astro` - Entry point with routing logic
  - [x] `frontend/src/pages/onboarding.astro` - Complete onboarding wizard
  - [x] `frontend/src/pages/dashboard.astro` - Main dashboard UI
  - [x] `frontend/src/tests/onboarding.test.ts` - Comprehensive test suite
  - [x] `frontend/package.json` - Dependencies and scripts
- **Tests:** ✅ Implemented with TDD approach
  - [x] Frontend: 24 tests covering wizard flow, accessibility, integration
  - [x] Backend: 5 tests covering system detection, config persistence

---

## Progress Summary

### ✅ Completed (Phase 1)
1. [x] Research documentation complete
2. [x] Implementation plan documentation complete  
3. [x] Onboarding & Setup Wizard fully implemented with TDD approach
4. [x] Comprehensive test coverage (frontend + backend)
5. [x] Cross-platform system detection and requirements checking
6. [x] Accessible UI components following WCAG 2.2 AA standards

### 🔄 Current Phase (Phase 2)
**Next:** Password Authentication System
- Write failing tests for authentication
- Implement secure password storage (Argon2 hashing)
- Create login UI components
- Integrate with onboarding flow

### ⏳ Upcoming Phases
- OpenCode Server Process Management
- Cloudflared Tunnel Integration  
- Dashboard completion with live data
- Final accessibility audit and compliance verification