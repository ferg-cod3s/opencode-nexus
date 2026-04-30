#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
script_name="${0:t}"
project="$script_dir/OpenCodeNexus.xcodeproj"
scheme="${SCHEME:-OpenCodeNexus}"
configuration="${CONFIGURATION:-Debug}"
device_id="${DEVICE_ID:-00008140-000518440C7B001C}"
bundle_id="${BUNDLE_ID:-com.agentic-codeflow.opencode-nexus}"
derived_data="${DERIVED_DATA_PATH:-$script_dir/build/DerivedData}"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
keychain="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
keychain_timeout="${KEYCHAIN_TIMEOUT:-21600}"
signing_cert_sha="${SIGNING_CERT_SHA:-auto}"
disable_debug_dylib="${DISABLE_DEBUG_DYLIB:-1}"
allow_provisioning_updates=0
prepare_signing=0
install_app=1
launch_app=1
clean_build=0

usage() {
  printf "Usage: %s [options]\n" "$script_name"
  printf "\n"
  printf "Builds OpenCodeNexus for a physical iPhone, installs it, and launches it.\n"
  printf "\n"
  printf "Options:\n"
  printf "  -d, --device ID          Device UDID\n"
  printf "      --bundle-id ID       App bundle id\n"
  printf "      --scheme NAME        Xcode scheme\n"
  printf "  -c, --configuration CFG  Build configuration\n"
  printf "      --derived-data PATH  DerivedData output path\n"
  printf "      --developer-dir PATH Xcode Developer directory\n"
  printf "      --keychain PATH      Keychain for --prepare-signing\n"
  printf "      --signing-cert SHA   Code signing certificate SHA-1 hash, or 'auto'\n"
  printf "      --default-signing    Do not force a certificate SHA-1 hash\n"
  printf "      --debug-dylib        Keep Xcode debug dylib mode enabled\n"
  printf "      --allow-provisioning-updates\n"
  printf "                           Allow Xcode to refresh managed signing assets\n"
  printf "      --prepare-signing    Unlock keychain and allow codesign from SSH\n"
  printf "      --clean              Run clean before build\n"
  printf "      --build-only         Build without installing or launching\n"
  printf "      --skip-install       Build without installing\n"
  printf "      --skip-launch        Build/install without launching\n"
  printf "  -h, --help               Show this help\n"
  printf "\n"
  printf "Environment overrides: DEVICE_ID, BUNDLE_ID, SCHEME, CONFIGURATION,\n"
  printf "DERIVED_DATA_PATH, DEVELOPER_DIR, KEYCHAIN, KEYCHAIN_PASSWORD,\n"
  printf "KEYCHAIN_TIMEOUT, SIGNING_CERT_SHA, DISABLE_DEBUG_DYLIB.\n"
}

need_value() {
  if [[ $# -lt 2 || -z "$2" ]]; then
    printf "%s requires a value\n" "$1" >&2
    exit 1
  fi
}

prepare_keychain() {
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
  security set-keychain-settings -lut "$keychain_timeout" "$keychain"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain"
  unset keychain_password
}

detect_signing_cert() {
  local line rest
  local -a identities
  identities=("${(@f)$(security find-identity -v -p codesigning "$keychain" 2>/dev/null)}")
  for line in "${identities[@]}"; do
    if [[ "$line" == *'"Apple Development:'* ]]; then
      rest="${line#*) }"
      printf "%s" "${rest%% *}"
      return 0
    fi
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)
      need_value "$1" "${2:-}"
      device_id="$2"
      shift 2
      ;;
    --bundle-id)
      need_value "$1" "${2:-}"
      bundle_id="$2"
      shift 2
      ;;
    --scheme)
      need_value "$1" "${2:-}"
      scheme="$2"
      shift 2
      ;;
    -c|--configuration)
      need_value "$1" "${2:-}"
      configuration="$2"
      shift 2
      ;;
    --derived-data)
      need_value "$1" "${2:-}"
      derived_data="$2"
      shift 2
      ;;
    --developer-dir)
      need_value "$1" "${2:-}"
      developer_dir="$2"
      shift 2
      ;;
    --keychain)
      need_value "$1" "${2:-}"
      keychain="$2"
      shift 2
      ;;
    --signing-cert)
      need_value "$1" "${2:-}"
      signing_cert_sha="$2"
      shift 2
      ;;
    --default-signing)
      signing_cert_sha=""
      shift
      ;;
    --debug-dylib)
      disable_debug_dylib=0
      shift
      ;;
    --allow-provisioning-updates)
      allow_provisioning_updates=1
      shift
      ;;
    --prepare-signing)
      prepare_signing=1
      shift
      ;;
    --clean)
      clean_build=1
      shift
      ;;
    --build-only)
      install_app=0
      launch_app=0
      shift
      ;;
    --skip-install)
      install_app=0
      shift
      ;;
    --skip-launch)
      launch_app=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$project" ]]; then
  printf "Project not found: %s\n" "$project" >&2
  exit 1
fi

if [[ ! -d "$developer_dir" ]]; then
  printf "Developer directory not found: %s\n" "$developer_dir" >&2
  exit 1
fi

export DEVELOPER_DIR="$developer_dir"

if (( prepare_signing )); then
  printf "Preparing keychain for SSH signing...\n"
  prepare_keychain
fi

if [[ "$signing_cert_sha" == "auto" ]]; then
  if signing_cert_sha="$(detect_signing_cert)"; then
    printf "Using detected signing certificate %s...\n" "$signing_cert_sha"
  else
    signing_cert_sha=""
    allow_provisioning_updates=1
    printf "No Apple Development signing identity found; enabling managed signing refresh...\n"
  fi
fi

printf "Checking device %s...\n" "$device_id"
xcrun devicectl device info details --device "$device_id" >/dev/null

printf "Building %s for device %s...\n" "$scheme" "$device_id"
xcodebuild_args=(
  -project "$project"
  -scheme "$scheme"
  -configuration "$configuration"
  -destination "platform=iOS,id=$device_id"
  -derivedDataPath "$derived_data"
)

if (( allow_provisioning_updates )); then
  xcodebuild_args+=(-allowProvisioningUpdates)
fi

if [[ -n "$signing_cert_sha" ]]; then
  printf "Forcing signing certificate %s...\n" "$signing_cert_sha"
  xcodebuild_args+=("OTHER_CODE_SIGN_FLAGS=--sign $signing_cert_sha")
fi

if (( disable_debug_dylib )); then
  xcodebuild_args+=(ENABLE_DEBUG_DYLIB=NO)
fi

if (( clean_build )); then
  xcodebuild "${xcodebuild_args[@]}" clean build
else
  xcodebuild "${xcodebuild_args[@]}" build
fi

product_dir="$derived_data/Build/Products/${configuration}-iphoneos"
app_path="$product_dir/${scheme}.app"

if [[ ! -d "$app_path" ]]; then
  app_path="$(find "$product_dir" -maxdepth 1 -type d -name "*.app" -print -quit)"
fi

if [[ -z "$app_path" || ! -d "$app_path" ]]; then
  printf "Built app not found in %s\n" "$product_dir" >&2
  exit 1
fi

if (( install_app )); then
  printf "Installing %s...\n" "$app_path"
  xcrun devicectl device install app --device "$device_id" "$app_path"
fi

if (( launch_app )); then
  printf "Launching %s...\n" "$bundle_id"
  xcrun devicectl device process launch --device "$device_id" --terminate-existing "$bundle_id"
fi

printf "Done.\n"
