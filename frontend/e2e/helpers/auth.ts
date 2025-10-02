import { Page, expect } from '@playwright/test';

export class AuthHelper {
  constructor(private page: Page) {}

  async navigateToLogin() {
    console.log('[AUTH HELPER] Navigating to login page...');
    await this.page.goto('/login');

    // Wait for page to load
    await this.page.waitForLoadState('networkidle');
    console.log('[AUTH HELPER] Page loaded, waiting for JS initialization...');
    await this.page.waitForTimeout(1000); // Give time for JS to initialize

    // Check if page content loaded
    const pageTitle = await this.page.title();
    console.log(`[AUTH HELPER] Page title: ${pageTitle}`);

    const loginForm = this.page.locator('[data-testid="login-form"]');
    const formExists = await loginForm.isVisible({ timeout: 5000 }).catch(() => false);
    console.log(`[AUTH HELPER] Login form visible: ${formExists}`);

    if (!formExists) {
      console.log('[AUTH HELPER] Login form not found, checking page content...');
      const bodyText = await this.page.locator('body').textContent();
      console.log(`[AUTH HELPER] Page body text: ${bodyText?.substring(0, 500)}...`);
    }

    // More aggressive error overlay dismissal
    try {
      // Check for and dismiss Vite error overlays multiple times
      for (let i = 0; i < 5; i++) {
        const overlay = this.page.locator('vite-error-overlay');
        if (await overlay.isVisible({ timeout: 1000 })) {
          console.log(`[AUTH HELPER] Vite error overlay found (attempt ${i + 1})`);

          // Try to read the error message
          try {
            const errorText = await this.page.locator('vite-error-overlay').textContent();
            console.log(`[AUTH HELPER] Vite error overlay content: ${errorText?.substring(0, 500)}...`);
          } catch (e) {
            console.log(`[AUTH HELPER] Could not read error overlay content: ${e}`);
          }

          console.log(`[AUTH HELPER] Dismissing Vite error overlay (attempt ${i + 1})`);

          // Try to remove the overlay from DOM
          try {
            await this.page.evaluate(() => {
              const overlay = document.querySelector('vite-error-overlay');
              if (overlay) {
                overlay.remove();
                console.log('Removed Vite error overlay from DOM');
              }
            });
          } catch (e) {
            console.log(`[AUTH HELPER] Could not remove overlay from DOM: ${e}`);
          }

          await this.page.keyboard.press('Escape');
          await this.page.waitForTimeout(500);

          // Also try clicking the overlay close button if it exists
          try {
            await this.page.locator('vite-error-overlay .close').click({ timeout: 1000 });
          } catch {
            // No close button, continue
          }
        } else {
          break; // No overlay visible
        }
      }

      // Wait a bit more for any remaining overlays to disappear
      await this.page.waitForTimeout(1000);
    } catch (error) {
      console.log('[AUTH HELPER] No Vite error overlay found or already dismissed');
    }

    await expect(this.page.locator('[data-testid="login-form"]')).toBeVisible();

    // Check if JavaScript is working
    try {
      const jsWorking = await this.page.evaluate(() => {
        console.log('🔍 Test: JavaScript is working');
        return true;
      });
      console.log(`[AUTH HELPER] JavaScript execution test: ${jsWorking}`);
    } catch (error) {
      console.log(`[AUTH HELPER] JavaScript execution failed: ${error}`);
    }

    // Check if the script is loaded
    const scripts = await this.page.locator('script').count();
    console.log(`[AUTH HELPER] Number of script tags: ${scripts}`);



    console.log('[AUTH HELPER] Login page navigation complete');
  }

