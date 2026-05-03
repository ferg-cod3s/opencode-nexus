# iOS Beta - Archive + Workspace Debug Plan

## Status: IN PROGRESS
## Date: 2026-05-02

---

## Issue Summary

User reports:
- **Session archiving not working**
- **Workspace creation not working**

Both features involve API calls to the OpenCode server.

---

## API Endpoints

| Feature | Endpoint | iOS Handler |
|--------|----------|-------------|
| Archive session | `POST /session/{id}/archive` | `ChatViewModel.archiveSession()` |
| Unarchive session | `POST /session/{id}/unarchive` | `ChatViewModel.unarchiveSession()` |
| Create workspace | `POST /experimental/workspace` | `WorkspaceManagerViewModel.createWorkspace()` |
| List adaptors | `GET /experimental/workspace/adaptor` | `OpenCodeClient.listWorkspaceAdaptors()` |

---

## Test Checklist

### Test 1: Archive

**Steps:**
1. Connect to OpenCode server
2. In sidebar, swipe left on any session
3. Tap **Archive** button

**Watch for:**
- Error toast appears? OR silently fails (doesn't move)?

**Console check (Xcode lldb):**
```
po errorMessage
po archivedSessions.count
po chatVM.directory(for: "SESSION_ID")
```

---

### Test 2: Workspace Creation

**Steps:**
1. Go to **Workspaces** tab
2. Any worktrees listed? OR empty?
3. Tap **+** button
4. Adaptor picker shows types? OR empty?
5. Select type → tap **Create**

**Console check (Xcode lldb):**
```
po adaptors.count
po errorMessage
```

---

### Test 3: Pre-Flight Check

**Console check:**
```
po chatVM.isConnected   // should be true
po chatVM.client       // should be non-nil
```

---

## User Confirmed Issues

1. **Archiving silently fails** — No error toast, session stays in active list
2. **Workspace error**: "Cannot read 'image' (this model does not support image input)"

---

## OpenCode Server Version

**Your server**: OpenCode Zen MiniMax M2.5 (version 1.14.30)

---

## Confirmed: Archive Endpoint MAY NOT EXIST

**From OpenCode API docs and GitHub research:**

| Endpoint | Status |
|----------|--------|
| `POST /session/:id/archive` | **NOT in official API docs** |
| `POST /session/:id/unarchive` | **Feature request (issue #24153)** — being worked on |

The OpenCode server API does NOT list `/session/:id/archive` as an available endpoint. Looking at the official docs:

```
GET    /session/:id    - Get session details
PATCH /session/:id    - Update session properties (title only)
DELETE /session/:id   - Delete session
```

There's no `PATCH /session/:id` with `archived` field in the documented API either.

---

## Root Cause Analysis

| Issue | Root Cause |
|-------|------------|
| Archive | **Endpoint doesn't exist on server** — iOS calls `POST /session/{id}/archive` but server returns 404 (catch block silently fails) |
| Workspace | Model doesn't support vision — "Cannot read 'image'" error from AI API |

---

## Fix Plan

### Fix 1: Archive (Server-Side Issue)

**Option A**: Use `PATCH /session/:id` with `{"time": {"archived": null}}` to set archive flag  
**Option B**: Wait for OpenCode server to add archive endpoint  
**Option C**: Use different API that already exists

Need to verify which approach works with OpenCode Zen server.

### Fix 2: Workspace (Model Selection)

The error comes from the AI model not supporting images.

**Fix**: When creating workspace, either:
- Select a vision-capable model (GPT-4o, Claude 3.5 with vision)
- Don't attach images to workspace creation

---

## USER UPDATE: Archive WORKS in Desktop/Web UI

So the server HAS the archive functionality. The issue is iOS client calling wrong endpoint or not handling response.

---

## Updated Root Cause

| Issue | Root Cause |
|-------|------------|
| Archive iOS | iOS calls `POST /session/{id}/archive` but server may expect different path (e.g., `PATCH /session/:id` with `archived` flag) |
| Workspace | Model selection doesn't support vision |

---

## Next Steps

### Fix 1: Archive - Reverse Engineer Desktop/Web API

Need to find what endpoint/path desktop/web UI uses:
- Option A: Use browser DevTools network tab to capture archive request
- Option B: Test with `curl -X PATCH` to see if `PATCH /session/:id` with `{"time": {"archived": ...}}` works

### Fix 2: Workspace

The "Cannot read 'image'" error is from the AI model - ensure vision model is selected when creating workspace.