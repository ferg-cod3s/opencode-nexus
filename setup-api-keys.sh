#!/bin/bash

# Secure API Key Distribution Script for OpenCode Nexus
# This script helps securely distribute API keys to mobile devices

set -e

echo "🔐 OpenCode Nexus - API Key Distribution"
echo "=========================================="

# Configuration
API_KEY_FILE="$(pwd)/.env.local"
QR_CODE_DIR="$(pwd)/qrcodes"
BACKUP_DIR="$(pwd)/backups"

# Create directories
mkdir -p "$QR_CODE_DIR"
mkdir -p "$BACKUP_DIR"

# Function to generate a secure API key
generate_api_key() {
    openssl rand -hex 32
}

# Function to create QR code for mobile scanning
create_qr_code() {
    local content="$1"
    local filename="$2"
    
    echo "📱 Creating QR code for mobile scanning..."
    
    # Check if qrencode is available
    if command -v qrencode &> /dev/null; then
        echo "$content" | qrencode -o "$QR_CODE_DIR/$filename.png" -s 10 -m 2
        echo "✅ QR code saved to: $QR_CODE_DIR/$filename.png"
        
        # Also create a text version
        echo "$content" > "$QR_CODE_DIR/$filename.txt"
        echo "📝 Text version saved to: $QR_CODE_DIR/$filename.txt"
    else
        echo "⚠️  qrencode not found. Installing..."
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt install qrencode -y
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install qrencode
        fi
        
        # Retry after installation
        if command -v qrencode &> /dev/null; then
            echo "$content" | qrencode -o "$QR_CODE_DIR/$filename.png" -s 10 -m 2
            echo "✅ QR code saved to: $QR_CODE_DIR/$filename.png"
            echo "$content" > "$QR_CODE_DIR/$filename.txt"
            echo "📝 Text version saved to: $QR_CODE_DIR/$filename.txt"
        else
            echo "❌ Could not install qrencode. Please install manually:"
            echo "   Ubuntu/Debian: sudo apt install qrencode"
            echo "   macOS: brew install qrencode"
            echo ""
            echo "📄 API Key (copy this manually):"
            echo "$content"
        fi
    fi
}

# Function to create mobile configuration file
create_mobile_config() {
    local api_key="$1"
    local server_url="$2"
    local config_file="$QR_CODE_DIR/mobile-config.json"
    
    cat > "$config_file" << EOF
{
  "apiKey": "$api_key",
  "serverUrl": "$server_url",
  "connectionMethod": "proxy",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "version": "1.0.0"
}
EOF
    
    echo "📱 Mobile config created: $config_file"
}

# Main menu
echo "Please select an option:"
echo "1) Generate new API key"
echo "2) Use existing API key"
echo "3) Show current API key"
echo "4) Create mobile connection package"
echo "5) Setup secure transfer"
echo ""

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo "🔑 Generating new API key..."
        API_KEY=$(generate_api_key)
        
        # Backup existing .env.local if it exists
        if [ -f "$API_KEY_FILE" ]; then
            cp "$API_KEY_FILE" "$BACKUP_DIR/.env.local.backup.$(date +%Y%m%d_%H%M%S)"
            echo "📦 Backed up existing .env.local"
        fi
        
        # Create new .env.local
        cat > "$API_KEY_FILE" << EOF
# OpenCode Nexus Environment Configuration
# Generated on $(date)

# API Configuration
OPENCODE_API_KEY=$API_KEY
OPENCODE_SERVER_URL=https://localhost:3000
OPENCODE_CONNECTION_METHOD=proxy

# Development Settings
NODE_ENV=development
LOG_LEVEL=debug

