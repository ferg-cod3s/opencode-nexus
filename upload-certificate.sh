#!/bin/bash
# Upload Certificate to GitHub Secrets
# Run this after exporting distribution_cert.p12 from Keychain Access

set -e

echo "📤 Uploading Certificate to GitHub Secrets..."

if [ ! -f ~/distribution_cert.p12 ]; then
    echo "❌ Certificate file not found: ~/distribution_cert.p12"
    echo "Please export certificate first using Keychain Access:"
    echo "1. Open Keychain Access"
    echo "2. Select 'login' keychain"
    echo "3. Select 'My Certificates'"
    echo "4. Find 'Apple Distribution: John Ferguson (PCJU8QD9FN)'"
    echo "5. Right-click → Export 'Apple Distribution: John Ferguson...'"
    echo "6. Save as: distribution_cert.p12"
    echo "7. Enter password: eEEB#bMm$*Ejp!Q6zgqj"
    exit 1
fi

echo "✅ Found certificate file"

# Base64 encode and upload
echo "🔐 Encoding certificate..."
base64 -i ~/distribution_cert.p12 | gh secret set IOS_CERTIFICATE_P12

# Set password
echo "🔑 Setting certificate password..."
gh secret set IOS_CERTIFICATE_PASSWORD --body 'eEEB#bMm$*Ejp!Q6zgqj'

# Clean up local file
echo "🧹 Cleaning up local file..."
rm ~/distribution_cert.p12

# Verify
echo "✅ Verifying secrets..."
gh secret list | grep -E "CERTIFICATE|PASSWORD"

echo ""
echo "🎉 Certificate upload complete!"
echo ""
echo "📋 Summary:"
echo "  - Certificate: Uploaded to IOS_CERTIFICATE_P12"
echo "  - Password: Set to IOS_CERTIFICATE_PASSWORD"
echo "  - Local file: Removed for security"