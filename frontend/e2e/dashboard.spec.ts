import { test, expect } from '@playwright/test';

test.describe('Dashboard Functionality - Static Tests', () => {
  // These tests verify dashboard structure without authentication
  // Full integration tests are in server-management.spec.ts
  
  test.beforeEach(async ({ page }) => {
    // Try to access dashboard directly to test redirect behavior
    await page.goto('/dashboard');
  });

  test('should redirect to login when not authenticated', async ({ page }) => {
    // Dashboard should redirect unauthenticated users to login
    await page.waitForURL('/login', { timeout: 5000 });
    await expect(page).toHaveURL('/login');
  });

  test('login page should have proper structure', async ({ page }) => {
    // After redirect, verify login page elements
    await page.waitForURL('/login');
    await expect(page.locator('[data-testid="username-input"]')).toBeAttached();
    await expect(page.locator('[data-testid="password-input"]')).toBeAttached();
    await expect(page.locator('[data-testid="login-button"]')).toBeAttached();
  });
});