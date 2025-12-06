#!/bin/bash
# CLI-based certificate export and upload to GitHub Secrets

set -e

CERT_PASSWORD="eEEB#bMm\$*Ejp!Q6zgqj"
OUTPUT_FILE="$HOME/distribution_cert.p12"
CERT_NAME="Apple Distribution: John Ferguson (PCJU8QD9FN)"

echo "🔐 Exporting certificate: $CERT_NAME"
echo ""

# Try method 1: Using security export with piped password
echo "Attempting certificate export..."

# Create a temporary file with just the password
TEMP_PASS_FILE=$(mktemp)
echo -n "eEEB#bMm\$*Ejp!Q6zgqj" > "$TEMP_PASS_FILE"

# Try exporting using the password file
if security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -o "$OUTPUT_FILE" \
  -P "eEEB#bMm\$*Ejp!Q6zgqj" 2>/dev/null; then
  
  echo "✅ Certificate exported successfully"
  
elif [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Certificate exported successfully (despite error message)"
  
else
  # Clean up
  rm -f "$TEMP_PASS_FILE"
  
  echo "❌ Export failed with security command"
  echo ""
  echo "macOS security command requires user interaction for keychain operations."
  echo "Please export manually using Keychain Access:"
  echo ""
  echo "1. Open Keychain Access app"
  echo "2. Select 'login' keychain (left sidebar)"
  echo "3. Select 'My Certificates' category"
  echo "4. Find 'Apple Distribution: John Ferguson (PCJU8QD9FN)'"
  echo "5. Right-click → Export 'Apple Distribution: John Ferguson...'"
  echo "6. Save as: distribution_cert.p12"
  echo "7. Enter password: eEEB#bMm\$*Ejp!Q6zgqj"
  echo "8. Enter your Mac login password to allow export"
  echo ""
  echo "Then run this script again:"
  echo "  $0"
  exit 1
fi

# Clean up temp file
rm -f "$TEMP_PASS_FILE"

# Check if file exists
if [ ! -f "$OUTPUT_FILE" ]; then
  echo "❌ Certificate file not found: $OUTPUT_FILE"
  exit 1
fi

echo "✅ Certificate file created: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"

# Now upload to GitHub Secrets
echo ""
echo "📤 Uploading to GitHub Secrets..."

# Base64 encode and upload
echo "   - Encoding certificate..."
base64 -i "$OUTPUT_FILE" | gh secret set IOS_CERTIFICATE_P12
echo "   ✅ Certificate uploaded to IOS_CERTIFICATE_P12"

# Set password
echo "   - Setting password..."
gh secret set IOS_CERTIFICATE_PASSWORD --body 'eEEB#bMm$*Ejp!Q6zgqj'
echo "   ✅ Password set to IOS_CERTIFICATE_PASSWORD"

# Clean up local file
echo "   - Cleaning up local file..."
rm "$OUTPUT_FILE"
echo "   ✅ Local file removed"

# Verify
echo ""
echo "🔍 Verifying secrets..."
gh secret list | grep -E "CERTIFICATE|PASSWORD"

echo ""
echo "🎉 Certificate upload complete!"
echo ""
echo "📋 Summary:"
echo "  ✅ Certificate: Uploaded to IOS_CERTIFICATE_P12"
echo "  ✅ Password: Set to IOS_CERTIFICATE_PASSWORD"
echo "  ✅ Local file: Removed for security"
echo ""
echo "🚀 Ready to build iOS app!"
