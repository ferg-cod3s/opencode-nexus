#!/bin/bash

# Cloudflare Tunnel Setup for OpenCode Nexus VPS Development
# Creates secure HTTPS tunnel from Cloudflare to your local OpenCode server

set -e

echo "🌐 Setting up Cloudflare Tunnel for OpenCode Nexus"
echo "================================================="

# Configuration
TUNNEL_NAME="opencode-nexus-dev"
TUNNEL_DOMAIN="dev-opencode.fergify.work"  # You can change this
LOCAL_PORT="8080"  # Your OpenCode server port
CONFIG_DIR="$HOME/.cloudflared"
SERVICE_FILE="/etc/systemd/system/cloudflared.service"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if cloudflared is installed
check_cloudflared() {
    log "Checking cloudflared installation..."
    
    if command -v cloudflared &> /dev/null; then
        log_success "cloudflared is already installed: $(cloudflared --version)"
        return 0
    fi
    
    log "Installing cloudflared..."
    
    # Detect OS and install
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        ARCH=$(uname -m)
        case $ARCH in
            x86_64)
                DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
                ;;
            aarch64)
                DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
                ;;
            *)
                log_error "Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac
        
        wget -O cloudflared "$DOWNLOAD_URL"
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
        
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install cloudflared
        else
            log_error "Please install Homebrew first: https://brew.sh/"
            exit 1
        fi
    else
        log_error "Unsupported OS. Please install cloudflared manually."
        exit 1
    fi
    
    log_success "cloudflared installed successfully"
}

# Authenticate with Cloudflare
authenticate_cloudflare() {
    log "Authenticating with Cloudflare..."
    
    if [ -f "$CONFIG_DIR/cert.pem" ]; then
        log_warning "Cloudflare credentials already exist"
        read -p "Do you want to re-authenticate? (y/N): " reauth
        if [[ ! $reauth =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    cloudflared tunnel login
    
    log_success "Authentication completed"
}

# Create tunnel
create_tunnel() {
    log "Creating tunnel: $TUNNEL_NAME"
    
    # Check if tunnel already exists
    if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
        log_warning "Tunnel '$TUNNEL_NAME' already exists"
        read -p "Do you want to use existing tunnel? (Y/n): " use_existing
        if [[ ! $use_existing =~ ^[Nn]$ ]]; then
            TUNNEL_UUID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
            log_success "Using existing tunnel: $TUNNEL_UUID"
            return 0
        fi
    fi
    
    # Create new tunnel
    TUNNEL_UUID=$(cloudflared tunnel create "$TUNNEL_NAME" --output json | jq -r '.uuid')
    
    log_success "Tunnel created with UUID: $TUNNEL_UUID"
}

# Create tunnel configuration
create_tunnel_config() {
    log "Creating tunnel configuration..."
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/config.yml" << EOF
tunnel: $TUNNEL_UUID
credentials-file: $CONFIG_DIR/$TUNNEL_UUID.json

ingress:
  # Main OpenCode server
  - hostname: $TUNNEL_DOMAIN
    service: http://localhost:$LOCAL_PORT
    
  # Fallback for any other requests
  - service: http_status:404
EOF
    
    log_success "Tunnel configuration created at $CONFIG_DIR/config.yml"
    log "Domain: $TUNNEL_DOMAIN"
    log "Local service: http://localhost:$LOCAL_PORT"
}

# Create DNS record
create_dns_record() {
    log "Creating DNS record..."
    
    cloudflared tunnel route dns "$TUNNEL_NAME" "$TUNNEL_DOMAIN"
    
    log_success "DNS record created: $TUNNEL_DOMAIN → tunnel"
}

# Test tunnel
test_tunnel() {
    log "Testing tunnel connection..."
    
    # Start tunnel in background for testing
    log "Starting tunnel for testing (this may take a moment)..."
    
    # Test if local server is running
    if ! curl -s "http://localhost:$LOCAL_PORT" > /dev/null; then
        log_warning "Local server on port $LOCAL_PORT is not responding"
        log "Make sure your OpenCode server is running before testing"
    fi
    
    log_success "Tunnel setup complete!"
    log ""
    log "To start the tunnel manually:"
    log "  cloudflared tunnel run $TUNNEL_NAME"
    log ""
    log "To start as a service:"
    log "  sudo ./setup-cloudflare-tunnel.sh service"
    log ""
    log "Your mobile app can connect to:"
    log "  URL: https://$TUNNEL_DOMAIN"
    log "  Method: tunnel"
    log "  SSL: Verified (Cloudflare)"
}

# Setup as systemd service
setup_service() {
    log "Setting up cloudflared as systemd service..."
    
    # Create systemd service file
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=cloudflared tunnel
After=network.target

[Service]
User=$USER
Group=$USER
ExecStart=/usr/local/bin/cloudflared tunnel run $TUNNEL_NAME
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared
    sudo systemctl start cloudflared
    
    log_success "Cloudflare tunnel service started"
    log "Check status with: sudo systemctl status cloudflared"
    log "View logs with: sudo journalctl -u cloudflared -f"
}

# Show status
show_status() {
    log "Cloudflare Tunnel Status:"
    log "========================"
    
    if command -v cloudflared &> /dev/null; then
        log "cloudflared: $(cloudflared --version)"
    else
        log "cloudflared: Not installed"
    fi
    
    if [ -f "$CONFIG_DIR/config.yml" ]; then
        log "Config: $CONFIG_DIR/config.yml"
        log "Domain: $TUNNEL_DOMAIN"
        log "Local port: $LOCAL_PORT"
    else
        log "Config: Not created"
    fi
    
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        log "Service: Running"
    else
        log "Service: Not running"
    fi
}

# Main menu
case "${1:-}" in
    "install")
        check_cloudflared
        authenticate_cloudflare
        create_tunnel
        create_tunnel_config
        create_dns_record
        test_tunnel
        ;;
        
    "service")
        setup_service
        ;;
        
    "status")
        show_status
        ;;
        
    "start")
        if [ -f "$CONFIG_DIR/config.yml" ]; then
            log "Starting tunnel manually..."
            cloudflared tunnel run "$TUNNEL_NAME"
        else
            log_error "Tunnel configuration not found. Run './setup-cloudflare-tunnel.sh install' first."
        fi
        ;;
        
    "stop")
        if systemctl is-active --quiet cloudflared 2>/dev/null; then
            sudo systemctl stop cloudflared
            log_success "Tunnel service stopped"
        else
            log_warning "Tunnel service is not running"
        fi
        ;;
        
    *)
        echo "Cloudflare Tunnel Setup for OpenCode Nexus"
        echo "Usage: $0 {install|service|status|start|stop}"
        echo ""
        echo "Commands:"
        echo "  install  - Install and configure tunnel (run once)"
        echo "  service  - Setup as systemd service"
        echo "  status   - Show current status"
        echo "  start    - Start tunnel manually"
        echo "  stop     - Stop tunnel service"
        echo ""
        echo "Quick start:"
        echo "  1. $0 install"
        echo "  2. $0 service"
        echo "  3. Test with: curl https://$TUNNEL_DOMAIN"
        ;;
esac