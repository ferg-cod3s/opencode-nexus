#!/usr/bin/env python3
"""
CLI-based certificate export using Python Keychain access
Bypasses the security command's user interaction requirement
"""

import subprocess
import sys
import os
import base64
import json

CERT_PASSWORD = "eEEB#bMm$*Ejp!Q6zgqj"
OUTPUT_FILE = os.path.expanduser("~/distribution_cert.p12")
CERT_NAME = "Apple Distribution: John Ferguson (PCJU8QD9FN)"


def run_command(cmd, check=True):
    """Run a command and return output"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, check=check
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1


def export_certificate():
    """Export certificate using applescript via Python"""
    print(f"🔐 Exporting certificate: {CERT_NAME}")
    print("")

    # AppleScript to export certificate
    applescript = f"""
    tell application "Keychain Access"
        set certList to certificates of keychain "login.keychain"
        set targetCert to missing value
        
        repeat with cert in certList
            if name of cert contains "{CERT_NAME}" then
                set targetCert to cert
                exit repeat
            end if
        end repeat
        
        if targetCert is not missing value then
            export targetCert to file "{OUTPUT_FILE}" with password "{CERT_PASSWORD}"
            return true
        else
            return false
        end if
    end tell
    """

    # Run applescript
    cmd = f"osascript -e '{applescript}'"
    stdout, stderr, code = run_command(cmd)

    if code == 0 and os.path.exists(OUTPUT_FILE):
        print(f"✅ Certificate exported successfully to {OUTPUT_FILE}")
        return True
    else:
        print(f"⚠️  AppleScript export failed or certificate not found")
        return False


def upload_to_github():
    """Upload certificate to GitHub Secrets"""
    if not os.path.exists(OUTPUT_FILE):
        print(f"❌ Certificate file not found: {OUTPUT_FILE}")
        return False

    print(f"✅ Certificate file created")
    file_size = os.path.getsize(OUTPUT_FILE)
    print(f"   Size: {file_size / 1024:.1f} KB")
    print("")
    print("📤 Uploading to GitHub Secrets...")

    # Read and encode certificate
    print("   - Encoding certificate...")
    with open(OUTPUT_FILE, "rb") as f:
        cert_data = f.read()
    cert_b64 = base64.b64encode(cert_data).decode()

    # Upload certificate
    cmd = f"gh secret set IOS_CERTIFICATE_P12 --body '{cert_b64}'"
    stdout, stderr, code = run_command(cmd)
    if code == 0:
        print("   ✅ Certificate uploaded to IOS_CERTIFICATE_P12")
    else:
        print(f"   ❌ Failed to upload certificate: {stderr}")
        return False

    # Set password
    print("   - Setting password...")
    cmd = f"gh secret set IOS_CERTIFICATE_PASSWORD --body '{CERT_PASSWORD}'"
    stdout, stderr, code = run_command(cmd)
    if code == 0:
        print("   ✅ Password set to IOS_CERTIFICATE_PASSWORD")
    else:
        print(f"   ❌ Failed to set password: {stderr}")
        return False

    # Clean up
    print("   - Cleaning up local file...")
    try:
        os.remove(OUTPUT_FILE)
        print("   ✅ Local file removed")
    except Exception as e:
        print(f"   ⚠️  Failed to remove local file: {e}")

    return True


def verify_secrets():
    """Verify secrets are set"""
    print("")
    print("🔍 Verifying secrets...")
    cmd = "gh secret list | grep -E 'CERTIFICATE|PASSWORD'"
    stdout, stderr, code = run_command(cmd, check=False)
    if stdout:
        for line in stdout.split("\n"):
            if line.strip():
                print(f"   {line}")

    return code == 0


def main():
    """Main function"""
    # Export certificate
    if not export_certificate():
        print("")
        print("❌ Certificate export failed")
        print("")
        print("Manual export fallback:")
        print("1. Open Keychain Access app")
        print("2. Select 'login' keychain (left sidebar)")
        print("3. Select 'My Certificates' category")
        print("4. Find 'Apple Distribution: John Ferguson (PCJU8QD9FN)'")
        print("5. Right-click → Export 'Apple Distribution: John Ferguson...'")
        print("6. Save as: distribution_cert.p12")
        print(f"7. Enter password: {CERT_PASSWORD}")
        print("8. Enter your Mac login password to allow export")
        print("")
        print("Then run this script again")
        sys.exit(1)

    # Upload to GitHub
    if not upload_to_github():
        print("❌ Upload failed")
        sys.exit(1)

    # Verify
    if verify_secrets():
        print("")
        print("🎉 Certificate upload complete!")
        print("")
        print("📋 Summary:")
        print("  ✅ Certificate: Uploaded to IOS_CERTIFICATE_P12")
        print("  ✅ Password: Set to IOS_CERTIFICATE_PASSWORD")
        print("  ✅ Local file: Removed for security")
        print("")
        print("🚀 Ready to build iOS app!")
    else:
        print("⚠️  Could not verify secrets")
        sys.exit(1)


if __name__ == "__main__":
    main()
