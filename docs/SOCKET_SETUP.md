# Socket.dev Supply Chain Security Setup

Socket.dev provides real-time supply chain security scanning for npm and Cargo dependencies, detecting malicious packages, supply chain attacks, and security vulnerabilities.

## Features

Socket.dev protects against:
- 🔍 **Malicious packages** - Detects known malware and backdoors
- 🔗 **Supply chain attacks** - Identifies dependency confusion and substitution attacks
- 📦 **Dependency confusion** - Prevents internal package name squatting
- 🎯 **Typosquatting** - Catches packages with names similar to popular libraries
- 🔧 **Install scripts** - Analyzes risky install/postinstall scripts
- 🌐 **Network activity** - Flags packages making unexpected network calls
- 📁 **Filesystem access** - Detects unauthorized file system operations
- 🔐 **Obfuscated code** - Identifies heavily obfuscated or minified code
- 🚨 **Privileged API access** - Warns about packages using sensitive APIs

## Setup Instructions

### 1. Create Socket.dev Account

1. Go to [socket.dev](https://socket.dev/)
2. Sign up with your GitHub account
3. Authorize Socket.dev to access your repositories

### 2. Create a New Project

1. In Socket.dev dashboard, click **"New Project"**
2. Select **"OpenCode Nexus"** repository
3. Choose package managers: **npm** and **Cargo**
4. Copy your **Project ID** (you'll need this for GitHub Secrets)

### 3. Generate API Token

1. Go to **Settings** → **API Tokens**
2. Click **"Generate New Token"**
3. Name it: `github-actions-opencode-nexus`
4. Set permissions: **Read & Write**
5. Copy the token (shown only once!)

### 4. Add GitHub Secrets

1. Go to your GitHub repository: `Settings` → `Secrets and variables` → `Actions`
2. Click **"New repository secret"**
3. Add two secrets:

   **Secret 1:**
   - Name: `SOCKET_PROJECT_ID`
   - Value: `<your-project-id-from-step-2>`

   **Secret 2:**
   - Name: `SOCKET_API_TOKEN`
   - Value: `<your-api-token-from-step-3>`

### 5. Verify Setup

1. Create a test PR or push to `main`/`develop`
2. Check **Actions** tab for "Socket Security" workflow
3. Verify scan completes successfully
4. Check PR for Socket.dev comment with scan results

## Workflow Behavior

### On Pull Requests
- ✅ Scans all dependency changes
- ✅ Posts comment with results
- ✅ Blocks merge if critical issues found
- ✅ Provides detailed issue explanations

### On Push to main/develop
- ✅ Scans current dependencies
- ✅ Uploads results to Socket.dev dashboard
- ✅ Sends notifications for new issues

### Manual Trigger
- ✅ Can be run manually via Actions tab
- ✅ Useful for ad-hoc security audits

## Understanding Socket Scan Results

### Severity Levels

- **🔴 Critical** - Block PR, immediate action required
  - Known malware
  - Active exploits
  - Supply chain attacks

- **🟠 High** - Review carefully before merging
  - Suspicious patterns
  - Risky install scripts
  - Unexpected network activity

- **🟡 Medium** - Monitor and plan to fix
  - Deprecated packages
  - Outdated dependencies
  - Minor security concerns

- **🟢 Low** - Informational only
  - Code quality issues
  - Best practice violations

### Common Issues

**Install Scripts**
```
⚠️ Package runs install script with network access
```
**Action**: Review the install script in node_modules or Cargo.toml

**Obfuscated Code**
```
⚠️ Package contains heavily obfuscated code
```
**Action**: Check if obfuscation is legitimate (e.g., minified production code)

**Filesystem Access**
```
⚠️ Package reads/writes to filesystem outside project
```
**Action**: Verify this is expected behavior for the package

**Network Activity**
```
⚠️ Package makes network requests during install
```
**Action**: Ensure requests are to legitimate domains

## Configuration Options

### Customize Severity Threshold

Edit `.github/workflows/socket-security.yml`:

```yaml
issue-severity: high  # Options: critical, high, medium, low
```

### Disable PR Blocking

```yaml
fail-on-critical: false
```

### Disable PR Comments

```yaml
comment-pr: false
```

### Scan Specific Directories

```yaml
with:
  project-id: ${{ secrets.SOCKET_PROJECT_ID }}
  api-token: ${{ secrets.SOCKET_API_TOKEN }}
  paths: |
    frontend/package.json
    src-tauri/Cargo.toml
```

## Monitoring Dashboard

Access your Socket.dev dashboard at:
```
https://socket.dev/dashboard/<your-org>/<your-project>
```

Features:
- 📊 Real-time dependency graph
- 🔍 Vulnerability timeline
- 📈 Security score trends
- 🚨 Alert notifications
- 📋 Detailed issue reports

## Troubleshooting

### Workflow Fails with "Invalid API Token"

**Solution**: Regenerate token and update `SOCKET_API_TOKEN` secret

### Workflow Skipped on PR

**Solution**: Ensure workflow file is on the base branch (main/develop)

### False Positives

**Solution**: Create exceptions in Socket.dev dashboard:
1. Go to issue in dashboard
2. Click **"Mark as False Positive"**
3. Add explanation
4. Future scans will ignore this issue

### Scan Takes Too Long

**Solution**: Socket scans are usually fast (<30s). If slow:
- Check Socket.dev service status
- Reduce number of dependencies if possible
- Contact Socket.dev support

## Integration with Other Security Tools

Socket.dev complements existing security scanning:

| Tool | Purpose | Socket.dev Advantage |
|------|---------|---------------------|
| npm audit | Known CVEs | Real-time supply chain detection |
| Dependabot | Dependency updates | Behavioral analysis |
| CodeQL | Code analysis | Package-level security |
| Trivy | Container scanning | Install-time threat detection |

## Best Practices

1. ✅ **Review all Socket alerts** before merging PRs
2. ✅ **Keep dependencies minimal** - fewer packages = smaller attack surface
3. ✅ **Pin dependency versions** - prevents unexpected updates
4. ✅ **Audit new dependencies** - manually review before adding
5. ✅ **Monitor dashboard weekly** - stay informed of new threats
6. ✅ **Update promptly** - apply security patches quickly
7. ✅ **Use lockfiles** - commit package-lock.json and Cargo.lock

## Additional Resources

- [Socket.dev Documentation](https://docs.socket.dev/)
- [Socket.dev GitHub Action](https://github.com/SocketDev/socket-security-action)
- [Supply Chain Security Guide](https://socket.dev/guides/supply-chain-security)
- [Socket Blog](https://socket.dev/blog)

## Support

- **Socket.dev Support**: support@socket.dev
- **GitHub Issues**: [SocketDev/socket-security-action](https://github.com/SocketDev/socket-security-action/issues)
- **Community**: [Socket Slack](https://socket.dev/slack)

---

**Status**: ⚠️ **Setup Required**

Follow steps 1-4 above to complete Socket.dev integration.
