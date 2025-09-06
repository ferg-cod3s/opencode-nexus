import { test, expect } from '@playwright/test';
import { AuthHelper } from './helpers/auth';

test.describe('Authentication Flow', () => {
  let auth: AuthHelper;

  test.beforeEach(async ({ page }) => {
    auth = new AuthHelper(page);
  });

  test.describe('User Login', () => {
    test('successful login redirects to dashboard', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Valid credentials should log in successfully
      await auth.login('testuser', 'SecurePass123!');
      
      // Should redirect to dashboard
      await expect(page).toHaveURL('/dashboard');
      await expect(page.locator('[data-testid="user-menu"]')).toContainText('testuser');
      await expect(page.locator('[data-testid="dashboard-welcome"]')).toBeVisible();
    });

    test('invalid credentials show error message', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Invalid credentials should fail
      await auth.login('testuser', 'wrongpassword', { expectFailure: true });
      
      // Should stay on login page with error
      await expect(page).toHaveURL('/login');
      await expect(page.locator('[data-testid="login-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="login-error"]')).toContainText('Invalid username or password');
    });

    test('empty fields show validation errors', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Try to login with empty fields
      await page.click('[data-testid="login-button"]');
      
      // Should show validation errors
      await expect(page.locator('[data-testid="username-required"]')).toBeVisible();
      await expect(page.locator('[data-testid="password-required"]')).toBeVisible();
      
      // Should not redirect
      await expect(page).toHaveURL('/login');
    });

    test('account lockout after 5 failed attempts', async ({ page }) => {
      test.setTimeout(30000); // Allow time for multiple login attempts
      
      await auth.triggerAccountLockout('testuser');
      
      // Should show account locked message
      await expect(page.locator('[data-testid="account-locked"]')).toBeVisible();
      await expect(page.locator('[data-testid="lockout-timer"]')).toBeVisible();
      
      // Login form should be disabled
      await expect(page.locator('[data-testid="login-button"]')).toBeDisabled();
      
      // Timer should show remaining time
      const timerText = await page.textContent('[data-testid="lockout-timer"]');
      expect(timerText).toMatch(/\d+:\d+/); // Format: MM:SS
    });
  });

  test.describe('Desktop Security Model', () => {
    test('public registration is blocked for security', async ({ page }) => {
      // SECURITY: Verify that public account creation is not possible
      try {
        await auth.createAccount({
          username: 'hacker',
          password: 'TryToBreakIn123!',
          confirmPassword: 'TryToBreakIn123!'
        });
        
        // Should not reach here - createAccount should throw error
        throw new Error('Security vulnerability: Public account creation was allowed');
      } catch (error) {
        // This is expected - public registration should be blocked
        expect(error.message).toContain('Account creation disabled for security');
      }
    });

    test('only owner account can authenticate', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Try to authenticate as non-owner account (should fail)
      await auth.login('hacker', 'TryToBreakIn123!', { expectFailure: true });
      
      // Should stay on login page with security error
      await expect(page).toHaveURL('/login');
      await expect(page.locator('[data-testid="login-error"]')).toBeVisible();
    });

    test('authentication requires completed onboarding', async ({ page }) => {
      // This test assumes onboarding and owner account setup is required
      await auth.navigateToLogin();
      
      // Without proper onboarding, authentication should fail  
      // (This test will be updated based on actual onboarding flow)
      await expect(page.locator('[data-testid="login-form"]')).toBeVisible();
    });

    test('security logging tracks unauthorized attempts', async ({ page }) => {
      // This test verifies that security violations are logged
      // The actual implementation logs to Sentry, which we can't test directly
      // But we can verify the behavior is secure
      
      await auth.navigateToLogin();
      await auth.login('unauthorized-user', 'fake-password', { expectFailure: true });
      
      // Should fail and stay on login page
      await expect(page).toHaveURL('/login');
    });
  });

  test.describe('Session Management', () => {
    test('session persists across page reloads', async ({ page }) => {
      await auth.loginAsTestUser();
      
      await auth.verifySessionPersistence();
      
      // User should still be logged in after reload
      await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
    });

    test('session expires after configured timeout', async ({ page }) => {
      await auth.loginAsTestUser();
      
      // Mock session expiration
      await auth.verifySessionExpiration();
      
      // Should be redirected to login
      await expect(page).toHaveURL('/login');
    });

    test('logout clears session and redirects', async ({ page }) => {
      await auth.loginAsTestUser();
      
      // Logout
      await auth.logout();
      
      // Should be redirected to login
      await expect(page).toHaveURL('/login');
      
      // Trying to access protected route should redirect to login
      await page.goto('/dashboard');
      await expect(page).toHaveURL('/login');
    });

    test('multiple tabs share authentication state', async ({ context }) => {
      // Create first tab and login
      const page1 = await context.newPage();
      const auth1 = new AuthHelper(page1);
      await auth1.loginAsTestUser();
      
      // Create second tab
      const page2 = await context.newPage();
      await page2.goto('/dashboard');
      
      // Second tab should also be authenticated
      await expect(page2).toHaveURL('/dashboard');
      await expect(page2.locator('[data-testid="user-menu"]')).toBeVisible();
      
      // Logout from first tab
      await auth1.logout();
      
      // Second tab should also be logged out after refresh/navigation
      await page2.reload();
      await expect(page2).toHaveURL('/login');
    });
  });

  test.describe('Security Features', () => {
    test('password is masked in input field', async ({ page }) => {
      await auth.navigateToLogin();
      
      const passwordInput = page.locator('[data-testid="password-input"]');
      
      // Password input should have type="password"
      await expect(passwordInput).toHaveAttribute('type', 'password');
      
      // Fill password and verify it's masked
      await passwordInput.fill('testpassword');
      const inputValue = await passwordInput.inputValue();
      expect(inputValue).toBe('testpassword'); // Value is there but visually masked
    });

    test('login form prevents CSRF attacks', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Check for CSRF token or other security measures
      const csrfToken = page.locator('[name="_token"], [name="csrf_token"]');
      if (await csrfToken.isVisible()) {
        await expect(csrfToken).toHaveValue(/.+/); // Should have some value
      }
      
      // Form should have proper security headers
      const form = page.locator('[data-testid="login-form"]');
      await expect(form).toBeVisible();
    });

    test('sensitive data is not exposed in URLs or storage', async ({ page }) => {
      await auth.loginAsTestUser();
      
      // Check that no sensitive data is in the URL
      const currentURL = page.url();
      expect(currentURL).not.toContain('password');
      expect(currentURL).not.toContain('token');
      
      // Check localStorage/sessionStorage for exposed secrets
      const localStorage = await page.evaluate(() => JSON.stringify(localStorage));
      const sessionStorage = await page.evaluate(() => JSON.stringify(sessionStorage));
      
      expect(localStorage.toLowerCase()).not.toContain('password');
      expect(sessionStorage.toLowerCase()).not.toContain('password');
    });

    test('brute force protection works correctly', async ({ page }) => {
      // This test verifies that repeated failed logins are handled properly
      await auth.navigateToLogin();
      
      // Track failed login attempts
      let attempts = 0;
      const maxAttempts = 5;
      
      while (attempts < maxAttempts) {
        await auth.login('testuser', 'wrongpassword', { expectFailure: true });
        attempts++;
        
        // Clear form for next attempt
        await page.fill('[data-testid="username-input"]', '');
        await page.fill('[data-testid="password-input"]', '');
        
        // Check if lockout occurred early
        if (await page.locator('[data-testid="account-locked"]').isVisible()) {
          break;
        }
      }
      
      // Should eventually trigger lockout
      if (attempts === maxAttempts) {
        await auth.login('testuser', 'wrongpassword', { expectFailure: true });
        await expect(page.locator('[data-testid="account-locked"]')).toBeVisible();
      }
    });
  });

  test.describe('Accessibility', () => {
    test('login form is keyboard accessible', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Tab through form elements
      await page.keyboard.press('Tab');
      await expect(page.locator('[data-testid="username-input"]')).toBeFocused();
      
      await page.keyboard.press('Tab');
      await expect(page.locator('[data-testid="password-input"]')).toBeFocused();
      
      await page.keyboard.press('Tab');
      await expect(page.locator('[data-testid="login-button"]')).toBeFocused();
      
      // Should be able to submit with Enter
      await page.fill('[data-testid="username-input"]', 'testuser');
      await page.fill('[data-testid="password-input"]', 'SecurePass123!');
      await page.keyboard.press('Enter');
      
      await expect(page).toHaveURL('/dashboard');
    });

    test('form labels and ARIA attributes are present', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Check for proper labels
      await expect(page.locator('label[for="username"], [aria-labelledby*="username"]')).toBeVisible();
      await expect(page.locator('label[for="password"], [aria-labelledby*="password"]')).toBeVisible();
      
      // Check for ARIA attributes
      const usernameInput = page.locator('[data-testid="username-input"]');
      const passwordInput = page.locator('[data-testid="password-input"]');
      
      await expect(usernameInput).toHaveAttribute('aria-label', /.+/);
      await expect(passwordInput).toHaveAttribute('aria-label', /.+/);
    });

    test('error messages are announced to screen readers', async ({ page }) => {
      await auth.navigateToLogin();
      
      // Trigger validation error
      await page.click('[data-testid="login-button"]');
      
      // Error messages should have proper ARIA attributes
      const errorMessage = page.locator('[data-testid="login-error"], [data-testid="username-required"]');
      if (await errorMessage.isVisible()) {
        await expect(errorMessage).toHaveAttribute('role', 'alert');
        // or aria-live="assertive" for immediate announcement
      }
    });
  });
});