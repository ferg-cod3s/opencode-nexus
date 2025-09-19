# Server Startup Failure After Onboarding - Validation Fix Implementation Plan

## Overview

This plan addresses the critical issue where users can complete onboarding with invalid OpenCode server paths, causing runtime failures when accessing chat functionality. The solution implements strict validation during onboarding, automatic server download capabilities, and comprehensive logging integration to prevent false success scenarios.

## Current State Analysis

### Critical Issues Identified

1. **Configuration Validation Gap**
   - `src-tauri/src/onboarding.rs:347-357` - `complete_onboarding()` accepts any path without validation
   - `src-tauri/src/onboarding.rs:274-328` - Robust validation exists but never applied to user input
   - `src-tauri/src/server_manager.rs:296` - Runtime requires valid executable paths

2. **Runtime Validation Failures**
   - Chat commands at `src-tauri/src/lib.rs:696-886` fail when API client creation requires functional server
   - `ServerManager::ensure_api_client()` at `src-tauri/src/server_manager.rs:657-674` expects running server
   - Error cascade: Invalid path → API client failure → Chat functionality blocked

3. **Logging System Disconnect**
   - Frontend uses `console.error()` exclusively across all pages
   - Backend has file logging system at `src-tauri/src/lib.rs:24-78`
   - Bridge command `log_frontend_error` exists but never used

### Key Discoveries

- Validation logic already exists in `detect_opencode_server()` function
- Server manager has robust executable validation patterns
- Authentication system shows excellent validation patterns to model after
- API client has URL validation that can be extended

## Desired End State

After this plan is complete:

1. **Onboarding cannot complete with invalid server paths**
2. **Users can auto-download OpenCode server to verified locations**
3. **All frontend logs automatically reach persistent log files**  
4. **Existing invalid configurations are recoverable without data loss**
5. **Clear error messages guide users to successful setup**

### Verification Criteria

- Onboarding completion blocked when `opencode --version` fails
- Download progress visible in UI with successful installation
- Frontend errors appear in `~/.config/opencode-nexus/application.log`
- Recovery workflow handles existing bad configurations
- Chat functionality works immediately after successful onboarding

## What We're NOT Doing

- Changing the overall onboarding flow (6 steps remain the same)
- Modifying chat system architecture or API client patterns
- Implementing custom OpenCode server builds or modifications
- Adding online-only requirements (offline installation remains supported)
- Breaking existing valid configurations

## Implementation Approach

### Strategy: Strict Validation with Graceful UX

1. **Enforcement at completion** - Block invalid paths during `complete_onboarding()`
2. **Auto-download integration** - Provide seamless installation option
3. **Automatic log forwarding** - Bridge all frontend logs to persistent storage
4. **Progressive enhancement** - Add features without breaking existing flows

### Technical Patterns to Follow

- Use existing validation functions from `onboarding.rs:274-328`
- Follow authentication system validation patterns from `auth.rs:85-120`
- Model download implementation after system requirements detection
- Apply server manager executable validation approach

## Phase 1: Strict Path Validation Implementation

### Overview

Implement mandatory validation during onboarding completion to prevent invalid server paths from being stored.

### Changes Required

#### 1. Enhanced Onboarding Validation

**File**: `src-tauri/src/onboarding.rs`
**Changes**: Add strict validation to `complete_onboarding()` method

```rust
pub fn complete_onboarding(&self, opencode_server_path: Option<PathBuf>) -> Result<()> {
    // Validate server path is provided and functional
    let validated_path = if let Some(path) = opencode_server_path {
        // Apply existing detection logic to user-provided path
        if self.validate_opencode_path(&path)? {
            path
        } else {
            return Err(anyhow!("Invalid OpenCode server path: executable not found or non-functional at {}", path.display()));
        }
    } else {
        return Err(anyhow!("OpenCode server path is required to complete onboarding"));
    };

    let config = OnboardingConfig {
        is_completed: true,
        opencode_server_path: Some(validated_path),
        owner_account_created: false,
        owner_username: None,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
    };
    
    self.save_config(&config)
}

// New validation method leveraging existing detection logic
fn validate_opencode_path(&self, path: &PathBuf) -> Result<bool> {
    // Check file exists
    if !path.exists() {
        return Ok(false);
    }

    // Check executable permissions (Unix-like systems)
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let metadata = std::fs::metadata(path)?;
        if !metadata.permissions().mode() & 0o111 != 0 {
            return Ok(false);
        }
    }

    // Execute version command to verify functionality
    match Command::new(path).arg("--version").output() {
        Ok(output) => {
            if output.status.success() {
                let version_output = String::from_utf8_lossy(&output.stdout);
                Ok(version_output.contains("OpenCode"))
            } else {
                Ok(false)
            }
        }
        Err(_) => Ok(false),
    }
}
```

#### 2. Frontend Validation Feedback

**File**: `frontend/src/pages/onboarding.astro`
**Changes**: Add validation feedback and prevent completion with invalid paths

