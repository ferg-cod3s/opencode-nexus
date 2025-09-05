---
date: 2025-09-03T06:48:00-07:00
researcher: claude-sonnet-4
git_commit: a49c901455f76ebecb499ba526a3fdcb0bf2d6fb
branch: main
repository: opencode-nexus
topic: "CLAUDE.md and AGENTS.md Best Practices for File Linking and Context Provision"
tags: [research, documentation, ai-configuration, claude-code, agents, file-linking, context-provision]
status: complete
last_updated: 2025-09-03
last_updated_by: claude-sonnet-4
---

## Ticket Synopsis
Research and improve CLAUDE.md and AGENTS.md files to follow best practices for file linking and context provision, using web-search-researcher to verify industry standards and patterns for AI-readable documentation files.

## Summary
The research reveals significant issues with the current CLAUDE.md file including outdated project information, broken file references, and generic content that doesn't match the Tauri-based OpenCode Nexus project. In contrast, AGENTS.md demonstrates superior patterns with accurate project context and valid file references. Industry best practices for AI documentation emphasize absolute file paths, hierarchical structure, and comprehensive context provision, though official standards for CLAUDE.md files are limited.

## Detailed Findings

### Current File Analysis

#### CLAUDE.md Critical Issues (`/Users/johnferguson/Github/opencode-nexus/CLAUDE.md`)
- **Outdated Technology Stack**: Claims "Astro + Svelte stack" but project is actually Tauri + React + TypeScript
- **Broken File References**: 
  - `docs/api/README.md` (does not exist)
  - `CONTRIBUTING.md` (does not exist)
  - `.env.example` (does not exist)
- **Generic Content**: Contains monorepo patterns and commands that don't apply to this project
- **Inconsistent Path Usage**: Mixes relative and absolute paths without clear pattern

#### AGENTS.md Strengths (`/Users/johnferguson/Github/opencode-nexus/AGENTS.md`)
- **Accurate Project Description**: Correctly identifies as "Tauri-based desktop application"
- **Valid File References**: All referenced paths exist in the codebase
- **Comprehensive Context**: Provides detailed project architecture and file structure
- **Consistent Patterns**: Uses relative paths consistently for project files

### Web Research Findings

#### Limited Official Documentation
- **Anthropic Documentation**: Minimal specific guidance on CLAUDE.md structure from official sources
- **Community Standards**: CLAUDE.md files are emerging as community standard but lack standardization
- **Claude Code Tool**: Relatively new tool with limited public documentation on configuration files

#### AI Documentation Best Practices Identified
1. **Hierarchical Structure**: Use clear heading levels (H1, H2, H3) for logical organization
2. **Absolute vs Relative Paths**: 
   - Absolute paths for user-global files (`~/.claude/`)
   - Relative paths for project files (`docs/`, `src/`)
3. **Context Before Details**: Provide overview information before diving into specifics
4. **Structured Information**: Use bullet points and numbered lists for AI parsing
5. **Code Block Formatting**: All commands and examples in proper code blocks

### Existing Documentation Structure Analysis

#### Available Documentation (`/Users/johnferguson/Github/opencode-nexus/docs/`)
- `docs/ARCHITECTURE.md` - System architecture overview
- `docs/SECURITY.md` - Security model and authentication
- `docs/USER-FLOWS.md` - User experience flows
- `docs/TESTING.md` - Testing strategy and TDD approach
- `docs/DEVOPS.md` - CI/CD pipelines and deployment
- `docs/ONBOARDING.md` - Developer onboarding procedures
- `docs/PRD.md` - Product requirements document

#### Missing Documentation Links
- Neither CLAUDE.md nor AGENTS.md properly leverage the comprehensive `/docs` directory
- No systematic linking to feature documentation
- Missing cross-references between configuration files

## Code References
- `CLAUDE.md:1-274` - Current Claude Code configuration file with issues
- `AGENTS.md:1-355` - Well-structured agent configuration file
- `docs/ARCHITECTURE.md` - Comprehensive system architecture not referenced in CLAUDE.md
- `docs/SECURITY.md` - Security documentation missing from agent context
- `src-tauri/src/lib.rs` - Main Tauri command handlers not documented in CLAUDE.md

