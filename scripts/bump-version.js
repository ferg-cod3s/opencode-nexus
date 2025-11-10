#!/usr/bin/env node

/**
 * Bump version script for OpenCode Nexus
 * Keeps tauri.conf.json, package.json, and Cargo.toml in sync
 *
 * Usage:
 *   node scripts/bump-version.js patch   # 0.1.1 -> 0.1.2
 *   node scripts/bump-version.js minor   # 0.1.1 -> 0.2.0
 *   node scripts/bump-version.js major   # 0.1.1 -> 1.0.0
 *   node scripts/bump-version.js 1.2.3   # Set to specific version
 */

const fs = require('fs');
const path = require('path');

const TAURI_CONFIG = path.join(__dirname, '../src-tauri/tauri.conf.json');
const PACKAGE_JSON = path.join(__dirname, '../package.json');
const CARGO_TOML = path.join(__dirname, '../src-tauri/Cargo.toml');

// Parse semver version
function parseVersion(version) {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)(-.*)?$/);
  if (!match) {
    throw new Error(`Invalid version format: ${version}`);
  }
  return {
    major: parseInt(match[1]),
    minor: parseInt(match[2]),
    patch: parseInt(match[3]),
    prerelease: match[4] || ''
  };
}

// Format version
function formatVersion(v) {
  return `${v.major}.${v.minor}.${v.patch}${v.prerelease}`;
}

// Bump version
function bumpVersion(currentVersion, bumpType) {
  const v = parseVersion(currentVersion);

  switch (bumpType) {
    case 'major':
      v.major++;
      v.minor = 0;
      v.patch = 0;
      v.prerelease = '';
      break;
    case 'minor':
      v.minor++;
      v.patch = 0;
      v.prerelease = '';
      break;
    case 'patch':
      v.patch++;
      v.prerelease = '';
      break;
    default:
      // Assume it's a specific version
      return bumpType;
  }

  return formatVersion(v);
}

// Update tauri.conf.json
function updateTauriConfig(newVersion) {
  const config = JSON.parse(fs.readFileSync(TAURI_CONFIG, 'utf8'));
  const oldVersion = config.version;
  config.version = newVersion;
  fs.writeFileSync(TAURI_CONFIG, JSON.stringify(config, null, 2) + '\n');
  return oldVersion;
}

// Update package.json
function updatePackageJson(newVersion) {
  const pkg = JSON.parse(fs.readFileSync(PACKAGE_JSON, 'utf8'));
  const oldVersion = pkg.version;
  pkg.version = newVersion;
  fs.writeFileSync(PACKAGE_JSON, JSON.stringify(pkg, null, 2) + '\n');
  return oldVersion;
}

// Update Cargo.toml
function updateCargoToml(newVersion) {
  let content = fs.readFileSync(CARGO_TOML, 'utf8');
  const match = content.match(/^version = "([^"]+)"$/m);

  if (!match) {
    throw new Error('Could not find version in Cargo.toml');
  }

  const oldVersion = match[1];
  content = content.replace(/^version = "[^"]+"$/m, `version = "${newVersion}"`);
  fs.writeFileSync(CARGO_TOML, content);
  return oldVersion;
}

// Main
function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: bump-version.js <major|minor|patch|version>');
    console.error('Examples:');
    console.error('  bump-version.js patch   # Bump patch version');
    console.error('  bump-version.js minor   # Bump minor version');
    console.error('  bump-version.js major   # Bump major version');
    console.error('  bump-version.js 1.2.3   # Set specific version');
    process.exit(1);
  }

  const bumpType = args[0];

  // Get current version from tauri.conf.json (source of truth)
  const tauriConfig = JSON.parse(fs.readFileSync(TAURI_CONFIG, 'utf8'));
  const currentVersion = tauriConfig.version;

  // Calculate new version
  const newVersion = bumpVersion(currentVersion, bumpType);

  console.log(`\n📦 Bumping version: ${currentVersion} → ${newVersion}\n`);

  // Update all files
  try {
    const tauriOld = updateTauriConfig(newVersion);
    console.log(`✅ Updated tauri.conf.json: ${tauriOld} → ${newVersion}`);

    const pkgOld = updatePackageJson(newVersion);
    console.log(`✅ Updated package.json: ${pkgOld} → ${newVersion}`);

    const cargoOld = updateCargoToml(newVersion);
    console.log(`✅ Updated Cargo.toml: ${cargoOld} → ${newVersion}`);

    console.log(`\n✨ Version bump complete!`);
    console.log(`\nNext steps:`);
    console.log(`  1. Review changes: git diff`);
    console.log(`  2. Commit: git add -A && git commit -m "chore: bump version to ${newVersion}"`);
    console.log(`  3. Build & deploy: npm run deploy:testflight`);
    console.log();

  } catch (error) {
    console.error(`❌ Error updating files: ${error.message}`);
    process.exit(1);
  }
}

main();
