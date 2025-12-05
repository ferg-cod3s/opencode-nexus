# CI/CD Integration Test Fixes Implementation Plan

**Date:** 2025-12-05  
**Status:** Ready for Implementation  
**PR Affected:** #35 (docs/ios-app-clarification)  
**Priority:** P0 - Blocking PR merge

---

## Executive Summary

The integration test workflow is failing due to 5 distinct issues. This plan breaks down the fixes into atomic, independently executable tasks that can be completed in chunks.

---

## Acceptance Criteria

- [ ] All 3 jobs in `test-integration.yml` pass or are intentionally skipped
- [ ] PR #35 CI checks turn green
- [ ] No new warnings introduced
- [ ] Changes are backwards compatible
- [ ] Documentation updated for skipped tests

---

## Issues Overview

| ID | Issue | Severity | Estimated Time |
|----|-------|----------|----------------|
| FIX-01 | Invalid Bun `cache` parameter | Critical | 5 min |
| FIX-02 | Missing `mock-server/` directory | Critical | 15 min |
| FIX-03 | Missing backend integration tests | Medium | 5 min |
| FIX-04 | Missing frontend integration tests | Medium | 5 min |
| FIX-05 | API test job depends on missing CLI | Medium | 5 min |

---

## Atomic Tasks

### Task 1: Fix Bun Setup Action (FIX-01)

**File:** `.github/workflows/test-integration.yml`  
**Lines:** 60-64, 162-166  
**Time:** 5 minutes  
**Dependencies:** None

#### Problem
The `oven-sh/setup-bun@v1` action doesn't support a `cache` parameter. The workflow incorrectly uses `cache: 'frontend'`.

#### Changes Required

**Change 1a - Line 60-64 (integration-test job):**

```yaml
# BEFORE:
- name: Setup Bun
  uses: oven-sh/setup-bun@v1
  with:
    bun-version: latest
    cache: 'frontend'

# AFTER:
- name: Setup Bun
  uses: oven-sh/setup-bun@v2
  with:
    bun-version: latest
```

**Change 1b - Line 162-166 (api-integration-test job):**

```yaml
# BEFORE:
- name: Setup Bun
  uses: oven-sh/setup-bun@v1
  with:
    bun-version: latest
    cache: 'frontend'

# AFTER:
- name: Setup Bun
  uses: oven-sh/setup-bun@v2
  with:
    bun-version: latest
```

#### Validation
```bash
# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test-integration.yml'))"
```

---

### Task 2: Fix Mock Server Dockerfile (FIX-02)

**File:** `tests/integration/Dockerfile.mock-server`  
**Time:** 15 minutes  
**Dependencies:** None

#### Problem
The Dockerfile references a non-existent `mock-server/` directory and `package*.json` files.

#### Changes Required

Replace entire file content with self-contained mock server:

```dockerfile
# Mock OpenCode Server for Testing
FROM node:20-alpine

WORKDIR /app

# Install only express (needed for mock server)
RUN npm init -y && npm install express

# Copy mock data files
COPY tests/integration/mock-server-data/ ./data/

# Create inline mock server
RUN cat > server.js << 'SERVEREOF'
const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(express.json());

// Health check
app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok", timestamp: new Date().toISOString() });
});

// Load mock data helper
const loadData = (file) => {
  try {
    return JSON.parse(fs.readFileSync(path.join(__dirname, "data", file), "utf8"));
  } catch (e) {
    console.error(`Failed to load ${file}:`, e.message);
    return [];
  }
};

// API endpoints matching OpenCode SDK expectations
app.get("/api/models", (req, res) => res.json(loadData("models.json")));
app.get("/api/sessions", (req, res) => res.json(loadData("sessions.json")));
app.get("/api/sessions/:id", (req, res) => {
  const sessions = loadData("sessions.json");
  const session = sessions.find(s => s.id === req.params.id);
  if (session) {
    res.json(session);
  } else {
    res.status(404).json({ error: "Session not found" });
  }
});
app.get("/api/sessions/:id/messages", (req, res) => res.json(loadData("messages.json")));
app.get("/api/files", (req, res) => res.json(loadData("files.json")));

// Echo endpoint for chat testing
app.post("/api/chat", (req, res) => {
  res.json({
    id: "test-response-" + Date.now(),
    content: "Mock response to: " + (req.body?.content || "empty"),
    role: "assistant",
    created_at: new Date().toISOString()
  });
});

// Streaming endpoint (SSE)
app.post("/api/chat/stream", (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  
  const chunks = ["Hello", " from", " mock", " server", "!"];
  let i = 0;
  const interval = setInterval(() => {
    if (i < chunks.length) {
      res.write(`data: ${JSON.stringify({ content: chunks[i], done: false })}\n\n`);
      i++;
    } else {
      res.write(`data: ${JSON.stringify({ content: "", done: true })}\n\n`);
      clearInterval(interval);
      res.end();
    }
  }, 100);
});

const PORT = process.env.PORT || 4096;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Mock OpenCode server running on port ${PORT}`);
});
SERVEREOF

