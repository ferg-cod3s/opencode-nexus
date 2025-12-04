# Self-Hosted Runner Operations Guide

**Purpose**: Complete operational guide for managing self-hosted GitHub Actions runner  
**Target Audience**: DevOps engineers, system administrators, developers  
**Last Updated**: December 4, 2025

---

## 🎯 Quick Reference

| Command | Purpose | Location |
|---------|---------|----------|
| `./runner-health-check.sh` | Full health assessment | `scripts/` |
| `./runner-monitor.sh` | Real-time monitoring dashboard | `scripts/` |
| `./runner-restart.sh` | Safe runner restart | `scripts/` |
| `./svc.sh status` | Service status | `~/github-runner/` |
| `./svc.sh restart` | Service restart | `~/github-runner/` |

---

## 🏥 Runner Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Workflows                              │
│  (ios-release-*.yml, test-backend.yml, etc.)                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                    ┌────▼────────────────────┐
                    │  Runner Detection       │
                    │  (runner-detection.yml) │
                    └────┬────────────────────┘
                         │
         ┌───────────────┴────────────────┐
         │                                │
    ┌────▼────────────┐      ┌─────────▼────────────┐
    │  Self-Hosted    │      │  GitHub-Hosted       │
    │  macOS Runner   │      │  Fallback Runner     │
    │                 │      │                      │
    │  • MacBook Air  │      │  • macos-14         │
    │  • M-series CPU │      │  • $0.08/min        │
    │  • $0/min       │      │  • Always available   │
    └────────┬────────┘      └───────────────────────┘
             │
    ┌────────▼────────┐
    │  Health Monitor │
    │                 │
    │  • Daily checks │
    │  • Alerts      │
    │  • Metrics     │
    └─────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

- **Hardware**: MacBook Air/Pro with M1/M2/M3 chip
- **OS**: macOS 14+ (Sonoma)
- **Software**: Xcode 15.4+, Git, curl, jq
- **Network**: Stable internet connection
- **Storage**: Minimum 10GB free space

### Initial Setup

1. **Install Runner** (if not already done):
   ```bash
   mkdir -p ~/github-runner
   cd ~/github-runner
   
   # Download latest runner
   curl -o actions-runner-osx-arm64-2.322.0.tar.gz \
     -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-osx-arm64-2.322.0.tar.gz
   
   # Extract and configure
   tar xzf ./actions-runner-osx-arm64-2.322.0.tar.gz
   ./config.sh --url https://github.com/YOUR_REPO \
               --token YOUR_TOKEN
   ```

2. **Install as Service**:
   ```bash
   cd ~/github-runner
   ./svc.install
   ./svc.start
   ```

3. **Verify Installation**:
   ```bash
   cd ~/github-runner
   ./svc.status
   ```

---

## 🔧 Daily Operations

### Health Checks

#### Automated Daily Health Check
- **Trigger**: GitHub Actions workflow (2 AM UTC)
- **Location**: `.github/workflows/runner-health-check.yml`
- **Actions**: 
  - Check runner status via GitHub API
  - Verify system resources (CPU, memory, disk)
  - Test network connectivity
  - Generate health report
  - Alert on issues

#### Manual Health Check
```bash
# From repository root
./scripts/runner-health-check.sh

# Or from runner directory
cd ~/github-runner
../../scripts/runner-health-check.sh
```

**Health Check Components**:
- ✅ Service status verification
- ✅ System resource monitoring
- ✅ Network connectivity testing
- ✅ Configuration validation
- ✅ Recent job performance analysis

### Monitoring

#### Real-Time Monitoring Dashboard
```bash
# Start interactive monitoring
./scripts/runner-monitor.sh

# Or run in background
nohup ./scripts/runner-monitor.sh > /dev/null 2>&1 &
```

**Dashboard Features**:
- 🖥️ Live system metrics (CPU, memory, disk)
- 🏃 Runner service status
- 🌐 Network connectivity
- 📊 Active job count
- 🚨 Real-time alerts
- ⌨️ Interactive controls (restart, health check)

#### Monitoring Configuration
```bash
# Environment variables for monitoring
export MONITOR_INTERVAL=60          # Check every 60 seconds
export ALERT_THRESHOLD_CPU=80        # Alert at 80% CPU
export ALERT_THRESHOLD_MEMORY=85     # Alert at 85% memory
export ALERT_THRESHOLD_DISK=90       # Alert at 90% disk
export LOG_RETENTION_DAYS=7         # Keep logs for 7 days
```

---

## 🔄 Maintenance Procedures

### Routine Maintenance

#### Daily (Automated)
- ✅ Health check workflow runs
- ✅ Log rotation and cleanup
- ✅ Metrics collection
- ✅ Alert notifications

#### Weekly (Manual)
```bash
# 1. Review runner performance
./scripts/runner-health-check.sh

# 2. Check for system updates
softwareupdate --list

# 3. Review recent logs
cd ~/github-runner
tail -50 _diag/Runner_*.log

# 4. Monitor disk usage
df -h ~/github-runner
```

