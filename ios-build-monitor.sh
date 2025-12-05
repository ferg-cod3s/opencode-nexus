#!/bin/bash
# iOS Build Status Monitor for OpenCode Nexus
# Provides real-time monitoring and diagnostics for iOS builds

set -euo pipefail

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly MONITOR_INTERVAL=30
readonly LOG_FILE="${PROJECT_ROOT}/ios-build-monitor.log"

# Monitoring state
declare -A PREVIOUS_STATE
declare -i MONITOR_COUNT=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${NC} $(date '+%H:%M:%S') $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1" | tee -a "$LOG_FILE"; }
log_monitor() { echo -e "${CYAN}[MONITOR]${NC} $(date '+%H:%M:%S') $1" | tee -a "$LOG_FILE"; }

# System health checks
check_system_health() {
    local health_score=0
    local max_score=100
    
    # Disk space check (30 points)
    local available_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_gb" -gt 10 ]; then
        health_score=$((health_score + 30))
        log_info "Disk space: ${available_gb}GB (✅)"
    elif [ "$available_gb" -gt 5 ]; then
        health_score=$((health_score + 15))
        log_warning "Disk space: ${available_gb}GB (⚠️)"
    else
        log_error "Disk space: ${available_gb}GB (❌)"
    fi
    
    # Memory check (25 points)
    local free_pages=$(vm_stat | grep 'Pages free' | awk '{print $3}' | sed 's/\.//')
    local free_mb=$((free_pages * 4096 / 1024 / 1024))
    if [ "$free_mb" -gt 4096 ]; then
        health_score=$((health_score + 25))
        log_info "Memory: ${free_mb}MB free (✅)"
    elif [ "$free_mb" -gt 2048 ]; then
        health_score=$((health_score + 12))
        log_warning "Memory: ${free_mb}MB free (⚠️)"
    else
        log_error "Memory: ${free_mb}MB free (❌)"
    fi
    
    # CPU load check (20 points)
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_num=$(echo "$load_avg" | awk '{printf "%.0f", $1 * 100}')
    if [ "$load_num" -lt 200 ]; then
        health_score=$((health_score + 20))
        log_info "CPU load: $load_avg (✅)"
    elif [ "$load_num" -lt 400 ]; then
        health_score=$((health_score + 10))
        log_warning "CPU load: $load_avg (⚠️)"
    else
        log_error "CPU load: $load_avg (❌)"
    fi
    
    # Network check (15 points)
    if ping -c 1 -W 3000 google.com >/dev/null 2>&1; then
        health_score=$((health_score + 15))
        log_info "Network: Connected (✅)"
    else
        log_warning "Network: Limited connectivity (⚠️)"
    fi
    
    # Tools check (10 points)
    local tools_ok=true
    for tool in xcodebuild cargo bun; do
        if ! command -v "$tool" &> /dev/null; then
            tools_ok=false
            break
        fi
    done
    
    if [ "$tools_ok" = true ]; then
        health_score=$((health_score + 10))
        log_info "Tools: All available (✅)"
    else
        log_error "Tools: Missing required tools (❌)"
    fi
    
    echo "$health_score"
}

# Check build processes
check_build_processes() {
    local rust_processes=$(pgrep -f "cargo.*ios" | wc -l)
    local xcode_processes=$(pgrep -f "xcodebuild" | wc -l)
    local tauri_processes=$(pgrep -f "tauri.*ios" | wc -l)
    
    log_monitor "Active processes - Rust: $rust_processes, Xcode: $xcode_processes, Tauri: $tauri_processes"
    
    if [ "$rust_processes" -gt 0 ] || [ "$xcode_processes" -gt 0 ] || [ "$tauri_processes" -gt 0 ]; then
        return 0  # Build in progress
    else
        return 1  # No build processes
    fi
}

