#!/bin/zsh
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  printf "Usage: %s [keychain]\n" "$0"
  printf "Defaults to ~/Library/Keychains/login.keychain-db.\n"
  printf "Set KEYCHAIN_PASSWORD to run non-interactively.\n"
  exit 0
fi

keychain="${1:-$HOME/Library/Keychains/login.keychain-db}"
timeout="${KEYCHAIN_TIMEOUT:-21600}"

if [[ ! -f "$keychain" ]]; then
  printf "Keychain not found: %s\n" "$keychain" >&2
  exit 1
fi

if [[ -n "${KEYCHAIN_PASSWORD:-}" ]]; then
  keychain_password="$KEYCHAIN_PASSWORD"
elif [[ -r /dev/tty ]]; then
  printf "Keychain password for %s: " "$keychain" >/dev/tty
  stty -echo </dev/tty
  IFS= read -r keychain_password </dev/tty
  stty echo </dev/tty
  printf "\n" >/dev/tty
else
  printf "No TTY available. Set KEYCHAIN_PASSWORD and rerun.\n" >&2
  exit 1
fi

security unlock-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut "$timeout" "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain"

unset keychain_password

security find-identity -v -p codesigning "$keychain"
printf "SSH signing is ready for xcodebuild.\n"
