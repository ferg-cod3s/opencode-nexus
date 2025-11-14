#!/bin/bash
# Setup script to organize all credentials and build files

echo "🔐 Setting up ~/.credentials/ folder..."

# Create credentials folder
mkdir -p ~/.credentials

# Copy provisioning profiles
echo "✓ Copying provisioning profiles..."
cp ~/Downloads/OpenCode_Nexus_App_Store*.mobileprovision ~/.credentials/ 2>/dev/null || true

# Copy .env file
if [ -f ".env" ]; then
    echo "✓ Copying .env to ~/.credentials/..."
    cp .env ~/.credentials/.env
fi

# Copy build scripts
echo "✓ Copying build scripts..."
cp *.sh ~/.credentials/ 2>/dev/null || true

# Copy important documentation
echo "✓ Copying documentation..."
cp GET_APPSTORE_PROFILE.md ~/.credentials/ 2>/dev/null || true
cp IOS_BUILD_SESSION_SUMMARY.md ~/.credentials/ 2>/dev/null || true
cp NEXT_SESSION_IOS_CHECKLIST.md ~/.credentials/ 2>/dev/null || true

# Show what was created
echo ""
echo "📦 Contents of ~/.credentials/:"
ls -lh ~/.credentials/

echo ""
echo "✅ Setup complete!"
echo ""
echo "Future builds can now use:"
echo "  - Provisioning profiles: ~/.credentials/OpenCode_Nexus_App_Store*.mobileprovision"
echo "  - Build scripts: ~/.credentials/*.sh"
echo "  - Environment: source ~/.credentials/.env"
echo "  - Documentation: ~/.credentials/"
