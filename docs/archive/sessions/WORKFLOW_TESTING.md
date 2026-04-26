# Testing GitHub Workflows Locally

This guide shows how to test GitHub Actions workflows before pushing to GitHub.

## Quick Start: Test Your Workflows Right Now

### Option 1: YAML Validation (Fastest, No Setup)

**Validate workflow syntax:**
```bash
# Install yamllint if needed
brew install yamllint

# Validate workflow
yamllint .github/workflows/ios-release-fixed.yml
```

**Our project:**
```bash
cd /Users/johnferguson/Github/opencode-nexus
npx yaml-lint .github/workflows/ios-release-fixed.yml
```

✅ This catches syntax errors before pushing.

---

### Option 2: Using `act` (Best for Full Testing)

`act` runs your GitHub Actions workflows locally in Docker containers.

#### Installation

```bash
# Install act
brew install act

# Verify installation
act --version
```

#### Basic Usage

```bash
# List available workflows
act --list

# Run a specific workflow
act push --workflow=.github/workflows/ios-release-fixed.yml

# Run with specific event trigger
act -j build-ios

# Run with secrets (create .secrets file first)
act --secret-file=.secrets
```

#### For Your iOS Release Workflow

```bash
cd /Users/johnferguson/Github/opencode-nexus

# Create a secrets file
cat > .actrc << 'EOF'
# Secrets for act
--container-architecture linux/arm64
--reuse-containers
EOF

# List jobs in the workflow
act --list --workflow=.github/workflows/ios-release-fixed.yml

# Run just the runner detection job
act -j detect-runner --workflow=.github/workflows/ios-release-fixed.yml

# Run full workflow (NOTE: will fail on code signing steps without real secrets)
act push --workflow=.github/workflows/ios-release-fixed.yml -s SENTRY_AUTH_TOKEN=your_token
```

#### Common `act` Flags

| Flag | Purpose |
|------|---------|
| `-j job_id` | Run specific job |
| `-l` / `--list` | List jobs |
| `-s SECRET=value` | Set secret |
| `--secret-file=.secrets` | Load secrets from file |
| `--reuse-containers` | Reuse containers between runs |
| `-b` / `--bind` | Bind working directory |
| `--verbose` | Verbose output |
| `-P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest` | Use custom container |

#### Secrets File Format

Create `.secrets` file:
```
SENTRY_AUTH_TOKEN=your_sentry_token_here
IOS_CERTIFICATE_P12=your_base64_cert_here
IOS_CERTIFICATE_PASSWORD=your_password
APP_STORE_CONNECT_API_KEY_ID=your_key_id
```

#### Limitations of Local Testing

⚠️ Some steps can't run locally:
- Code signing (requires actual iOS certificates)
- App Store Connect uploads
- TestFlight uploads
- Some GitHub-specific outputs

✅ What you CAN test locally:
- YAML syntax validation
- Step ordering and conditions
- Environment variable setup
- Bash script logic
- Dependency installation
- Build steps (without actual signing)

---

### Option 3: Extract and Test Individual Steps

Run specific workflow steps locally without `act`:

```bash
# Extract the "Get version from tag" logic
TAG_NAME="ios-v0.0.0-dev002"
VERSION=$(echo "$TAG_NAME" | sed 's/^[^0-9]*//;s/[^0-9.]*$//')
BUILD_NUMBER=$(git rev-list --count HEAD)
echo "Version: $VERSION (Build: $BUILD_NUMBER)"

# Test environment setup
export RUST_BACKTRACE=0
export RUST_LOG=warn
export NODE_ENV=production
echo "Environment ready"

# Test Rust compilation step
cd src-tauri
cargo --version
rustup target list | grep ios
```

---

### Option 4: Manual Testing via GitHub UI

**Easiest way to test without local setup:**

1. Go to Actions: `https://github.com/v1truv1us/opencode-nexus/actions`
2. Click on "iOS TestFlight Release (Fixed)"
3. Click "Run workflow"
4. Choose a tag or branch
5. Click "Run workflow" button
6. Watch logs in real-time

**Pros:**
- No local setup needed
- Real GitHub environment
- Full debug logs available

