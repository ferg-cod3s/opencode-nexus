#!/bin/bash

# Runner Restart Script
# Safely restarts the self-hosted GitHub Actions runner

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RUNNER_DIR="${RUNNER_DIR:-$HOME/github-runner}"
MAX_WAIT_TIME="${MAX_WAIT_TIME:-300}"  # 5 minutes
POLL_INTERVAL="${POLL_INTERVAL:-10}"     # 10 seconds

# Helper functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
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
        exit 1
    fi
}

# Check current runner status
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

# Wait for running jobs to complete
wait_for_jobs_completion() {
    info "Checking for running jobs..."
    
    cd "$RUNNER_DIR"
    
    # Check if there are any running jobs
    if [ -d "_diag" ]; then
        # Look for recent job activity
        RECENT_ACTIVITY=$(find _diag -name "*.log" -mmin -1 2>/dev/null | wc -l)
        
        if [ "$RECENT_ACTIVITY" -gt 0 ]; then
            warning "Recent job activity detected"
            info "Waiting for jobs to complete (max ${MAX_WAIT_TIME}s)..."
            
            ELAPSED=0
            while [ $ELAPSED -lt $MAX_WAIT_TIME ]; do
                # Check for active job indicators
                ACTIVE_JOBS=$(grep -l "Running job" _diag/Runner_*.log 2>/dev/null | wc -l || echo "0")
                
                if [ "$ACTIVE_JOBS" -eq 0 ]; then
                    success "No active jobs found"
                    return 0
                fi
                
                info "Active jobs: $ACTIVE_JOBS (waiting ${POLL_INTERVAL}s)..."
                sleep $POLL_INTERVAL
                ELAPSED=$((ELAPSED + POLL_INTERVAL))
            done
            
            warning "Timeout reached, proceeding with restart"
            return 1
        else
            success "No recent job activity"
            return 0
        fi
    else
        warning "No diagnostic directory found, proceeding with restart"
        return 0
    fi
}

# Stop the runner service
stop_runner() {
    info "Stopping runner service..."
    
    cd "$RUNNER_DIR"
    
    if [ -f "./svc.sh" ]; then
        if ./svc.sh stop; then
            success "Runner service stopped"
            return 0
        else
            error "Failed to stop runner service"
            return 1
        fi
    else
        warning "No service script found, trying manual stop"
        
        # Try to find and kill runner processes
        RUNNER_PIDS=$(pgrep -f "Runner.Listener" || true)
        if [ -n "$RUNNER_PIDS" ]; then
            info "Terminating runner processes: $RUNNER_PIDS"
            echo "$RUNNER_PIDS" | xargs kill -TERM
            sleep 5
            
            # Force kill if still running
            REMAINING_PIDS=$(pgrep -f "Runner.Listener" || true)
            if [ -n "$REMAINING_PIDS" ]; then
                warning "Force terminating remaining processes: $REMAINING_PIDS"
                echo "$REMAINING_PIDS" | xargs kill -KILL
            fi
        fi
        
        return 0
    fi
}

# Start the runner service
start_runner() {
    info "Starting runner service..."
    
    cd "$RUNNER_DIR"
    
    if [ -f "./svc.sh" ]; then
        if ./svc.sh start; then
            success "Runner service started"
            return 0
        else
            error "Failed to start runner service"
            return 1
        fi
    else
        error "No service script found"
        return 1
    fi
}

# Verify runner is online
verify_runner_online() {
    info "Verifying runner is online..."
    
    cd "$RUNNER_DIR"
    
    # Wait a bit for service to start
    sleep 10
    
    # Check service status
    STATUS=$(get_runner_status)
    if [ "$STATUS" = "active" ]; then
        success "Runner service is active"
    else
        error "Runner service is not active: $STATUS"
        return 1
    fi
    
    # Check connectivity to GitHub
    info "Testing GitHub connectivity..."
    if curl -s --connect-timeout 10 https://github.com >/dev/null; then
        success "GitHub connectivity OK"
    else
        error "Cannot reach GitHub"
        return 1
    fi
    
    # Check if runner appears in GitHub (this would need API access)
    info "Runner appears to be online and ready"
    return 0
}

# Generate restart report
generate_report() {
    echo ""
    echo -e "${BLUE}🔄 Runner Restart Report${NC}"
    echo "=========================="
    echo "Timestamp: $(date)"
    echo "Runner Directory: $RUNNER_DIR"
    echo "Previous Status: $PREVIOUS_STATUS"
    echo "Current Status: $(get_runner_status)"
    echo ""
    
    if [ "$RESTART_SUCCESS" = "true" ]; then
        success "Restart completed successfully"
        echo "✅ Runner is ready to accept jobs"
    else
        error "Restart failed"
        echo "❌ Manual intervention may be required"
    fi
    
    echo ""
    echo "📋 Next Steps:"
    echo "- Check runner status: cd $RUNNER_DIR && ./svc.sh status"
    echo "- View logs: cd $RUNNER_DIR && tail -f _diag/Runner_*.log"
    echo "- Verify in GitHub: https://github.com/$(git config --get remote.origin.url | sed -e 's/\.git$//' -e 's#.*/##')/settings/actions/runners"
}

# Main execution
main() {
    echo -e "${BLUE}🔄 Self-Hosted Runner Restart${NC}"
    echo "================================="
    
    # Check prerequisites
    check_runner_directory
    
    # Get current status
    PREVIOUS_STATUS=$(get_runner_status)
    info "Current runner status: $PREVIOUS_STATUS"
    
    # If already inactive, just start it
    if [ "$PREVIOUS_STATUS" = "inactive" ] || [ "$PREVIOUS_STATUS" = "unknown" ]; then
        info "Runner is not active, starting..."
        if start_runner; then
            RESTART_SUCCESS="true"
        else
            RESTART_SUCCESS="false"
        fi
    else
        # Wait for jobs to complete
        if ! wait_for_jobs_completion; then
            warning "Proceeding with restart despite active jobs"
        fi
        
        # Stop the runner
        if ! stop_runner; then
            RESTART_SUCCESS="false"
        else
            # Start the runner
            if start_runner; then
                # Verify it's online
                if verify_runner_online; then
                    RESTART_SUCCESS="true"
                else
                    RESTART_SUCCESS="false"
                fi
            else
                RESTART_SUCCESS="false"
            fi
        fi
    fi
    
    # Generate final report
    generate_report
    
    # Exit with appropriate code
    if [ "$RESTART_SUCCESS" = "true" ]; then
        exit 0
    else
        exit 1
    fi
}

# Handle command line arguments
case "${1:-restart}" in
    "status")
        check_runner_directory
        echo "Runner status: $(get_runner_status)"
        ;;
    "stop")
        check_runner_directory
        stop_runner
        ;;
    "start")
        check_runner_directory
        start_runner
        ;;
    "restart"|*)
        main "$@"
        ;;
esac