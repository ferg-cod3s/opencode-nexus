#!/bin/bash

# Remote API Key Distribution for OpenCode Nexus VPS
# This script handles API key distribution for remote development via Cloudflare Tunnel

set -e

echo "🌐 OpenCode Nexus - Remote API Key Distribution"
echo "================================================="

# Configuration
API_KEY_FILE="$(pwd)/.env.local"
QR_CODE_DIR="$(pwd)/qrcodes"
BACKUP_DIR="$(pwd)/backups"
TUNNEL_DOMAIN="dev-opencode.fergify.work"  # Should match tunnel setup

# Create directories
mkdir -p "$QR_CODE_DIR"
mkdir -p "$BACKUP_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo "$1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to generate a secure API key
generate_api_key() {
    openssl rand -hex 32
}

# Function to create QR code for mobile scanning
create_qr_code() {
    local content="$1"
    local filename="$2"
    
    log_info "Creating QR code for mobile scanning..."
    
    # Check if qrencode is available
    if command -v qrencode &> /dev/null; then
        echo "$content" | qrencode -o "$QR_CODE_DIR/$filename.png" -s 10 -m 2
        log_success "QR code saved to: $QR_CODE_DIR/$filename.png"
        
        # Also create a text version
        echo "$content" > "$QR_CODE_DIR/$filename.txt"
        log_success "Text version saved to: $QR_CODE_DIR/$filename.txt"
    else
        log_warning "qrencode not found. Installing..."
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt update && sudo apt install -y qrencode
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install qrencode
        fi
        
        # Retry after installation
        if command -v qrencode &> /dev/null; then
            echo "$content" | qrencode -o "$QR_CODE_DIR/$filename.png" -s 10 -m 2
            log_success "QR code saved to: $QR_CODE_DIR/$filename.png"
            echo "$content" > "$QR_CODE_DIR/$filename.txt"
            log_success "Text version saved to: $QR_CODE_DIR/$filename.txt"
        else
            log_error "Could not install qrencode"
            log "📄 Content (copy this manually):"
            echo "$content"
        fi
    fi
}

# Function to create mobile configuration file
create_mobile_config() {
    local api_key="$1"
    local server_url="$2"
    local connection_method="$3"
    local config_file="$QR_CODE_DIR/mobile-config.json"
    
    cat > "$config_file" << EOF
{
  "apiKey": "$api_key",
  "serverUrl": "$server_url",
  "connectionMethod": "$connection_method",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "version": "1.0.0",
  "sslVerification": true,
  "environment": "development"
}
EOF
    
    log_success "Mobile config created: $config_file"
}

# Function to test tunnel connectivity
test_tunnel() {
    local test_url="https://$TUNNEL_DOMAIN/session"
    
    log_info "Testing tunnel connectivity..."
    log "Testing URL: $test_url"
    
    if curl -s -w '%{http_code}' -o /dev/null "$test_url" | grep -q '200\|401\|404'; then
        log_success "Tunnel is accessible!"
        return 0
    else
        log_warning "Tunnel may not be running or accessible"
        log "Make sure to run: ./setup-cloudflare-tunnel.sh install"
        log "Then: ./setup-cloudflare-tunnel.sh service"
        return 1
    fi
}

# Function to create secure transfer package
create_secure_package() {
    local api_key="$1"
    local server_url="$2"
    local connection_method="$3"
    
    log_info "Creating secure transfer package..."
    
    # Create mobile config
    create_mobile_config "$api_key" "$server_url" "$connection_method"
    
    # Create encrypted zip
    local package_name="mobile-config-$(date +%Y%m%d_%H%M%S)"
    local password=$(openssl rand -hex 16)
    
    cd "$QR_CODE_DIR"
    zip -e -P "$password" "$package_name.zip" mobile-config.json
    cd - > /dev/null
    
    log_success "Secure package created:"
    log "📦 File: $QR_CODE_DIR/$package_name.zip"
    log "🔑 Password: $password"
    log ""
    log "Transfer methods:"
    log "  - Email the zip file and share password separately"
    log "  - Use secure messaging app for password"
    log "  - AirDrop for iOS devices (if available)"
}