#### Monthly (Manual)
```bash
# 1. Full system cleanup
./scripts/runner-health-check.sh --cleanup

# 2. Review cost savings
# Check GitHub Actions cost tracking workflow results

# 3. Update runner if needed
cd ~/github-runner
# Check for newer runner versions
```

### Service Management

#### Start/Stop/Restart
```bash
cd ~/github-runner

# Check status
./svc.sh status

# Stop service
./svc.sh stop

# Start service
./svc.sh start

# Restart service
./svc.sh restart
```

#### Using Management Scripts
```bash
# Safe restart with job waiting
./scripts/runner-restart.sh

# Quick status check
./scripts/runner-restart.sh status

# Force stop
./scripts/runner-restart.sh stop

# Force start
./scripts/runner-restart.sh start
```

---

## 🚨 Troubleshooting

### Common Issues

#### Runner Offline
**Symptoms**:
- Jobs fail with "no available runners"
- GitHub shows runner as offline
- Health check reports "inactive" status

**Solutions**:
```bash
# 1. Check service status
cd ~/github-runner
./svc.sh status

# 2. If inactive, restart
./scripts/runner-restart.sh

# 3. Check network connectivity
curl -s https://github.com >/dev/null && echo "OK" || echo "Network issue"

# 4. Review logs for errors
tail -50 _diag/Runner_*.log

# 5. Check system resources
df -h ~/github-runner
top -l 1 | head -10
```

#### High Resource Usage
**Symptoms**:
- Slow job execution
- System becomes unresponsive
- Health check shows resource warnings

**Solutions**:
```bash
# 1. Check current usage
./scripts/runner-monitor.sh

# 2. Identify resource-intensive processes
top -o cpu -l 1
top -o mem -l 1

# 3. Clear disk space if needed
cd ~/github-runner
rm -rf _diag/Runner_*.log.old
rm -rf target/debug
rm -rf target/release

# 4. Restart runner to clear memory
./scripts/runner-restart.sh
```

#### Network Connectivity Issues
**Symptoms**:
- Runner cannot connect to GitHub
- Jobs timeout during checkout
- Health check shows network offline

**Solutions**:
```bash
# 1. Test basic connectivity
ping -c 4 github.com
curl -I https://api.github.com

# 2. Check DNS
nslookup github.com
nslookup api.github.com

# 3. Test from runner
cd ~/github-runner
./run.sh --check  # If supported

# 4. Restart network services
sudo dscacheutil -flushcache
sudo pkill -HUP mDNSResponder
```

#### Job Failures
**Symptoms**:
- Jobs start but fail during execution
- Inconsistent failure patterns
- Error logs show build issues

**Solutions**:
```bash
# 1. Review job logs
cd ~/github-runner
grep -A 10 -B 5 "ERROR" _diag/Runner_*.log

# 2. Check runner configuration
cat .runner
cat .credentials

# 3. Verify tools and dependencies
which git xcodebuild rustc
git --version
xcodebuild -version
rustc --version

# 4. Test manual job execution
# Create a simple test workflow to isolate the issue
```

### Emergency Procedures

#### Complete Runner Recovery
```bash
# 1. Stop all runner processes
cd ~/github-runner
./svc.sh stop
pkill -f "Runner.Listener"
pkill -f "Runner.Worker"

# 2. Backup configuration
cp .runner .runner.backup
cp .credentials .credentials.backup

# 3. Clean and restart
rm -rf _diag
./svc.sh start

# 4. Verify registration
./svc.sh status
```

#### Runner Re-registration
```bash
# 1. Remove old registration
cd ~/github-runner
./config.sh remove --token REMOVE_TOKEN

# 2. Get new token from GitHub
# Visit: https://github.com/YOUR_REPO/settings/actions/runners/new

# 3. Re-register
./config.sh --url https://github.com/YOUR_REPO \
            --token NEW_TOKEN

# 4. Restart service
./svc.sh restart
```

---

## 📊 Performance Optimization

### System Tuning

#### macOS Optimization
```bash
# 1. Optimize energy settings for consistent performance
sudo pmset -c disablesleep 0
sudo pmset -c displaysleep 0

# 2. Increase file limits
echo 'kern.maxfiles=65536' | sudo tee -a /etc/sysctl.conf
echo 'kern.maxfilesperproc=65536' | sudo tee -a /etc/sysctl.conf

# 3. Optimize network settings
sudo sysctl -w net.inet.tcp.msl=1000
sudo sysctl -w net.inet.tcp.always_keepalive=1
```

#### Runner Configuration
```bash
# 1. Optimize runner settings
cd ~/github-runner

# Edit .runner file for performance
# - Increase concurrent job limit if hardware supports
# - Optimize cache settings
# - Configure resource limits

# 2. Set environment variables
echo "export RUST_LOG=warn" >> .env
echo "export CARGO_TARGET_DIR=/tmp/target" >> .env
echo "export BUN_INSTALL_CACHE=/tmp/bun" >> .env
```

### Cache Optimization

#### GitHub Actions Cache
```yaml
# In workflow files
- name: Optimize Cache
  uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/registry
      ~/.cargo/git
      target
      frontend/node_modules
    key: ${{ runner.os }}-optimized-${{ hashFiles('**/Cargo.lock', '**/package.json') }}
    restore-keys: |
      ${{ runner.os }}-optimized-
      ${{ runner.os }}-
```