EXPOSE 4096

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost:4096/health || exit 1

CMD ["node", "server.js"]
```

#### Validation
```bash
# Test Docker build locally
docker build -f tests/integration/Dockerfile.mock-server -t mock-opencode-test .
docker run -d -p 4096:4096 --name test-mock mock-opencode-test
sleep 5
curl http://localhost:4096/health
docker stop test-mock && docker rm test-mock
```

---

### Task 3: Skip Backend Integration Tests (FIX-03)

**File:** `.github/workflows/test-integration.yml`  
**Lines:** 101-107  
**Time:** 5 minutes  
**Dependencies:** None

#### Problem
`cargo test --test integration` requires `src-tauri/tests/integration.rs` which doesn't exist.

#### Changes Required

```yaml
# BEFORE:
- name: Run backend integration tests
  working-directory: ./src-tauri
  env:
    DATABASE_URL: postgresql://test_user:test_password@localhost:5432/opencode_test
    REDIS_URL: redis://localhost:6379
    RUST_LOG: debug
  run: cargo test --test integration --all-features

# AFTER:
- name: Run backend integration tests
  working-directory: ./src-tauri
  env:
    DATABASE_URL: postgresql://test_user:test_password@localhost:5432/opencode_test
    REDIS_URL: redis://localhost:6379
    RUST_LOG: debug
  run: |
    echo "⏭️ Backend integration tests skipped - not yet implemented"
    echo "TODO: Create src-tauri/tests/integration.rs"
    # cargo test --test integration --all-features
```

---

### Task 4: Skip Frontend Integration Tests (FIX-04)

**File:** `.github/workflows/test-integration.yml`  
**Lines:** 109-115  
**Time:** 5 minutes  
**Dependencies:** None

#### Problem
`bun test src/tests/integration/` expects a directory that doesn't exist.

#### Changes Required

```yaml
# BEFORE:
- name: Run frontend integration tests
  working-directory: ./frontend
  env:
    NODE_ENV: test
    VITE_DATABASE_URL: postgresql://test_user:test_password@localhost:5432/opencode_test
    VITE_REDIS_URL: redis://localhost:6379
  run: bun test src/tests/integration/

# AFTER:
- name: Run frontend integration tests
  working-directory: ./frontend
  env:
    NODE_ENV: test
    VITE_DATABASE_URL: postgresql://test_user:test_password@localhost:5432/opencode_test
    VITE_REDIS_URL: redis://localhost:6379
  run: |
    echo "⏭️ Frontend integration tests skipped - not yet implemented"
    echo "TODO: Create frontend/src/tests/integration/ directory"
    # bun test src/tests/integration/
```

---

### Task 5: Disable API Integration Test Job (FIX-05)

**File:** `.github/workflows/test-integration.yml`  
**Lines:** 154-188  
**Time:** 5 minutes  
**Dependencies:** None

#### Problem
The `api-integration-test` job depends on:
1. `bun run opencode:start` which requires the `opencode` CLI
2. The CLI is not installed in CI

#### Changes Required

Add `if: false` to disable the job until proper mock infrastructure is ready:

```yaml
# BEFORE:
api-integration-test:
  name: API Integration Tests
  runs-on: ubuntu-latest

