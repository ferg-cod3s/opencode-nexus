#!/bin/bash

# Connection Test Script for OpenCode Nexus
# Tests the complete flow from mobile app through proxies to OpenCode server

set -e

echo "🧪 OpenCode Nexus - Connection Testing"
echo "======================================"

# Configuration
API_KEY_FILE="$(pwd)/.env.local"
TEST_RESULTS_FILE="$(pwd)/test-results-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$1" | tee -a "$TEST_RESULTS_FILE"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$TEST_RESULTS_FILE"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$TEST_RESULTS_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$TEST_RESULTS_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$TEST_RESULTS_FILE"
}

# Test function
test_connection() {
    local url="$1"
    local description="$2"
    local api_key="$3"
    local expected_status="${4:-200}"
    
    log_info "Testing: $description"
    log "URL: $url"
    
    # Build curl command
    local curl_cmd="curl -s -w '%{http_code}' -o /dev/null"
    
    if [ -n "$api_key" ]; then
        curl_cmd="$curl_cmd -H 'X-API-Key: $api_key'"
    fi
    
    # Add insecure flag for localhost
    if [[ "$url" == *"localhost"* ]]; then
        curl_cmd="$curl_cmd -k"
    fi
    
    curl_cmd="$curl_cmd '$url/session'"
    
    log "Command: $curl_cmd"
    
    # Execute and capture status
    local status_code=$(eval "$curl_cmd")
    
    if [ "$status_code" -eq "$expected_status" ]; then
        log_success "✓ $description - Status: $status_code"
        return 0
    else
        log_error "✗ $description - Status: $status_code (expected: $expected_status)"
        return 1
    fi
}

# Test with verbose output
test_connection_verbose() {
    local url="$1"
    local description="$2"
    local api_key="$3"
    
    log_info "Verbose test: $description"
    
    local curl_cmd="curl -v"
    
    if [ -n "$api_key" ]; then
        curl_cmd="$curl_cmd -H 'X-API-Key: $api_key'"
    fi
    
    if [[ "$url" == *"localhost"* ]]; then
        curl_cmd="$curl_cmd -k"
    fi
    
    curl_cmd="$curl_cmd '$url/session'"
    
    log "Command: $curl_cmd"
    log "Response:"
    eval "$curl_cmd" 2>&1 | tee -a "$TEST_RESULTS_FILE"
    log ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit 1
    fi
    
    # Check if .env.local exists
    if [ ! -f "$API_KEY_FILE" ]; then
        log_error ".env.local file not found. Please run ./setup-api-keys.sh first"
        exit 1
    fi
    
    # Check if Caddy is running (for localhost tests)
    if ! lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Caddy is not running on port 3000. Local tests will fail."
        log_info "Start Caddy with: ./setup-caddy.sh"
    fi
    
    log_success "Prerequisites checked"
}

# Load configuration
load_config() {
    log_info "Loading configuration from $API_KEY_FILE"
    
    if [ -f "$API_KEY_FILE" ]; then
        API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
        SERVER_URL=$(grep "OPENCODE_SERVER_URL=" "$API_KEY_FILE" | cut -d'=' -f2)
        CONNECTION_METHOD=$(grep "OPENCODE_CONNECTION_METHOD=" "$API_KEY_FILE" | cut -d'=' -f2)
        
        log "API Key: ${API_KEY:0:8}..."
        log "Server URL: $SERVER_URL"
        log "Connection Method: $CONNECTION_METHOD"
    else
        log_error "Configuration file not found"
        exit 1
    fi
}