# Check build artifacts
check_build_artifacts() {
    local artifacts_found=0
    local artifacts_total=6
    
    # Frontend build
    if [ -f "$PROJECT_ROOT/frontend/dist/index.html" ]; then
        ((artifacts_found++))
        log_info "Frontend build: Found"
    else
        log_warning "Frontend build: Missing"
    fi
    
    # Rust library
    if [ -f "$PROJECT_ROOT/src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a" ]; then
        ((artifacts_found++))
        log_info "Rust library: Found"
    else
        log_warning "Rust library: Missing"
    fi
    
    # iOS project
    if [ -f "$PROJECT_ROOT/src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj" ]; then
        ((artifacts_found++))
        log_info "iOS project: Found"
    else
        log_warning "iOS project: Missing"
    fi
    
    # Pre-built library
    if [ -f "$PROJECT_ROOT/src-tauri/gen/apple/Externals/arm64/Release/libapp.a" ]; then
        ((artifacts_found++))
        log_info "Pre-built library: Found"
    else
        log_warning "Pre-built library: Missing"
    fi
    
    # Archive
    if [ -d "$PROJECT_ROOT/src-tauri/gen/apple/build/archives" ]; then
        ((artifacts_found++))
        log_info "Archive: Found"
    else
        log_warning "Archive: Missing"
    fi
    
    # IPA
    if [ -f "$PROJECT_ROOT/src-tauri/gen/apple/build/ipa"/*.ipa ]; then
        ((artifacts_found++))
        log_info "IPA: Found"
    else
        log_warning "IPA: Missing"
    fi
    
    echo "$artifacts_found/$artifacts_total"
}

# Check recent build logs
check_build_logs() {
    local recent_errors=0
    local recent_warnings=0
    
    # Check recent log files
    if [ -f "$PROJECT_ROOT/src-tauri/target/aarch64-apple-ios/release/build.log" ]; then
        recent_errors=$(grep -c "error" "$PROJECT_ROOT/src-tauri/target/aarch64-apple-ios/release/build.log" 2>/dev/null || echo "0")
        recent_warnings=$(grep -c "warning" "$PROJECT_ROOT/src-tauri/target/aarch64-apple-ios/release/build.log" 2>/dev/null || echo "0")
    fi
    
    log_monitor "Recent build issues - Errors: $recent_errors, Warnings: $recent_warnings"
    
    echo "$recent_errors:$recent_warnings"
}

# Generate status report
generate_status_report() {
    local health_score=$1
    local build_status=$2
    local artifacts_status=$3
    local log_status=$4
    
    echo ""
    echo -e "${BOLD}📊 iOS Build Status Report${NC}"
    echo "=========================="
    echo ""
    
    # Overall status
    if [ "$health_score" -gt 80 ]; then
        echo -e "🟢 ${BOLD}Overall Status: HEALTHY${NC}"
    elif [ "$health_score" -gt 60 ]; then
        echo -e "🟡 ${BOLD}Overall Status: WARNING${NC}"
    else
        echo -e "🔴 ${BOLD}Overall Status: CRITICAL${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}System Health Score: ${health_score}/100${NC}"
    
    # Build status
    if [ "$build_status" = "0" ]; then
        echo -e "🔨 Build Status: ${GREEN}In Progress${NC}"
    else
        echo -e "🔨 Build Status: ${YELLOW}Idle${NC}"
    fi
    
    # Artifacts
    echo -e "📦 Build Artifacts: ${artifacts_status}"
    
    # Recent issues
    local errors=$(echo "$log_status" | cut -d: -f1)
    local warnings=$(echo "$log_status" | cut -d: -f2)
    echo -e "📝 Recent Issues: ${RED}Errors: $errors${NC}, ${YELLOW}Warnings: $warnings${NC}"
    
    echo ""
    
    # Recommendations
    echo -e "${BOLD}💡 Recommendations:${NC}"
    
    if [ "$health_score" -lt 60 ]; then
        echo "  • System health is critical - consider freeing resources"
    fi
    
    if [ "$build_status" = "1" ] && [ "$artifacts_status" != "6/6" ]; then
        echo "  • Build artifacts incomplete - consider running build script"
    fi
    
    if [ "$errors" -gt 0 ]; then
        echo "  • Recent errors detected - check build logs"
    fi
    
    if [ "$warnings" -gt 5 ]; then
        echo "  • High warning count - review build configuration"
    fi
    
    echo ""
}

# Monitor loop
monitor_build() {
    local duration=${1:-3600}  # Default 1 hour
    local end_time=$(($(date +%s) + duration))
    
    log_info "Starting iOS build monitoring for ${duration}s"
    log_info "Monitoring interval: ${MONITOR_INTERVAL}s"
    log_info "Log file: $LOG_FILE"
    
    while [ $(date +%s) -lt $end_time ]; do
        ((MONITOR_COUNT++))
        
        echo ""
        log_monitor "=== Monitor Cycle #$MONITOR_COUNT ==="
        
        # System health
        local health_score=$(check_system_health)
        
        # Build processes
        local build_in_progress=false
        if check_build_processes; then
            build_in_progress=true
        fi
        
        # Build artifacts
        local artifacts_status=$(check_build_artifacts)
        
        # Build logs
        local log_status=$(check_build_logs)
        
        # Generate report
        generate_status_report "$health_score" "$([ "$build_in_progress" = true ] && echo "0" || echo "1")" "$artifacts_status" "$log_status"
        
        # Check for critical issues
        if [ "$health_score" -lt 40 ]; then
            log_error "Critical system health detected!"
        fi
        
        local errors=$(echo "$log_status" | cut -d: -f1)
        if [ "$errors" -gt 10 ]; then
            log_error "High error count detected: $errors"
        fi
        
        # Sleep until next cycle
        if [ $(date +%s) -lt $end_time ]; then
            sleep $MONITOR_INTERVAL
        fi
    done
    
    log_info "Monitoring completed after $MONITOR_COUNT cycles"
}

# Quick status check
quick_status() {
    echo -e "${BOLD}🔍 Quick iOS Build Status${NC}"
    echo "========================"
    echo ""
    
    # System health
    local health_score=$(check_system_health)
    echo "System Health: $health_score/100"
    
    # Build processes
    if check_build_processes; then
        echo "Build Status: 🟢 In Progress"
    else
        echo "Build Status: 🔴 Idle"
    fi
    
    # Artifacts
    local artifacts_status=$(check_build_artifacts)
    echo "Build Artifacts: $artifacts_status"
    
    # Recent activity
    local log_status=$(check_build_logs)
    local errors=$(echo "$log_status" | cut -d: -f1)
    local warnings=$(echo "$log_status" | cut -d: -f2)
    echo "Recent Issues: Errors: $errors, Warnings: $warnings"
    
    echo ""
}

# Show help
show_help() {
    echo -e "${BOLD}iOS Build Monitor for OpenCode Nexus${NC}"
    echo "======================================"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  monitor [duration]  Monitor build status for specified duration (default: 3600s)"
    echo "  status              Show quick status check"
    echo "  health              Show detailed system health"
    echo "  artifacts           Check build artifacts status"
    echo "  logs                Analyze recent build logs"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 monitor 1800     # Monitor for 30 minutes"
    echo "  $0 status           # Quick status check"
    echo "  $0 health           # Detailed health check"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
}

# Detailed health check
detailed_health() {
    echo -e "${BOLD}🏥 Detailed System Health Check${NC}"
    echo "================================="
    echo ""
    
    # Disk space
    echo "💾 Disk Space:"
    df -h . | awk 'NR==2 {printf "  Available: %s, Used: %s, Usage: %s\n", $4, $3, $5}'
    echo ""
    
    # Memory
    echo "🧠 Memory Usage:"
    vm_stat | head -10
    echo ""
    
    # CPU
    echo "🔥 CPU Usage:"
    top -l 1 | head -10
    echo ""
    
    # Network
    echo "🌐 Network Status:"
    if ping -c 1 -W 3000 google.com >/dev/null 2>&1; then
        echo "  ✅ Connected to internet"
    else
        echo "  ❌ No internet connectivity"
    fi
    echo ""
    
    # Tools
    echo "🛠️ Development Tools:"
    for tool in xcodebuild cargo bun git; do
        if command -v "$tool" &> /dev/null; then
            local version=$("$tool" --version 2>/dev/null | head -1 || echo "Unknown version")
            echo "  ✅ $tool: $version"
        else
            echo "  ❌ $tool: Not found"
        fi
    done
    echo ""
}

# Analyze build logs
analyze_logs() {
    echo -e "${BOLD}📝 Build Log Analysis${NC}"
    echo "======================"
    echo ""
    
    # Find recent log files
    local log_files=(
        "$PROJECT_ROOT/src-tauri/target/aarch64-apple-ios/release/build.log"
        "$PROJECT_ROOT/ios-build-"*.log
        "$PROJECT_ROOT/.github/workflows/ios-build-"*.log
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            echo "📄 Analyzing: $(basename "$log_file")"
            
            local errors=$(grep -c "error" "$log_file" 2>/dev/null || echo "0")
            local warnings=$(grep -c "warning" "$log_file" 2>/dev/null || echo "0")
            local fatal=$(grep -c "fatal" "$log_file" 2>/dev/null || echo "0")
            
            echo "  Errors: $errors, Warnings: $warnings, Fatal: $fatal"
            
            if [ "$errors" -gt 0 ]; then
                echo "  Recent errors:"
                grep "error" "$log_file" | tail -3 | sed 's/^/    /'
            fi
            
            echo ""
        fi
    done
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    case "${1:-monitor}" in
        "monitor")
            monitor_build "${2:-3600}"
            ;;
        "status")
            quick_status
            ;;
        "health")
            detailed_health
            ;;
        "artifacts")
            check_build_artifacts
            ;;
        "logs")
            analyze_logs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"