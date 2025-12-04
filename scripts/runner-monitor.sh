#!/bin/bash

# Runner Monitor Script
# Continuously monitors self-hosted GitHub Actions runner health and performance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RUNNER_DIR="${RUNNER_DIR:-$HOME/github-runner}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-60}"      # 1 minute
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-7}"
ALERT_THRESHOLD_CPU="${ALERT_THRESHOLD_CPU:-80}"
ALERT_THRESHOLD_MEMORY="${ALERT_THRESHOLD_MEMORY:-85}"
ALERT_THRESHOLD_DISK="${ALERT_THRESHOLD_DISK:-90}"
MONITOR_LOG="$RUNNER_DIR/_diag/monitor.log"
ALERT_LOG="$RUNNER_DIR/_diag/alerts.log"

# Ensure log directory exists
mkdir -p "$RUNNER_DIR/_diag"

# Helper functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MONITOR_LOG"
}

log_alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $1" | tee -a "$ALERT_LOG"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING: $1"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    log "ERROR: $1"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO: $1"
}

alert() {
    echo -e "${RED}🚨 $1${NC}"
    log_alert "$1"
}

# Get system metrics
get_cpu_usage() {
    if command -v top >/dev/null 2>&1; then
        # macOS
        CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    elif command -v vmstat >/dev/null 2>&1; then
        # Alternative macOS method
        CPU_USAGE=$(vm_stat 2>/dev/null | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        # Convert to percentage (simplified)
        CPU_USAGE=$((100 - CPU_USAGE * 4096 / 1024 / 1024 / 1024))
    else
        # Linux
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    fi
    echo "${CPU_USAGE:-0}"
}

get_memory_usage() {
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS
        FREE_MEMORY=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        INACTIVE_MEMORY=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
        WIRED_MEMORY=$(vm_stat | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
        ACTIVE_MEMORY=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        
        TOTAL_MEMORY=$((FREE_MEMORY + INACTIVE_MEMORY + WIRED_MEMORY + ACTIVE_MEMORY))
        USED_MEMORY=$((WIRED_MEMORY + ACTIVE_MEMORY))
        
        if [ "$TOTAL_MEMORY" -gt 0 ]; then
            MEMORY_USAGE=$((USED_MEMORY * 100 / TOTAL_MEMORY))
        else
            MEMORY_USAGE=0
        fi
    else
        # Linux
        MEMORY_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100.0}')
    fi
    echo "${MEMORY_USAGE:-0}"
}

get_disk_usage() {
    DISK_USAGE=$(df "$RUNNER_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "${DISK_USAGE:-0}"
}

get_runner_status() {
    cd "$RUNNER_DIR"
    
    if [ -f "./svc.sh" ]; then
        STATUS=$(./svc.sh status 2>/dev/null || echo "unknown")
        case "$STATUS" in
            *"active"*)
                echo "active"
                ;;
            *"inactive"*)
                echo "inactive"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "no-service"
    fi
}

get_network_status() {
    if curl -s --connect-timeout 5 https://github.com >/dev/null 2>&1; then
        echo "online"
    else
        echo "offline"
    fi
}

get_job_count() {
    cd "$RUNNER_DIR"
    
    if [ -d "_diag" ]; then
        # Count active jobs in recent logs
        JOB_COUNT=$(grep -c "Running job" _diag/Runner_*.log 2>/dev/null || echo "0")
        echo "$JOB_COUNT"
    else
        echo "0"
    fi
}

