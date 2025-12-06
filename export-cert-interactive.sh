#!/bin/bash
# Simple interactive certificate export and upload

CERT_PASSWORD="eEEB#bMm\$*Ejp!Q6zgqj"
OUTPUT_FILE="$HOME/distribution_cert.p12"

echo "🔐 iOS Certificate Export & Upload"
echo "===================================="
echo ""
echo "This script will:"
echo "  1. Guide you to export the certificate from Keychain Access (interactive)"
echo "  2. Upload it to GitHub Secrets automatically"
echo ""

# Ask user to export manually
echo "⚠️  Keychain requires interactive authentication for security"
echo ""
echo "Please follow these steps in Keychain Access:"
echo "  1. Open Keychain Access app"
echo "  2. Select 'login' keychain (left sidebar)"
echo "  3. Select 'My Certificates' category"
echo "  4. Find 'Apple Distribution: John Ferguson (PCJU8QD9FN)'"
echo "  5. Right-click → Export 'Apple Distribution: John Ferguson...'"
echo "  6. Save as: distribution_cert.p12"
echo "  7. Enter password: $CERT_PASSWORD"
echo "  8. Enter your Mac login password"
echo ""
read -p "Press ENTER after exporting the certificate... "

# Check if file exists
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "❌ Certificate not found at $OUTPUT_FILE"
    echo "Please make sure you saved it correctly."
    exit 1
fi

echo ""
echo "✅ Certificate file found!"
ls -lh "$OUTPUT_FILE"

echo ""
echo "📤 Uploading to GitHub Secrets..."

# Upload certificate
echo "   - Encoding and uploading certificate..."
base64 -i "$OUTPUT_FILE" | gh secret set IOS_CERTIFICATE_P12
echo "   ✅ Certificate uploaded"

# Set password
echo "   - Setting password..."
gh secret set IOS_CERTIFICATE_PASSWORD --body "$CERT_PASSWORD"
echo "   ✅ Password set"

# Cleanup
echo "   - Cleaning up local file..."
rm "$OUTPUT_FILE"
echo "   ✅ Cleaned up"

echo ""
echo "🔍 Verifying secrets..."
gh secret list | grep -E "CERTIFICATE|PASSWORD"

echo ""
echo "🎉 Done! Your iOS build is ready to go!"
