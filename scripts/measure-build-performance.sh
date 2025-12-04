#!/bin/bash
# iOS Build Performance Monitoring and Optimization Script
# Monitors build performance and provides optimization recommendations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PERFORMANCE_DIR="$PROJECT_ROOT/performance"
METRICS_FILE="$PERFORMANCE_DIR/build-metrics.csv"
OPTIMIZATION_REPORT="$PERFORMANCE_DIR/optimization-report.md"

# Performance thresholds
WARNING_THRESHOLD=300  # 5 minutes
CRITICAL_THRESHOLD=600  # 10 minutes
TARGET_BUILD_TIME=180     # 3 minutes

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_metric() {
    echo -e "${PURPLE}[METRIC]${NC} $1"
}

print_optimization() {
    echo -e "${CYAN}[OPTIMIZE]${NC} $1"
}

# Initialize performance monitoring
init_monitoring() {
    mkdir -p "$PERFORMANCE_DIR"
    
    # Create metrics file with headers if it doesn't exist
    if [[ ! -f "$METRICS_FILE" ]]; then
        cat > "$METRICS_FILE" << EOF
timestamp,build_type,total_time,rust_time,tauri_time,frontend_time,cache_hit,artifact_size,success
EOF
    fi
    
    print_status "Performance monitoring initialized"
    echo "  Metrics file: $METRICS_FILE"
    echo "  Performance dir: $PERFORMANCE_DIR"
}

# Measure build performance
measure_build() {
    local build_type=${1:-release}
    local target=${2:-aarch64-apple-ios}
    
    print_status "Starting performance measurement..."
    echo "=================================="
    echo "Build Type: $build_type"
    echo "Target: $target"
    echo "Timestamp: $(date -Iseconds)"
    echo "=================================="
    
    local total_start_time=$(date +%s)
    local rust_start_time
    local tauri_start_time
    local frontend_start_time
    local rust_duration
    local tauri_duration
    local frontend_duration
    local total_duration
    local cache_hit=false
    local artifact_size=0
    local build_success=false
    
    # Check cache state
    if [[ -d "src-tauri/target" ]]; then
        cache_hit=true
        print_status "Cache detected: YES"
    else
        print_status "Cache detected: NO"
    fi
    
    # Measure frontend build
    print_status "Measuring frontend build..."
    frontend_start_time=$(date +%s)
    if cd frontend && bun run build; then
        frontend_duration=$(($(date +%s) - frontend_start_time))
        print_metric "Frontend build time: ${frontend_duration}s"
        cd ..
    else
        print_error "Frontend build failed"
        return 1
    fi
    
    # Measure Rust build
    print_status "Measuring Rust build..."
    rust_start_time=$(date +%s)
    if cd src-tauri && cargo build --target "$target" --profile "$build_type"; then
        rust_duration=$(($(date +%s) - rust_start_time))
        print_metric "Rust build time: ${rust_duration}s"
        cd ..
    else
        print_error "Rust build failed"
        return 1
    fi
    
    # Measure Tauri iOS build
    print_status "Measuring Tauri iOS build..."
    tauri_start_time=$(date +%s)
    if cd src-tauri && cargo tauri ios build --profile "$build_type"; then
        tauri_duration=$(($(date +%s) - tauri_start_time))
        print_metric "Tauri build time: ${tauri_duration}s"
        cd ..
        build_success=true
    else
        print_error "Tauri iOS build failed"
        return 1
    fi
    
    # Calculate total duration
    total_duration=$(($(date +%s) - total_start_time))
    print_metric "Total build time: ${total_duration}s"
    
    # Measure artifact size
    if [[ -d "src-tauri/gen/apple/build/Build/Products" ]]; then
        artifact_size=$(du -sk "src-tauri/gen/apple/build/Build/Products" | cut -f1)
        print_metric "Artifact size: ${artifact_size}KB"
    fi
    
    # Record metrics
    record_metrics "$build_type" "$total_duration" "$rust_duration" "$tauri_duration" "$frontend_duration" "$cache_hit" "$artifact_size" "$build_success"
    
    # Analyze performance
    analyze_performance "$total_duration" "$rust_duration" "$tauri_duration" "$frontend_duration" "$cache_hit" "$artifact_size"
    
    # Generate recommendations
    generate_optimization_recommendations "$total_duration" "$rust_duration" "$tauri_duration" "$frontend_duration" "$cache_hit" "$artifact_size"
    
    print_success "Performance measurement completed"
}

