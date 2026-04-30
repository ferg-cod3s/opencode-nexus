#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT_DIR/OpenAPIClient/Sources/OpenAPIClient/GeneratedSources"
TOOL_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TOOL_DIR"
}
trap cleanup EXIT

cat > "$TOOL_DIR/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenAPIGeneratorTool",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.11.0"),
    ]
)
SWIFT

mkdir -p "$OUTPUT_DIR"

swift run \
  --package-path "$TOOL_DIR" \
  swift-openapi-generator \
  generate "$ROOT_DIR/OpenAPIClient/Sources/OpenAPIClient/openapi.json" \
  --config "$ROOT_DIR/OpenAPIClient/Sources/OpenAPIClient/openapi-generator-config.yaml" \
  --output-directory "$OUTPUT_DIR"
