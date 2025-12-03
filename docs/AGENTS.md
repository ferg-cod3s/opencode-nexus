# AGENTS.md – Documentation Directory

Central repository for OpenCode Nexus architecture, design, and implementation guidance.

## Documentation Structure

### Client-Specific Docs (`client/`)

| Document | Purpose | Audience |
|----------|---------|----------|
| **[ARCHITECTURE.md](client/ARCHITECTURE.md)** | System architecture & design decisions | All developers (READ FIRST) |
| **[SECURITY.md](client/SECURITY.md)** | Security implementation & best practices | Backend/security-focused devs |
| **[TESTING.md](client/TESTING.md)** | TDD approach & mobile testing strategies | All developers (MANDATORY) |
| **[PRD.md](client/PRD.md)** | Product requirements & feature specs | Product, frontend devs |
| **[USER-FLOWS.md](client/USER-FLOWS.md)** | Mobile touch interactions & offline flows | Frontend/UX devs |
| **[README.md](client/README.md)** | Complete client documentation guide | Quick reference |

## When to Reference These Docs

### For Architecture Questions
→ **[ARCHITECTURE.md](client/ARCHITECTURE.md)**
- System design and component relationships
- Data flow and communication patterns
- iOS/Android/Desktop considerations

### For Security Implementation
→ **[SECURITY.md](client/SECURITY.md)**
- Authentication and authorization
- Data encryption and storage
- Network security and TLS
- Password hashing (Argon2)
- Input validation requirements

### For Testing Guidance
→ **[TESTING.md](client/TESTING.md)** (MANDATORY)
- Test-driven development (TDD) approach
- Unit test patterns (Bun/Vitest)
- E2E test patterns (Playwright)
- Mobile-specific testing strategies
- Coverage targets (80-90% for critical paths)

### For Feature Requirements
→ **[PRD.md](client/PRD.md)**
- Feature specifications
- MVP scope and priorities
- Acceptance criteria
- Mobile-first design principles

### For Mobile Interactions
→ **[USER-FLOWS.md](client/USER-FLOWS.md)**
- Touch interaction patterns (44px targets)
- Offline capability requirements
- Session persistence flows
- Error recovery flows

## Documentation Workflow

1. **Planning Phase:** Read [ARCHITECTURE.md](client/ARCHITECTURE.md) + relevant docs
2. **Implementation:** Follow patterns in [TESTING.md](client/TESTING.md)
3. **Security Review:** Check [SECURITY.md](client/SECURITY.md)
4. **Testing:** Implement per [TESTING.md](client/TESTING.md)
5. **Update Docs:** Add new patterns or considerations discovered

## Quick Links

- **Development Status:** [status_docs/TODO.md](../status_docs/TODO.md)
- **Quick Commands:** [AGENTS.md](../AGENTS.md) (root)
- **Development Guide:** [CLAUDE.md](../CLAUDE.md)
- **Implementation Plan:** [thoughts/plans/](../thoughts/plans/)

---

**Important:** Always reference the appropriate documentation before making architectural or security decisions. Keep docs synchronized with code changes.

See [client/README.md](client/README.md) for a complete guide to the documentation structure.
