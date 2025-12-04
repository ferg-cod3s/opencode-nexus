# 🎯 Self-Hosted Runner Setup Guide

## Why This Matters

**GitHub Actions macOS runner costs:**
- `macos-14` runner: **$0.08 per minute** (10x more expensive than Linux!)
- Your previous usage: **~$1,000+/month** 🚨

**With self-hosted runner on your MacBook:**
- Cost: **$0/month** ✅
- Savings: **$1,000+/month**
- Builds: **Faster** (no queue, local network)

---

## Prerequisites

- ✅ MacBook Air (M1/M2/M3 - any Apple Silicon)
- ✅ Xcode installed (`xcode-select --install` if needed)
- ✅ GitHub account access to this repository
- ✅ ~10 minutes of setup time

---

## Setup Instructions

### Step 1: Get Registration Token from GitHub

1. Open: https://github.com/ferg-cod3s/opencode-nexus/settings/actions/runners/new
2. Select **macOS** (should be default)
3. Copy the registration token (you'll use it in Step 3)

### Step 2: Create Runner Directory on Your MacBook

Open Terminal on your MacBook and run:

```bash
mkdir -p ~/github-runner
cd ~/github-runner
```

### Step 3: Download and Extract GitHub Actions Runner

```bash
# Download the latest runner for Apple Silicon
# Check https://github.com/actions/runner/releases for latest version
curl -o actions-runner-osx-arm64-2.322.0.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-osx-arm64-2.322.0.tar.gz

# Extract
tar xzf ./actions-runner-osx-arm64-2.322.0.tar.gz
```

### Step 4: Configure the Runner

```bash
./config.sh --url https://github.com/ferg-cod3s/opencode-nexus \
            --token YOUR_TOKEN_HERE
```

**Replace `YOUR_TOKEN_HERE` with the token from Step 1**

When prompted during configuration:
- **Runner name:** `macbook-air` (or your preference)
- **Runner group:** Press Enter (default)
- **Work directory:** Press Enter (_work)
- **Labels:** Leave blank (press Enter)

### Step 5: Install as macOS Service (Auto-Start)

```bash
cd ~/github-runner
./svc.install
./svc.start
```

### Step 6: Verify Runner is Running

```bash
cd ~/github-runner
./svc.status
```

You should see output like:
```
Runner service status
status   : active
```

### Step 7: Verify in GitHub Web UI

Go to: https://github.com/ferg-cod3s/opencode-nexus/settings/actions/runners

You should see your runner listed as **IDLE** with a green dot ✅

---

## Test It Out

Push a small change to trigger workflows:

```bash
git add .
git commit -m "test: verify self-hosted runner setup"
git push origin main
```

Then check: https://github.com/ferg-cod3s/opencode-nexus/actions

The workflow should run on your MacBook (you'll see "macbook-air" or your runner name in the logs).

---

## Important Notes

### ⚠️ Your MacBook Must Be Running

- Workflows will only execute when your MacBook is on
- If you turn it off, builds will queue waiting for a runner
- The service auto-starts after MacBook restarts
- Check status: `cd ~/github-runner && ./svc.status`

### ✅ The Service Handles Everything

- Auto-starts on MacBook reboot
- Connects to GitHub automatically
- Listens for workflows to run
- No manual intervention needed

### 🔒 Security

- Registration token is unique and time-limited
- Can revoke anytime in GitHub settings
- Token is NOT stored in this repository
- Service runs as your user (not root)

---

## Troubleshooting

### Runner shows "Offline" in GitHub

```bash
cd ~/github-runner
./svc.stop
./svc.start
./svc.status
```

### See detailed logs

```bash
cd ~/github-runner
tail -f _diag/Runner_*.log
```

### Stop the service (if needed)

```bash
cd ~/github-runner
./svc.stop
```

### Completely uninstall runner

```bash
cd ~/github-runner
./svc.stop
./svc.uninstall
rm -rf ~/github-runner
```

---

## What Changed in Workflows

The following workflows now use `self-hosted` instead of `macos-14`:

1. `.github/workflows/ios-release-fixed.yml`
2. `.github/workflows/ios-release-optimized.yml`
3. `.github/workflows/test-backend.yml` (for macOS targets)

These changes:
- ✅ Eliminate macOS runner costs
- ✅ Make builds faster (local execution)
- ✅ Give you full control of build environment

---

## Support

For issues or questions:

1. Check `./svc.status` to verify runner is active
2. Review logs: `tail -f _diag/Runner_*.log`
3. See GitHub's self-hosted runner docs: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners

---

## Cost Savings Summary

| Metric | Before | After |
|--------|--------|-------|
| Monthly Cost | ~$1,000+ | $0 |
| Runner Type | `macos-14` ($0.08/min) | Your MacBook ($0/min) |
| Build Speed | ~10-15 min + queue | ~10-15 min (immediate) |
| Monthly Savings | — | **$1,000+** ✅ |

**Setup time: ~10 minutes**  
**Break-even: Immediate (first month saves $1,000+)**

