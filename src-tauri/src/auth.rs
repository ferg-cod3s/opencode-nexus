use anyhow::{anyhow, Result};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthConfig {
    pub username: String,
    pub password_hash: String,
    pub salt: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_login_at: Option<DateTime<Utc>>,
    pub failed_login_attempts: u32,
    pub locked_until: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginAttempt {
    pub username: String,
    pub timestamp: DateTime<Utc>,
    pub success: bool,
    pub ip_address: Option<String>,
}

#[derive(Debug, Clone)]
pub struct AuthSession {
    pub username: String,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub is_valid: bool,
}

pub struct AuthManager {
    config_dir: PathBuf,
}

impl AuthManager {
    pub fn new(config_dir: PathBuf) -> Result<Self> {
        std::fs::create_dir_all(&config_dir)?;
        Ok(Self { config_dir })
    }

    fn get_auth_config_path(&self) -> PathBuf {
        self.config_dir.join("auth.json")
    }

    pub fn is_configured(&self) -> bool {
        self.get_auth_config_path().exists()
    }

    pub fn create_user(&self, username: &str, password: &str) -> Result<()> {
        // Validate password strength
        self.validate_password(password)?;
        
        // Check if user already exists
        if self.is_configured() {
            return Err(anyhow!("User already exists"));
        }

        // Generate salt and hash password
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        let password_hash = argon2
            .hash_password(password.as_bytes(), &salt)
            .map_err(|e| anyhow!("Failed to hash password: {}", e))?
            .to_string();

        // Create auth config
        let auth_config = AuthConfig {
            username: username.to_string(),
            password_hash,
            salt: salt.to_string(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
            last_login_at: None,
            failed_login_attempts: 0,
            locked_until: None,
        };

        // Save to disk
        self.save_auth_config(&auth_config)?;
        
        Ok(())
    }

    pub fn authenticate(&self, username: &str, password: &str) -> Result<AuthSession> {
        let mut auth_config = self.load_auth_config()?;

        // Check if account is locked
        if let Some(locked_until) = auth_config.locked_until {
            if Utc::now() < locked_until {
                return Err(anyhow!("Account is locked due to too many failed login attempts"));
            } else {
                // Unlock account
                auth_config.locked_until = None;
                auth_config.failed_login_attempts = 0;
            }
        }

        // Verify username
        if auth_config.username != username {
            auth_config.failed_login_attempts += 1;
            self.handle_failed_login(&mut auth_config)?;
            return Err(anyhow!("Invalid credentials"));
        }

        // Verify password
        let parsed_hash = PasswordHash::new(&auth_config.password_hash)
            .map_err(|e| anyhow!("Failed to parse password hash: {}", e))?;
        
        let argon2 = Argon2::default();
        match argon2.verify_password(password.as_bytes(), &parsed_hash) {
            Ok(_) => {
                // Successful login
                auth_config.last_login_at = Some(Utc::now());
                auth_config.failed_login_attempts = 0;
                auth_config.locked_until = None;
                self.save_auth_config(&auth_config)?;

                // Create session
                let session = AuthSession {
                    username: username.to_string(),
                    created_at: Utc::now(),
                    expires_at: Utc::now() + chrono::Duration::hours(24), // 24 hour session
                    is_valid: true,
                };

                self.log_login_attempt(username, true, None)?;
                Ok(session)
            }
            Err(_) => {
                auth_config.failed_login_attempts += 1;
                self.handle_failed_login(&mut auth_config)?;
                self.log_login_attempt(username, false, None)?;
                Err(anyhow!("Invalid credentials"))
            }
        }
    }

    pub fn change_password(&self, username: &str, old_password: &str, new_password: &str) -> Result<()> {
        // Authenticate with old password first
        self.authenticate(username, old_password)?;

        // Validate new password
        self.validate_password(new_password)?;

        // Load current config
        let mut auth_config = self.load_auth_config()?;

        // Generate new salt and hash
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        let password_hash = argon2
            .hash_password(new_password.as_bytes(), &salt)
            .map_err(|e| anyhow!("Failed to hash password: {}", e))?
            .to_string();

        // Update config
        auth_config.password_hash = password_hash;
        auth_config.salt = salt.to_string();
        auth_config.updated_at = Utc::now();
        auth_config.failed_login_attempts = 0;
        auth_config.locked_until = None;

        // Save to disk
        self.save_auth_config(&auth_config)?;

        Ok(())
    }

    pub fn reset_failed_attempts(&self, username: &str) -> Result<()> {
        let mut auth_config = self.load_auth_config()?;
        
        if auth_config.username != username {
            return Err(anyhow!("User not found"));
        }

        auth_config.failed_login_attempts = 0;
        auth_config.locked_until = None;
        auth_config.updated_at = Utc::now();

        self.save_auth_config(&auth_config)?;
        Ok(())
    }

    pub fn get_user_info(&self) -> Result<Option<(String, DateTime<Utc>, Option<DateTime<Utc>>)>> {
        if !self.is_configured() {
            return Ok(None);
        }

        let auth_config = self.load_auth_config()?;
        Ok(Some((
            auth_config.username,
            auth_config.created_at,
            auth_config.last_login_at,
        )))
    }

    fn validate_password(&self, password: &str) -> Result<()> {
        if password.len() < 8 {
            return Err(anyhow!("Password must be at least 8 characters long"));
        }

        if password.len() > 128 {
            return Err(anyhow!("Password must be less than 128 characters long"));
        }

        // Check for at least one lowercase letter
        if !password.chars().any(|c| c.is_lowercase()) {
            return Err(anyhow!("Password must contain at least one lowercase letter"));
        }

        // Check for at least one uppercase letter
        if !password.chars().any(|c| c.is_uppercase()) {
            return Err(anyhow!("Password must contain at least one uppercase letter"));
        }

        // Check for at least one digit
        if !password.chars().any(|c| c.is_ascii_digit()) {
            return Err(anyhow!("Password must contain at least one number"));
        }

        Ok(())
    }

    fn handle_failed_login(&self, auth_config: &mut AuthConfig) -> Result<()> {
        const MAX_FAILED_ATTEMPTS: u32 = 5;
        const LOCK_DURATION_MINUTES: i64 = 30;

        if auth_config.failed_login_attempts >= MAX_FAILED_ATTEMPTS {
            auth_config.locked_until = Some(Utc::now() + chrono::Duration::minutes(LOCK_DURATION_MINUTES));
        }

        auth_config.updated_at = Utc::now();
        self.save_auth_config(auth_config)?;
        Ok(())
    }

    fn log_login_attempt(&self, username: &str, success: bool, ip_address: Option<&str>) -> Result<()> {
        let log_path = self.config_dir.join("login_attempts.log");
        let attempt = LoginAttempt {
            username: username.to_string(),
            timestamp: Utc::now(),
            success,
            ip_address: ip_address.map(|s| s.to_string()),
        };

        let log_entry = format!(
            "{} - {} - {} - {}\n",
            attempt.timestamp.format("%Y-%m-%d %H:%M:%S UTC"),
            attempt.username,
            if attempt.success { "SUCCESS" } else { "FAILED" },
            attempt.ip_address.unwrap_or_else(|| "unknown".to_string())
        );

        use std::fs::OpenOptions;
        use std::io::Write;

        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(log_path)?;
        
        file.write_all(log_entry.as_bytes())?;
        file.flush()?;

        Ok(())
    }

    fn load_auth_config(&self) -> Result<AuthConfig> {
        let config_path = self.get_auth_config_path();
        if !config_path.exists() {
            return Err(anyhow!("Authentication not configured"));
        }

        let config_json = std::fs::read_to_string(config_path)?;
        let config: AuthConfig = serde_json::from_str(&config_json)?;
        Ok(config)
    }

    fn save_auth_config(&self, config: &AuthConfig) -> Result<()> {
        let config_json = serde_json::to_string_pretty(config)?;
        std::fs::write(self.get_auth_config_path(), config_json)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    struct TestAuthManager {
        manager: AuthManager,
        _temp_dir: TempDir,
    }

    impl TestAuthManager {
        fn new() -> Result<Self> {
            let temp_dir = tempfile::tempdir()?;
            let manager = AuthManager::new(temp_dir.path().to_path_buf())?;
            Ok(Self {
                manager,
                _temp_dir: temp_dir,
            })
        }
    }

    #[test]
    fn test_not_configured_initially() {
        let test_manager = TestAuthManager::new().unwrap();
        assert!(!test_manager.manager.is_configured());
    }

    #[test]
    fn test_create_user_success() {
        let test_manager = TestAuthManager::new().unwrap();
        
        let result = test_manager.manager.create_user("testuser", "TestPass123");
        assert!(result.is_ok());
        assert!(test_manager.manager.is_configured());
    }

    #[test]
    fn test_create_user_weak_password() {
        let test_manager = TestAuthManager::new().unwrap();
        
        // Too short
        let result = test_manager.manager.create_user("testuser", "weak");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("at least 8 characters"));
        
        // No uppercase
        let result = test_manager.manager.create_user("testuser", "lowercase123");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("uppercase letter"));
        
        // No lowercase
        let result = test_manager.manager.create_user("testuser", "UPPERCASE123");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("lowercase letter"));
        
        // No number
        let result = test_manager.manager.create_user("testuser", "NoNumbersHere");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("number"));
    }

    #[test]
    fn test_create_user_already_exists() {
        let test_manager = TestAuthManager::new().unwrap();
        
        // Create first user
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        // Try to create another user
        let result = test_manager.manager.create_user("anotheruser", "AnotherPass123");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("User already exists"));
    }

    #[test]
    fn test_authenticate_success() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        let session = test_manager.manager.authenticate("testuser", "TestPass123").unwrap();
        assert_eq!(session.username, "testuser");
        assert!(session.is_valid);
        assert!(session.expires_at > Utc::now());
    }

    #[test]
    fn test_authenticate_wrong_password() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        let result = test_manager.manager.authenticate("testuser", "WrongPass123");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Invalid credentials"));
    }

    #[test]
    fn test_authenticate_wrong_username() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        let result = test_manager.manager.authenticate("wronguser", "TestPass123");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Invalid credentials"));
    }

    #[test]
    fn test_authenticate_not_configured() {
        let test_manager = TestAuthManager::new().unwrap();
        
        let result = test_manager.manager.authenticate("testuser", "TestPass123");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Authentication not configured"));
    }

    #[test]
    fn test_failed_login_attempts_and_lockout() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        // Make 5 failed attempts
        for _ in 0..5 {
            let result = test_manager.manager.authenticate("testuser", "WrongPass");
            assert!(result.is_err());
        }
        
        // Account should now be locked
        let result = test_manager.manager.authenticate("testuser", "TestPass123");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Account is locked"));
    }

    #[test]
    fn test_reset_failed_attempts() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        // Make some failed attempts
        for _ in 0..3 {
            let _ = test_manager.manager.authenticate("testuser", "WrongPass");
        }
        
        // Reset attempts
        test_manager.manager.reset_failed_attempts("testuser").unwrap();
        
        // Should be able to authenticate now
        let session = test_manager.manager.authenticate("testuser", "TestPass123").unwrap();
        assert!(session.is_valid);
    }

    #[test]
    fn test_change_password_success() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "OldPass123").unwrap();
        
        let result = test_manager.manager.change_password("testuser", "OldPass123", "NewPass456");
        assert!(result.is_ok());
        
        // Should be able to authenticate with new password
        let session = test_manager.manager.authenticate("testuser", "NewPass456").unwrap();
        assert!(session.is_valid);
        
        // Should not be able to authenticate with old password
        let result = test_manager.manager.authenticate("testuser", "OldPass123");
        assert!(result.is_err());
    }

    #[test]
    fn test_change_password_wrong_old_password() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "OldPass123").unwrap();
        
        let result = test_manager.manager.change_password("testuser", "WrongOldPass", "NewPass456");
        assert!(result.is_err());
    }

    #[test]
    fn test_change_password_weak_new_password() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "OldPass123").unwrap();
        
        let result = test_manager.manager.change_password("testuser", "OldPass123", "weak");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("at least 8 characters"));
    }

    #[test]
    fn test_get_user_info() {
        let test_manager = TestAuthManager::new().unwrap();
        
        // No user initially
        let info = test_manager.manager.get_user_info().unwrap();
        assert!(info.is_none());
        
        // Create user
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        let info = test_manager.manager.get_user_info().unwrap();
        assert!(info.is_some());
        
        let (username, created_at, last_login_at) = info.unwrap();
        assert_eq!(username, "testuser");
        assert!(created_at <= Utc::now());
        assert!(last_login_at.is_none());
        
        // Authenticate and check last login
        test_manager.manager.authenticate("testuser", "TestPass123").unwrap();
        
        let info = test_manager.manager.get_user_info().unwrap().unwrap();
        assert!(info.2.is_some()); // last_login_at should be set
    }

    #[test]
    fn test_login_attempt_logging() {
        let test_manager = TestAuthManager::new().unwrap();
        
        test_manager.manager.create_user("testuser", "TestPass123").unwrap();
        
        // Successful login
        test_manager.manager.authenticate("testuser", "TestPass123").unwrap();
        
        // Failed login
        let _ = test_manager.manager.authenticate("testuser", "WrongPass");
        
        // Check if log file exists
        let log_path = test_manager._temp_dir.path().join("login_attempts.log");
        assert!(log_path.exists());
        
        let log_content = std::fs::read_to_string(log_path).unwrap();
        assert!(log_content.contains("SUCCESS"));
        assert!(log_content.contains("FAILED"));
        assert!(log_content.contains("testuser"));
    }
}