# Record metrics to CSV
record_metrics() {
    local build_type=$1
    local total_time=$2
    local rust_time=$3
    local tauri_time=$4
    local frontend_time=$5
    local cache_hit=$6
    local artifact_size=$7
    local success=$8
    
    local timestamp=$(date -Iseconds)
    local cache_value="false"
    
    if [[ "$cache_hit" == "true" ]]; then
        cache_value="true"
    fi
    
    echo "$timestamp,$build_type,$total_time,$rust_time,$tauri_time,$frontend_time,$cache_value,$artifact_size,$success" >> "$METRICS_FILE"
    
    print_status "Metrics recorded to $METRICS_FILE"
}

# Analyze performance metrics
analyze_performance() {
    local total_time=$1
    local rust_time=$2
    local tauri_time=$3
    local frontend_time=$4
    local cache_hit=$5
    local artifact_size=$6
    
    echo ""
    print_status "Performance Analysis:"
    echo "=================================="
    
    # Total build time analysis
    if [[ $total_time -le $TARGET_BUILD_TIME ]]; then
        print_success "Total build time (${total_time}s) is within target (${TARGET_BUILD_TIME}s)"
    elif [[ $total_time -le $WARNING_THRESHOLD ]]; then
        print_warning "Total build time (${total_time}s) exceeds target but acceptable"
    else
        print_error "Total build time (${total_time}s) exceeds acceptable threshold"
    fi
    
    # Component breakdown
    local rust_percentage=$((rust_time * 100 / total_time))
    local tauri_percentage=$((tauri_time * 100 / total_time))
    local frontend_percentage=$((frontend_time * 100 / total_time))
    
    print_metric "Build breakdown:"
    echo "  Rust: ${rust_time}s (${rust_percentage}%)"
    echo "  Tauri: ${tauri_time}s (${tauri_percentage}%)"
    echo "  Frontend: ${frontend_time}s (${frontend_percentage}%)"
    
    # Cache analysis
    if [[ "$cache_hit" == "true" ]]; then
        print_success "Cache was utilized - this should improve build times"
    else
        print_warning "No cache detected - first build will be slower"
    fi
    
    # Artifact size analysis
    if [[ $artifact_size -gt 50000 ]]; then  # 50MB
        print_warning "Artifact size (${artifact_size}KB) is large"
    else
        print_success "Artifact size (${artifact_size}KB) is reasonable"
    fi
    
    # Historical comparison
    if [[ -f "$METRICS_FILE" ]]; then
        local build_count=$(tail -n +2 "$METRICS_FILE" | wc -l)
        if [[ $build_count -gt 1 ]]; then
            print_status "Historical comparison (based on $build_count builds):"
            
            # Calculate averages
            local avg_total=$(tail -n +2 "$METRICS_FILE" | cut -d, -f3 | awk '{sum+=$1} END {print int(sum/NR)}')
            local avg_rust=$(tail -n +2 "$METRICS_FILE" | cut -d, -f4 | awk '{sum+=$1} END {print int(sum/NR)}')
            local avg_tauri=$(tail -n +2 "$METRICS_FILE" | cut -d, -f5 | awk '{sum+=$1} END {print int(sum/NR)}')
            
            echo "  Average total time: ${avg_total}s"
            echo "  Average Rust time: ${avg_rust}s"
            echo "  Average Tauri time: ${avg_tauri}s"
            
            # Compare with current build
            if [[ $total_time -lt $avg_total ]]; then
                print_success "Current build is faster than average"
            else
                print_warning "Current build is slower than average"
            fi
        fi
    fi
}

