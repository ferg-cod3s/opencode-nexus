# Runner Monitoring and Observability Guide

**Purpose**: Comprehensive monitoring strategy for self-hosted GitHub Actions runner  
**Target Audience**: DevOps engineers, SREs, system administrators  
**Last Updated**: December 4, 2025

---

## 🎯 Monitoring Strategy Overview

### Monitoring Pillars

1. **Availability Monitoring**: Runner uptime and service status
2. **Performance Monitoring**: System resources and job execution metrics
3. **Cost Monitoring**: Usage patterns and savings tracking
4. **Security Monitoring**: Access control and anomaly detection
5. **Operational Monitoring**: Log analysis and trend identification

### Monitoring Stack

```
┌─────────────────────────────────────────────────────────┐
│                    Monitoring Stack                      │
├─────────────────────────────────────────────────────────┤
│  📊 Metrics Collection                                   │
│  ├── System Metrics (CPU, Memory, Disk)                  │
│  ├── Runner Metrics (Jobs, Status, Uptime)                 │
│  ├── Network Metrics (Latency, Connectivity)                │
│  └── Cost Metrics (Usage, Savings, ROI)                  │
├─────────────────────────────────────────────────────────┤
│  📈 Visualization & Alerting                            │
│  ├── GitHub Actions Dashboard                                │
│  ├── Real-time Monitor (runner-monitor.sh)                   │
│  ├── Health Check Reports (runner-health-check.sh)            │
│  └── Cost Tracking Reports (cost-tracking.yml)               │
├─────────────────────────────────────────────────────────┤
│  📋 Log Management                                      │
│  ├── Structured Logging (JSON format)                        │
│  ├── Log Rotation (automated)                              │
│  ├── Log Aggregation (centralized)                          │
│  └── Log Analysis (pattern detection)                       │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Metrics Collection

### System Metrics

#### CPU Monitoring
```bash
# Real-time CPU usage
top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//'

# Historical CPU trends
sar -u 1 300 | tail -10

# Alert thresholds
export ALERT_THRESHOLD_CPU=80    # Warning at 80%
export ALERT_THRESHOLD_CPU_CRITICAL=95  # Critical at 95%
```

#### Memory Monitoring
```bash
# macOS memory usage
vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//'

# Memory pressure
memory_pressure | grep "System-wide memory free percentage" | awk '{print $5}'

# Alert thresholds
export ALERT_THRESHOLD_MEMORY=85    # Warning at 85%
export ALERT_THRESHOLD_MEMORY_CRITICAL=95  # Critical at 95%
```

#### Disk Monitoring
```bash
# Disk usage
df -h ~/github-runner | tail -1 | awk '{print $5}' | sed 's/%//'

# Disk I/O stats
iostat -d 1 10

# Alert thresholds
export ALERT_THRESHOLD_DISK=90    # Warning at 90%
export ALERT_THRESHOLD_DISK_CRITICAL=98  # Critical at 98%
```

### Runner Metrics

#### Service Status
```bash
# Runner service status
cd ~/github-runner
./svc.sh status

# Expected outputs: active, inactive, unknown
```

#### Job Metrics
```bash
# Active job count
grep -c "Running job" _diag/Runner_*.log

# Job success rate
grep -c "Job completed" _diag/Runner_*.log
grep -c "Job failed" _diag/Runner_*.log

# Average job duration
grep "Job completed" _diag/Runner_*.log | \
  awk '{print $NF}' | \
  awk '{sum+=$1; count++} END {print sum/count}'
```

#### Network Metrics
```bash
# GitHub connectivity
curl -o /dev/null -s -w "%{time_total}\n" https://github.com

# API response time
curl -o /dev/null -s -w "%{time_total}\n" https://api.github.com

# Packet loss
ping -c 10 github.com | grep "packet loss" | awk '{print $6}'
```

---

## 📈 Visualization & Alerting

### Real-Time Dashboard

#### Interactive Monitor
```bash
# Start real-time monitoring
./scripts/runner-monitor.sh

