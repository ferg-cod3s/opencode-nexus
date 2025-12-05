#!/bin/bash

# Runner Health Check Script
# Checks the health and status of self-hosted GitHub Actions runner

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RUNNER_DIR="${RUNNER_DIR:-$HOME/github-runner}"
MIN_DISK_SPACE_GB="${MIN_DISK_SPACE_GB:-10}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-4}"
LOG_FILE="$RUNNER_DIR/_diag/health-check.log"

# Helper functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
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

# Check if runner directory exists
check_runner_directory() {
    if [ ! -d "$RUNNER_DIR" ]; then
        error "Runner directory not found: $RUNNER_DIR"
        echo "Please ensure the runner is installed in: $RUNNER_DIR"
        return 1
    fi
    success "Runner directory found: $RUNNER_DIR"
}

# Check runner service status
check_service_status() {
    info "Checking runner service status..."
    
    cd "$RUNNER_DIR"
    
    if [ -f "./svc.sh" ]; then
        STATUS=$(./svc.sh status 2>/dev/null || echo "unknown")
        case "$STATUS" in
            *"active"*)
                success "Runner service is active"
                return 0
                ;;
            *"inactive"*)
                warning "Runner service is inactive"
                return 1
                ;;
            *"unknown"*)
                error "Runner service status unknown"
                return 1
                ;;
            *)
                error "Unexpected service status: $STATUS"
                return 1
                ;;
        esac
    else
        error "Runner service script not found"
        return 1
    fi
}

