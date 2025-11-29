#!/bin/bash

# Setup script for Caddy local development with SSL
# This script sets up Caddy for local HTTPS development

set -e

echo "🔧 Setting up Caddy for local SSL development..."

# Check if Caddy is installed
if ! command -v caddy &> /dev/null; then
    echo "📦 Installing Caddy..."
    
    # Detect OS and install Caddy
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        sudo apt update
        sudo apt install caddy -y
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install caddy
        else
            echo "❌ Please install Homebrew first: https://brew.sh/"
            exit 1
        fi
    else
        echo "❌ Unsupported OS. Please install Caddy manually: https://caddyserver.com/install"
        exit 1
    fi
fi

echo "✅ Caddy installed: $(caddy version)"

# Create Caddyfile if it doesn't exist
CADDYFILE_PATH="$(pwd)/Caddyfile"
if [ ! -f "$CADDYFILE_PATH" ]; then
    echo "❌ Caddyfile not found at $CADDYFILE_PATH"
    exit 1
fi

echo "📁 Using Caddyfile at: $CADDYFILE_PATH"

# Start Caddy in development mode
echo "🚀 Starting Caddy with local SSL certificates..."
echo "📍 Your local HTTPS server will be available at:"
echo "   - https://localhost:3000 (if proxying to port 8080)"
echo "   - https://localhost:8080 (if server runs directly)"
echo ""
echo "🔑 Caddy will automatically generate self-signed certificates"
echo "📱 Your mobile app can now connect via HTTPS with certificate validation"
echo ""

# Check if port is already in use
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port 3000 is already in use. You may need to stop the existing service."
fi

if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port 8080 is already in use. This might be your OpenCode server."
fi

# Start Caddy
echo "🔄 Starting Caddy..."
caddy run --config "$CADDYFILE_PATH" --adapter caddyfile

# Note: This will run until you stop it (Ctrl+C)
# For production, use: caddy start --config "$CADDYFILE_PATH"