```javascript
async function completeOnboarding() {
    try {
        // Validate path before attempting completion
        if (serverPath && !serverPath.trim()) {
            showError('Please provide a valid OpenCode server path');
            return;
        }

        await invoke('complete_onboarding', {
            opencode_server_path: serverPath || null
        });

        // Success - redirect to dashboard
        window.location.href = '/dashboard';
    } catch (error) {
        // Display specific validation errors
        showError(`Onboarding failed: ${error}`);
        // Provide guidance for fixing the issue
        if (error.includes('executable not found')) {
            showDownloadSuggestion();
        }
    }
}

function showDownloadSuggestion() {
    // Phase 2 will implement auto-download UI here
    const suggestion = document.createElement('div');
    suggestion.innerHTML = `
        <p>OpenCode server not found. Would you like to:</p>
        <button onclick="startAutoDownload()">Download OpenCode Server Automatically</button>
        <button onclick="selectManualPath()">Browse for Existing Installation</button>
    `;
    document.getElementById('error-container').appendChild(suggestion);
}
```

#### 3. Enhanced Error Messages

**File**: `src-tauri/src/lib.rs`  
**Changes**: Update `complete_onboarding` command with detailed error handling

```rust
#[tauri::command]
async fn complete_onboarding(opencode_server_path: Option<String>) -> Result<(), String> {
    let manager = OnboardingManager::new().map_err(|e| {
        format!("Failed to initialize onboarding manager: {}", e)
    })?;
    
    let path = opencode_server_path.map(std::path::PathBuf::from);
    
    manager.complete_onboarding(path).map_err(|e| {
        // Provide specific error messages based on failure type
        let error_msg = format!("{}", e);
        if error_msg.contains("executable not found") {
            format!("OpenCode server not found. Please ensure the path points to a valid OpenCode executable, or use the auto-download option.")
        } else if error_msg.contains("non-functional") {
            format!("OpenCode server found but not working. Please verify the installation or try downloading a fresh copy.")
        } else {
            error_msg
        }
    })
}
```

### Success Criteria

#### Automated Verification

- [x] Unit tests pass: `cargo test onboarding::tests` (11 tests passing)
- [x] Invalid path rejection: `test_complete_onboarding_blocks_invalid_path` 
- [x] Valid path acceptance: `test_complete_onboarding_accepts_valid_server`
- [x] Error message formatting: Enhanced error messages in `complete_onboarding` command
- [x] Server path validation: `test_validate_opencode_path` and `test_complete_onboarding_requires_server_path`

#### Manual Verification

- [x] Onboarding blocked when pointing to non-existent file (validated by `test_complete_onboarding_blocks_invalid_path`)
- [x] Onboarding blocked when pointing to non-executable file (validated by `test_complete_onboarding_blocks_non_executable`)
- [x] Onboarding blocked when pointing to non-OpenCode executable (validated by `test_complete_onboarding_blocks_wrong_executable`)
- [x] Clear error messages guide user to resolution (implemented with specific error messages and download suggestions)
- [x] Existing valid configurations remain unaffected (validated by `test_config_persistence` with valid server)

---

## Phase 2: Auto-Download & Installation System

### Overview

Implement automatic OpenCode server detection, download, and installation to provide users with a seamless setup experience when no valid server is found.

### Changes Required

#### 1. Download Manager Implementation

**File**: `src-tauri/src/download_manager.rs` (new)
**Changes**: Create comprehensive download and installation system

```rust
use anyhow::{anyhow, Result};
use reqwest::Client;
use std::path::{Path, PathBuf};
use std::fs;
use tokio::io::AsyncWriteExt;
use tauri::Emitter;

pub struct DownloadManager {
    client: Client,
    app_handle: Option<tauri::AppHandle>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct DownloadProgress {
    pub total_bytes: u64,
    pub downloaded_bytes: u64,
    pub percentage: f64,
    pub status: String,
}

impl DownloadManager {
    pub fn new(app_handle: Option<tauri::AppHandle>) -> Self {
        Self {
            client: Client::new(),
            app_handle,
        }
    }

    pub async fn download_opencode_server(&self, install_path: &Path) -> Result<PathBuf> {
        // Determine download URL based on platform
        let download_url = self.get_download_url()?;
        let filename = self.get_filename_for_platform()?;
        let temp_path = install_path.join(&filename);

        // Ensure install directory exists
        fs::create_dir_all(install_path)?;

        // Emit download started event
        self.emit_progress(DownloadProgress {
            total_bytes: 0,
            downloaded_bytes: 0,
            percentage: 0.0,
            status: "Starting download...".to_string(),
        });

        // Download with progress tracking
        let response = self.client.get(&download_url).send().await?;
        let total_size = response.content_length().unwrap_or(0);

        let mut file = tokio::fs::File::create(&temp_path).await?;
        let mut downloaded = 0u64;
        let mut stream = response.bytes_stream();

        use tokio_stream::StreamExt;
        while let Some(chunk) = stream.next().await {
            let chunk = chunk?;
            file.write_all(&chunk).await?;
            downloaded += chunk.len() as u64;

            let percentage = if total_size > 0 {
                (downloaded as f64 / total_size as f64) * 100.0
            } else {
                0.0
            };

            self.emit_progress(DownloadProgress {
                total_bytes: total_size,
                downloaded_bytes: downloaded,
                percentage,
                status: "Downloading...".to_string(),
            });
        }

        file.flush().await?;
        drop(file);

        // Make executable (Unix-like systems)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&temp_path)?.permissions();
            perms.set_mode(0o755);
            fs::set_permissions(&temp_path, perms)?;
        }

        // Verify download worked
        let output = std::process::Command::new(&temp_path)
            .arg("--version")
            .output()?;

        if !output.status.success() {
            return Err(anyhow!("Downloaded OpenCode server is not functional"));
        }

        self.emit_progress(DownloadProgress {
            total_bytes: total_size,
            downloaded_bytes: downloaded,
            percentage: 100.0,
            status: "Download complete!".to_string(),
        });

        Ok(temp_path)
    }

    fn get_download_url(&self) -> Result<String> {
        // Platform-specific download URLs
        match std::env::consts::OS {
            "macos" => Ok("https://github.com/opencodedev/opencode/releases/latest/download/opencode-macos".to_string()),
            "linux" => Ok("https://github.com/opencodedev/opencode/releases/latest/download/opencode-linux".to_string()),
            "windows" => Ok("https://github.com/opencodedev/opencode/releases/latest/download/opencode-windows.exe".to_string()),
            _ => Err(anyhow!("Unsupported platform for auto-download")),
        }
    }

    fn get_filename_for_platform(&self) -> Result<String> {
        match std::env::consts::OS {
            "macos" | "linux" => Ok("opencode".to_string()),
            "windows" => Ok("opencode.exe".to_string()),
            _ => Err(anyhow!("Unsupported platform")),
        }
    }

    fn emit_progress(&self, progress: DownloadProgress) {
        if let Some(app_handle) = &self.app_handle {
            let _ = app_handle.emit("download-progress", &progress);
        }
    }
}
```