## Architecture Insights
The project follows a hybrid documentation pattern where:
- **AGENTS.md** serves as comprehensive multi-AI system configuration
- **CLAUDE.md** should serve as Claude Code-specific project instructions
- **`/docs` directory** contains detailed technical documentation
- **Disconnect exists** between high-level configuration files and detailed documentation

## Best Practices Synthesis

### CLAUDE.md Recommended Structure
```markdown
# OpenCode Nexus - Claude Code Configuration

## Project Overview
- **Technology Stack**: Tauri (Rust backend) + Astro/Svelte (frontend) + Bun runtime
- **Project Type**: Cross-platform desktop application for managing OpenCode servers
- **Architecture**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Development Commands
### Frontend Development
```bash
cd frontend
bun install && bun run dev
```

### Backend Development  
```bash
cargo tauri dev  # Full stack development
cargo test       # Backend tests
```

## Project Structure
- `/src-tauri/` - Rust backend with Tauri framework
- `/frontend/` - Astro + Svelte frontend
- `/docs/` - Comprehensive project documentation
- See: [docs/PRD.md](docs/PRD.md) for detailed requirements

## Development Guidelines
### Required Reading
- [docs/TESTING.md](docs/TESTING.md) - TDD approach mandatory
- [docs/SECURITY.md](docs/SECURITY.md) - Security requirements
- [docs/ONBOARDING.md](docs/ONBOARDING.md) - Developer setup

### Code Standards
- **Rust**: Follow patterns in [src-tauri/src/lib.rs](src-tauri/src/lib.rs)
- **TypeScript**: Strict mode enabled, see [frontend/tsconfig.json](frontend/tsconfig.json)
- **Testing**: 80-90% coverage target, TDD mandatory

## Context for AI Assistant
### Key Files
- [src-tauri/src/server_manager.rs](src-tauri/src/server_manager.rs) - OpenCode server lifecycle
- [src-tauri/src/auth.rs](src-tauri/src/auth.rs) - Authentication system
- [frontend/src/pages/dashboard.astro](frontend/src/pages/dashboard.astro) - Main UI

### Current Status
- Phase 3 complete: Server management implementation
- Next: Cloudflared tunnel integration
- Progress tracking: [TODO.md](TODO.md)
```

### File Linking Best Practices Identified

#### 1. Path Conventions
- **Project Files**: Use relative paths `docs/ARCHITECTURE.md`
- **User Global**: Use absolute paths `~/.claude/config`
- **Verification**: Ensure all referenced files exist before including

#### 2. Context Hierarchy
```
1. Project Overview (what/why)
2. Quick Start Commands (immediate needs)
3. Detailed Structure (how it's organized) 
4. Development Guidelines (standards/patterns)
5. AI-Specific Context (key files/current status)
```

#### 3. Cross-Reference Patterns
- Link to comprehensive docs: `[Full Details](docs/ARCHITECTURE.md)`
- Reference example implementations: `[Example Pattern](src/example.rs:45-67)`
- Provide current status: `[Progress Tracking](TODO.md)`

## Recommendations

### Immediate Actions Required
1. **Fix CLAUDE.md Technology Stack**: Update from "Astro + Svelte" to accurate "Tauri + Astro/Svelte"
2. **Remove Broken References**: Eliminate links to non-existent files
3. **Add Project-Specific Context**: Include Tauri-specific development commands and patterns
4. **Leverage Existing Documentation**: Link to comprehensive `/docs` directory content

### File Structure Improvements
1. **Standardize Path Usage**: Use relative paths for project files consistently
2. **Add Cross-References**: Link between CLAUDE.md, AGENTS.md, and /docs files
3. **Verify All Links**: Implement process to validate file references before committing
4. **Context Alignment**: Ensure both files reflect current project architecture

### Documentation Integration Strategy
1. **CLAUDE.md**: Focus on Claude Code-specific guidance and quick reference
2. **AGENTS.md**: Maintain comprehensive multi-AI configuration
3. **Cross-Linking**: Create systematic references between all documentation files
4. **Validation**: Regular verification of file paths and project accuracy

## Open Questions
1. Should CLAUDE.md reference the comprehensive AGENTS.md for detailed context?
2. How to maintain consistency between multiple AI configuration files?
3. What's the optimal balance between comprehensive context and quick reference?
4. Should there be a unified documentation index that links all AI configuration files?