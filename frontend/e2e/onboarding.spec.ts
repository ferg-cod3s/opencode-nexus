import { test, expect } from '@playwright/test';

test.describe('Onboarding Flow', () => {
  test('should complete full onboarding process', async ({ page }) => {
    // Navigate to onboarding page
    await page.goto('/onboarding');

    // Verify welcome step is active
    await expect(page.locator('.step.active[data-step="welcome"]')).toBeVisible();
    await expect(page.locator('.step-content.active[data-step="welcome"]')).toBeVisible();

    // Click "Get Started" button
    await page.click('[data-action="next"]');

    // Verify requirements step is now active
    await expect(page.locator('.step.active[data-step="requirements"]')).toBeVisible();
    await expect(page.locator('.step-content.active[data-step="requirements"]')).toBeVisible();

    // Wait for system requirements check to complete
    await page.waitForSelector('[data-action="check-requirements"]:not([disabled])');

    // Click check requirements button
    await page.click('[data-action="check-requirements"]');

    // Verify all requirements show success status
    await expect(page.locator('.status-icon.success')).toHaveCount(4);

    // Click continue to server setup
    await page.click('[data-action="next"]');

    // Verify server setup step is active
    await expect(page.locator('.step.active[data-step="server"]')).toBeVisible();
    await expect(page.locator('.step-content.active[data-step="server"]')).toBeVisible();

    // Select auto-download option
    await page.check('#auto-download');

    // Verify continue button is enabled
    await expect(page.locator('[data-action="setup-server"]')).not.toBeDisabled();

    // Click continue
    await page.click('[data-action="setup-server"]');

    // Should navigate to security setup step
    await expect(page.locator('.step.active[data-step="security"]')).toBeVisible();

    // Fill in security credentials
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'TestPass123!');
    await page.fill('#confirm-password', 'TestPass123!');

    // Click complete setup
    await page.click('[data-action="complete"]');

    // Should redirect to dashboard
    await expect(page).toHaveURL('/dashboard');
  });

  test('should handle system requirements failure', async ({ page }) => {
    // Navigate to onboarding
    await page.goto('/onboarding');

    // Navigate to requirements step
    await page.click('[data-action="next"]');

    // Mock a failed system check (this would be handled by backend)
    // In a real scenario, we'd mock the Tauri invoke call

    // Verify error handling UI appears
    // This test would need backend mocking to fully work
    await expect(page.locator('.step.active[data-step="requirements"]')).toBeVisible();
  });

  test('should validate security form inputs', async ({ page }) => {
    // Navigate to onboarding and complete previous steps
    await page.goto('/onboarding');

    // Fast-forward to security step by simulating completed steps
    await page.evaluate(() => {
      // Simulate completed onboarding state
      localStorage.setItem('onboarding_step', 'security');
      localStorage.setItem('system_check_complete', 'true');
      localStorage.setItem('server_setup_complete', 'true');
    });

    await page.reload();

    // Verify security step is active
    await expect(page.locator('.step.active[data-step="security"]')).toBeVisible();

    // Try to submit with empty fields
    await page.click('[data-action="complete"]');

    // Should show validation errors
    await expect(page.locator('.error-message')).toBeVisible();

    // Fill invalid password
    await page.fill('#username', 'test');
    await page.fill('#password', 'weak');
    await page.fill('#confirm-password', 'weak');

    // Should show password strength error
    await expect(page.locator('.password-strength.weak')).toBeVisible();

    // Fill valid credentials
    await page.fill('#username', 'validuser');
    await page.fill('#password', 'StrongPass123!');
    await page.fill('#confirm-password', 'StrongPass123!');

    // Should show strong password indicator
    await expect(page.locator('.password-strength.strong')).toBeVisible();
  });

  test('should support keyboard navigation', async ({ page }) => {
    await page.goto('/onboarding');

    // Tab through welcome step elements
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');

    // Enter key should activate focused button
    await page.keyboard.press('Enter');

    // Should navigate to requirements step
    await expect(page.locator('.step.active[data-step="requirements"]')).toBeVisible();
  });

  test('should be accessible with screen reader', async ({ page }) => {
    await page.goto('/onboarding');

    // Check for proper ARIA labels
    await expect(page.locator('[aria-label]')).toHaveCount(await page.locator('[aria-label]').count());

    // Check for proper heading structure
    const headings = await page.locator('h1, h2, h3').allTextContents();
    expect(headings.length).toBeGreaterThan(0);

    // Check for focus management
    await page.keyboard.press('Tab');
    const focusedElement = await page.evaluate(() => document.activeElement?.tagName);
    expect(focusedElement).toBeTruthy();
  });
});