#### 2. Enhanced Onboarding with Download Option

**File**: `src-tauri/src/onboarding.rs`
**Changes**: Integrate download manager into onboarding flow

```rust
use crate::download_manager::DownloadManager;

impl OnboardingManager {
    pub async fn auto_download_opencode(&self, install_path: &Path, app_handle: Option<tauri::AppHandle>) -> Result<PathBuf> {
        let download_manager = DownloadManager::new(app_handle);
        let downloaded_path = download_manager.download_opencode_server(install_path).await?;
        
        // Verify the downloaded server works
        let (detected, _) = self.test_opencode_at_path(&downloaded_path)?;
        if !detected {
            return Err(anyhow!("Downloaded OpenCode server failed verification"));
        }
        
        Ok(downloaded_path)
    }

    fn test_opencode_at_path(&self, path: &Path) -> Result<(bool, Option<String>)> {
        match Command::new(path).arg("--version").output() {
            Ok(output) => {
                if output.status.success() {
                    let version = String::from_utf8_lossy(&output.stdout);
                    Ok((version.contains("OpenCode"), Some(version.trim().to_string())))
                } else {
                    Ok((false, None))
                }
            }
            Err(_) => Ok((false, None)),
        }
    }

    pub fn get_default_install_path(&self) -> Result<PathBuf> {
        // Platform-specific default installation paths
        match std::env::consts::OS {
            "macos" | "linux" => {
                if let Some(home) = dirs::home_dir() {
                    Ok(home.join(".local/bin"))
                } else {
                    Ok(PathBuf::from("/usr/local/bin"))
                }
            }
            "windows" => {
                if let Some(local_app_data) = dirs::data_local_dir() {
                    Ok(local_app_data.join("opencode-nexus").join("bin"))
                } else {
                    Err(anyhow!("Could not determine install path on Windows"))
                }
            }
            _ => Err(anyhow!("Unsupported platform")),
        }
    }
}
```

#### 3. Frontend Download UI Integration

**File**: `frontend/src/pages/onboarding.astro`  
**Changes**: Add download UI and progress tracking

```javascript
let downloadProgress = { percentage: 0, status: 'Ready' };
let isDownloading = false;

async function startAutoDownload() {
    try {
        isDownloading = true;
        downloadProgress = { percentage: 0, status: 'Starting download...' };

        // Get default installation path
        const defaultPath = await invoke('get_default_install_path');
        
        // Start download
        const downloadedPath = await invoke('auto_download_opencode', {
            install_path: defaultPath
        });

        // Set the downloaded path for onboarding
        serverPath = downloadedPath;
        
        // Complete onboarding with downloaded path
        await completeOnboarding();
        
    } catch (error) {
        showError(`Download failed: ${error}`);
        isDownloading = false;
    }
}

// Listen for download progress events
window.__TAURI__.event.listen('download-progress', (event) => {
    downloadProgress = event.payload;
    // Update UI with progress
    updateDownloadUI();
});

function updateDownloadUI() {
    const progressElement = document.getElementById('download-progress');
    if (progressElement) {
        progressElement.innerHTML = `
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${downloadProgress.percentage}%"></div>
            </div>
            <p>${downloadProgress.status} (${Math.round(downloadProgress.percentage)}%)</p>
        `;
    }
}
```

#### 4. New Tauri Commands

**File**: `src-tauri/src/lib.rs`
**Changes**: Add download-related commands

```rust
mod download_manager;
use download_manager::DownloadManager;

#[tauri::command]
async fn auto_download_opencode(app_handle: tauri::AppHandle, install_path: String) -> Result<String, String> {
    let manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let path = PathBuf::from(&install_path);
    
    let downloaded_path = manager.auto_download_opencode(&path, Some(app_handle)).await.map_err(|e| e.to_string())?;
    Ok(downloaded_path.to_string_lossy().to_string())
}

#[tauri::command]
async fn get_default_install_path() -> Result<String, String> {
    let manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    let path = manager.get_default_install_path().map_err(|e| e.to_string())?;
    Ok(path.to_string_lossy().to_string())
}
```

### Success Criteria

#### Automated Verification

