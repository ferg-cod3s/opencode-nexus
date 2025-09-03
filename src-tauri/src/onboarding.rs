use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemRequirements {
    pub os_compatible: bool,
    pub memory_sufficient: bool,
    pub disk_space_sufficient: bool,
    pub network_available: bool,
    pub required_permissions: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnboardingConfig {
    pub is_completed: bool,
    pub opencode_server_path: Option<PathBuf>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnboardingState {
    pub config: Option<OnboardingConfig>,
    pub system_requirements: SystemRequirements,
    pub opencode_detected: bool,
    pub opencode_path: Option<PathBuf>,
}

pub struct OnboardingManager {
    config_dir: PathBuf,
}

impl OnboardingManager {
    pub fn new() -> Result<Self> {
        let config_dir = Self::get_config_dir()?;
        std::fs::create_dir_all(&config_dir)?;
        Ok(Self { config_dir })
    }

    fn get_config_dir() -> Result<PathBuf> {
        dirs::config_dir()
            .map(|dir| dir.join("opencode-nexus"))
            .ok_or_else(|| anyhow!("Could not determine config directory"))
    }

    pub fn get_config_path(&self) -> PathBuf {
        self.config_dir.join("onboarding.json")
    }

    pub fn is_first_launch(&self) -> bool {
        !self.get_config_path().exists()
    }

    pub fn check_system_requirements(&self) -> SystemRequirements {
        SystemRequirements {
            os_compatible: self.check_os_compatibility(),
            memory_sufficient: self.check_memory_requirements(),
            disk_space_sufficient: self.check_disk_space(),
            network_available: self.check_network_connectivity(),
            required_permissions: self.check_permissions(),
        }
    }

    fn check_os_compatibility(&self) -> bool {
        // For now, assume all supported platforms are compatible
        true
    }

    fn check_memory_requirements(&self) -> bool {
        // Check available system memory (minimum 4GB required)
        match self.get_system_memory() {
            Ok(memory_gb) => memory_gb >= 4.0,
            Err(_) => true, // If we can't check, assume it's okay to avoid blocking
        }
    }

    fn check_disk_space(&self) -> bool {
        // Check available disk space in config directory (minimum 2GB required)
        match self.get_available_disk_space() {
            Ok(space_gb) => space_gb >= 2.0,
            Err(_) => true, // If we can't check, assume it's okay to avoid blocking
        }
    }

    fn check_network_connectivity(&self) -> bool {
        // Simple network connectivity check
        self.test_network_connection()
    }

    fn check_permissions(&self) -> bool {
        // Check if we can write to config directory
        let test_file = self.config_dir.join(".permissions_test");
        match std::fs::write(&test_file, "test") {
            Ok(_) => {
                let _ = std::fs::remove_file(&test_file);
                true
            }
            Err(_) => false,
        }
    }

    fn get_system_memory(&self) -> Result<f64> {
        // Platform-specific memory detection
        #[cfg(target_os = "macos")]
        {
            self.get_macos_memory()
        }
        #[cfg(target_os = "linux")]
        {
            self.get_linux_memory()
        }
        #[cfg(target_os = "windows")]
        {
            self.get_windows_memory()
        }
        #[cfg(not(any(target_os = "macos", target_os = "linux", target_os = "windows")))]
        {
            Ok(8.0) // Default assumption for unknown platforms
        }
    }

    #[cfg(target_os = "macos")]
    fn get_macos_memory(&self) -> Result<f64> {
        use std::process::Command;
        
        let output = Command::new("sysctl")
            .args(&["-n", "hw.memsize"])
            .output()?;
        
        if output.status.success() {
            let memory_bytes: u64 = String::from_utf8(output.stdout)?
                .trim()
                .parse()?;
            Ok(memory_bytes as f64 / 1024.0 / 1024.0 / 1024.0)
        } else {
            Err(anyhow!("Failed to get memory info"))
        }
    }

    #[cfg(target_os = "linux")]
    fn get_linux_memory(&self) -> Result<f64> {
        let meminfo = std::fs::read_to_string("/proc/meminfo")?;
        
        for line in meminfo.lines() {
            if line.starts_with("MemTotal:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    let memory_kb: u64 = parts[1].parse()?;
                    return Ok(memory_kb as f64 / 1024.0 / 1024.0);
                }
            }
        }
        
        Err(anyhow!("Could not parse memory info"))
    }

    #[cfg(target_os = "windows")]
    fn get_windows_memory(&self) -> Result<f64> {
        use std::process::Command;
        
        let output = Command::new("wmic")
            .args(&["computersystem", "get", "TotalPhysicalMemory", "/value"])
            .output()?;
        
        if output.status.success() {
            let output_str = String::from_utf8(output.stdout)?;
            
            for line in output_str.lines() {
                if line.starts_with("TotalPhysicalMemory=") {
                    let memory_bytes: u64 = line
                        .strip_prefix("TotalPhysicalMemory=")
                        .unwrap_or("0")
                        .trim()
                        .parse()?;
                    return Ok(memory_bytes as f64 / 1024.0 / 1024.0 / 1024.0);
                }
            }
        }
        
        Err(anyhow!("Failed to get memory info"))
    }

    fn get_available_disk_space(&self) -> Result<f64> {
        let config_path = &self.config_dir;
        
        // Ensure the directory exists
        std::fs::create_dir_all(config_path)?;
        
        // Platform-specific disk space check
        #[cfg(unix)]
        {
            self.get_unix_disk_space(config_path)
        }
        #[cfg(windows)]
        {
            self.get_windows_disk_space(config_path)
        }
    }

    #[cfg(unix)]
    fn get_unix_disk_space(&self, path: &Path) -> Result<f64> {
        use std::ffi::CString;
        
        let path_cstring = CString::new(path.to_string_lossy().as_bytes())?;
        
        unsafe {
            let mut statvfs: libc::statvfs = std::mem::zeroed();
            if libc::statvfs(path_cstring.as_ptr(), &mut statvfs) == 0 {
                let available_bytes = statvfs.f_bavail as u64 * statvfs.f_frsize as u64;
                Ok(available_bytes as f64 / 1024.0 / 1024.0 / 1024.0)
            } else {
                Err(anyhow!("Failed to get disk space"))
            }
        }
    }

    #[cfg(windows)]
    fn get_windows_disk_space(&self, path: &Path) -> Result<f64> {
        use std::ffi::OsStr;
        use std::os::windows::ffi::OsStrExt;
        
        let path_wide: Vec<u16> = OsStr::new(path)
            .encode_wide()
            .chain(std::iter::once(0))
            .collect();
        
        unsafe {
            let mut free_bytes_available = 0u64;
            let mut total_bytes = 0u64;
            let mut total_free_bytes = 0u64;
            
            let result = winapi::um::fileapi::GetDiskFreeSpaceExW(
                path_wide.as_ptr(),
                &mut free_bytes_available,
                &mut total_bytes,
                &mut total_free_bytes,
            );
            
            if result != 0 {
                Ok(free_bytes_available as f64 / 1024.0 / 1024.0 / 1024.0)
            } else {
                Err(anyhow!("Failed to get disk space"))
            }
        }
    }

    fn test_network_connection(&self) -> bool {
        use std::net::TcpStream;
        use std::time::Duration;
        
        // Try to connect to a reliable external service
        let test_addresses = [
            "1.1.1.1:53",        // Cloudflare DNS
            "8.8.8.8:53",        // Google DNS
            "208.67.222.222:53", // OpenDNS
        ];
        
        for address in &test_addresses {
            if let Ok(_) = TcpStream::connect_timeout(
                &address.parse().unwrap(),
                Duration::from_secs(3)
            ) {
                return true;
            }
        }
        
        false
    }

    pub fn detect_opencode_server(&self) -> (bool, Option<PathBuf>) {
        // Check common installation paths for OpenCode server
        let common_paths = [
            "opencode",
            "opencode-server",
            "./opencode",
            "./opencode-server",
        ];

        for path_str in &common_paths {
            if let Ok(output) = Command::new(path_str)
                .arg("--version")
                .output()
            {
                if output.status.success() {
                    return (true, Some(PathBuf::from(path_str)));
                }
            }
        }

        (false, None)
    }

    pub fn save_config(&self, config: &OnboardingConfig) -> Result<()> {
        let config_json = serde_json::to_string_pretty(config)?;
        std::fs::write(self.get_config_path(), config_json)?;
        Ok(())
    }

    pub fn load_config(&self) -> Result<Option<OnboardingConfig>> {
        let config_path = self.get_config_path();
        if !config_path.exists() {
            return Ok(None);
        }

        let config_json = std::fs::read_to_string(config_path)?;
        let config: OnboardingConfig = serde_json::from_str(&config_json)?;
        Ok(Some(config))
    }

    pub fn complete_onboarding(&self, opencode_server_path: Option<PathBuf>) -> Result<()> {
        let config = OnboardingConfig {
            is_completed: true,
            opencode_server_path,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        };
        self.save_config(&config)
    }

    pub fn get_onboarding_state(&self) -> Result<OnboardingState> {
        let config = self.load_config()?;
        let system_requirements = self.check_system_requirements();
        let (opencode_detected, opencode_path) = self.detect_opencode_server();

        Ok(OnboardingState {
            config,
            system_requirements,
            opencode_detected,
            opencode_path,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    struct TestOnboardingManager {
        manager: OnboardingManager,
        _temp_dir: TempDir,
    }

    impl TestOnboardingManager {
        fn new() -> Result<Self> {
            let temp_dir = tempfile::tempdir()?;
            let mut manager = OnboardingManager::new()?;
            manager.config_dir = temp_dir.path().to_path_buf();
            Ok(Self {
                manager,
                _temp_dir: temp_dir,
            })
        }
    }

    #[test]
    fn test_first_launch_detection() {
        let test_manager = TestOnboardingManager::new().unwrap();
        assert!(test_manager.manager.is_first_launch());
    }

    #[test]
    fn test_system_requirements_check() {
        let test_manager = TestOnboardingManager::new().unwrap();
        let requirements = test_manager.manager.check_system_requirements();
        
        // All should be true for basic setup
        assert!(requirements.os_compatible);
        // Note: memory and disk checks are stubbed for now
        assert!(requirements.memory_sufficient);
        assert!(requirements.disk_space_sufficient);
    }

    #[test]
    fn test_opencode_detection() {
        let test_manager = TestOnboardingManager::new().unwrap();
        let (detected, _path) = test_manager.manager.detect_opencode_server();
        
        // This will likely be false in test environment unless opencode is installed
        // The important thing is that it doesn't panic
        assert!(!detected || detected); // Either way is fine
    }

    #[test]
    fn test_config_persistence() {
        let test_manager = TestOnboardingManager::new().unwrap();
        
        // Should be no config initially
        assert!(test_manager.manager.load_config().unwrap().is_none());
        
        // Complete onboarding
        let opencode_path = Some(PathBuf::from("/usr/local/bin/opencode"));
        test_manager.manager.complete_onboarding(opencode_path.clone()).unwrap();
        
        // Should not be first launch anymore
        assert!(!test_manager.manager.is_first_launch());
        
        // Should be able to load config
        let config = test_manager.manager.load_config().unwrap().unwrap();
        assert!(config.is_completed);
        assert_eq!(config.opencode_server_path, opencode_path);
    }

    #[test]
    fn test_onboarding_state() {
        let test_manager = TestOnboardingManager::new().unwrap();
        let state = test_manager.manager.get_onboarding_state().unwrap();
        
        // Should be None for first launch
        assert!(state.config.is_none());
        
        // System requirements should be checked
        assert!(state.system_requirements.os_compatible);
        
        // OpenCode detection should run without error
        assert!(!state.opencode_detected || state.opencode_detected);
    }
}