# Features:
# - Live system metrics
# - Color-coded alerts
# - Interactive controls
# - Historical trends
# - Job status tracking
```

#### Dashboard Components
1. **System Metrics Panel**
   - CPU usage gauge (0-100%)
   - Memory usage gauge (0-100%)
   - Disk usage gauge (0-100%)
   - Network status indicator

2. **Runner Status Panel**
   - Service status (active/inactive)
   - Current job count
   - Recent job history
   - Uptime percentage

3. **Alert Panel**
   - Active alerts list
   - Alert history
   - Severity indicators
   - Resolution status

### GitHub Actions Integration

#### Workflow Status Badges
```yaml
# In README.md
![Runner Status](https://github.com/YOUR_REPO/actions/workflows/runner-health-check.yml/badge.svg)
![Cost Savings](https://github.com/YOUR_REPO/actions/workflows/cost-tracking.yml/badge.svg)
```

#### Summary Reports
```markdown
## 🏥 Runner Health Summary

### ✅ Current Status
- **Runner**: Online and Active
- **CPU Usage**: 45% (Normal)
- **Memory Usage**: 62% (Normal)
- **Disk Usage**: 78% (Warning)
- **Network**: Connected (12ms latency)

### 📊 Recent Performance
- **Uptime**: 99.8% (last 7 days)
- **Jobs Completed**: 142/145 (97.9% success rate)
- **Average Duration**: 8.5 minutes
- **Cost Savings**: $127.50 this month
```

---

## 🚨 Alerting Strategy

### Alert Levels

#### Informational (ℹ️)
- Runner started/stopped
- Job completed successfully
- System maintenance events

#### Warning (⚠️)
- Resource usage >80%
- Runner offline <5 minutes
- Job failure rate >10%

#### Critical (🚨)
- Resource usage >95%
- Runner offline >15 minutes
- Job failure rate >25%
- Security anomalies detected

### Alert Channels

#### GitHub Actions Notifications
```yaml
# In workflow files
- name: Alert on Critical Issues
  if: failure()
  run: |
    echo "::error::Critical runner issue detected"
    echo "Check: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
```

#### Email Alerts
```bash
# Configure email notifications
export ALERT_EMAIL="devops@company.com"
export SMTP_SERVER="smtp.company.com"
export SMTP_USER="alerts@company.com"
export SMTP_PASS="${{ secrets.SMTP_PASSWORD }}"
```

#### Slack Integration
```bash
# Slack webhook integration
export SLACK_WEBHOOK="${{ secrets.SLACK_WEBHOOK_URL }}"

# Send alert to Slack
send_slack_alert() {
  local message="$1"
  local severity="$2"
  
  curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"🚨 Runner Alert [$severity]: $message\"}" \
    "$SLACK_WEBHOOK"
}
```

### Alert Rules

#### System Resource Alerts
```bash
# CPU Alert Rule
if [ "$(get_cpu_usage)" -gt "$ALERT_THRESHOLD_CPU_CRITICAL" ]; then
  send_alert "CPU usage critical: $(get_cpu_usage)%" "CRITICAL"
  trigger_auto_scaling
fi

# Memory Alert Rule
if [ "$(get_memory_usage)" -gt "$ALERT_THRESHOLD_MEMORY_CRITICAL" ]; then
  send_alert "Memory usage critical: $(get_memory_usage)%" "CRITICAL"
  trigger_memory_cleanup
fi

# Disk Alert Rule
if [ "$(get_disk_usage)" -gt "$ALERT_THRESHOLD_DISK_CRITICAL" ]; then
  send_alert "Disk usage critical: $(get_disk_usage)%" "CRITICAL"
  trigger_disk_cleanup
fi
```

#### Runner Service Alerts
```bash
# Service Down Alert
if [ "$(get_runner_status)" != "active" ]; then
  send_alert "Runner service down: $(get_runner_status)" "CRITICAL"
  trigger_auto_recovery
fi

# Job Failure Alert
FAILURE_RATE=$(calculate_failure_rate)
if [ "$FAILURE_RATE" -gt 25 ]; then
  send_alert "High job failure rate: ${FAILURE_RATE}%" "WARNING"
  trigger_investigation
fi
```

---

## 📋 Log Management

### Structured Logging

#### Log Format Standard
```json
{
  "timestamp": "2025-12-04T10:30:00Z",
  "level": "INFO",
  "component": "runner-monitor",
  "event": "system_metrics",
  "data": {
    "cpu_usage": 45.2,
    "memory_usage": 67.8,
    "disk_usage": 78.1,
    "runner_status": "active",
    "active_jobs": 2
  },
  "metadata": {
    "hostname": "macbook-air.local",
    "runner_version": "2.322.0",
    "os_version": "macOS 14.1"
  }
}
```

#### Log Categories
1. **System Logs**: Resource usage, system events
2. **Runner Logs**: Service status, job execution
3. **Network Logs**: Connectivity, latency, errors
4. **Security Logs**: Access attempts, authentication
5. **Performance Logs**: Job duration, queue times

### Log Rotation

#### Automated Rotation
```bash
# Log rotation configuration
LOG_RETENTION_DAYS=30
COMPRESS_OLD_LOGS=true
MAX_LOG_SIZE="100M"

# Rotation script
rotate_logs() {
  local log_dir="$RUNNER_DIR/_diag"
  
  # Compress logs older than 7 days
  find "$log_dir" -name "*.log" -mtime +7 -exec gzip {} \;
  
  # Delete logs older than retention period
  find "$log_dir" -name "*.log.gz" -mtime +$LOG_RETENTION_DAYS -delete
  
  # Split large logs
  find "$log_dir" -name "*.log" -size +$MAX_LOG_SIZE -exec split -b 50M {} {}_part_ \;
}
```

### Log Analysis

#### Pattern Detection
```bash
# Error pattern analysis
analyze_errors() {
  local log_file="$1"
  
  # Common error patterns
  grep -E "(ERROR|FATAL|CRITICAL)" "$log_file" | \
    awk '{print $0}' | \
    sort | uniq -c | sort -nr
}

# Performance pattern analysis
analyze_performance() {
  local log_file="$1"
  
  # Extract job durations
  grep "Job completed" "$log_file" | \
    awk '{print $NF}' | \
    sort -n | \
    awk '{
      count[NR]=$1;
      sum+=$1
    } END {
      print "Min:", count[1];
      print "Max:", count[NR];
      print "Avg:", sum/NR;
      print "Median:", count[int(NR/2)];
    }'
}
```

#### Anomaly Detection
```bash
# Statistical anomaly detection
detect_anomalies() {
  local metric="$1"
  local threshold="$2"
  
  # Calculate baseline (last 24 hours)
  baseline=$(get_baseline_metric "$metric" 24)
  
  # Current value
  current=$(get_current_metric "$metric")
  
  # Detect anomaly (>3 standard deviations)
  if (( $(echo "$current - $baseline > $threshold" | bc -l) )); then
    send_alert "Anomaly detected in $metric: $current (baseline: $baseline)" "WARNING"
  fi
}
```

---

## 📊 Performance Dashboards

### Grafana Dashboard (Optional)

#### Data Sources
```yaml
# Prometheus configuration
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'runner-metrics'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/metrics'
```

#### Dashboard Panels
1. **System Overview**
   - CPU usage (last 24h)
   - Memory usage (last 24h)
   - Disk usage (last 24h)
   - Network latency (last 24h)

2. **Runner Performance**
   - Job success rate (last 7 days)
   - Average job duration (last 7 days)
   - Queue time distribution (last 24h)
   - Concurrent job count (real-time)

3. **Cost Analysis**
   - Daily cost breakdown
   - Monthly savings trend
   - Runner utilization percentage
   - ROI calculation

### GitHub Actions Dashboard

#### Built-in Metrics
- Workflow run history
- Job execution times
- Success/failure rates
- Resource utilization

#### Custom Reports
```markdown
## 📊 Monthly Performance Report

### System Health
- **Average CPU**: 42% (target: <70%)
- **Average Memory**: 65% (target: <80%)
- **Average Disk**: 72% (target: <85%)

### Runner Performance
- **Uptime**: 99.7% (target: >99.5%)
- **Jobs Completed**: 287/295 (97.3% success)
- **Average Duration**: 7.2 minutes (target: <10 min)

### Cost Efficiency
- **Self-Hosted Usage**: 89% (target: >85%)
- **Monthly Savings**: $156.80
- **Annual ROI**: 94%
```

---

## 🔍 Troubleshooting Monitoring

### Common Monitoring Issues

#### Missing Metrics
**Symptoms**:
- Dashboard shows no data
- Alerts not triggering
- Gaps in metric collection

**Solutions**:
```bash
# Check metric collection service
ps aux | grep runner-monitor

# Verify log permissions
ls -la ~/github-runner/_diag/

# Test metric collection manually
./scripts/runner-health-check.sh --verbose
```

#### False Alerts
**Symptoms**:
- Too many warning alerts
- Alerts for normal conditions
- Alert fatigue

**Solutions**:
```bash
# Adjust alert thresholds
export ALERT_THRESHOLD_CPU=85  # Was 80
export ALERT_THRESHOLD_MEMORY=90  # Was 85

# Add alert cooldown
ALERT_COOLDOWN=300  # 5 minutes between same alert

# Implement alert correlation
# Only alert if multiple metrics are anomalous
```

#### Performance Impact
**Symptoms**:
- Monitoring slows down runner
- High CPU from monitoring tools
- Job execution delays

**Solutions**:
```bash
# Reduce monitoring frequency
export MONITOR_INTERVAL=120  # Was 60 seconds

# Optimize metric collection
# Use system APIs instead of command-line tools

# Offload heavy processing
# Move log analysis to separate process
```

---

## 📚 Monitoring Tools and Integrations

### Native Tools
```bash
# System monitoring
top -l 1                    # CPU and memory
iostat 1 10                 # Disk I/O
netstat -i                     # Network interfaces
vm_stat                        # Memory statistics

# Log analysis
tail -f _diag/Runner_*.log   # Real-time logs
grep -E "ERROR|WARN" *.log   # Error filtering
jq '.' structured_log.json      # JSON log parsing
```

### Third-Party Tools

#### Monitoring Agents
```bash
# Prometheus node exporter
curl -L https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.darwin-amd64.tar.gz | tar xz
./node_exporter --web.listen-address=:9090

# Telegraf for comprehensive metrics
brew install telegraf
# Configure with /usr/local/etc/telegraf.conf
```

#### Visualization
```bash
# Grafana (self-hosted)
docker run -d -p 3000:3000 grafana/grafana

# Kibana (for log analysis)
docker run -d -p 5601:5601 kibana:7.14.0
```

### Cloud Integrations

#### AWS CloudWatch
```bash
# Install CloudWatch agent
curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py | python

# Configure for runner metrics
cat > /etc/awslogs/awslogs.conf << EOF
[general]
state_file = /var/awslogs/state/runner-state

[runner-metrics]
log_group_name = /github/runner/metrics
file = /Users/runner/github-runner/_diag/metrics.log
EOF
```

#### DataDog
```bash
# Install DataDog agent
DD_API_KEY="${{ secrets.DATADOG_API_KEY }}" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

# Configure custom metrics
cat > /etc/datadog/conf.d/runner_metrics.yaml << EOF
init_config:
  - type: file
    path: /Users/runner/github-runner/_diag/metrics.json
EOF
```

---

## 📈 Future Enhancements

### Advanced Monitoring
1. **Machine Learning Anomaly Detection**
   - Unsupervised learning for pattern detection
   - Predictive failure alerts
   - Automated root cause analysis

2. **Distributed Tracing**
   - Job execution tracing
   - Performance bottleneck identification
   - Cross-service dependency mapping

3. **Capacity Planning**
   - Resource usage forecasting
   - Scaling recommendations
   - Cost optimization suggestions

### Automation
1. **Self-Healing**
   - Automatic service recovery
   - Resource optimization
   - Performance tuning

2. **Intelligent Alerting**
   - Context-aware alerts
   - Alert suppression for maintenance
   - Automated escalation

---

## 📋 Monitoring Checklist

### Daily
- [ ] Review health check results
- [ ] Check for active alerts
- [ ] Verify dashboard functionality
- [ ] Monitor resource trends

### Weekly
- [ ] Analyze performance trends
- [ ] Review alert effectiveness
- [ ] Check log rotation
- [ ] Update monitoring configurations

### Monthly
- [ ] Generate performance reports
- [ ] Review cost optimization opportunities
- [ ] Update monitoring documentation
- [ ] Plan monitoring improvements

---

**Document Maintainer**: DevOps Team  
**Review Schedule**: Monthly  
**Last Reviewed**: December 4, 2025