- [ ] Download tests pass: `cargo test download_manager::tests`
- [ ] Platform detection works: `cargo test -- test_platform_download_urls`
- [ ] Progress tracking functional: `cargo test -- test_download_progress_events`
- [ ] Installation verification: `cargo test -- test_downloaded_server_validation`

#### Manual Verification

- [ ] Download UI appears when server not found
- [ ] Progress bar shows realistic download progress  
- [ ] Downloaded server passes validation and works
- [ ] Downloaded server enables chat functionality immediately
- [ ] Cross-platform download works (macOS, Linux, Windows)

---

## Phase 3: Configuration Recovery & Migration

### Overview

Handle existing users who have invalid configurations by providing recovery workflows without data loss.

### Changes Required

#### 1. Startup Configuration Validation

**File**: `src-tauri/src/lib.rs`
**Changes**: Add configuration validation on application startup

```rust
#[tauri::command]
async fn validate_startup_configuration(app_handle: tauri::AppHandle) -> Result<ValidationResult, String> {
    let manager = OnboardingManager::new().map_err(|e| e.to_string())?;
    
    if let Ok(Some(config)) = manager.load_config() {
        if config.is_completed {
            // Check if stored server path is still valid
            if let Some(server_path) = config.opencode_server_path {
                if manager.validate_opencode_path(&server_path).unwrap_or(false) {
                    return Ok(ValidationResult::Valid);
                } else {
                    return Ok(ValidationResult::Invalid { 
                        reason: "Configured OpenCode server path is no longer valid".to_string(),
                        suggested_action: SuggestionAction::ReconfigureServer { current_path: server_path },
                    });
                }
            } else {
                return Ok(ValidationResult::Invalid {
                    reason: "No OpenCode server path configured".to_string(),
                    suggested_action: SuggestionAction::CompleteSetup,
                });
            }
        }
    }
    
    Ok(ValidationResult::IncompleteOnboarding)
}

#[derive(serde::Serialize)]
pub enum ValidationResult {
    Valid,
    Invalid { reason: String, suggested_action: SuggestionAction },
    IncompleteOnboarding,
}

#[derive(serde::Serialize)]
pub enum SuggestionAction {
    CompleteSetup,
    ReconfigureServer { current_path: PathBuf },
    DownloadNewServer,
}
```

#### 2. Configuration Recovery UI

**File**: `frontend/src/pages/index.astro` (entry point)
**Changes**: Add configuration validation check

```javascript
async function checkConfiguration() {
    try {
        const validation = await invoke('validate_startup_configuration');
        
        if (validation.type === 'Invalid') {
            // Show recovery options instead of normal flow
            showRecoveryOptions(validation.reason, validation.suggested_action);
            return false;
        } else if (validation.type === 'IncompleteOnboarding') {
            // Normal onboarding flow
            window.location.href = '/onboarding';
            return false;
        }
        
        return true; // Valid configuration
    } catch (error) {
        console.error('Configuration check failed:', error);
        return false;
    }
}

function showRecoveryOptions(reason, suggestedAction) {
    document.body.innerHTML = `
        <div class="recovery-screen">
            <h1>Configuration Issue Detected</h1>
            <p>${reason}</p>
            
            <div class="recovery-options">
                <h2>How would you like to proceed?</h2>
                
                <button onclick="startReconfiguration()" class="primary">
                    Fix Server Configuration
                </button>
                
                <button onclick="downloadNewServer()" class="secondary">
                    Download Fresh OpenCode Server
                </button>
                
                <button onclick="restartOnboarding()" class="tertiary">
                    Start Over (Reset Configuration)
                </button>
            </div>
        </div>
    `;
}
```

#### 3. Graceful Migration System

**File**: `src-tauri/src/onboarding.rs`
**Changes**: Add migration utilities for configuration updates

```rust
impl OnboardingManager {
    pub fn migrate_configuration(&self) -> Result<bool> {
        let config_path = self.get_config_path();
        if !config_path.exists() {
            return Ok(false); // No migration needed
        }

        let mut config = self.load_config()?.unwrap();
        let mut migration_performed = false;

        // Migration 1: Add missing fields from older versions
        if config.owner_username.is_none() && config.owner_account_created {
            // Try to detect owner username from auth system
            if let Ok(auth_manager) = crate::auth::AuthManager::new(self.config_dir.clone()) {
                if let Ok(Some((username, _, _))) = auth_manager.get_user_info() {
                    config.owner_username = Some(username);
                    config.updated_at = chrono::Utc::now();
                    migration_performed = true;
                }
            }
        }

        // Migration 2: Validate and fix server paths
        if let Some(server_path) = &config.opencode_server_path {
            if !self.validate_opencode_path(server_path).unwrap_or(false) {
                // Try to auto-detect in common locations
                let (detected, new_path) = self.detect_opencode_server();
                if detected {
                    config.opencode_server_path = new_path;
                    config.updated_at = chrono::Utc::now();
                    migration_performed = true;
                } else {
                    // Mark as needing reconfiguration but don't break existing setup
                    // This will be handled by the recovery UI
                }
            }
        }

        if migration_performed {
            self.save_config(&config)?;
        }

        Ok(migration_performed)
    }

    pub fn reset_configuration(&self) -> Result<()> {
        let config_path = self.get_config_path();
        if config_path.exists() {
            std::fs::remove_file(&config_path)?;
        }
        Ok(())
    }
}
```

### Success Criteria

#### Automated Verification

