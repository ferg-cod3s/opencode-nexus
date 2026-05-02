# Implementation Plan: WorkspaceAdaptor JSON Decoding Fix

## Spec Reference
`specs/workspace-adaptor-decoding-fix/spec.md`

## Overview
Single-file fix to map the server's `type` JSON field to the Swift model's `id` property via an explicit `CodingKeys` enum.

## Tasks

### T-001: Fix WorkspaceAdaptor CodingKeys Mapping
**Spec**: US-001
**File**: `ios-app/OpenCodeNexus/Models/Workspace.swift`
**Lines**: 82-99

**Steps**:
1. Add `enum CodingKeys: String, CodingKey` to `WorkspaceAdaptor` with `case id = "type"`
2. Verify the existing `init(from:)` already uses `CodingKeys.self` — it does, so no change needed there
3. Build and verify no compilation errors

**Acceptance**:
- `WorkspaceAdaptor` decodes `type` from JSON into `id` property
- Project compiles cleanly

### T-002: Run Existing Tests
**Spec**: US-002
**Command**: `bun run ios:test`

**Steps**:
1. Run unit tests to verify no regression
2. Confirm all tests pass

**Acceptance**:
- All existing tests pass

## Dependencies
```
T-001 → T-002
```

## Estimated Effort
- T-001: ~2 minutes (one-line enum addition)
- T-002: ~5 minutes (test execution)
- Total: ~7 minutes

## Risk Assessment
- **Risk**: Low — single struct change, no API contract modification
- **Rollback**: Revert the `CodingKeys` enum addition
