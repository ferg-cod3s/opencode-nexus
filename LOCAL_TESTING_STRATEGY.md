# Local Testing Strategy for GitHub Actions

## 🎯 **Problem We're Solving**

Instead of pushing changes and waiting for GitHub Actions to fail, we should test all workflows locally first using `act` and direct tool execution.

## 📋 **Current Issues Found**

### **Backend Tests (Rust)**
- ✅ **Formatting**: Fixed with `cargo fmt`
- ❌ **Compilation**: iOS targets failing on Linux (expected)
- ❌ **Dependencies**: Missing system dependencies for full build

### **Frontend Tests (TypeScript/Svelte)**
- ❌ **Linting**: 100+ ESLint errors/warnings
- ❌ **Type Safety**: Many `any` types and unused variables
- ❌ **Accessibility**: Missing ARIA roles and labels
- ❌ **CSS**: Unused selectors throughout

### **Integration Tests**
- ❌ **Docker**: Container setup issues
- ❌ **Services**: Health check failures
- ❌ **Mock Server**: SIGTERM termination issues

## 🛠️ **Local Testing Setup**

### **Prerequisites**
```bash
# Install act for GitHub Actions local testing
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Install Docker/Podman for container tests
# (Not available in current environment)

# Install system dependencies for Rust
sudo apt-get update
sudo apt-get install -y \
  pkg-config libssl-dev libwebkit2gtk-4.1-dev \
  postgresql-client redis-tools \
  clang libjavascriptcoregtk-4.1-dev
```

### **Test Commands**

#### **1. Backend Tests**
```bash
# Formatting check
cd src-tauri && cargo fmt --all --check

# Linting (Linux target only)
cd src-tauri && cargo clippy --target x86_64-unknown-linux-gnu --all-features -- -D warnings

# Unit tests (Linux target only)
cd src-tauri && cargo test --target x86_64-unknown-linux-gnu --all-features

# Full workflow with act
act -j test-backend -P ubuntu-latest=nektos/act-ubuntu:latest
```

#### **2. Frontend Tests**
```bash
# Linting
cd frontend && bun run lint

# Type checking
cd frontend && bun run typecheck

# Unit tests
cd frontend && bun test

# Full workflow with act
act -j test-frontend -P ubuntu-latest=nektos/act-ubuntu:latest
```

#### **3. Integration Tests**
```bash
# Requires Docker environment
act -j integration-test -P ubuntu-latest=nektos/act-ubuntu:latest
```

## 🚨 **Priority Fixes Needed**

### **High Priority (CI Blockers)**
1. **Frontend Linting**: Fix 100+ ESLint errors
2. **Unused Variables**: Clean up all unused imports/variables
3. **Type Safety**: Replace `any` types with proper TypeScript types
4. **Accessibility**: Add missing ARIA roles and labels

### **Medium Priority**
1. **CSS Cleanup**: Remove unused CSS selectors
2. **Integration Tests**: Fix Docker container health checks
3. **Mock Server**: Fix graceful shutdown handling

### **Low Priority**
1. **Documentation**: Add JSDoc comments
2. **Performance**: Optimize bundle sizes
3. **Testing**: Increase test coverage

## 🔄 **Development Workflow**

### **Before Any Push**
```bash
# 1. Format and lint backend
cd src-tauri && cargo fmt && cargo clippy --target x86_64-unknown-linux-gnu

# 2. Lint and type-check frontend  
cd frontend && bun run lint && bun run typecheck

# 3. Run unit tests
cd src-tauri && cargo test --target x86_64-unknown-linux-gnu
cd frontend && bun test

# 4. Only push if all pass
git add . && git commit -m "feat: changes with local testing validation"
git push origin main
```

### **Local CI Simulation**
```bash
# Test entire workflow locally
act -j test-backend,test-frontend -P ubuntu-latest=nektos/act-ubuntu:latest

# Test specific jobs
act -j test-backend -P ubuntu-latest=nektos/act-ubuntu:latest
act -j test-frontend -P ubuntu-latest=nektos/act-ubuntu:latest
```

## 📊 **Current Status**

| Component | Local Test Status | CI Status | Issues |
|-----------|------------------|------------|---------|
| Rust Formatting | ✅ Fixed | ✅ Passing | None |
| Rust Linting | ❌ Deps missing | ❌ Failing | Missing system deps |
| Frontend Linting | ❌ 100+ errors | ❌ Failing | Many ESLint issues |
| Frontend Tests | ❌ Not run | ❌ Failing | Blocked by linting |
| Integration | ❌ No Docker | ❌ Failing | Container issues |

## 🎯 **Immediate Actions**

1. **Fix Frontend Linting** (Biggest Impact)
   - Remove unused variables and imports
   - Fix accessibility issues
   - Replace `any` types
   - Clean up unused CSS

2. **Setup Local Testing Environment**
   - Install Docker/container runtime
   - Configure `act` properly
   - Add system dependencies

3. **Implement Pre-commit Hooks**
   - Automatic formatting/linting
   - Prevent bad pushes
   - Local validation

## 💡 **Recommendation**

**Stop pushing to main until frontend linting is fixed locally.** The current approach of "push and see what fails" is inefficient and wastes CI resources.

Instead:
1. Fix issues locally
2. Validate with `act` 
3. Only push when local tests pass
4. Use feature branches for experimental changes

This will reduce CI failures and improve development velocity.