- [ ] Migration tests pass: `cargo test -- test_configuration_migration`
- [ ] Recovery detection: `cargo test -- test_invalid_config_detection`
- [ ] Reset functionality: `cargo test -- test_configuration_reset`

#### Manual Verification

- [ ] Users with invalid configs see recovery UI instead of errors
- [ ] Recovery options successfully fix configuration issues
- [ ] Migration preserves user data (owner account, auth, etc.)
- [ ] "Start Over" option cleanly resets to onboarding
- [ ] Fixed configurations enable chat functionality immediately

---

## Phase 4: Automatic Frontend Log Forwarding

### Overview

Bridge the frontend console logging system with the backend persistent file logging to ensure all debugging information is captured automatically.

### Changes Required

#### 1. Frontend Log Interceptor

**File**: `frontend/src/utils/logging.ts` (new)
**Changes**: Create automatic log forwarding system

```typescript
import { invoke } from '@tauri-apps/api/tauri';

// Log levels matching backend system
export type LogLevel = 'error' | 'warn' | 'info' | 'debug';

class LogForwarder {
    private queue: Array<{ level: LogLevel; message: string; details?: string; timestamp: number }> = [];
    private isProcessing = false;
    private batchSize = 10;
    private flushInterval = 1000; // 1 second

    constructor() {
        // Start periodic flushing
        setInterval(() => this.flush(), this.flushInterval);
        
        // Flush on page unload
        window.addEventListener('beforeunload', () => this.flush());
    }

    async log(level: LogLevel, message: string, details?: any) {
        // Add to queue
        this.queue.push({
            level,
            message,
            details: details ? JSON.stringify(details) : undefined,
            timestamp: Date.now()
        });

        // Flush immediately for errors
        if (level === 'error') {
            await this.flush();
        }
    }

    private async flush() {
        if (this.isProcessing || this.queue.length === 0) return;
        
        this.isProcessing = true;
        try {
            // Process in batches
            while (this.queue.length > 0) {
                const batch = this.queue.splice(0, this.batchSize);
                
                // Send batch to backend
                for (const logEntry of batch) {
                    try {
                        await invoke('log_frontend_error', {
                            level: logEntry.level,
                            message: logEntry.message,
                            details: logEntry.details
                        });
                    } catch (error) {
                        // Avoid infinite recursion - just fail silently for log forwarding errors
                        console.warn('Failed to forward log to backend:', error);
                    }
                }
            }
        } finally {
            this.isProcessing = false;
        }
    }
}

// Global log forwarder instance
const logForwarder = new LogForwarder();

// Enhanced console methods that also forward to backend
export const logger = {
    error: (message: string, ...args: any[]) => {
        console.error(message, ...args);
        logForwarder.log('error', message, args.length > 0 ? args : undefined);
    },
    
    warn: (message: string, ...args: any[]) => {
        console.warn(message, ...args);
        logForwarder.log('warn', message, args.length > 0 ? args : undefined);
    },
    
    info: (message: string, ...args: any[]) => {
        console.info(message, ...args);
        logForwarder.log('info', message, args.length > 0 ? args : undefined);
    },
    
    debug: (message: string, ...args: any[]) => {
        console.debug(message, ...args);
        logForwarder.log('debug', message, args.length > 0 ? args : undefined);
    }
};

// Override global console methods (optional - for comprehensive coverage)
export function interceptConsole() {
    const originalConsole = { ...console };
    
    console.error = (...args) => {
        originalConsole.error(...args);
        logForwarder.log('error', args.join(' '));
    };
    
    console.warn = (...args) => {
        originalConsole.warn(...args);
        logForwarder.log('warn', args.join(' '));
    };
    
    console.info = (...args) => {
        originalConsole.info(...args);
        logForwarder.log('info', args.join(' '));
    };
    
    console.debug = (...args) => {
        originalConsole.debug(...args);
        logForwarder.log('debug', args.join(' '));
    };
    
    console.log = (...args) => {
        originalConsole.log(...args);
        logForwarder.log('info', args.join(' '));
    };
}
```

#### 2. Global Log Integration

**File**: `frontend/src/layouts/Layout.astro`
**Changes**: Initialize log forwarding in base layout

```astro
---
// Existing imports...
---

<html>
<head>
    <!-- Existing head content... -->
    <script>
        // Initialize logging as early as possible
        import('./utils/logging.js').then(({ interceptConsole }) => {
            // Automatically intercept all console calls
            interceptConsole();
        });
    </script>
</head>
<body>
    <!-- Existing body content... -->
</body>
</html>
```

#### 3. Enhanced Backend Log Processing

**File**: `src-tauri/src/lib.rs`
**Changes**: Improve frontend log processing and add context

```rust
#[tauri::command]
async fn log_frontend_error(level: String, message: String, details: Option<String>) -> Result<(), String> {
    let timestamp = chrono::Utc::now().format("%H:%M:%S%.3f");
    let details_str = details.as_ref()
        .map(|d| format!(" | Details: {}", d))
        .unwrap_or_default();
    
    // Add more context to frontend logs
    let full_message = format!("🌐 [FRONTEND] [{}] {}{}", timestamp, message, details_str);
    
    match level.to_lowercase().as_str() {
        "error" => {
            log_error!("{}", full_message);
            // Also send to Sentry for error tracking
            sentry::capture_message(&full_message, sentry::Level::Error);
        },
        "warn" => {
            log_warn!("{}", full_message);
        },
        "info" => {
            log_info!("{}", full_message);
        },
        "debug" => {
            log_debug!("{}", full_message);
        },
        _ => {
            log_info!("{}", full_message);
        },
    }
    
    Ok(())
}

// Add batch processing for better performance
#[tauri::command]
async fn log_frontend_batch(logs: Vec<FrontendLogEntry>) -> Result<(), String> {
    for log_entry in logs {
        let _ = log_frontend_error(log_entry.level, log_entry.message, log_entry.details).await;
    }
    Ok(())
}

#[derive(serde::Deserialize)]
struct FrontendLogEntry {
    level: String,
    message: String,
    details: Option<String>,
}
```

#### 4. Update All Frontend Pages

**File**: `frontend/src/pages/chat.astro` (and others)
**Changes**: Replace console.error with logger.error

```javascript
// Before:
// console.error('Failed to send message:', error);

// After:
import { logger } from '../utils/logging.js';
// ...
try {
    await sendMessage();
} catch (error) {
    logger.error('Failed to send message:', error);
    // UI error handling continues as before
}
```

**Apply similar changes to**:
- `frontend/src/pages/dashboard.astro`
- `frontend/src/pages/login.astro` 
- `frontend/src/pages/onboarding.astro`
- `frontend/src/pages/index.astro`

### Success Criteria

#### Automated Verification

- [ ] Log forwarding tests: `bun test -- logging.test.ts`
- [ ] Backend log processing: `cargo test -- test_frontend_log_integration`
- [ ] Batch processing: `cargo test -- test_log_batch_processing`

#### Manual Verification

- [ ] Frontend console.error appears in application.log file
- [ ] Frontend console.warn appears in application.log file  
- [ ] Frontend console.info appears in application.log file
- [ ] Error context includes timestamp and source identification
- [ ] Log files contain both frontend and backend entries
- [ ] No noticeable performance impact from log forwarding

---

## Phase 5: Comprehensive Testing & Validation

### Overview

Ensure the complete solution works reliably across all platforms and scenarios with comprehensive automated and manual testing.

### Changes Required

#### 1. Enhanced Test Coverage

**File**: `src-tauri/src/onboarding.rs` (in tests module)
**Changes**: Add comprehensive validation tests

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_complete_onboarding_blocks_invalid_path() {
        let temp_dir = TempDir::new().unwrap();
        let mut manager = TestOnboardingManager::new().unwrap();
        manager.manager.config_dir = temp_dir.path().to_path_buf();

        // Test with non-existent path
        let invalid_path = temp_dir.path().join("nonexistent");
        let result = manager.manager.complete_onboarding(Some(invalid_path));
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("executable not found"));
    }

    #[test]
    fn test_complete_onboarding_blocks_non_executable() {
        let temp_dir = TempDir::new().unwrap();
        let mut manager = TestOnboardingManager::new().unwrap();
        manager.manager.config_dir = temp_dir.path().to_path_buf();

        // Create non-executable file
        let non_executable = temp_dir.path().join("not_executable");
        std::fs::write(&non_executable, "not an executable").unwrap();

        let result = manager.manager.complete_onboarding(Some(non_executable));
        assert!(result.is_err());
    }

    #[test]
    fn test_complete_onboarding_blocks_wrong_executable() {
        let temp_dir = TempDir::new().unwrap();
        let mut manager = TestOnboardingManager::new().unwrap();
        manager.manager.config_dir = temp_dir.path().to_path_buf();

        // Create executable that's not OpenCode
        let fake_executable = temp_dir.path().join("fake_opencode");
        std::fs::write(&fake_executable, "#!/bin/bash\necho 'Not OpenCode'\n").unwrap();
        
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&fake_executable, std::fs::Permissions::from_mode(0o755)).unwrap();
        }

        let result = manager.manager.complete_onboarding(Some(fake_executable));
        assert!(result.is_err());
    }

    #[test]
    fn test_complete_onboarding_accepts_valid_server() {
        let temp_dir = TempDir::new().unwrap();
        let mut manager = TestOnboardingManager::new().unwrap();
        manager.manager.config_dir = temp_dir.path().to_path_buf();

        // Create mock OpenCode server
        let valid_server = temp_dir.path().join("opencode");
        std::fs::write(&valid_server, "#!/bin/bash\necho 'OpenCode Server v1.0.0'\n").unwrap();
        
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&valid_server, std::fs::Permissions::from_mode(0o755)).unwrap();
        }

        let result = manager.manager.complete_onboarding(Some(valid_server.clone()));
        assert!(result.is_ok());

        // Verify config was saved with correct path
        let config = manager.manager.load_config().unwrap().unwrap();
        assert!(config.is_completed);
        assert_eq!(config.opencode_server_path.unwrap(), valid_server);
    }

    #[tokio::test]
    async fn test_auto_download_integration() {
        // Mock download test - would require network stubbing for real implementation
        let temp_dir = TempDir::new().unwrap();
        let manager = OnboardingManager::new().unwrap();
        let install_path = temp_dir.path().join("downloaded");

        // This would test the download flow with mocked network responses
        // For now, just test that the function exists and has correct signature
        assert!(manager.get_default_install_path().is_ok());
    }

    #[test]
    fn test_configuration_migration() {
        let temp_dir = TempDir::new().unwrap();
        let mut manager = TestOnboardingManager::new().unwrap();
        manager.manager.config_dir = temp_dir.path().to_path_buf();

        // Create old config format
        let old_config = OnboardingConfig {
            is_completed: true,
            opencode_server_path: Some(PathBuf::from("/invalid/path")),
            owner_account_created: true,
            owner_username: None, // Missing field to trigger migration
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        };
        manager.manager.save_config(&old_config).unwrap();

        // Run migration
        let migration_result = manager.manager.migrate_configuration();
        assert!(migration_result.is_ok());
    }
}
```

#### 2. Frontend Testing

**File**: `frontend/src/utils/logging.test.ts` (new)
**Changes**: Add frontend logging tests

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { logger, interceptConsole } from './logging';

// Mock Tauri invoke
const mockInvoke = vi.fn();
vi.mock('@tauri-apps/api/tauri', () => ({
    invoke: mockInvoke
}));

describe('Frontend Logging', () => {
    beforeEach(() => {
        mockInvoke.mockClear();
    });

    it('should forward error logs to backend', async () => {
        await logger.error('Test error message', { context: 'test' });
        
        // Give time for async forwarding
        await new Promise(resolve => setTimeout(resolve, 10));
        
        expect(mockInvoke).toHaveBeenCalledWith('log_frontend_error', {
            level: 'error',
            message: 'Test error message',
            details: expect.stringContaining('context')
        });
    });

    it('should batch non-error logs', async () => {
        logger.info('Info message 1');
        logger.info('Info message 2');
        
        // Wait for batching interval
        await new Promise(resolve => setTimeout(resolve, 1100));
        
        expect(mockInvoke).toHaveBeenCalledTimes(2);
    });

    it('should intercept console methods', () => {
        const originalError = console.error;
        interceptConsole();
        
        expect(console.error).not.toBe(originalError);
        
        // Test that intercepted console still calls original
        const spy = vi.spyOn(originalError, 'apply');
        console.error('test message');
        expect(spy).toHaveBeenCalled();
    });
});
```

