# 📱 iOS Certificate Password Setup

## ✅ What's Ready

All credential files are consolidated in `.credentials/` and 7/9 GitHub secrets are configured.

## 🔐 What You Need to Do

### 1. Edit the .env file
Edit `.credentials/.env` and replace these lines:

```bash
# FROM:
IOS_CERTIFICATE_PASSWORD=YOUR_CERT_PASSWORD_HERE
KEYCHAIN_PASSWORD=YOUR_CERT_PASSWORD_HERE

# TO (use your actual certificate password):
IOS_CERTIFICATE_PASSWORD=your_actual_certificate_password
KEYCHAIN_PASSWORD=your_actual_certificate_password
```

### 2. Run the final setup script
```bash
cd /home/vitruvius/git/opencode-nexus
./final-secrets-setup.sh
```

## 🎯 What This Does

The `.p12 password is the password you set when exporting the distribution certificate from your Mac's Keychain. This password:

- **Encrypts the private key** in the .p12 file
- **Required during iOS builds** to access the certificate
- **Used by GitHub Actions** to sign your app for TestFlight

## 🚀 After Setup

Once you add the password to `.env` and run the script:

- ✅ All 9 GitHub secrets will be configured
- ✅ iOS workflows will be ready to run
- ✅ TestFlight uploads will work automatically

## 📋 Scripts Available

- `final-secrets-setup.sh` - Reads from .env and sets remaining secrets
- `verify-secrets.sh` - Checks what's configured vs what's needed
- `quick-setup-secrets.sh` - Non-interactive setup (already run)

## 🔍 Current Status

- ✅ 7/9 secrets configured
- ⚠️  Need: IOS_CERTIFICATE_PASSWORD and KEYCHAIN_PASSWORD
- 📁 Files ready: `.credentials/` directory
- 🎯 22% complete - just need password!

---

**Next: Edit `.credentials/.env` with your certificate password, then run `./final-secrets-setup.sh`** 🎉