# Generate optimization recommendations
generate_optimization_recommendations() {
    local total_time=$1
    local rust_time=$2
    local tauri_time=$3
    local frontend_time=$4
    local cache_hit=$5
    local artifact_size=$6
    
    echo ""
    print_optimization "Optimization Recommendations:"
    echo "=================================="
    
    local recommendations=()
    
    # Rust build optimizations
    if [[ $rust_time -gt 120 ]]; then  # 2 minutes
        recommendations+=("RUST_BUILD_SLOW")
    fi
    
    # Tauri build optimizations
    if [[ $tauri_time -gt 180 ]]; then  # 3 minutes
        recommendations+=("TAURI_BUILD_SLOW")
    fi
    
    # Frontend build optimizations
    if [[ $frontend_time -gt 60 ]]; then  # 1 minute
        recommendations+=("FRONTEND_BUILD_SLOW")
    fi
    
    # Cache optimizations
    if [[ "$cache_hit" == "false" ]]; then
        recommendations+=("CACHE_MISS")
    fi
    
    # Artifact size optimizations
    if [[ $artifact_size -gt 50000 ]]; then  # 50MB
        recommendations+=("ARTIFACT_SIZE_LARGE")
    fi
    
    # General optimizations
    if [[ $total_time -gt $TARGET_BUILD_TIME ]]; then
        recommendations+=("TOTAL_BUILD_SLOW")
    fi
    
    # Generate specific recommendations
    for rec in "${recommendations[@]}"; do
        case $rec in
            RUST_BUILD_SLOW)
                echo "🔧 Rust Build Optimizations:"
                echo "  - Enable incremental compilation: cargo build --incremental"
                echo "  - Use fewer CPU cores if system is overloaded"
                echo "  - Consider using rustc cache: export RUSTC_WRAPPER=sccache"
                echo "  - Optimize Rust dependencies: remove unused crates"
                echo ""
                ;;
            TAURI_BUILD_SLOW)
                echo "🔧 Tauri Build Optimizations:"
                echo "  - Ensure iOS project is properly initialized"
                echo "  - Check CocoaPods dependencies for updates"
                echo "  - Verify Xcode project settings are optimal"
                echo "  - Consider parallel builds: cargo tauri ios build -j"
                echo ""
                ;;
            FRONTEND_BUILD_SLOW)
                echo "🔧 Frontend Build Optimizations:"
                echo "  - Use Bun for faster package installation"
                echo "  - Enable build caching in frontend config"
                echo "  - Optimize bundle size and treeshaking"
                echo "  - Consider using Vite's build optimization features"
                echo ""
                ;;
            CACHE_MISS)
                echo "🔧 Cache Optimizations:"
                echo "  - Run pre-warm script: ./scripts/pre-warm-deps.sh"
                echo "  - Check CI/CD caching configuration"
                echo "  - Verify cache directories have proper permissions"
                echo "  - Consider using GitHub Actions cache for CI builds"
                echo ""
                ;;
            ARTIFACT_SIZE_LARGE)
                echo "🔧 Artifact Size Optimizations:"
                echo "  - Enable binary stripping: cargo build --release"
                echo "  - Use LTO (Link Time Optimization)"
                echo "  - Optimize for size: opt-level = 's'"
                echo "  - Remove debug symbols from release builds"
                echo ""
                ;;
            TOTAL_BUILD_SLOW)
                echo "🔧 General Build Optimizations:"
                echo "  - Use SSD storage for faster I/O"
                echo "  - Close unnecessary applications to free resources"
                echo "  - Ensure sufficient RAM is available"
                echo "  - Consider using build farm for large projects"
                echo ""
                ;;
        esac
    done
    
    # System recommendations
    echo "🔧 System Optimizations:"
    echo "  - Ensure macOS is updated to latest version"
    echo "  - Use Xcode 15.4+ for optimal performance"
    echo "  - Keep Rust and Bun updated to latest versions"
    echo "  - Monitor system resources during builds"
    echo ""
    
    # Save recommendations to file
    save_optimization_report "$total_time" "$rust_time" "$tauri_time" "$frontend_time" "$cache_hit" "$artifact_size" "${recommendations[@]}"
}