# Check for alerts
check_alerts() {
    local cpu_usage=$1
    local memory_usage=$2
    local disk_usage=$3
    local runner_status=$4
    local network_status=$5
    local job_count=$6
    
    local alerts_triggered=()
    
    # CPU alert
    if [ "$cpu_usage" -gt "$ALERT_THRESHOLD_CPU" ]; then
        alerts_triggered+=("CPU usage high: ${cpu_usage}%")
    fi
    
    # Memory alert
    if [ "$memory_usage" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
        alerts_triggered+=("Memory usage high: ${memory_usage}%")
    fi
    
    # Disk alert
    if [ "$disk_usage" -gt "$ALERT_THRESHOLD_DISK" ]; then
        alerts_triggered+=("Disk usage high: ${disk_usage}%")
    fi
    
    # Runner status alert
    if [ "$runner_status" != "active" ]; then
        alerts_triggered+=("Runner not active: $runner_status")
    fi
    
    # Network alert
    if [ "$network_status" != "online" ]; then
        alerts_triggered+=("Network offline: $network_status")
    fi
    
    # Job count alert (if too many jobs)
    if [ "$job_count" -gt 3 ]; then
        alerts_triggered+=("High job count: $job_count")
    fi
    
    # Log alerts
    if [ ${#alerts_triggered[@]} -gt 0 ]; then
        for alert_msg in "${alerts_triggered[@]}"; do
            alert "$alert_msg"
        done
        return 1
    else
        success "All metrics within normal ranges"
        return 0
    fi
}

# Display metrics dashboard
display_dashboard() {
    local cpu_usage=$1
    local memory_usage=$2
    local disk_usage=$3
    local runner_status=$4
    local network_status=$5
    local job_count=$6
    
    clear
    echo -e "${CYAN}🖥️  Runner Monitor Dashboard${NC}"
    echo "================================"
    echo "Timestamp: $(date)"
    echo "Runner Directory: $RUNNER_DIR"
    echo ""
    
    # System Metrics
    echo -e "${BLUE}📊 System Metrics${NC}"
    echo "-------------------"
    
    # CPU usage with color
    if [ "$cpu_usage" -gt "$ALERT_THRESHOLD_CPU" ]; then
        echo -e "CPU Usage:        ${RED}${cpu_usage}%${NC} 🚨"
    elif [ "$cpu_usage" -gt 60 ]; then
        echo -e "CPU Usage:        ${YELLOW}${cpu_usage}%${NC} ⚠️"
    else
        echo -e "CPU Usage:        ${GREEN}${cpu_usage}%${NC} ✅"
    fi
    
    # Memory usage with color
    if [ "$memory_usage" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
        echo -e "Memory Usage:     ${RED}${memory_usage}%${NC} 🚨"
    elif [ "$memory_usage" -gt 70 ]; then
        echo -e "Memory Usage:     ${YELLOW}${memory_usage}%${NC} ⚠️"
    else
        echo -e "Memory Usage:     ${GREEN}${memory_usage}%${NC} ✅"
    fi
    
    # Disk usage with color
    if [ "$disk_usage" -gt "$ALERT_THRESHOLD_DISK" ]; then
        echo -e "Disk Usage:       ${RED}${disk_usage}%${NC} 🚨"
    elif [ "$disk_usage" -gt 80 ]; then
        echo -e "Disk Usage:       ${YELLOW}${disk_usage}%${NC} ⚠️"
    else
        echo -e "Disk Usage:       ${GREEN}${disk_usage}%${NC} ✅"
    fi
    
    echo ""
    
    # Runner Status
    echo -e "${BLUE}🏃 Runner Status${NC}"
    echo "-------------------"
    
    # Runner status with color
    case "$runner_status" in
        "active")
            echo -e "Runner Service:   ${GREEN}Active${NC} ✅"
            ;;
        "inactive")
            echo -e "Runner Service:   ${RED}Inactive${NC} ❌"
            ;;
        *)
            echo -e "Runner Service:   ${YELLOW}Unknown${NC} ⚠️"
            ;;
    esac
    
    # Network status with color
    if [ "$network_status" = "online" ]; then
        echo -e "Network:          ${GREEN}Online${NC} ✅"
    else
        echo -e "Network:          ${RED}Offline${NC} ❌"
    fi
    
    echo -e "Active Jobs:      $job_count"
    echo ""
    
    # Recent Alerts
    echo -e "${BLUE}🚨 Recent Alerts${NC}"
    echo "-------------------"
    if [ -f "$ALERT_LOG" ]; then
        RECENT_ALERTS=$(tail -5 "$ALERT_LOG" 2>/dev/null || echo "No recent alerts")
        echo "$RECENT_ALERTS"
    else
        echo "No alerts logged"
    fi
    
    echo ""
    echo -e "${BLUE}📋 Controls${NC}"
    echo "-------------------"
    echo "Press 'q' to quit, 'r' to restart runner, 'h' for health check"
}

# Cleanup old logs
cleanup_logs() {
    info "Cleaning up old logs (retention: ${LOG_RETENTION_DAYS} days)..."
    
    # Clean monitor logs
    find "$RUNNER_DIR/_diag" -name "monitor.log.*" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    
    # Clean alert logs
    find "$RUNNER_DIR/_diag" -name "alerts.log.*" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    
    # Clean runner logs (keep longer)
    find "$RUNNER_DIR/_diag" -name "Runner_*.log" -mtime +30 -delete 2>/dev/null || true
    
    success "Log cleanup completed"
}

# Handle user input
handle_input() {
    while read -t 1 -n 1 key 2>/dev/null; do
        case "$key" in
            q|Q)
                info "Exiting monitor..."
                return 1
                ;;
            r|R)
                info "Restarting runner..."
                "$RUNNER_DIR/../scripts/runner-restart.sh"
                return 1
                ;;
            h|H)
                info "Running health check..."
                "$RUNNER_DIR/../scripts/runner-health-check.sh" || true
                ;;
        esac
    done
    return 0
}