# Check system resources
check_system_resources() {
    info "Checking system resources..."
    
    # Check disk space
    AVAILABLE_SPACE=$(df -h "$RUNNER_DIR" | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_GB=$(df "$RUNNER_DIR" | tail -1 | awk '{print int($4/1024/1024)}')
    
    if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_DISK_SPACE_GB" ]; then
        error "Insufficient disk space: ${AVAILABLE_SPACE_GB}GB < ${MIN_DISK_SPACE_GB}GB"
        echo "Available: $AVAILABLE_SPACE"
        return 1
    else
        success "Disk space OK: ${AVAILABLE_SPACE_GB}GB available (${AVAILABLE_SPACE})"
    fi
    
    # Check memory
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS
        FREE_MEMORY=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        FREE_MEMORY_GB=$((FREE_MEMORY * 4096 / 1024 / 1024 / 1024))
        
        if [ "$FREE_MEMORY_GB" -lt "$MIN_MEMORY_GB" ]; then
            warning "Low memory: ${FREE_MEMORY_GB}GB free"
        else
            success "Memory OK: ${FREE_MEMORY_GB}GB free"
        fi
    else
        # Linux
        AVAILABLE_MEMORY=$(free -h | awk '/^Mem:/ {print $7}')
        success "Memory OK: $AVAILABLE_MEMORY available"
    fi
    
    # Check CPU load
    if command -v uptime >/dev/null 2>&1; then
        LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        LOAD_NUM=$(echo "$LOAD_AVG" | awk '{print $1}')
        
        # Compare with number of CPU cores
        if command -v sysctl >/dev/null 2>&1; then
            CPU_CORES=$(sysctl -n hw.ncpu)
        else
            CPU_CORES=$(nproc)
        fi
        
        if command -v bc >/dev/null 2>&1; then
            if (( $(echo "$LOAD_NUM > $CPU_CORES" | bc -l) )); then
                warning "High CPU load: $LOAD_AVG (cores: $CPU_CORES)"
            else
                success "CPU load OK: $LOAD_AVG (cores: $CPU_CORES)"
            fi
        else
            # Fallback: compare integer parts only
            LOAD_NUM_INT=${LOAD_NUM%.*}
            CPU_CORES_INT=${CPU_CORES%.*}
            if [ "$LOAD_NUM_INT" -gt "$CPU_CORES_INT" ]; then
                warning "High CPU load: $LOAD_AVG (cores: $CPU_CORES) [integer comparison, bc not found]"
            else
                success "CPU load OK: $LOAD_AVG (cores: $CPU_CORES) [integer comparison, bc not found]"
            fi
        fi
    fi
}

# Check network connectivity
check_network() {
    info "Checking network connectivity..."
    
    # Check GitHub connectivity
    if curl -s --connect-timeout 5 https://github.com >/dev/null; then
        success "GitHub connectivity OK"
    else
        error "Cannot reach GitHub"
        return 1
    fi
    
    # Check GitHub Actions API
    if curl -s --connect-timeout 5 https://api.github.com >/dev/null; then
        success "GitHub API connectivity OK"
    else
        error "Cannot reach GitHub API"
        return 1
    fi
}

# Check runner configuration
check_configuration() {
    info "Checking runner configuration..."
    
    cd "$RUNNER_DIR"
    
    # Check .runner file
    if [ -f ".runner" ]; then
        success "Runner configuration file found"
        
        # Extract runner name
        if command -v jq >/dev/null 2>&1; then
            RUNNER_NAME=$(jq -r '.agentName' .runner 2>/dev/null || echo "unknown")
            success "Runner name: $RUNNER_NAME"
        fi
    else
        error "Runner configuration file not found"
        return 1
    fi
    
    # Check credentials
    if [ -f ".credentials" ]; then
        success "Runner credentials file found"
    else
        error "Runner credentials file not found"
        return 1
    fi
    
    # Check for required binaries
    REQUIRED_BINARIES=("git" "curl")
    for binary in "${REQUIRED_BINARIES[@]}"; do
        if command -v "$binary" >/dev/null 2>&1; then
            success "Binary found: $binary"
        else
            error "Required binary not found: $binary"
            return 1
        fi
    done
    
    # Check for optional binaries (enhance functionality but not required)
    OPTIONAL_BINARIES=("jq" "bc")
    for binary in "${OPTIONAL_BINARIES[@]}"; do
        if command -v "$binary" >/dev/null 2>&1; then
            success "Optional binary found: $binary"
        else
            info "Optional binary not found: $binary (some features may be limited)"
        fi
    done
}

# Check recent job performance
check_job_performance() {
    info "Checking recent job performance..."
    
    cd "$RUNNER_DIR"
    
    # Look for recent job logs
    if [ -d "_diag" ]; then
        RECENT_LOGS=$(find _diag -name "Runner_*.log" -mtime -7 | wc -l)
        if [ "$RECENT_LOGS" -gt 0 ]; then
            success "Found recent job logs: $RECENT_LOGS files"
            
            # Check for recent errors
            ERROR_COUNT=$(grep -c "ERROR" _diag/Runner_*.log 2>/dev/null || echo "0")
            if [ "$ERROR_COUNT" -gt 0 ]; then
                warning "Found $ERROR_COUNT errors in recent logs"
            else
                success "No errors found in recent logs"
            fi
        else
            warning "No recent job logs found"
        fi
    else
        warning "No diagnostic directory found"
    fi
}

# Generate health report
generate_report() {
    echo ""
    echo -e "${BLUE}📊 Health Check Summary${NC}"
    echo "========================"
    echo "Timestamp: $(date)"
    echo "Runner Directory: $RUNNER_DIR"
    echo "Log File: $LOG_FILE"
    echo ""
    
    # Overall status
    if [ "${#FAILED_CHECKS[@]}" -eq 0 ]; then
        success "Overall Status: HEALTHY"
        echo "✅ Runner is ready to accept jobs"
    else
        error "Overall Status: UNHEALTHY"
        echo "❌ Runner needs attention before accepting jobs"
        echo ""
        echo "Failed Checks:"
        for check in "${FAILED_CHECKS[@]}"; do
            echo "  - $check"
        done
    fi
    
    echo ""
    echo "📋 Quick Actions:"
    echo "- Restart runner: cd $RUNNER_DIR && ./svc.sh restart"
    echo "- View logs: cd $RUNNER_DIR && tail -f _diag/Runner_*.log"
    echo "- Check status: cd $RUNNER_DIR && ./svc.sh status"
    echo "- Full health report: cat $LOG_FILE"
}

# Main execution
main() {
    echo -e "${BLUE}🏥 Self-Hosted Runner Health Check${NC}"
    echo "=================================="
    
    FAILED_CHECKS=()
    
    # Run all checks
    if ! check_runner_directory; then
        FAILED_CHECKS+=("Runner Directory")
        generate_report
        exit 1
    fi
    
    if ! check_service_status; then
        FAILED_CHECKS+=("Service Status")
    fi
    
    if ! check_system_resources; then
        FAILED_CHECKS+=("System Resources")
    fi
    
    if ! check_network; then
        FAILED_CHECKS+=("Network Connectivity")
    fi
    
    if ! check_configuration; then
        FAILED_CHECKS+=("Configuration")
    fi
    
    # Job performance check is non-critical
    check_job_performance
    
    # Generate final report
    generate_report
    
    # Exit with appropriate code
    if [ "${#FAILED_CHECKS[@]}" -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"