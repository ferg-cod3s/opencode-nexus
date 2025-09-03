---
description: Create user, API, and technical documentation from code and plans
---

# Document Feature

You are tasked with producing high-quality documentation based on the implemented feature, its plan, and the code. Deliver user-facing guides, API references, and developer notes as appropriate.

## Inputs
- <audience>: user | api | developer | mixed
- <plan>: optional path to implementation plan
- <files>: key code files for reference
- <changelog>: optional list of notable changes

## Process

1) Gather and read context
- Read <plan> if provided
- Read all <files> fully (no limit/offset)
- Skim related modules to confirm behavior and constraints

2) Choose document set by audience
- user: step-by-step how-to, screenshots/placeholders, troubleshooting
- api: endpoint/CLI reference, request/response, error codes, examples
- developer: architecture overview, data flow, invariants, extension points

3) Draft structure, then fill in details
- Present a concise outline first if scope is broad
- Keep sections short, scannable, and accurate to code

4) Validate correctness
- Cross-check examples with real code/CLI outputs
- Prefer copyable examples that run

5) Save docs
- Use `thoughts/documentation/` with descriptive filenames
- Keep one file per audience when possible

## Templates

### User Guide
```markdown
---
title: <Feature Name> - User Guide
audience: user
version: <semver or commit>
---

## Overview
Short description of the value and when to use it.

## Prerequisites
- ...

## Steps
1. ...
2. ...

## Troubleshooting
- Symptom → Cause → Fix
```

### API Reference
```markdown
---
title: <Feature Name> - API Reference
audience: api
version: <semver or commit>
---

## Endpoints / Commands
- Method/Command: Path / Name
- Request: fields and types
- Response: fields and types
- Errors: codes/messages
- Examples:
```bash
curl ...
```
```

### Developer Notes
```markdown
---
title: <Feature Name> - Developer Notes
audience: developer
version: <semver or commit>
---

## Architecture
- Components and data flow

## Key Decisions
- Rationale and implications

## Extension Points
- How to add/modify behavior safely
```

## Deliverables
- Files under `thoughts/documentation/`:
  - `YYYY-MM-DD-<feature>-user.md` (if audience includes user)
  - `YYYY-MM-DD-<feature>-api.md` (if audience includes api)
  - `YYYY-MM-DD-<feature>-dev.md` (if audience includes developer)

<audience>$ARGUMENTS</audience>