# Function to generate connection summary
generate_connection_summary() {
    local api_key="$1"
    local server_url="$2"
    local connection_method="$3"
    
    log_info "Generating connection summary..."
    
    cat > "$QR_CODE_DIR/CONNECTION_SUMMARY.md" << EOF
# OpenCode Nexus - Mobile Connection Summary

## Quick Setup

### Server Information
- **URL**: $server_url
- **Method**: $connection_method
- **SSL**: Verified (Cloudflare)
- **API Key**: ${api_key:0:8}...

### Mobile App Configuration

#### Option 1: Scan QR Code
1. Open mobile camera
2. Scan \`mobile-config.png\`
3. Tap notification to import

#### Option 2: Manual Entry
1. Open OpenCode Nexus app
2. Go to Settings → Connection
3. Enter:
   - Server URL: \`$server_url\`
   - Connection Method: \`$connection_method\`
   - API Key: \`$api_key\`

#### Option 3: Import Config File
1. Transfer \`mobile-config.json\` to device
2. Open app → Import Configuration
3. Select the config file

### Testing Connection
1. Open app after configuration
2. Should auto-connect to server
3. Check connection status in app

### Troubleshooting
- **Connection failed**: Check tunnel is running
- **SSL errors**: Ensure SSL verification is enabled
- **API key rejected**: Verify key is correct

### Tunnel Management
- Start tunnel: \`./setup-cloudflare-tunnel.sh start\`
- Stop tunnel: \`./setup-cloudflare-tunnel.sh stop\`
- Check status: \`./setup-cloudflare-tunnel.sh status\`

Generated: $(date)
EOF
    
    log_success "Connection summary created: $QR_CODE_DIR/CONNECTION_SUMMARY.md"
}

# Main menu
echo "Choose an option:"
echo "1) Generate new API key for remote development"
echo "2) Create mobile connection package"
echo "3) Test tunnel connectivity"
echo "4) Create secure transfer package"
echo "5) Show current configuration"
echo "6) Quick setup (generate + package)"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        log_info "Generating new API key for remote development..."
        API_KEY=$(generate_api_key)
        
        # Backup existing .env.local if it exists
        if [ -f "$API_KEY_FILE" ]; then
            cp "$API_KEY_FILE" "$BACKUP_DIR/.env.local.backup.$(date +%Y%m%d_%H%M%S)"
            log_success "Backed up existing .env.local"
        fi
        
        # Create new .env.local for remote development
        cat > "$API_KEY_FILE" << EOF
# OpenCode Nexus Remote Development Configuration
# Generated on $(date)

# API Configuration
OPENCODE_API_KEY=$API_KEY
OPENCODE_SERVER_URL=https://$TUNNEL_DOMAIN
OPENCODE_CONNECTION_METHOD=tunnel

# Development Settings
NODE_ENV=development
LOG_LEVEL=debug

# Security Settings
API_KEY_HEADER=X-API-Key
CORS_ORIGIN=*

# Tunnel Configuration
TUNNEL_DOMAIN=$TUNNEL_DOMAIN
TUNNEL_PORT=8080
EOF
        
        log_success "Remote API key generated and saved to .env.local"
        log "🔑 API Key: $API_KEY"
        log "🌐 Server URL: https://$TUNNEL_DOMAIN"
        ;;
        
    2)
        if [ -f "$API_KEY_FILE" ]; then
            API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
            SERVER_URL=$(grep "OPENCODE_SERVER_URL=" "$API_KEY_FILE" | cut -d'=' -f2)
            CONNECTION_METHOD=$(grep "OPENCODE_CONNECTION_METHOD=" "$API_KEY_FILE" | cut -d'=' -f2)
            
            log_success "Using existing configuration from .env.local"
            
            # Create mobile config
            create_mobile_config "$API_KEY" "$SERVER_URL" "$CONNECTION_METHOD"
            
            # Create QR codes
            create_qr_code "$API_KEY" "api-key"
            create_qr_code "$SERVER_URL" "server-url"
            create_qr_code "$(cat "$QR_CODE_DIR/mobile-config.json")" "mobile-config"
            
            # Generate summary
            generate_connection_summary "$API_KEY" "$SERVER_URL" "$CONNECTION_METHOD"
            
            log ""
            log_success "📱 Mobile Connection Package Created!"
            log "=================================="
            log "📁 Location: $QR_CODE_DIR"
            log "📄 Files created:"
            log "   - mobile-config.json (complete configuration)"
            log "   - api-key.png (API key QR code)"
            log "   - server-url.png (Server URL QR code)"
            log "   - mobile-config.png (Complete config QR code)"
            log "   - CONNECTION_SUMMARY.md (Setup instructions)"
            log ""
            log "📲 Mobile Setup Options:"
            log "   1. Scan mobile-config.png with camera (easiest)"
            log "   2. Transfer mobile-config.json via AirDrop/email"
            log "   3. Manually enter details from CONNECTION_SUMMARY.md"
        else
            log_error "No .env.local file found. Please generate an API key first."
        fi
        ;;
        
    3)
        test_tunnel
        ;;
        
    4)
        if [ -f "$API_KEY_FILE" ]; then
            API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
            SERVER_URL=$(grep "OPENCODE_SERVER_URL=" "$API_KEY_FILE" | cut -d'=' -f2)
            CONNECTION_METHOD=$(grep "OPENCODE_CONNECTION_METHOD=" "$API_KEY_FILE" | cut -d'=' -f2)
            
            create_secure_package "$API_KEY" "$SERVER_URL" "$CONNECTION_METHOD"
        else
            log_error "No .env.local file found. Please generate an API key first."
        fi
        ;;
        
    5)
        if [ -f "$API_KEY_FILE" ]; then
            log "Current Configuration:"
            log "===================="
            cat "$API_KEY_FILE"
        else
            log_error "No .env.local file found."
        fi
        ;;
        
    6)
        log_info "Quick setup: Generating API key and mobile package..."
        
        # Generate API key
        API_KEY=$(generate_api_key)
        
        # Backup existing file
        if [ -f "$API_KEY_FILE" ]; then
            cp "$API_KEY_FILE" "$BACKUP_DIR/.env.local.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Create .env.local
        cat > "$API_KEY_FILE" << EOF
# OpenCode Nexus Remote Development Configuration
# Generated on $(date)

# API Configuration
OPENCODE_API_KEY=$API_KEY
OPENCODE_SERVER_URL=https://$TUNNEL_DOMAIN
OPENCODE_CONNECTION_METHOD=tunnel

# Development Settings
NODE_ENV=development
LOG_LEVEL=debug

# Security Settings
API_KEY_HEADER=X-API-Key
CORS_ORIGIN=*

# Tunnel Configuration
TUNNEL_DOMAIN=$TUNNEL_DOMAIN
TUNNEL_PORT=8080
EOF
        
        # Create mobile package
        SERVER_URL="https://$TUNNEL_DOMAIN"
        CONNECTION_METHOD="tunnel"
        
        create_mobile_config "$API_KEY" "$SERVER_URL" "$CONNECTION_METHOD"
        create_qr_code "$(cat "$QR_CODE_DIR/mobile-config.json")" "mobile-config"
        generate_connection_summary "$API_KEY" "$SERVER_URL" "$CONNECTION_METHOD"
        
        log_success "🚀 Quick setup complete!"
        log ""
        log "Next steps:"
        log "1. Start tunnel: ./setup-cloudflare-tunnel.sh install"
        log "2. Setup service: ./setup-cloudflare-tunnel.sh service"
        log "3. Test connection: ./test-connection.sh"
        log "4. Scan QR code in $QR_CODE_DIR/mobile-config.png"
        ;;
        
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

log ""
log_success "Remote API key distribution setup complete!"
log "📖 For tunnel setup, see: ./setup-cloudflare-tunnel.sh"
log "🔒 Remember to keep API keys secure and rotate regularly"