# AFTER:
api-integration-test:
  name: API Integration Tests
  runs-on: ubuntu-latest
  # Temporarily disabled until mock server infrastructure is ready
  # TODO: Enable when Docker-based mock server is integrated
  if: false
```

---

## Implementation Order

Execute tasks in this order for minimal risk:

```
┌──────────────────────────────────────────────────────────────┐
│  Phase 1: Critical Fixes (unblocks CI)                       │
│  ┌────────────┐    ┌────────────┐                           │
│  │  Task 1    │───▶│  Task 5    │  (Can be parallel)        │
│  │  Bun fix   │    │ Disable API│                           │
│  └────────────┘    └────────────┘                           │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 2: Skip Non-implemented Tests                         │
│  ┌────────────┐    ┌────────────┐                           │
│  │  Task 3    │    │  Task 4    │  (Can be parallel)        │
│  │ Skip Rust  │    │ Skip Front │                           │
│  └────────────┘    └────────────┘                           │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  Phase 3: Docker Infrastructure                              │
│  ┌────────────┐                                              │
│  │  Task 2    │                                              │
│  │ Dockerfile │                                              │
│  └────────────┘                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Testing Strategy

### Pre-commit Validation
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test-integration.yml'))"

# Validate Dockerfile syntax
docker build -f tests/integration/Dockerfile.mock-server -t test-mock . --dry-run 2>/dev/null || echo "Note: --dry-run may not be supported, actual build will validate"
```

### Post-push Validation
1. Push changes to branch
2. Monitor GitHub Actions run: https://github.com/v1truv1us/opencode-nexus/actions
3. Verify all jobs pass or are correctly skipped

### Local Docker Test (Optional)
```bash
# Build and test mock server
docker build -f tests/integration/Dockerfile.mock-server -t mock-opencode .
docker run -d -p 4096:4096 --name mock-test mock-opencode
sleep 5

# Test endpoints
curl http://localhost:4096/health
curl http://localhost:4096/api/models
curl http://localhost:4096/api/sessions

# Cleanup
docker stop mock-test && docker rm mock-test
```

---

## Potential Risks

| Risk | Mitigation |
|------|------------|
| YAML syntax error | Validate with Python yaml parser before commit |
| Docker build failure | Test build locally before push |
| Skipped tests hide real issues | Add TODO comments and track in GitHub issues |
| Breaking other workflows | Changes are isolated to `test-integration.yml` |

---

## Rollback Plan

If issues arise after deployment:

```bash
# Revert the changes
git revert HEAD

# Or restore specific file
git checkout HEAD~1 -- .github/workflows/test-integration.yml
```

---

## Future Work (Out of Scope)

These improvements should be tracked as separate issues:

1. **Implement Backend Integration Tests**
   - Create `src-tauri/tests/integration.rs`
   - Add database connectivity tests
   - Add Redis connectivity tests

2. **Implement Frontend Integration Tests**
   - Create `frontend/src/tests/integration/` directory
   - Add server connection tests
   - Add API response validation tests

3. **Create Proper Mock Server Infrastructure**
   - Move inline server to `tests/integration/mock-server/`
   - Add more comprehensive mock endpoints
   - Add WebSocket/SSE mock support

4. **Enable API Integration Tests**
   - Use Docker-based mock server instead of CLI
   - Update workflow to use containerized testing

---

## Checklist

- [ ] Task 1: Fix Bun setup action (both occurrences)
- [ ] Task 2: Fix Dockerfile.mock-server
- [ ] Task 3: Skip backend integration tests
- [ ] Task 4: Skip frontend integration tests  
- [ ] Task 5: Disable API integration test job
- [ ] Validate YAML syntax locally
- [ ] Push and verify CI passes
- [ ] Update PR description if needed

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `.github/workflows/test-integration.yml` | Fix Bun action, skip tests, disable API job |
| `tests/integration/Dockerfile.mock-server` | Replace with self-contained mock server |

**Total Estimated Time:** 35 minutes
