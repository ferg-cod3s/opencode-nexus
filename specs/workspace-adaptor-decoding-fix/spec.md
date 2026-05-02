# WorkspaceAdaptor JSON Decoding Fix

## Overview

Fixes a critical bug where workspace adaptors cannot be selected in the workspace creation sheet. The `WorkspaceAdaptor` Swift model incorrectly maps the JSON field `type` (returned by the OpenCode server API) to a non-existent `id` field, causing all adaptors to decode with empty identifiers. This breaks SwiftUI's `Identifiable` conformance and prevents `Picker` selection from working.

## Context

### User Personas
- **iOS App User**: Developers using the OpenCode Nexus iOS app to manage workspaces on their OpenCode server. They need to create workspaces with different adaptors (e.g., Worktree) but cannot select any adaptor due to this bug.

### System Context
- **Module**: `ios-app/OpenCodeNexus/Models/Workspace.swift` — `WorkspaceAdaptor` struct
- **Integration Point**: `GET /experimental/workspace/adaptor` endpoint on the OpenCode server
- **API Contract**: OpenAPI spec (`openapi.json` line 449) defines the adaptor object with a `type` field, not `id`
- **Downstream Impact**: `WorkspaceManagerViewModel.loadWorkspaces()` fetches adaptors; `WorkspaceCreateSheet` displays them in a `Picker` where each item is tagged with `adaptor.id`

### Root Cause Analysis

| Layer | Expectation | Reality |
|-------|-------------|---------|
| OpenAPI spec | `type` (string, required) | `type` (string, required) |
| Server response | `{"type": "worktree", "name": "Worktree", "description": "..."}` | Same |
| Swift model (before fix) | Decodes `id` field from JSON | No `id` field exists; `decodeIfPresent` returns `""` |
| Picker behavior | Each item has unique tag | All items have tag `""`; selection impossible |

The `WorkspaceAdaptor` struct declares `let id: String` but its `init(from:)` uses `CodingKeys` (implicitly synthesized) which maps `id` to JSON key `"id"`. Since the server sends `"type"`, the decode falls back to `""`.

### Existing Patterns
- The `Workspace` model already uses explicit `CodingKeys` with custom mapping (e.g., `projectID` maps to `projectID`)
- The `Project` model decodes `worktree` directly from JSON key `"worktree"`
- All models in this codebase use `decodeIfPresent` with fallback defaults

## User Stories

### US-001: Select Workspace Adaptor During Creation
**As an** iOS app user
**I want** to select a workspace adaptor (e.g., Worktree) from the creation sheet
**So that** I can create workspaces with the correct backend type

#### Acceptance Criteria
- [ ] `WorkspaceAdaptor` correctly decodes the `type` field from the server response as its `id` property
- [ ] The `Picker` in `WorkspaceCreateSheet` displays all available adaptors with their names
- [ ] Selecting an adaptor sets `selectedAdaptor` to the adaptor's `type` value (e.g., `"worktree"`)
- [ ] The Create button is enabled when an adaptor is selected
- [ ] Creating a workspace sends the correct `type` value in the POST body

### US-002: Verify No Regression in Existing Workspace Functionality
**As an** iOS app user
**I want** existing workspace listing, creation, and management to continue working
**So that** this fix doesn't break other workspace features

#### Acceptance Criteria
- [ ] `Workspace` model still decodes correctly (unchanged)
- [ ] `WorkspaceStatus` model still decodes correctly (unchanged)
- [ ] Existing unit tests pass without modification
- [ ] `WorkspaceCreateSheet` still validates that `selectedAdaptor` is non-empty before enabling Create

## Non-Functional Requirements

### Code Quality
- Swift 6.2, iOS 26.0+ deployment target
- No comments in code (per project conventions)
- 4-space indentation, consistent with existing codebase

### Testing
- Existing unit tests must continue to pass
- No new test required for this one-line `CodingKeys` fix (covered by integration testing)

### Maintainability
- The fix should be self-documenting through the explicit `CodingKeys` enum mapping

## Technical Specification

### Files Modified

| File | Change |
|------|--------|
| `ios-app/OpenCodeNexus/Models/Workspace.swift` | Add `CodingKeys` enum to `WorkspaceAdaptor` mapping `id` to JSON key `"type"` |

### Change Detail

**Before:**
```swift
struct WorkspaceAdaptor: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}
```

**After:**
```swift
struct WorkspaceAdaptor: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id = "type"
        case name
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}
```

### Data Flow (After Fix)

```
Server Response                    Swift Decoding                    Picker Selection
─────────────────                  ──────────────                    ────────────────
[                                  WorkspaceAdaptor                  Picker("Type", selection: $selectedAdaptor)
  {                                ┌──────────────────┐              ForEach(viewModel.adaptors) { adaptor in
    "type": "worktree",            │ id = "worktree"  │              Text(adaptor.name).tag(adaptor.id)
    "name": "Worktree",     ────▶  │ name = "Worktree"│              }
    "description": "..."           │ description = ...│
  }                                └──────────────────┘              selectedAdaptor = "worktree" ✓
]
```

## Open Questions

None identified. The fix is straightforward and the API contract is unambiguous.

## Success Criteria

- [ ] `WorkspaceAdaptor.id` correctly contains the `type` value from server responses
- [ ] Users can select "Worktree" (and any other adaptor) in the workspace creation sheet
- [ ] Workspace creation succeeds with the selected adaptor type
- [ ] All existing tests pass
- [ ] No regression in `Workspace` or `WorkspaceStatus` decoding

## Specification Validation

### Completeness
- [x] User stories have acceptance criteria
- [x] Non-functional requirements defined (code quality, testing)
- [x] Technical specification with before/after code

### Clarity
- [x] No unresolved [NEEDS CLARIFICATION] markers
- [x] Root cause analysis documented
- [x] Data flow diagram included

### Alignment
- [x] Aligned with Swift 6.2 / iOS 26+ project standards
- [x] Follows existing model patterns in the codebase
- [x] No comments added (per code style convention)

### Measurability
- [x] Acceptance criteria are verifiable through UI interaction
- [x] Success criteria are specific and testable
