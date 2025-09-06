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

  // SECURITY: Account creation removed - desktop app uses owner-only authentication
  async createAccount(credentials: {
    username: string;
    password: string;
    confirmPassword: string;
  }) {
    throw new Error('Account creation disabled for security - desktop app uses owner-only authentication');
  }

  // SECURITY: Password strength testing removed - no public registration allowed
  async testPasswordStrength(password: string): Promise<string> {
    throw new Error('Password strength testing disabled - no public registration in desktop app');
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

  // SECURITY: Username validation removed - no public registration allowed
  async testInvalidUsernameFormat(invalidUsername: string) {
    throw new Error('Username format testing disabled - no public registration in desktop app');
  }

  // SECURITY: Password mismatch testing removed - no public registration allowed  
  async testPasswordMismatch() {
    throw new Error('Password mismatch testing disabled - no public registration in desktop app');
  }
}