# Save optimization report
save_optimization_report() {
    local total_time=$1
    local rust_time=$2
    local tauri_time=$3
    local frontend_time=$4
    local cache_hit=$5
    local artifact_size=$6
    shift 6
    local recommendations=("$@")
    
    cat > "$OPTIMIZATION_REPORT" << EOF
# iOS Build Performance Optimization Report

**Generated**: $(date)
**Build Duration**: ${total_time}s
**Target Duration**: ${TARGET_BUILD_TIME}s

## Performance Metrics

| Component | Duration | Percentage |
|-----------|-----------|------------|
| Frontend | ${frontend_time}s | $((frontend_time * 100 / total_time))% |
| Rust | ${rust_time}s | $((rust_time * 100 / total_time))% |
| Tauri | ${tauri_time}s | $((tauri_time * 100 / total_time))% |
| **Total** | **${total_time}s** | **100%** |

## Build Analysis

- **Cache Utilization**: $cache_hit
- **Artifact Size**: ${artifact_size}KB
- **Build Success**: true

## Performance Assessment

EOF

    if [[ $total_time -le $TARGET_BUILD_TIME ]]; then
        echo "✅ **Performance**: EXCELLENT - Build time within target" >> "$OPTIMIZATION_REPORT"
    elif [[ $total_time -le $WARNING_THRESHOLD ]]; then
        echo "⚠️ **Performance**: ACCEPTABLE - Build time exceeds target but reasonable" >> "$OPTIMIZATION_REPORT"
    else
        echo "❌ **Performance**: NEEDS IMPROVEMENT - Build time exceeds acceptable threshold" >> "$OPTIMIZATION_REPORT"
    fi
    
    cat >> "$OPTIMIZATION_REPORT" << EOF

## Optimization Recommendations

EOF

    # Add recommendations based on analysis
    local has_recommendations=false
    
    for rec in "${recommendations[@]}"; do
        case $rec in
            RUST_BUILD_SLOW)
                echo "### Rust Build Optimizations" >> "$OPTIMIZATION_REPORT"
                echo "- Enable incremental compilation" >> "$OPTIMIZATION_REPORT"
                echo "- Use build caching (sccache)" >> "$OPTIMIZATION_REPORT"
                echo "- Optimize dependency tree" >> "$OPTIMIZATION_REPORT"
                echo "" >> "$OPTIMIZATION_REPORT"
                has_recommendations=true
                ;;
            TAURI_BUILD_SLOW)
                echo "### Tauri Build Optimizations" >> "$OPTIMIZATION_REPORT"
                echo "- Update CocoaPods dependencies" >> "$OPTIMIZATION_REPORT"
                echo "- Optimize Xcode project settings" >> "$OPTIMIZATION_REPORT"
                echo "- Use parallel builds" >> "$OPTIMIZATION_REPORT"
                echo "" >> "$OPTIMIZATION_REPORT"
                has_recommendations=true
                ;;
            FRONTEND_BUILD_SLOW)
                echo "### Frontend Build Optimizations" >> "$OPTIMIZATION_REPORT"
                echo "- Use Bun package manager" >> "$OPTIMIZATION_REPORT"
                echo "- Enable build caching" >> "$OPTIMIZATION_REPORT"
                echo "- Optimize bundle size" >> "$OPTIMIZATION_REPORT"
                echo "" >> "$OPTIMIZATION_REPORT"
                has_recommendations=true
                ;;
            CACHE_MISS)
                echo "### Cache Optimizations" >> "$OPTIMIZATION_REPORT"
                echo "- Run dependency pre-warming" >> "$OPTIMIZATION_REPORT"
                echo "- Configure CI/CD caching" >> "$OPTIMIZATION_REPORT"
                echo "- Verify cache permissions" >> "$OPTIMIZATION_REPORT"
                echo "" >> "$OPTIMIZATION_REPORT"
                has_recommendations=true
                ;;
            ARTIFACT_SIZE_LARGE)
                echo "### Artifact Size Optimizations" >> "$OPTIMIZATION_REPORT"
                echo "- Enable binary stripping" >> "$OPTIMIZATION_REPORT"
                echo "- Use LTO optimization" >> "$OPTIMIZATION_REPORT"
                echo "- Optimize for size over speed" >> "$OPTIMIZATION_REPORT"
                echo "" >> "$OPTIMIZATION_REPORT"
                has_recommendations=true
                ;;
        esac
    done
    
    if [[ "$has_recommendations" == "false" ]]; then
        echo "### 🎉 Excellent Performance!" >> "$OPTIMIZATION_REPORT"
        echo "No optimizations needed - build performance is within targets." >> "$OPTIMIZATION_REPORT"
    fi
    
    cat >> "$OPTIMIZATION_REPORT" << EOF

