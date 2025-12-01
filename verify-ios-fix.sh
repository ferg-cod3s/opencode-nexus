#!/bin/bash
# iOS Build Fix Verification Script
# Tests that all fixes are correctly implemented

echo "🔍 Verifying iOS Build Fixes..."
echo "=================================="

# 1. Verify library name in Cargo.toml
echo "1. Checking Cargo.toml library name..."
LIB_NAME=$(grep '^name = "src_tauri_lib"' /home/vitruvius/git/opencode-nexus/src-tauri/Cargo.toml | sed 's/name = "//;s/"//g')
if [ "$LIB_NAME" = 'src_tauri_lib' ]; then
    echo "   ✅ Library name correct: $LIB_NAME"
else
    echo "   ❌ Library name incorrect: $LIB_NAME"
fi

# 2. Verify scripts use correct library name
echo ""
echo "2. Checking script library references..."

# Check ci_post_clone.sh
if rg -q "libsrc_tauri_lib.a" /home/vitruvius/git/opencode-nexus/ci_scripts/ci_post_clone.sh; then
    echo "   ✅ ci_post_clone.sh uses correct library name"
else
    echo "   ❌ ci_post_clone.sh missing correct library name"
fi

# Check build_rust_code.sh
if rg -q "libsrc_tauri_lib.a" /home/vitruvius/git/opencode-nexus/ci_scripts/build_rust_code.sh; then
    echo "   ✅ build_rust_code.sh uses correct library name"
else
    echo "   ❌ build_rust_code.sh missing correct library name"
fi

# Check GitHub Actions workflow
if rg -q "libsrc_tauri_lib.a" /home/vitruvius/git/opencode-nexus/.github/workflows/ios-release.yml; then
    echo "   ✅ GitHub Actions workflow uses correct library name"
else
    echo "   ❌ GitHub Actions workflow missing correct library name"
fi

# 3. Verify duplicate uuid removal
echo ""
echo "3. Checking for duplicate uuid dependencies..."
UUID_COUNT=$(rg -c 'uuid.*version.*1' /home/vitruvius/git/opencode-nexus/src-tauri/Cargo.toml)
if [ "$UUID_COUNT" = "1" ]; then
    echo "   ✅ Only one uuid dependency found"
else
    echo "   ❌ Multiple uuid dependencies found: $UUID_COUNT"
fi

# 4. Verify fallback logic exists
echo ""
echo "4. Checking for fallback logic..."

# Check ci_post_clone.sh fallback
if rg -q "find.*lib\*\.a" /home/vitruvius/git/opencode-nexus/ci_scripts/ci_post_clone.sh; then
    echo "   ✅ ci_post_clone.sh has fallback logic"
else
    echo "   ❌ ci_post_clone.sh missing fallback logic"
fi

# Check workflow fallback
if rg -q "find.*lib\*\.a" /home/vitruvius/git/opencode-nexus/.github/workflows/ios-release.yml; then
    echo "   ✅ GitHub Actions workflow has fallback logic"
else
    echo "   ❌ GitHub Actions workflow missing fallback logic"
fi

# 5. Summary
echo ""
echo "=================================="
echo "✅ iOS Build Fix Verification Complete"
echo ""
echo "Key Changes Made:"
echo "  • Library name: libsrc_tauri_lib.a (from Cargo.toml)"
echo "  • Fallback logic: Search for any lib*.a if specific not found"
echo "  • Duplicate uuid: Removed from Cargo.toml"
echo "  • CI compatibility: Pre-build + skip pattern implemented"
echo ""
echo "Expected Result:"
echo "  • No more TCP socket errors in CI"
echo "  • Correct library detected and copied"
echo "  • Xcode build phase skipped when library exists"
echo "  • Successful IPA generation for TestFlight"