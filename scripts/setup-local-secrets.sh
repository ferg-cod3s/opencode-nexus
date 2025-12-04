#!/bin/bash

# Setup script for local testing secrets
# This script helps create and manage local secrets for GitHub Actions testing

set -e

SECRETS_FILE=".secrets.local"
SECRETS_EXAMPLE=".secrets.local.example"

echo "🔐 Setting up local secrets for GitHub Actions testing..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if secrets file already exists
if [ -f "$SECRETS_FILE" ]; then
    print_warning "Secrets file already exists at $SECRETS_FILE"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping existing secrets file"
        exit 0
    fi
fi

# Create secrets file from example
if [ -f "$SECRETS_EXAMPLE" ]; then
    cp "$SECRETS_EXAMPLE" "$SECRETS_FILE"
    print_status "Created secrets file from example"
else
    # Create basic secrets file
    cat > "$SECRETS_FILE" << EOF
# Local Secrets for GitHub Actions Testing
# This file contains secrets for local Act CLI testing
# IMPORTANT: This file should be gitignored and never committed!

# GitHub Token for API access
GITHUB_TOKEN=your_github_token_here

# iOS Build Secrets (if testing locally)
IOS_CERTIFICATE_P12=base64_encoded_certificate_here
IOS_CERTIFICATE_PASSWORD=your_certificate_password_here
IOS_PROVISIONING_PROFILE=base64_encoded_profile_here

# API Keys (if needed for testing)
OPENCODE_API_KEY=your_api_key_here
SENTRY_DSN=your_sentry_dsn_here

# Database credentials (for integration testing)
DATABASE_URL=postgresql://test:test@localhost:5432/test_db
REDIS_URL=redis://localhost:6379

# Other environment variables needed for testing
NODE_ENV=test
RUST_LOG=debug
RUST_BACKTRACE=1
EOF
    print_status "Created basic secrets file"
fi

# Function to prompt for secret
prompt_secret() {
    local var_name=$1
    local prompt_text=$2
    local default_value=$3
    
    echo
    print_info "$prompt_text"
    if [ -n "$default_value" ]; then
        read -p "Enter value (or press Enter for default): " -s value
        echo
        if [ -z "$value" ]; then
            value="$default_value"
        fi
    else
        read -p "Enter value (or press Enter to skip): " -s value
        echo
    fi
    
    if [ -n "$value" ]; then
        # Escape special characters for sed
        value=$(printf '%s\n' "$value" | sed 's/[[\.*^$()+?{|]/\\&/g')
        sed -i.bak "s/^${var_name}=.*$/${var_name}=${value}/" "$SECRETS_FILE"
        rm "${SECRETS_FILE}.bak"
        print_status "Updated $var_name"
    else
        print_warning "Skipped $var_name"
    fi
}

# Prompt for essential secrets
echo
print_info "Let's configure essential secrets for local testing..."

# GitHub Token (optional but recommended)
prompt_secret "GITHUB_TOKEN" "Enter your GitHub token (for API access):" ""

# Database URLs (for integration testing)
prompt_secret "DATABASE_URL" "Enter test database URL:" "postgresql://test:test@localhost:5432/test_db"
prompt_secret "REDIS_URL" "Enter Redis URL:" "redis://localhost:6379"

# Environment variables
prompt_secret "NODE_ENV" "Enter Node environment:" "test"
prompt_secret "RUST_LOG" "Enter Rust log level:" "debug"

# Set file permissions
chmod 600 "$SECRETS_FILE"
print_status "Set secure permissions on secrets file"

# Verify file is in .gitignore
if ! grep -q "^\.secrets\.local$" .gitignore; then
    echo "" >> .gitignore
    echo "# Local testing secrets" >> .gitignore
    echo ".secrets.local" >> .gitignore
    print_status "Added .secrets.local to .gitignore"
fi

# Create Act CLI configuration if it doesn't exist
if [ ! -f ".actrc" ]; then
    print_warning ".actrc not found. Creating basic configuration..."
    cat > .actrc << EOF
# Act CLI Configuration for OpenCode Nexus
-P ubuntu-latest=nektos/act-ubuntu-latest:latest
-P macos-14=nektos/act-macos-latest:latest
-s .secrets.local
EOF
    print_status "Created .actrc configuration"
fi

echo
print_status "Local secrets setup completed! 🎉"
echo
print_info "Next steps:"
echo "1. Review and update $SECRETS_FILE with any additional secrets"
echo "2. Test your workflows with: act -l"
echo "3. Run workflows locally with: act"
echo
print_warning "Never commit $SECRETS_FILE to version control!"
echo
print_info "The secrets file is configured for:"
echo "- Act CLI local testing"
echo "- Integration testing with local databases"
echo "- Environment variable simulation"
echo
echo "For more information, see the GitHub Actions testing documentation."