## Historical Trends

EOF

    # Add historical data if available
    if [[ -f "$METRICS_FILE" ]]; then
        local build_count=$(tail -n +2 "$METRICS_FILE" | wc -l)
        if [[ $build_count -gt 1 ]]; then
            echo "Based on $build_count previous builds:" >> "$OPTIMIZATION_REPORT"
            
            # Calculate trends
            local avg_total=$(tail -n +2 "$METRICS_FILE" | cut -d, -f3 | awk '{sum+=$1} END {print int(sum/NR)}')
            local min_total=$(tail -n +2 "$METRICS_FILE" | cut -d, -f3 | sort -n | head -1)
            local max_total=$(tail -n +2 "$METRICS_FILE" | cut -d, -f3 | sort -n | tail -1)
            
            echo "- Average build time: ${avg_total}s" >> "$OPTIMIZATION_REPORT"
            echo "- Fastest build: ${min_total}s" >> "$OPTIMIZATION_REPORT"
            echo "- Slowest build: ${max_total}s" >> "$OPTIMIZATION_REPORT"
            echo "" >> "$OPTIMIZATION_REPORT"
        fi
    fi
    
    cat >> "$OPTIMIZATION_REPORT" << EOF
## Next Steps

1. **Apply Recommendations**: Implement the optimizations above
2. **Monitor Performance**: Run regular performance measurements
3. **Track Trends**: Monitor build times over time
4. **Update Dependencies**: Keep tools and dependencies updated
5. **Optimize Iteratively**: Make small improvements and measure impact

---
*Report generated by iOS build performance monitor*
EOF

    print_status "Optimization report saved: $OPTIMIZATION_REPORT"
}

# Show performance history
show_history() {
    if [[ ! -f "$METRICS_FILE" ]]; then
        print_warning "No performance data available"
        return 1
    fi
    
    print_status "Performance History:"
    echo "=================================="
    
    # Show last 10 builds
    tail -n 11 "$METRICS_FILE" | while IFS=',' read -r timestamp build_type total_time rust_time tauri_time frontend_time cache_hit artifact_size success; do
        if [[ "$timestamp" == "timestamp" ]]; then
            printf "%-20s %-10s %-10s %-10s %-10s %-10s %-8s %-10s %-8s\n" "Timestamp" "Type" "Total" "Rust" "Tauri" "Frontend" "Cache" "Size" "Success"
            printf "%-20s %-10s %-10s %-10s %-10s %-10s %-8s %-10s %-8s\n" "--------------------" "----------" "----------" "----------" "----------" "----------" "--------" "----------" "--------"
        else
            local formatted_timestamp=$(date -d "$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$timestamp")
            local cache_status="No"
            if [[ "$cache_hit" == "true" ]]; then
                cache_status="Yes"
            fi
            local success_status="No"
            if [[ "$success" == "true" ]]; then
                success_status="Yes"
            fi
            printf "%-20s %-10s %-10s %-10s %-10s %-10s %-8s %-10s %-8s\n" "$formatted_timestamp" "$build_type" "${total_time}s" "${rust_time}s" "${tauri_time}s" "${frontend_time}s" "$cache_status" "${artifact_size}KB" "$success_status"
        fi
    done
}