#### 3. Integration Testing

**File**: `src-tauri/src/tests/integration_tests.rs` (new)
**Changes**: Add end-to-end integration tests

```rust
use super::*;
use tempfile::TempDir;
use tokio::test;

#[tokio::test]
async fn test_complete_onboarding_to_chat_flow() {
    let temp_dir = TempDir::new().unwrap();
    let config_dir = temp_dir.path().join("config");
    
    // Create mock OpenCode server
    let server_binary = temp_dir.path().join("opencode");
    create_mock_opencode_server(&server_binary).unwrap();
    
    // Complete onboarding with valid server
    let onboarding_manager = OnboardingManager::new().unwrap();
    let result = onboarding_manager.complete_onboarding(Some(server_binary.clone()));
    assert!(result.is_ok());
    
    // Verify server manager can be created with this configuration
    let server_manager = ServerManager::new(config_dir, server_binary, None);
    assert!(server_manager.is_ok());
    
    // Verify server can be started (with mock)
    let mut server_manager = server_manager.unwrap();
    // Note: This would require more sophisticated mocking for real server start
    assert!(!server_manager.is_running()); // Should start as stopped
}

#[tokio::test]
async fn test_invalid_config_recovery_flow() {
    let temp_dir = TempDir::new().unwrap();
    let config_dir = temp_dir.path().to_path_buf();
    
    // Create invalid configuration
    let invalid_config = OnboardingConfig {
        is_completed: true,
        opencode_server_path: Some(PathBuf::from("/nonexistent/path")),
        owner_account_created: false,
        owner_username: None,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
    };
    
    let onboarding_manager = OnboardingManager {
        config_dir: config_dir.clone(),
    };
    onboarding_manager.save_config(&invalid_config).unwrap();
    
    // Simulate startup validation
    let validation_result = validate_configuration_for_test(config_dir).await;
    match validation_result {
        ValidationResult::Invalid { reason, suggested_action } => {
            assert!(reason.contains("no longer valid"));
            // Verify recovery suggestions are provided
            match suggested_action {
                SuggestionAction::ReconfigureServer { .. } => {
                    // This is expected
                }
                _ => panic!("Expected ReconfigureServer suggestion"),
            }
        }
        _ => panic!("Expected Invalid validation result"),
    }
}

fn create_mock_opencode_server(path: &Path) -> std::io::Result<()> {
    std::fs::write(path, "#!/bin/bash\necho 'OpenCode Server v1.0.0'\n")?;
    
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755))?;
    }
    
    Ok(())
}
```

#### 4. Manual Testing Checklist

**File**: `docs/TESTING_CHECKLIST.md` (new)
**Changes**: Comprehensive manual testing procedures