#### Local Cache Management
```bash
# Regular cleanup script
#!/bin/bash
cd ~/github-runner

# Clean old build artifacts
find . -name "target" -type d -mtime +7 -exec rm -rf {} +
find . -name "node_modules" -type d -mtime +7 -exec rm -rf {} +

# Clean old logs
find _diag -name "*.log" -mtime +30 -delete

# Optimize cargo cache
cargo cache --dir ~/.cargo --gc
```

---

## 📈 Monitoring and Alerting

### Key Metrics

#### System Metrics
- **CPU Usage**: Alert at 80%, Critical at 95%
- **Memory Usage**: Alert at 85%, Critical at 95%
- **Disk Usage**: Alert at 90%, Critical at 98%
- **Network Latency**: Alert at >1000ms to GitHub

#### Runner Metrics
- **Uptime**: Target 99.5%+
- **Job Success Rate**: Target 95%+
- **Average Job Duration**: Track trends
- **Queue Time**: Should be <1 minute

#### Cost Metrics
- **Self-Hosted Utilization**: Target 85%+
- **Monthly Savings**: Track and optimize
- **Cost per Job**: Monitor and reduce

### Alert Configuration

#### GitHub Actions Alerts
```yaml
# In workflow files
- name: Alert on High Resource Usage
  if: failure()
  run: |
    echo "::error::High resource usage detected"
    echo "Check runner health: ./scripts/runner-health-check.sh"
```

#### Local Monitoring Alerts
```bash
# Configure email alerts (optional)
export ALERT_EMAIL="admin@company.com"
export SMTP_SERVER="smtp.company.com"

# Or use Slack/webhook notifications
export SLACK_WEBHOOK="https://hooks.slack.com/..."
```

---

## 🔒 Security Considerations

### Runner Security

#### Access Control
```bash
# 1. Secure runner directory
chmod 700 ~/github-runner
chmod 600 .runner .credentials

# 2. Use dedicated user account
# Create separate user for runner service
sudo dscl . -create /Users/runner
sudo dscl . -append /Users/runner PrimaryGroupID 20
sudo dscl . -create /Users/runner UserShell /bin/bash
```

#### Network Security
```bash
# 1. Use firewall rules
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/bin/git
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/bin/curl

# 2. Verify SSL certificates
curl -v https://github.com 2>&1 | grep "Server certificate"
```

#### Credential Management
```bash
# 1. Rotate runner tokens regularly
# Every 90 days maximum
./config.sh remove --token OLD_TOKEN
./config.sh --url https://github.com/YOUR_REPO \
            --token NEW_TOKEN

# 2. Monitor for unauthorized access
grep -i "unauthorized\|forbidden" _diag/Runner_*.log
```

---

## 📋 Runbooks

### Daily Runbook
1. **Morning Check** (9 AM):
   - Review overnight health check results
   - Check for any alerts or failures
   - Verify runner status in GitHub UI

2. **During Day**:
   - Monitor active jobs for unusual patterns
   - Respond to any alerts promptly
   - Check system resource usage

3. **Evening** (6 PM):
   - Review daily job completion rates
   - Check for any pending issues
   - Ensure runner is ready for overnight jobs

### Weekly Runbook
1. **Monday**:
   - Review previous week's performance
   - Check cost savings report
   - Plan any maintenance

2. **Wednesday**:
   - Perform system updates if needed
   - Review and rotate logs
   - Optimize cache settings

3. **Friday**:
   - Weekly performance review
   - Document any issues and resolutions
   - Prepare for weekend monitoring

### Monthly Runbook
1. **Beginning of Month**:
   - Review cost tracking report
   - Analyze utilization trends
   - Plan optimizations

2. **Mid-Month**:
   - Perform runner software updates
   - Review security patches
   - Update documentation

3. **End of Month**:
   - Generate monthly performance report
   - Review and update runbooks
   - Plan next month's improvements

---

## 📚 Additional Resources

### Documentation
- [GitHub Actions Runner Docs](https://docs.github.com/en/actions/hosting-your-own-runners)
- [macOS Performance Tuning](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)
- [Repository Setup Guide](../SELF_HOSTED_RUNNER_SETUP.md)

### Tools and Utilities
- [GitHub CLI](https://cli.github.com/) - Command-line GitHub management
- [jq](https://stedolan.github.io/jq/) - JSON processing for logs
- [htop](https://htop.dev/) - Process monitoring
- [iStat Menus](https://bjango.com/mac/istatmenus/) - System monitoring

### Community and Support
- [GitHub Actions Community](https://github.com/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/github-actions)
- [GitHub Discussions](https://github.com/orgs/community/discussions)

---

## 🔄 Version History

| Version | Date | Changes |
|---------|-------|----------|
| 1.0 | 2025-12-04 | Initial comprehensive operations guide |
| 1.1 | TBD | Future enhancements and improvements |

---

**Document Maintainer**: DevOps Team  
**Review Schedule**: Monthly  
**Last Reviewed**: December 4, 2025