# Generate performance summary
generate_summary() {
    if [[ ! -f "$METRICS_FILE" ]]; then
        print_warning "No performance data available"
        return 1
    fi
    
    print_status "Performance Summary:"
    echo "=================================="
    
    local build_count=$(tail -n +2 "$METRICS_FILE" | wc -l)
    local successful_builds=$(tail -n +2 "$METRICS_FILE" | grep ",true$" | wc -l)
    local avg_total=$(tail -n +2 "$METRICS_FILE" | cut -d, -f3 | awk '{sum+=$1} END {print int(sum/NR)}')
    local avg_rust=$(tail -n +2 "$METRICS_FILE" | cut -d, -f4 | awk '{sum+=$1} END {print int(sum/NR)}')
    local avg_tauri=$(tail -n +2 "$METRICS_FILE" | cut -d, -f5 | awk '{sum+=$1} END {print int(sum/NR)}')
    local avg_frontend=$(tail -n +2 "$METRICS_FILE" | cut -d, -f6 | awk '{sum+=$1} END {print int(sum/NR)}')
    local avg_artifact_size=$(tail -n +2 "$METRICS_FILE" | cut -d, -f8 | awk '{sum+=$1} END {print int(sum/NR)}')
    
    echo "📊 Overall Statistics:"
    echo "  Total builds: $build_count"
    echo "  Successful builds: $successful_builds"
    echo "  Success rate: $((successful_builds * 100 / build_count))%"
    echo ""
    echo "⏱️ Average Build Times:"
    echo "  Total: ${avg_total}s"
    echo "  Rust: ${avg_rust}s"
    echo "  Tauri: ${avg_tauri}s"
    echo "  Frontend: ${avg_frontend}s"
    echo ""
    echo "📦 Average Artifact Size: ${avg_artifact_size}KB"
    echo ""
    
    # Performance assessment
    if [[ $avg_total -le $TARGET_BUILD_TIME ]]; then
        print_success "Overall performance is EXCELLENT"
    elif [[ $avg_total -le $WARNING_THRESHOLD ]]; then
        print_warning "Overall performance is ACCEPTABLE"
    else
        print_error "Overall performance NEEDS IMPROVEMENT"
    fi
}

# Parse command line arguments
case "${1:-measure}" in
    measure)
        measure_build "${2:-release}" "${3:-aarch64-apple-ios}"
        ;;
    history)
        show_history
        ;;
    summary)
        generate_summary
        ;;
    report)
        if [[ -f "$OPTIMIZATION_REPORT" ]]; then
            cat "$OPTIMIZATION_REPORT"
        else
            print_warning "No optimization report available. Run 'measure' first."
        fi
        ;;
    clean)
        print_status "Cleaning performance data..."
        rm -rf "$PERFORMANCE_DIR"
        print_success "Performance data cleaned"
        ;;
    --help)
        echo "iOS Build Performance Monitor"
        echo ""
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  measure [type] [target]  Measure build performance"
        echo "  history                  Show performance history"
        echo "  summary                  Generate performance summary"
        echo "  report                   Show latest optimization report"
        echo "  clean                    Clean performance data"
        echo "  --help                   Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 measure release aarch64-apple-ios"
        echo "  $0 history"
        echo "  $0 summary"
        echo ""
        echo "Targets:"
        echo "  aarch64-apple-ios        iOS device"
        echo "  aarch64-apple-ios-sim    iOS simulator (ARM)"
        echo "  x86_64-apple-ios         iOS simulator (Intel)"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac