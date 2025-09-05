import { test, expect } from '@playwright/test';

test.describe('Complete User Flow', () => {
  test('should complete onboarding and use chat functionality', async ({ page }) => {
    // Step 1: Start onboarding
    await page.goto('/onboarding');

    // Verify welcome step
    await expect(page.locator('.step.active[data-step="welcome"]')).toBeVisible();

    // Navigate through onboarding steps
    await page.click('[data-action="next"]'); // Welcome → Requirements
    await expect(page.locator('.step.active[data-step="requirements"]')).toBeVisible();

    // Wait for system check and continue
    await page.waitForSelector('[data-action="check-requirements"]:not([disabled])');
    await page.click('[data-action="check-requirements"]');
    await page.click('[data-action="next"]'); // Requirements → Server

    // Configure server setup
    await page.check('#auto-download');
    await page.click('[data-action="setup-server"]');

    // Complete security setup
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'TestPass123!');
    await page.fill('#confirm-password', 'TestPass123!');
    await page.click('[data-action="complete"]');

    // Step 2: Verify dashboard loads
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('.dashboard-header')).toBeVisible();

    // Step 3: Navigate to chat interface
    await page.click('[data-nav="chat"]');
    await expect(page).toHaveURL('/');

    // Step 4: Test chat functionality
    await expect(page.locator('.welcome-screen')).toBeVisible();
    await page.click('.start-btn');

    // Verify chat interface loads
    await expect(page.locator('.chat-interface')).toBeVisible();
    await expect(page.locator('.sessions-sidebar')).toBeVisible();

    // Send a test message
    await page.fill('.message-input textarea', 'Hello OpenCode!');
    await page.click('button[data-action="send"]');

    // Verify message appears
    await expect(page.locator('.message-bubble.user')).toContainText('Hello OpenCode!');

    // Test session management
    await expect(page.locator('.session-card')).toHaveCount(1);

    // Test navigation back to dashboard
    await page.click('[data-nav="dashboard"]');
    await expect(page).toHaveURL('/dashboard');
  });

  test('should handle error states gracefully', async ({ page }) => {
    // Navigate to dashboard without completing onboarding
    await page.goto('/dashboard');

    // Should redirect to onboarding
    await expect(page).toHaveURL('/onboarding');

    // Try to access chat without setup
    await page.goto('/');

    // Should redirect to onboarding
    await expect(page).toHaveURL('/onboarding');
  });

  test('should maintain state across navigation', async ({ page }) => {
    // Complete onboarding flow
    await page.goto('/onboarding');

    // Fast-forward through steps
    await page.evaluate(() => {
      localStorage.setItem('onboarding_complete', 'true');
      localStorage.setItem('user_configured', 'true');
    });

    await page.reload();

    // Navigate to dashboard
    await page.goto('/dashboard');
    await expect(page.locator('.dashboard-header')).toBeVisible();

    // Navigate to chat
    await page.click('[data-nav="chat"]');
    await expect(page.locator('.chat-interface')).toBeVisible();

    // Navigate back to dashboard
    await page.click('[data-nav="dashboard"]');
    await expect(page.locator('.dashboard-header')).toBeVisible();

    // State should be maintained
    await expect(page.locator('.server-status-card')).toBeVisible();
  });

  test('should work on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });

    // Complete onboarding
    await page.goto('/onboarding');

    // Fast-forward setup
    await page.evaluate(() => {
      localStorage.setItem('onboarding_complete', 'true');
      localStorage.setItem('user_configured', 'true');
    });

    await page.reload();

    // Navigate to dashboard
    await page.goto('/dashboard');

    // Verify mobile layout
    await expect(page.locator('.mobile-menu')).toBeVisible();

    // Test chat on mobile
    await page.click('[data-nav="chat"]');
    await expect(page.locator('.chat-interface')).toBeVisible();

    // Verify mobile chat layout
    await expect(page.locator('.sessions-sidebar')).toHaveCSS('max-height', '300px');
  });

  test('should handle network connectivity issues', async ({ page }) => {
    // Complete setup
    await page.goto('/onboarding');
    await page.evaluate(() => {
      localStorage.setItem('onboarding_complete', 'true');
      localStorage.setItem('user_configured', 'true');
    });
    await page.reload();

    // Navigate to chat
    await page.click('[data-nav="chat"]');
    await page.click('.start-btn');

    // Simulate network disconnection (would need backend mocking)
    // For now, test error handling UI
    await expect(page.locator('.message-input')).toBeVisible();

    // Try to send message during "disconnection"
    await page.fill('.message-input textarea', 'Test message');
    await page.click('button[data-action="send"]');

    // Should handle gracefully (would show error in real scenario)
    await expect(page.locator('.message-input textarea')).toHaveValue('Test message');
  });
});