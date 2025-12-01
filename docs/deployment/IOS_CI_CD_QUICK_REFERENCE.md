# iOS CI/CD Pipeline Quick Reference

## 🚀 Quick Start

### 1. Test Locally First
```bash
# Run comprehensive test suite
./test-ios-ci-cd.sh
```

### 2. Deploy to GitHub Actions
- Replace existing workflow with `.github/workflows/ios-release-optimized.yml`
- Update secrets if needed
- Test on `test-ios-build` branch

### 3. Update Xcode Cloud (if used)
- Set `ci_post_clone` script to `ci_scripts/ci_post_clone_enhanced.sh`
- Set `pre_xcode_build` script to `ci_scripts/pre_xcode_build_enhanced.sh`
- Update "Build Rust Code" phase to use `ci_scripts/build_rust_code_enhanced.sh`

## 🔧 Key Files

| File | Purpose | Key Feature |
|------|---------|-------------|
| `ios-release-optimized.yml` | GitHub Actions workflow | Pre-build strategy |
| `ci_post_clone_enhanced.sh` | Xcode Cloud post-clone | Correct library naming |
| `pre_xcode_build_enhanced.sh` | Xcode Cloud pre-build | Comprehensive validation |
| `build_rust_code_enhanced.sh` | Xcode build phase | CI/local detection |
| `test-ios-ci-cd.sh` | Local testing | 8 test categories |

## 📋 Library Name Mapping

**Cargo.toml**: `name = "src_tauri_lib"`
**Built Library**: `libsrc_tauri_lib.a`
**Xcode Expects**: `libapp.a`

**Copy Commands**:
```bash
cp target/aarch64-apple-ios/release/libsrc_tauri_lib.a \
   gen/apple/Externals/arm64/Release/libapp.a
cp target/aarch64-apple-ios/release/libsrc_tauri_lib.a \
   gen/apple/Externals/arm64/release/libapp.a
```

## 🐛 Common Issues & Fixes

### Issue: Library Not Found
```bash
# Check if library was built
find src-tauri/target/aarch64-apple-ios/release -name "*.a"

# Verify Cargo.toml name
grep '^name = ' src-tauri/Cargo.toml
```

### Issue: Architecture Mismatch
```bash
# Check library architecture
lipo -info src-tauri/target/aarch64-apple-ios/release/libsrc_tauri_lib.a

# Verify iOS target installed
rustup target list --installed | grep aarch64-apple-ios
```

### Issue: Xcode Project Not Patched
```bash
# Check if patch was applied
grep "CI-Compatible: Skip if pre-built libapp.a exists" \
  src-tauri/gen/apple/src-tauri.xcodeproj/project.pbxproj
```

## 🔍 Validation Commands

### Pre-Build Validation
```bash
# Check library exists and is valid
file src-tauri/gen/apple/Externals/arm64/Release/libapp.a
lipo -info src-tauri/gen/apple/Externals/arm64/Release/libapp.a

# Check Xcode project
ls -la src-tauri/gen/apple/src-tauri.xcworkspace/
```

### Post-Build Validation
```bash
# Check IPA was created
find . -name "*.ipa" -type f

# Check IPA size
du -h *.ipa
```

## 📊 Environment Variables

### GitHub Actions
- `GITHUB_ACTIONS`: Set to "true" in GitHub Actions
- `CI_PRIMARY_REPOSITORY_PATH`: Not used in GitHub Actions

### Xcode Cloud
- `CI_PRIMARY_REPOSITORY_PATH`: Set to repository root
- `CI`: Set to "true" in Xcode Cloud
- `SRCROOT`: Set to `gen/apple` during Xcode build

## 🔄 Rollback Procedure

### Quick Rollback
```bash
# Restore original workflow
git checkout HEAD~1 -- .github/workflows/ios-release.yml

# Restore original scripts
git checkout HEAD~1 -- ci_scripts/

# Commit and push rollback
git commit -m "Rollback iOS CI/CD changes"
git push origin main
```

## 📞 Support

### Debug Information Collection
```bash
# System info
rustc --version
cargo --version
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version

# Build logs
cargo build --target aarch64-apple-ios --release --lib --verbose
```

### Error Reporting
Include in bug reports:
- Full error message
- System information (above)
- Relevant log snippets
- Steps to reproduce

## ✅ Success Indicators

### Build Success
- ✅ Rust library built successfully
- ✅ Library copied to correct locations
- ✅ Xcode project patched
- ✅ xcodebuild archive succeeds
- ✅ IPA exported and uploaded

### Performance Improvements
- ⏱️ Build time < 60 minutes
- 📈 Success rate > 95%
- 🚀 Faster recovery from failures

## 📚 Documentation Links

- **Full Implementation Plan**: `docs/deployment/IOS_CI_CD_IMPLEMENTATION_PLAN.md`
- **Implementation Summary**: `docs/deployment/IOS_CI_CD_IMPLEMENTATION_SUMMARY.md`
- **Agent Guidelines**: `AGENTS.md`
- **Development Guide**: `CLAUDE.md`

---

**Remember**: Always test locally before deploying to CI environments!