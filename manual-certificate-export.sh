#!/bin/bash
# Manual Certificate Export and Upload Guide

set -e

CERT_PASSWORD="eEEB#bMm$*Ejp!Q6zgqj"
OUTPUT_FILE="$HOME/distribution_cert.p12"

echo "📋 Manual Certificate Export Instructions"
echo "=================================="
echo ""
echo "Please follow these steps EXACTLY:"
echo ""
echo "1. 🍎 Open Keychain Access app"
echo "2. 📂 Select 'login' keychain (left sidebar)"
echo "3. 📜 Select 'My Certificates' category (left sidebar)"
echo "4. 🔍 Find 'Apple Distribution: John Ferguson (PCJU8QD9FN)'"
echo "5. 📤 Right-click → Export 'Apple Distribution: John Ferguson...'"
echo "6. 💾 Save as: distribution_cert.p12"
echo "7. 🔑 Enter password when prompted: $CERT_PASSWORD"
echo "8. 🔓 Enter your Mac login password to allow export"
echo ""
echo "⏳ After exporting, press any key to continue..."
read -n 1 -s

# Check if certificate was exported
if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "✅ Certificate found! Proceeding with upload..."
    echo ""
    
    # Now upload to GitHub Secrets
    echo "📤 Uploading to GitHub Secrets..."
    
    # Base64 encode and upload
    base64 -i "$OUTPUT_FILE" | gh secret set IOS_CERTIFICATE_P12
    
    # Set password
    gh secret set IOS_CERTIFICATE_PASSWORD --body "$CERT_PASSWORD"
    
    # Clean up local file
    rm "$OUTPUT_FILE"
    
    echo ""
    echo "🎉 Certificate upload complete!"
    echo ""
    echo "📋 Summary:"
    echo "  - Certificate: Uploaded to IOS_CERTIFICATE_P12"
    echo "  - Password: Set to IOS_CERTIFICATE_PASSWORD"
    echo "  - Local file: Removed for security"
    echo ""
    echo "🔍 Verifying secrets..."
    gh secret list | grep -E "CERTIFICATE|PASSWORD"
    
else
    echo ""
    echo "❌ Certificate not found at: $OUTPUT_FILE"
    echo "Please ensure you followed the export steps exactly."
    exit 1
fi