# Main monitoring loop
main() {
    echo -e "${CYAN}🖥️  Starting Runner Monitor${NC}"
    echo "==============================="
    info "Monitor interval: ${MONITOR_INTERVAL}s"
    info "Log retention: ${LOG_RETENTION_DAYS} days"
    info "Press 'q' to quit, 'r' to restart, 'h' for health check"
    echo ""
    
    # Handle command line arguments
    case "${1:-monitor}" in
        "health")
            "$RUNNER_DIR/../scripts/runner-health-check.sh"
            exit $?
        "restart")
            "$RUNNER_DIR/../scripts/runner-restart.sh"
            exit $?
        "status")
            echo "Runner Status: $(get_runner_status)"
            echo "Network Status: $(get_network_status)"
            exit 0
            ;;
        "cleanup")
            cleanup_logs
            exit 0
            ;;
    esac
    
    # Main monitoring loop
    while true; do
        # Collect metrics
        CPU_USAGE=$(get_cpu_usage)
        MEMORY_USAGE=$(get_memory_usage)
        DISK_USAGE=$(get_disk_usage)
        RUNNER_STATUS=$(get_runner_status)
        NETWORK_STATUS=$(get_network_status)
        JOB_COUNT=$(get_job_count)
        
        # Log metrics
        log "Metrics: CPU=${CPU_USAGE}%, MEM=${MEMORY_USAGE}%, DISK=${DISK_USAGE}%, STATUS=${RUNNER_STATUS}, NETWORK=${NETWORK_STATUS}, JOBS=${JOB_COUNT}"
        
        # Check for alerts
        check_alerts "$CPU_USAGE" "$MEMORY_USAGE" "$DISK_USAGE" "$RUNNER_STATUS" "$NETWORK_STATUS" "$JOB_COUNT"
        
        # Display dashboard
        display_dashboard "$CPU_USAGE" "$MEMORY_USAGE" "$DISK_USAGE" "$RUNNER_STATUS" "$NETWORK_STATUS" "$JOB_COUNT"
        
        # Handle user input
        if ! handle_input; then
            break
        fi
        
        # Wait for next iteration
        sleep "$MONITOR_INTERVAL"
    done
    
    info "Runner monitor stopped"
}

# Run main function
main "$@"