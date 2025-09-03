# OpenCode Nexus MVP – Research Summary

## Objective
Build a cross-platform desktop app (Tauri + Astro/Svelte, Bun) that manages a
user-supplied OpenCode server, provides secure remote access via Cloudflared, and
requires password-based authentication for access. Accessibility and security are
first-class requirements.

## Key Requirements
- **Platform/Stack:** Tauri (Rust backend), Astro/Svelte (frontend), Bun
- **User-supplied OpenCode server:** Not bundled; user must install and provide
path
- **Authentication:** Simple password-based (no OAuth for MVP)
- **Remote Access:** Cloudflared is the only supported tunnel provider for MVP
- **Accessibility:** All UI must meet WCAG 2.2 AA
- **Security:** Passwords never stored in plaintext; secure process management

## Current State Analysis
- No onboarding, authentication, or Cloudflared logic exists in the codebase
- Project structure is organized into `src-tauri/` (backend), `frontend/` (UI),
and `thoughts/` (research/planning)
- Docs reviewed: `README.md`, `TODO.md`, `docs/PRD.md`, `docs/ONBOARDING.md`,
`docs/USER-FLOWS.md`, `docs/ARCHITECTURE.md`

## Constraints & Assumptions
- User must install OpenCode server separately and provide its path
- Only password authentication (no multi-user or OAuth)
- Only Cloudflared for remote access (no alternatives in MVP)
- MVP does not require advanced user management or settings

## Open Questions & Answers
- All major requirements and constraints have been clarified; no open questions
remain

## References
- `README.md`: Project overview, build instructions
- `TODO.md`: Task tracking, priorities
- `docs/PRD.md`: Product requirements, MVP scope
- `docs/ONBOARDING.md`: User onboarding flows
- `docs/USER-FLOWS.md`: End-to-end user scenarios
- `docs/ARCHITECTURE.md`: Technical architecture, security, and accessibility
guidelines

## Summary of Findings
- The MVP must implement onboarding, authentication, and Cloudflared integration
from scratch
- All features must be accessible and secure by default
- TDD-first approach is required for all new features