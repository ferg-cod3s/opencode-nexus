#!/bin/bash
# Xcode Cloud Post-Clone Script
# Runs after repository is cloned, before pre_xcode_build.sh

set -e
echo "📥 Post-clone setup for Xcode Cloud..."

# Install Rust if not present
if ! command -v rustup &> /dev/null; then
    echo "🦀 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Install Tauri CLI
if ! command -v cargo-tauri &> /dev/null && ! cargo tauri --version &> /dev/null; then
    echo "📦 Installing Tauri CLI..."
    cargo install tauri-cli --version "^2" --locked
fi

echo "✅ Post-clone setup completed"