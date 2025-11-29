#!/bin/bash

# Simple web server to serve QR codes for mobile scanning
# This makes it easy to access QR codes from your phone

set -e

echo "📱 QR Code Web Server"
echo "===================="

QR_CODE_DIR="$(pwd)/qrcodes"
PORT=8081

# Check if qrcodes directory exists
if [ ! -d "$QR_CODE_DIR" ]; then
    echo "❌ QR codes directory not found. Run ./setup-remote-api-keys.sh first"
    exit 1
fi

# Check if mobile-config.png exists
if [ ! -f "$QR_CODE_DIR/mobile-config.png" ]; then
    echo "❌ QR code not found. Run ./setup-remote-api-keys.sh first"
    exit 1
fi

echo "🌐 Starting web server on port $PORT..."
echo "📱 Access from your phone at:"
echo "   http://YOUR_VPS_IP:$PORT"
echo ""
echo "📄 Files available:"
ls -la "$QR_CODE_DIR"
echo ""
echo "🔧 How to get QR code to your phone:"
echo "   1. Open http://YOUR_VPS_IP:$PORT on your phone"
echo "   2. Tap on mobile-config.png to view QR code"
echo "   3. Scan with your phone camera"
echo ""
echo "🛑 Press Ctrl+C to stop server"
echo ""

# Get VPS IP
VPS_IP=$(curl -s ifconfig.me) || VPS_IP="localhost"
echo "📱 Direct URL: http://$VPS_IP:$PORT"
echo ""

# Change to qrcodes directory and start simple HTTP server
cd "$QR_CODE_DIR"

# Try different Python versions
if command -v python3 &> /dev/null; then
    python3 -m http.server $PORT
elif command -v python &> /dev/null; then
    python -m SimpleHTTPServer $PORT
elif command -v node &> /dev/null; then
    npx http-server -p $PORT -c-1
else
    echo "❌ No Python or Node.js found. Please install one to run the web server."
    exit 1
fi