  async login(username: string, password: string, options?: { expectFailure?: boolean }) {
    await this.dismissErrorOverlays();

    await expect(this.page.locator('[data-testid="username-input"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="password-input"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="login-button"]')).toBeVisible();

    console.log(`[AUTH HELPER] Filling form with username: ${username}`);
    await this.page.fill('[data-testid="username-input"]', username);
    await this.page.fill('[data-testid="password-input"]', password);

    await this.page.waitForTimeout(100);
    await this.dismissErrorOverlays();

    console.log('[AUTH HELPER] Submitting login form via button click...');
    await this.page.click('[data-testid="login-button"]');

    if (!options?.expectFailure) {
      console.log('[AUTH HELPER] Expecting redirect to dashboard...');
      await this.page.waitForURL('/dashboard', { timeout: 5000 });

      // Wait for dashboard to load and JavaScript to execute
      await this.page.waitForTimeout(1000);

      // Check that we're on the dashboard
      await expect(this.page).toHaveURL('/dashboard');
      await expect(this.page.locator('[data-testid="dashboard-welcome"]')).toBeVisible();

      // Check that username is displayed
      await expect(this.page.locator('[data-testid="user-menu"]')).toContainText(username);
      console.log('[AUTH HELPER] Login successful, on dashboard');
    } else {
      console.log('[AUTH HELPER] Expecting to stay on login page with error...');
      await this.page.waitForTimeout(500);
      await expect(this.page).toHaveURL('/login');
      await expect(this.page.locator('[data-testid="login-error"]')).toBeVisible();
      console.log('[AUTH HELPER] Login failed as expected, error visible');
    }
  }

  private async dismissErrorOverlays() {
    try {
      // Check for and dismiss Vite error overlays
      const overlay = this.page.locator('vite-error-overlay');
      if (await overlay.isVisible({ timeout: 1000 })) {
        console.log('[AUTH HELPER] Dismissing Vite error overlay before interaction');

        // Try to remove the overlay from DOM
        try {
          await this.page.evaluate(() => {
            const overlay = document.querySelector('vite-error-overlay');
            if (overlay) {
              overlay.remove();
              console.log('Removed Vite error overlay from DOM');
            }
          });
        } catch (e) {
          console.log(`[AUTH HELPER] Could not remove overlay from DOM: ${e}`);
        }

        await this.page.keyboard.press('Escape');
        await this.page.waitForTimeout(500);

        // Also try clicking the overlay close button if it exists
        try {
          await this.page.locator('vite-error-overlay .close').click({ timeout: 1000 });
        } catch {
          // No close button, continue
        }
      }
    } catch {
      // No error overlay, continue
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
    
    console.log('[AUTH HELPER] Triggering account lockout - attempting 6 failed logins...');
    
    for (let i = 1; i <= 6; i++) {
      console.log(`[AUTH HELPER] Failed login attempt ${i}/6`);
      
      const usernameInput = this.page.locator('[data-testid="username-input"]');
      const passwordInput = this.page.locator('[data-testid="password-input"]');
      const loginButton = this.page.locator('[data-testid="login-button"]');
      
      const isDisabled = await usernameInput.isDisabled().catch(() => true);
      if (isDisabled) {
        console.log('[AUTH HELPER] Form already locked, stopping attempts');
        break;
      }
      
      await usernameInput.fill(username);
      await passwordInput.fill('wrongpassword');
      await loginButton.click();
      
      await this.page.waitForTimeout(800);
      
      await expect(this.page).toHaveURL('/login');
      
      const accountLocked = await this.page.locator('[data-testid="account-locked"]').isVisible().catch(() => false);
      if (accountLocked) {
        console.log(`[AUTH HELPER] Account locked after attempt ${i}`);
        break;
      }
      
      await expect(this.page.locator('[data-testid="login-error"]')).toBeVisible();
      
      if (i < 6) {
        const stillEnabled = await usernameInput.isEnabled().catch(() => false);
        if (stillEnabled) {
          await usernameInput.fill('');
          await passwordInput.fill('');
        }
      }
    }
    
    await expect(this.page.locator('[data-testid="account-locked"]').first()).toBeVisible();
    await expect(this.page.locator('[data-testid="lockout-timer"]').first()).toBeVisible();
    console.log('[AUTH HELPER] Account lockout triggered successfully');
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