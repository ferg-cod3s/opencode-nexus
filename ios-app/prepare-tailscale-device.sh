#!/bin/zsh
set -euo pipefail

device_id="${DEVICE_ID:-00008140-000518440C7B001C}"
bundle_id="${BUNDLE_ID:-com.agentic-codeflow.opencode-nexus}"

echo "=== Tailscale iOS Device Preparation ==="
echo ""

echo "Step 1: Check if iPhone is connected via USB..."
if idevice_id -l 2>/dev/null | grep -q "$device_id"; then
  echo "  ✅ iPhone (${device_id}) found via USB"
else
  echo "  ❌ iPhone not found via USB"
  echo "  Connect iPhone via USB cable first."
  exit 1
fi

echo ""
echo "Step 2: Pair device for wireless debugging..."
if idevicepair -u "$device_id" list 2>/dev/null | grep -q "$device_id"; then
  echo "  ✅ Device already paired"
else
  echo "  Pairing device..."
  idevicepair -u "$device_id" pair
  if [[ $? -eq 0 ]]; then
    echo "  ✅ Device paired successfully"
  else
    echo "  ❌ Pairing failed. Unlock iPhone and trust this Mac."
    exit 1
  fi
fi

echo ""
echo "Step 3: Verify Tailscale connectivity..."
if ! command -v tailscale &>/dev/null; then
  echo "  ❌ Tailscale not installed"
  exit 1
fi

tailscale status &>/dev/null
if [[ $? -ne 0 ]]; then
  echo "  ❌ Tailscale not running. Run: tailscale up"
  exit 1
fi
echo "  ✅ Tailscale is running"

echo ""
echo "Step 4: Check if iPhone appears in Tailscale peers..."
if tailscale status --json 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
peers=data.get('Peer',{})
for k,v in peers.items():
    name=v.get('HostName','').lower()
    if 'iphone' in name or 'phone' in name or 'ios' in name:
        print('FOUND')
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  echo "  ✅ iPhone found in Tailscale peers"
else
  echo "  ⚠️  iPhone not found in Tailscale peers"
  echo "  Ensure iPhone has Tailscale installed and connected"
fi

echo ""
echo "Step 5: Check network device discovery..."
if idevice_id -n 2>/dev/null | grep -q "$device_id"; then
  echo "  ✅ iPhone discoverable over network"
else
  echo "  ⚠️  iPhone not yet discoverable over network"
  echo "  On iPhone: Settings > Developer > Enable Wireless Debugging"
  echo "  Then reconnect to Tailscale on iPhone"
fi

echo ""
echo "=== Preparation Summary ==="
echo "Device ID: $device_id"
echo "Bundle ID: $bundle_id"
echo ""
echo "Next steps:"
echo "  1. Enable Wireless Debugging on iPhone (if not done)"
echo "  2. Ensure iPhone is on Tailscale VPN"
echo "  3. Run: bun run ios:device:tailscale"
echo "     or: cd ios-app && ./build-device-tailscale.sh"