# Test suite
run_tests() {
    local failed_tests=0
    local total_tests=0
    
    log_info "Starting connection tests..."
    log ""
    
    # Test 1: Localhost (if Caddy is running)
    if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        ((total_tests++))
        if test_connection "https://localhost:3000" "Localhost (Caddy proxy)" "$API_KEY"; then
            log_success "Local connection test passed"
        else
            ((failed_tests++))
            log_error "Local connection test failed"
        fi
        log ""
    else
        log_warning "Skipping localhost tests (Caddy not running)"
    fi
    
    # Test 2: Direct connection to OpenCode server (if on port 8080)
    if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
        ((total_tests++))
        if test_connection "http://localhost:8080" "Direct OpenCode server" "$API_KEY"; then
            log_success "Direct server connection test passed"
        else
            ((failed_tests++))
            log_error "Direct server connection test failed"
        fi
        log ""
    else
        log_warning "Skipping direct server tests (OpenCode server not running on port 8080)"
    fi
    
    # Test 3: Cloudflare proxy
    ((total_tests++))
    if test_connection "https://opencode.fergify.work" "Cloudflare proxy" "$API_KEY"; then
        log_success "Cloudflare proxy test passed"
    else
        ((failed_tests++))
        log_error "Cloudflare proxy test failed"
    fi
    log ""
    
    # Test 4: Cloudflare Tunnel (VPS development)
    ((total_tests++))
    if test_connection "https://dev-opencode.fergify.work" "Cloudflare Tunnel" "$API_KEY"; then
        log_success "Cloudflare Tunnel test passed"
    else
        ((failed_tests++))
        log_warning "Cloudflare Tunnel test failed (tunnel may not be running)"
    fi
    log ""
    
    # Test 5: API key validation
    ((total_tests++))
    if test_connection "https://opencode.fergify.work" "Without API key" "" "401"; then
        log_success "API key validation working (correctly rejected)"
    else
        log_warning "API key validation may not be working properly"
    fi
    log ""
    
    # Test 6: CORS preflight
    log_info "Testing CORS preflight..."
    local cors_status=$(curl -s -w '%{http_code}' -o /dev/null -X OPTIONS -H "Origin: https://localhost:1420" -H "Access-Control-Request-Method: POST" "https://opencode.fergify.work/session")
    if [ "$cors_status" -eq "200" ] || [ "$cors_status" -eq "204" ]; then
        log_success "CORS preflight test passed"
    else
        log_warning "CORS preflight returned status: $cors_status"
    fi
    ((total_tests++))
    log ""
    
    # Summary
    log_info "Test Summary:"
    log "Total tests: $total_tests"
    log "Failed tests: $failed_tests"
    log "Success rate: $(( (total_tests - failed_tests) * 100 / total_tests ))%"
    
    if [ $failed_tests -eq 0 ]; then
        log_success "All tests passed! 🎉"
        return 0
    else
        log_error "$failed_tests test(s) failed"
        return 1
    fi
}

# Troubleshooting mode
troubleshoot() {
    log_info "Running troubleshooting tests..."
    
    # Test DNS resolution
    log_info "Testing DNS resolution..."
    if nslookup opencode.fergify.work >> "$TEST_RESULTS_FILE" 2>&1; then
        log_success "DNS resolution working"
    else
        log_error "DNS resolution failed"
    fi
    log ""
    
    # Test SSL certificate
    log_info "Testing SSL certificate..."
    if echo | openssl s_client -connect opencode.fergify.work:443 2>/dev/null | openssl x509 -noout -dates >> "$TEST_RESULTS_FILE" 2>&1; then
        log_success "SSL certificate valid"
    else
        log_error "SSL certificate issue detected"
    fi
    log ""
    
    # Test with verbose output
    if [ -n "$API_KEY" ]; then
        test_connection_verbose "https://opencode.fergify.work" "Verbose Cloudflare test" "$API_KEY"
    fi
}

# Mobile app simulation
simulate_mobile_app() {
    log_info "Simulating mobile app connection..."
    
    # Create mobile config
    local mobile_config="{
  \"apiKey\": \"$API_KEY\",
  \"serverUrl\": \"$SERVER_URL\",
  \"connectionMethod\": \"$CONNECTION_METHOD\",
  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
  \"version\": \"1.0.0\"
}"
    
    log "Mobile configuration:"
    echo "$mobile_config" | tee -a "$TEST_RESULTS_FILE"
    log ""
    
    # Test connection as mobile app would
    log_info "Testing mobile app connection flow..."
    
    # Test 1: Health check
    if test_connection "$SERVER_URL" "Mobile health check" "$API_KEY"; then
        log_success "Mobile health check passed"
    else
        log_error "Mobile health check failed"
    fi
    
    # Test 2: Session creation
    log_info "Testing session creation..."
    local session_response=$(curl -s -H "X-API-Key: $API_KEY" "$SERVER_URL/session" 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_success "Session creation successful"
        log "Response: $session_response"
    else
        log_error "Session creation failed"
    fi
}

# Main menu
echo "Choose test mode:"
echo "1) Quick connection test"
echo "2) Full test suite"
echo "3) Troubleshooting mode"
echo "4) Mobile app simulation"
echo "5) Custom test"
echo ""

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        check_prerequisites
        load_config
        test_connection "https://opencode.fergify.work" "Quick connection test" "$API_KEY"
        ;;
        
    2)
        check_prerequisites
        load_config
        run_tests
        ;;
        
    3)
        check_prerequisites
        load_config
        troubleshoot
        ;;
        
    4)
        check_prerequisites
        load_config
        simulate_mobile_app
        ;;
        
    5)
        check_prerequisites
        load_config
        echo "Enter custom URL to test:"
        read custom_url
        test_connection "$custom_url" "Custom test" "$API_KEY"
        ;;
        
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

log ""
log_info "Test results saved to: $TEST_RESULTS_FILE"
log_info "Review the file for detailed information"