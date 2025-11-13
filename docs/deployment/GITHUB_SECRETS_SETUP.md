# GitHub Secrets Setup for iOS TestFlight Release

Quick reference for configuring GitHub Secrets using `gh cli`.

## Prerequisites

- ✅ `gh cli` installed and authenticated (`gh auth login`)
- ✅ All certificates and keys exported (see [IOS_RELEASE.md](./IOS_RELEASE.md))
- ✅ Files base64 encoded and ready

## One-Time Setup Commands

Copy and paste these commands in order. Replace values in `CAPS` with your actual values.

### 1. Apple Account Information

```bash
gh secret set APPLE_ID --body "YOUR_APPLE_ID_EMAIL@example.com"
gh secret set APPLE_TEAM_ID --body "PCJU8QD9FN"
```

**Where to get:**
- `APPLE_ID`: Your Apple Developer account email
- `APPLE_TEAM_ID`: Found in Apple Developer account settings (already set: PCJU8QD9FN)

### 2. App Store Connect API Keys

```bash
gh secret set APP_STORE_CONNECT_API_KEY_ID --body "YOUR_KEY_ID"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "YOUR_ISSUER_ID"
gh secret set APP_STORE_CONNECT_API_PRIVATE_KEY < path/to/authkey.p8.base64
```

**Where to get:**
- `APP_STORE_CONNECT_API_KEY_ID`: App Store Connect → Users and Access → Keys (shown in UI)
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect → Users and Access → Keys (UUID shown in UI)
- `.p8 file path`: Location of your base64-encoded API private key

**To create these:**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Users and Access → Keys
3. Click "Generate API Key"
4. Enter description: "OpenCode CI/CD"
5. Select role: "App Manager"
6. Click "Generate"
7. Download the .p8 file

### 3. Code Signing Certificate

```bash
gh secret set IOS_CERTIFICATE_P12 < path/to/cert.p12.base64
gh secret set IOS_CERTIFICATE_PASSWORD --body "YOUR_CERTIFICATE_PASSWORD"
```

**Where to get:**
- `cert.p12.base64`: Xcode → Settings → Accounts → Manage Certificates → Right-click Apple Distribution → Export (save as .p12, then base64 encode)
- `YOUR_CERTIFICATE_PASSWORD`: Password you set when exporting the certificate

**To export certificate:**
1. Open Xcode
2. Settings → Accounts
3. Select your Apple ID
4. Click "Manage Certificates"
5. Right-click "Apple Distribution" certificate
6. Select "Export Certificate..."
7. Save as `distribution_cert.p12` with a strong password

### 4. Provisioning Profile

```bash
gh secret set IOS_PROVISIONING_PROFILE < path/to/profile.mobileprovision.base64
```

**Where to get:**
- `profile.mobileprovision.base64`: Base64-encoded App Store provisioning profile for com.agentic-codeflow.opencode-nexus

**To create/download profile:**
1. Go to [Apple Developer Certificates, IDs & Profiles](https://developer.apple.com/account/resources/certificates/list)
2. Select Profiles → Create New Profile
3. Select "App Store" type
4. Select App ID: com.agentic-codeflow.opencode-nexus
5. Select Certificate: Apple Distribution (the one you exported above)
6. Download the profile (name it: `OpenCodeNexus_AppStore.mobileprovision`)

## Helper: Base64 Encoding Commands

If you haven't already encoded your files:

```bash
# Encode .p8 API key
base64 -i AuthKey_KEYID.p8 -o authkey.p8.base64

# Encode .p12 certificate
base64 -i distribution_cert.p12 -o cert.p12.base64

# Encode .mobileprovision profile
base64 -i OpenCodeNexus_AppStore.mobileprovision -o profile.mobileprovision.base64
```

## Verification

After adding all secrets, verify they were created:

```bash
# List all secrets (doesn't show values)
gh secret list

# You should see these 8 secrets:
# APPLE_ID
# APPLE_TEAM_ID
# APP_STORE_CONNECT_API_KEY_ID
# APP_STORE_CONNECT_ISSUER_ID
# APP_STORE_CONNECT_API_PRIVATE_KEY
# IOS_CERTIFICATE_P12
# IOS_CERTIFICATE_PASSWORD
# IOS_PROVISIONING_PROFILE
```

## Full Setup Script (Optional)

If you want to set all secrets at once, create a file `setup_secrets.sh`:

```bash
#!/bin/bash
set -e

echo "Setting up GitHub Secrets for iOS TestFlight Release..."
echo ""

# Prompt for values
read -p "Enter your Apple ID email: " APPLE_ID
read -p "Enter Apple Team ID (default: PCJU8QD9FN): " APPLE_TEAM_ID
APPLE_TEAM_ID="${APPLE_TEAM_ID:-PCJU8QD9FN}"

read -p "Enter App Store Connect API Key ID: " API_KEY_ID
read -p "Enter App Store Connect Issuer ID: " ISSUER_ID

read -p "Enter path to certificate .p12.base64 file: " CERT_PATH
read -p "Enter certificate password: " CERT_PASSWORD
read -s -p "Enter path to provisioning profile .base64 file: " PROFILE_PATH

echo ""
echo "Setting secrets..."

# Set all secrets
gh secret set APPLE_ID --body "$APPLE_ID"
gh secret set APPLE_TEAM_ID --body "$APPLE_TEAM_ID"
gh secret set APP_STORE_CONNECT_API_KEY_ID --body "$API_KEY_ID"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "$ISSUER_ID"
gh secret set IOS_CERTIFICATE_P12 < "$CERT_PATH"
gh secret set IOS_CERTIFICATE_PASSWORD --body "$CERT_PASSWORD"
gh secret set IOS_PROVISIONING_PROFILE < "$PROFILE_PATH"

echo ""
echo "✅ All secrets configured!"
echo ""
gh secret list
```

Run with: `bash setup_secrets.sh`

## Using Secrets in Workflows

Once configured, use secrets in your workflows:

```yaml
env:
  APPLE_ID: ${{ secrets.APPLE_ID }}
  CERT_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}

run: |
  # Secrets are automatically masked in logs
  echo "Using Apple ID: $APPLE_ID"  # Will show as ***
```

GitHub automatically masks secret values in workflow logs for security.

## Troubleshooting

### "Secret not found"
- Verify you ran the `gh secret set` command
- Check you're in the correct repository directory
- Run `gh secret list` to confirm

### "Secret not decoding properly"
- Verify base64 encoding: `file authkey.p8.base64` should show text
- Try re-encoding: `base64 -i originalfile.p8 -o newfile.p8.base64`
- Check there are no line breaks in the base64 output

### "Authentication failed when setting secret"
- Run `gh auth login` to re-authenticate
- Verify you have permission to configure secrets in the repository

### Rotating Secrets

When a certificate or key expires:

1. Generate new certificate/key in Apple Developer portal
2. Export/encode the new files
3. Update the GitHub secret: `gh secret set SECRET_NAME < newfile.base64`
4. The workflow will use the new value on next run

---

**Reference**: [Full iOS Release Guide](./IOS_RELEASE.md)