**Cons:**
- Takes 90-120 minutes for full build
- Uses GitHub's resources/quota

---

## Testing Strategy for Your Project

### For Workflow Changes

1. **Quick check** (< 1 min)
   ```bash
   npx yaml-lint .github/workflows/ios-release-fixed.yml
   ```

2. **Syntax validation** (< 1 min)
   ```bash
   act --list --workflow=.github/workflows/ios-release-fixed.yml
   ```

3. **Test individual steps** (5-10 min)
   ```bash
   # Test version extraction
   TAG_NAME="ios-v0.0.0-dev002"
   VERSION=$(echo "$TAG_NAME" | sed 's/^[^0-9]*//;s/[^0-9.]*$//')
   echo "Extracted version: $VERSION"
   
   # Test frontend build
   cd frontend
   bun run typecheck
   
   # Test Rust build
   cd ../src-tauri
   cargo build --lib
   ```

4. **Full workflow test** (90-120 min)
   - Push tag to GitHub
   - Monitor via Actions tab

### Recommended Workflow

```bash
# Step 1: Validate YAML
npx yaml-lint .github/workflows/ios-release-fixed.yml

# Step 2: Test code quality
cd frontend && bun run typecheck && cd ..
cd src-tauri && cargo test --lib && cargo clippy && cd ..

# Step 3: Push to GitHub (only after Step 1 & 2 pass)
git push origin main
git push origin ios-v0.0.0-dev002

# Step 4: Monitor via GitHub Actions
open https://github.com/v1truv1us/opencode-nexus/actions
```

---

## Debugging Workflow Failures

When a workflow fails:

1. **Check logs**
   - GitHub Actions UI shows step-by-step logs
   - Click on failed step for full output

2. **Enable debug logging**
   ```bash
   # In workflow, add:
   # env:
   #   ACTIONS_STEP_DEBUG: true
   ```

3. **Check environment**
   ```bash
   # In workflow step:
   run: |
     echo "Current directory: $(pwd)"
     echo "Available disk: $(df -h .)"
     echo "Memory: $(vm_stat | head -1)"
     echo "Rust: $(rustc --version)"
   ```

4. **Use workflow visualizer**
   - GitHub shows dependency graph of jobs
   - Check `if:` conditions

5. **Reproduce locally**
   - Extract failing step commands
   - Run in local terminal
   - Debug before re-pushing

---

## Pro Tips

### Install act Faster

```bash
# Using Homebrew (fastest)
brew install act

# Or using direct download
wget https://github.com/nektos/act/releases/download/v0.2.63/act_Darwin_arm64.tar.gz
tar xzf act_Darwin_arm64.tar.gz
sudo mv act /usr/local/bin/
```

### Use act with GitHub Container Registry

```bash
# Use official GitHub Actions runner image
act -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-latest
```

### Cache Dependencies in act

```bash
# Use reuse-containers to speed up multiple runs
act --reuse-containers
```

### Skip Non-Essential Steps

```bash
# Create .actrc to skip code signing
--env-file .env.test
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `act: command not found` | Install with `brew install act` |
| Docker container issues | Restart Docker and try `act --reuse-containers` |
| Secret not found | Use `--secret-file=.secrets` flag |
| Slow first run | First run builds Docker image; subsequent runs faster |
| Workflow syntax errors | Run `npx yaml-lint` before pushing |
| Memory issues | Increase Docker memory allocation |

---

## Next Steps

1. **Install act** (optional, but recommended)
   ```bash
   brew install act
   ```

2. **Validate workflows**
   ```bash
   npx yaml-lint .github/workflows/ios-release-fixed.yml
   ```

3. **Test code locally**
   ```bash
   cd src-tauri && cargo test --lib
   cd ../frontend && bun run typecheck
   ```

4. **Push and monitor**
   ```bash
   git push origin main && git push origin ios-v0.0.0-dev002
   ```

5. **Watch GitHub Actions**
   ```bash
   open https://github.com/v1truv1us/opencode-nexus/actions
   ```

---

## Resources

- **act GitHub**: https://github.com/nektos/act
- **act Documentation**: https://nektosact.com/
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Workflow Syntax**: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