# Security Settings
API_KEY_HEADER=X-API-Key
CORS_ORIGIN=*
EOF
        
        echo "✅ New API key generated and saved to .env.local"
        echo "🔑 API Key: $API_KEY"
        ;;
        
    2)
        if [ -f "$API_KEY_FILE" ]; then
            API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
            echo "✅ Using existing API key from .env.local"
        else
            echo "❌ No .env.local file found. Please generate a new API key first."
            exit 1
        fi
        ;;
        
    3)
        if [ -f "$API_KEY_FILE" ]; then
            API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
            echo "🔑 Current API Key: $API_KEY"
            echo "📁 Configuration file: $API_KEY_FILE"
        else
            echo "❌ No .env.local file found."
        fi
        exit 0
        ;;
        
    4)
        echo "📱 Creating mobile connection package..."
        
        # Get API key
        if [ -f "$API_KEY_FILE" ]; then
            API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
            SERVER_URL=$(grep "OPENCODE_SERVER_URL=" "$API_KEY_FILE" | cut -d'=' -f2)
        else
            echo "❌ No .env.local file found. Please generate an API key first."
            exit 1
        fi
        
        # Create mobile config
        create_mobile_config "$API_KEY" "$SERVER_URL"
        
        # Create QR codes
        create_qr_code "$API_KEY" "api-key"
        create_qr_code "$SERVER_URL" "server-url"
        create_qr_code "$(cat "$QR_CODE_DIR/mobile-config.json")" "mobile-config"
        
        echo ""
        echo "📱 Mobile Connection Package Created!"
        echo "=================================="
        echo "📁 Location: $QR_CODE_DIR"
        echo "📄 Files created:"
        echo "   - mobile-config.json (complete configuration)"
        echo "   - api-key.png (API key QR code)"
        echo "   - server-url.png (Server URL QR code)"
        echo "   - mobile-config.png (Complete config QR code)"
        echo ""
        echo "📲 How to use on mobile:"
        echo "   1. Scan the QR codes with your mobile camera"
        echo "   2. Or transfer the mobile-config.json file via AirDrop/email"
        echo "   3. Import the configuration in your OpenCode Nexus app"
        ;;
        
    5)
        echo "🔒 Setting up secure transfer methods..."
        echo ""
        echo "Option A: QR Code Transfer (Recommended for development)"
        echo "  - Scan with mobile camera"
        echo "  - Automatic import in app"
        echo ""
        echo "Option B: Encrypted File Transfer"
        echo "  - Creates encrypted zip with password"
        echo "  - Transfer via secure channel"
        echo ""
        echo "Option C: Direct Network Transfer"
        echo "  - Temporary secure endpoint"
        echo "  - One-time download link"
        echo ""
        
        read -p "Choose transfer method (A/B/C): " transfer_choice
        
        case $transfer_choice in
            A|a)
                echo "📱 Creating QR codes for transfer..."
                if [ -f "$API_KEY_FILE" ]; then
                    API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
                    SERVER_URL=$(grep "OPENCODE_SERVER_URL=" "$API_KEY_FILE" | cut -d'=' -f2)
                    create_mobile_config "$API_KEY" "$SERVER_URL"
                    create_qr_code "$(cat "$QR_CODE_DIR/mobile-config.json")" "transfer-config"
                    echo "✅ QR codes ready for scanning!"
                else
                    echo "❌ No .env.local file found."
                fi
                ;;
                
            B|b)
                echo "🔐 Creating encrypted transfer package..."
                if [ -f "$API_KEY_FILE" ]; then
                    API_KEY=$(grep "OPENCODE_API_KEY=" "$API_KEY_FILE" | cut -d'=' -f2)
                    SERVER_URL=$(grep "OPENCODE_SERVER_URL=" "$API_KEY_FILE" | cut -d'=' -f2)
                    create_mobile_config "$API_KEY" "$SERVER_URL"
                    
                    # Create encrypted zip
                    cd "$QR_CODE_DIR"
                    zip -e -P "$(openssl rand -hex 16)" "mobile-config-$(date +%Y%m%d).zip" mobile-config.json
                    echo "🔐 Encrypted package created with random password"
                    echo "📦 File: mobile-config-$(date +%Y%m%d).zip"
                    echo "🔑 Password: Check the zip creation output"
                    cd - > /dev/null
                else
                    echo "❌ No .env.local file found."
                fi
                ;;
                
            C|c)
                echo "🌐 Setting up temporary secure endpoint..."
                echo "⚠️  This feature requires additional setup"
                echo "📝 Consider using a service like: https://transfer.sh/"
                echo "🔐 Or set up a temporary nginx endpoint with basic auth"
                ;;
                
            *)
                echo "❌ Invalid choice"
                exit 1
                ;;
        esac
        ;;
        
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ API key distribution setup complete!"
echo "📖 For more information, see the documentation"
echo "🔒 Remember to keep API keys secure and rotate regularly"