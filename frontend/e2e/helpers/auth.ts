import { Page, expect } from '@playwright/test';

export class AuthHelper {
  constructor(private page: Page) {}

  async navigateToLogin() {
    await this.page.goto('/login');
    await expect(this.page.locator('[data-testid="login-form"]')).toBeVisible();
  }

  async login(username: string, password: string, options?: { expectFailure?: boolean }) {
    await this.page.fill('[data-testid="username-input"]', username);
    await this.page.fill('[data-testid="password-input"]', password);
    await this.page.click('[data-testid="login-button"]');

    if (!options?.expectFailure) {
      // Expect successful login
      await expect(this.page).toHaveURL('/dashboard');
      await expect(this.page.locator('[data-testid="user-menu"]')).toContainText(username);
    } else {
      // Stay on login page with error
      await expect(this.page).toHaveURL('/login');
      await expect(this.page.locator('[data-testid="login-error"]')).toBeVisible();
    }
  }

  async loginAsTestUser() {
    await this.navigateToLogin();
    await this.login('testuser', 'SecurePass123!');
  }

  async logout() {
    await this.page.click('[data-testid="user-menu"]');
    await this.page.click('[data-testid="logout-button"]');
    
    // Verify redirect to login
    await expect(this.page).toHaveURL('/login');
    await expect(this.page.locator('[data-testid="login-form"]')).toBeVisible();
  }

  async createAccount(credentials: {
    username: string;
    password: string;
    confirmPassword: string;
  }) {
    await this.page.goto('/register');
    
    await this.page.fill('[data-testid="username-input"]', credentials.username);
    await this.page.fill('[data-testid="password-input"]', credentials.password);
    await this.page.fill('[data-testid="confirm-password-input"]', credentials.confirmPassword);
    
    await this.page.click('[data-testid="create-account-button"]');
    
    // Should redirect to dashboard after successful registration
    await expect(this.page).toHaveURL('/dashboard');
  }

  async testPasswordStrength(password: string): Promise<string> {
    await this.navigateToLogin();
    await this.page.click('[data-testid="register-link"]');
    
    await this.page.fill('[data-testid="password-input"]', password);
    
    // Get password strength indicator
    const strengthIndicator = this.page.locator('[data-testid="password-strength"]');
    await expect(strengthIndicator).toBeVisible();
    
    return await strengthIndicator.textContent() || '';
  }

  async triggerAccountLockout(username: string) {
    await this.navigateToLogin();
    
    // Attempt 5 failed logins
    for (let i = 0; i < 5; i++) {
      await this.login(username, 'wrongpassword', { expectFailure: true });
      
      // Clear fields for next attempt
      await this.page.fill('[data-testid="username-input"]', '');
      await this.page.fill('[data-testid="password-input"]', '');
    }
    
    // 6th attempt should trigger lockout
    await this.login(username, 'wrongpassword', { expectFailure: true });
    await expect(this.page.locator('[data-testid="account-locked"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="lockout-timer"]')).toBeVisible();
  }

  async verifySessionPersistence() {
    // Should already be logged in
    await expect(this.page.locator('[data-testid="user-menu"]')).toBeVisible();
    
    // Reload page
    await this.page.reload();
    
    // Should still be authenticated
    await expect(this.page).toHaveURL('/dashboard');
    await expect(this.page.locator('[data-testid="user-menu"]')).toBeVisible();
  }

  async verifySessionExpiration() {
    // Mock session expiration by clearing session storage
    await this.page.evaluate(() => {
      localStorage.clear();
      sessionStorage.clear();
    });
    
    // Try to access protected route
    await this.page.goto('/dashboard');
    
    // Should redirect to login
    await expect(this.page).toHaveURL('/login');
  }

  async testInvalidUsernameFormat(invalidUsername: string) {
    await this.navigateToLogin();
    await this.page.click('[data-testid="register-link"]');
    
    await this.page.fill('[data-testid="username-input"]', invalidUsername);
    await this.page.fill('[data-testid="password-input"]', 'ValidPass123!');
    await this.page.fill('[data-testid="confirm-password-input"]', 'ValidPass123!');
    
    await this.page.click('[data-testid="create-account-button"]');
    
    // Should show validation error
    await expect(this.page.locator('[data-testid="username-error"]')).toBeVisible();
  }

  async testPasswordMismatch() {
    await this.navigateToLogin();
    await this.page.click('[data-testid="register-link"]');
    
    await this.page.fill('[data-testid="username-input"]', 'testuser');
    await this.page.fill('[data-testid="password-input"]', 'Password123!');
    await this.page.fill('[data-testid="confirm-password-input"]', 'DifferentPass123!');
    
    await this.page.click('[data-testid="create-account-button"]');
    
    // Should show password mismatch error
    await expect(this.page.locator('[data-testid="password-mismatch-error"]')).toBeVisible();
  }
}