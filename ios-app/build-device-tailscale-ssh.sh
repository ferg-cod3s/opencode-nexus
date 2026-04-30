#!/bin/zsh
set -euo pipefail

# ios:device:tailscale - Build locally, push via SSH to a local Mac, install to iPhone
# 
# REQUIREMENTS:
#   1. iPhone on WiFi + Tailscale (you've done this)
#   2. A Mac on the same local WiFi as the iPhone  
#   3. SSH access to that Mac via Tailscale
#   4. iPhone paired to that Mac: idevicepair -u 00008140-000518440C7B001C pair
#
# USAGE:
#   TAILSCALE_SSH_HOST=username@100.x.y.z bun run ios:device:tailscale
#   or set in environment

ssh_host="${TAILSCALE_SSH_HOST:-${TAURSCALE_SSH_HOST:-}}"
device_id="${DEVICE_ID:-00008140-000518440C7B001C}"
bundle_id="${BUNDLE_ID:-com.agentic-codeflow.opencode-nexus}"
script_dir="$(cd "${0:A:h}" && pwd)"
app_path="$script_dir/build/DerivedData/Build/Products/Debug-iphoneos/OpenCodeNexus.app"

if [[ -z "$ssh_host" ]]; then
  echo "ERROR: Set TAILSCALE_SSH_HOST=username@<Mac-Tailscale-IP>"
  echo "Example: TAILSCALE_SSH_HOST=john@100.127.65.2 bun run ios:device:tailscale"
  echo "Fallback TAURSCALE_SSH_HOST is still supported for existing local environments."
  exit 1
fi

echo "=== Step 1: Build for device (local) ==="
cd "$script_dir"
./build-device.sh --build-only

if [[ ! -d "$app_path" ]]; then
  echo "ERROR: Built app not found: $app_path"
  exit 1
fi
echo "✅ Build complete: $app_path"

echo ""
echo "=== Step 2: Transfer .app to remote Mac via Tailscale ==="
echo "Target: $ssh_host"

# Create temp dir on remote and transfer app
ssh "$ssh_host" "mkdir -p /tmp/opencode-nexus-build"
if [[ $? -ne 0 ]]; then
  echo "ERROR: Cannot SSH to $ssh_host"
  echo "Ensure: tailscale up on both devices, SSH enabled on remote Mac"
  exit 1
fi

echo "Transfering .app bundle..."
rsync -avz -e ssh "$app_path" "$ssh_host:/tmp/opencode-nexus-build/"
if [[ $? -ne 0 ]]; then
  echo "ERROR: Transfer failed"
  exit 1
fi
echo "✅ Transfer complete"

echo ""
echo "=== Step 3: Install to iPhone via remote Mac ==="
ssh "$ssh_host" "ideviceinstaller -u $device_id -i /tmp/opencode-nexus-build/OpenCodeNexus.app"
if [[ $? -eq 0 ]]; then
  echo "✅ Install successful"
else
  echo "❌ Install failed"
  echo "On remote Mac, ensure:"
  echo "  1. iPhone paired: idevicepair -u $device_id list"
  echo "  2. Wireless Debugging enabled on iPhone"
  echo "  3. iPhone on same WiFi as remote Mac"
  exit 1
fi

echo ""
echo "=== Step 4: Launch app ==="
ssh "$ssh_host" "idevicediagnostics -u $device_id launch $bundle_id" 2>/dev/null || \
  echo "Launch skipped (manual launch on device is fine)"

echo ""
echo "✅ Done! App installed to iPhone via Tailscale → local Mac → WiFi"
