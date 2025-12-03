# Xcode Cloud - NOT SUPPORTED

## Status: DISABLED ⛔

This project uses **GitHub Actions only** for iOS TestFlight CI/CD.

**Xcode Cloud is not supported** and should not be used.

## Why?

1. Xcode Cloud requires pre-configured build scripts for Rust cross-compilation
2. We've intentionally removed these scripts to avoid conflicts
3. GitHub Actions workflow (`ios-release-optimized.yml`) handles all iOS builds
4. This keeps CI/CD centralized and maintainable

## If You See Xcode Cloud Failures

This is expected. Ignore them. Use GitHub Actions instead:

```bash
# Check GitHub Actions workflow status
gh run list --limit 5 | grep iOS

# View iOS build logs
gh run view <run-id>
```

## To Use This Project

- Push to `main` → GitHub Actions workflow triggers
- Builds are sent directly to TestFlight
- No Xcode Cloud involvement needed

---

**Keep it simple: GitHub Actions → TestFlight. That's it.**