```markdown
# Manual Testing Checklist: Server Startup Failure Fix

## Pre-Testing Setup
- [ ] Clean test environment (remove existing OpenCode Nexus config)
- [ ] Test platforms: macOS, Linux, Windows
- [ ] OpenCode server availability: present, absent, invalid

## Phase 1: Strict Path Validation
### Invalid Path Scenarios
- [ ] Point to non-existent file → Onboarding blocked with clear error
- [ ] Point to directory instead of file → Onboarding blocked
- [ ] Point to non-executable file → Onboarding blocked  
- [ ] Point to executable that's not OpenCode → Onboarding blocked
- [ ] Leave path empty → Onboarding blocked with guidance

### Valid Path Scenarios  
- [ ] Point to valid OpenCode binary → Onboarding succeeds
- [ ] Subsequent chat access works immediately → No "path not configured" errors

### Error Message Quality
- [ ] Error messages are user-friendly and actionable
- [ ] Download suggestion appears for missing server
- [ ] Manual path option remains available

## Phase 2: Auto-Download System
### Download Flow
- [ ] Download option appears when no server detected
- [ ] Progress bar shows realistic progress (0-100%)
- [ ] Download completes successfully on each platform
- [ ] Downloaded binary is executable and functional
- [ ] Downloaded binary enables chat immediately

### Download Edge Cases
- [ ] Network failure during download → Clear error message
- [ ] Insufficient disk space → Clear error message  
- [ ] Download corruption → Validation catches and reports error
- [ ] User cancels download → Clean state recovery

### Installation Paths
- [ ] Default paths appropriate for each platform
- [ ] User can select custom installation location
- [ ] Permissions handled correctly for chosen path

## Phase 3: Configuration Recovery
### Existing Invalid Configs
- [ ] Users with invalid paths see recovery screen (not error)
- [ ] Recovery options presented clearly
- [ ] "Fix Configuration" option works
- [ ] "Download New Server" option works
- [ ] "Start Over" option resets cleanly

### Migration Testing
- [ ] Existing valid configurations remain unaffected
- [ ] User data preserved during migration (auth, etc.)
- [ ] Configuration updates don't break existing setup

## Phase 4: Automatic Log Forwarding  
### Log Integration
- [ ] Frontend console.error appears in application.log
- [ ] Frontend console.warn appears in application.log
- [ ] Frontend console.info appears in application.log
- [ ] Timestamps and source identification present

### Performance Impact
- [ ] No noticeable delay from log forwarding
- [ ] Large log volumes handled gracefully
- [ ] Log files don't grow excessively

### Cross-Page Coverage
- [ ] Onboarding page errors logged
- [ ] Login page errors logged
- [ ] Dashboard page errors logged  
- [ ] Chat page errors logged

## Integration Testing
### Complete User Journeys
- [ ] Fresh install → Onboarding → Auto-download → Chat works
- [ ] Fresh install → Onboarding → Manual path → Chat works
- [ ] Existing invalid config → Recovery → Chat works
- [ ] Valid config → Normal startup → Chat works

### Error Recovery
- [ ] Download fails → Manual path option works
- [ ] Manual path invalid → Download option works
- [ ] Network issues → Offline installation guidance provided

## Performance & Reliability
- [ ] Startup time remains acceptable (< 3 seconds)
- [ ] Memory usage stable during download
- [ ] No memory leaks from log forwarding
- [ ] Cross-platform binary compatibility verified
```

### Success Criteria

#### Automated Verification

- [ ] All unit tests pass: `cargo test`
- [ ] Frontend tests pass: `bun test`
- [ ] Integration tests pass: `cargo test --test integration_tests`
- [ ] No regressions: `cargo test && bun test`

#### Manual Verification

- [ ] Complete manual testing checklist passed
- [ ] Cross-platform functionality verified
- [ ] Performance benchmarks maintained
- [ ] User experience smooth and intuitive
- [ ] No false success scenarios possible

## Testing Strategy

### Unit Tests

**Backend Testing**:
- Path validation logic in `onboarding.rs`
- Download manager functionality  
- Configuration migration utilities
- Log forwarding command processing

**Frontend Testing**:
- Log forwarding utility functions
- Download UI state management
- Error handling in onboarding flow

### Integration Tests

**End-to-End Scenarios**:
- Complete onboarding → Chat functionality 
- Invalid config → Recovery → Chat functionality
- Auto-download → Installation → Chat functionality
- Log forwarding → File persistence verification

### Manual Testing Steps

1. **Fresh Installation Testing**
   - Clean environment setup
   - Auto-detection scenarios (present/absent server)
   - Download and installation flow
   - Immediate chat functionality verification

2. **Migration Testing**  
   - Setup existing invalid configurations
   - Startup recovery flow testing
   - User data preservation verification
   - Recovery option effectiveness

3. **Cross-Platform Testing**
   - macOS: Homebrew paths, download URLs, permissions
   - Linux: Standard paths, package manager integration
   - Windows: Registry paths, executable extensions, UAC considerations

4. **Error Scenario Testing**
   - Network failures during download
   - Corrupted installations
   - Insufficient permissions
   - Storage constraints

## Performance Considerations

### Download Performance
- Chunked downloads for large binaries
- Progress reporting accuracy  
- Bandwidth usage optimization
- Resume capability for interrupted downloads

### Logging Performance  
- Batched log forwarding to reduce overhead
- Queue size limits to prevent memory issues
- Async processing to avoid blocking UI
- Log rotation to manage file sizes

## Migration Notes

### For Existing Users
- Configuration validation runs on every startup
- Invalid configurations trigger recovery UI instead of silent failures
- User data (auth, sessions) preserved during migration
- Clear upgrade path from any previous version

### For New Users
- Strict validation prevents invalid configurations from being created
- Auto-download provides smooth installation experience
- Comprehensive error messages guide successful setup
- All logs automatically captured for support scenarios

## References

- Original issue analysis: `thoughts/research/2025-09-08_server-startup-failure-after-onboarding-completion.md`  
- Server manager patterns: `src-tauri/src/server_manager.rs:296-378`
- Validation patterns: `src-tauri/src/auth.rs:85-120`
- Frontend logging gaps: `frontend/src/pages/*.astro` console usage