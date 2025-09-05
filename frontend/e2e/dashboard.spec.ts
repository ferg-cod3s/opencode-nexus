import { test, expect } from '@playwright/test';

test.describe('Dashboard Functionality', () => {
  test.beforeEach(async ({ page }) => {
    // Assume onboarding is complete, navigate to dashboard
    await page.goto('/dashboard');
  });

  test('should display server status overview', async ({ page }) => {
    // Verify main dashboard elements are present
    await expect(page.locator('.dashboard-header')).toBeVisible();
    await expect(page.locator('.server-status-card')).toBeVisible();
    await expect(page.locator('.activity-feed')).toBeVisible();
  });

  test('should show server control buttons', async ({ page }) => {
    // Verify server control buttons are present
    await expect(page.locator('button[data-action="start-server"]')).toBeVisible();
    await expect(page.locator('button[data-action="stop-server"]')).toBeVisible();
    await expect(page.locator('button[data-action="restart-server"]')).toBeVisible();
  });

  test('should display system metrics', async ({ page }) => {
    // Verify system metrics are displayed
    await expect(page.locator('.cpu-usage')).toBeVisible();
    await expect(page.locator('.memory-usage')).toBeVisible();
    await expect(page.locator('.disk-usage')).toBeVisible();
  });

  test('should navigate to chat interface', async ({ page }) => {
    // Click chat navigation button
    await page.click('[data-nav="chat"]');

    // Should navigate to chat interface
    await expect(page).toHaveURL('/');

    // Verify chat interface elements
    await expect(page.locator('.chat-interface')).toBeVisible();
    await expect(page.locator('.sessions-sidebar')).toBeVisible();
  });

  test('should handle server start/stop actions', async ({ page }) => {
    // Click start server button
    await page.click('button[data-action="start-server"]');

    // Should show loading state
    await expect(page.locator('.loading-spinner')).toBeVisible();

    // Should eventually show running status
    await expect(page.locator('.server-status.running')).toBeVisible();
  });

  test('should display activity feed with real-time updates', async ({ page }) => {
    // Verify activity feed is present
    await expect(page.locator('.activity-feed')).toBeVisible();

    // Should have activity items
    const activityItems = page.locator('.activity-item');
    await expect(activityItems.first()).toBeVisible();
  });

  test('should be keyboard accessible', async ({ page }) => {
    // Tab through dashboard elements
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');

    // Verify focus is on interactive elements
    const focusedElement = await page.evaluate(() => document.activeElement?.tagName);
    expect(['BUTTON', 'A', 'INPUT']).toContain(focusedElement);
  });

  test('should handle server errors gracefully', async ({ page }) => {
    // Simulate server error (would need backend mocking)
    // Click start server when server is unavailable
    await page.click('button[data-action="start-server"]');

    // Should show error message
    await expect(page.locator('.error-message')).toBeVisible();

    // Should provide retry option
    await expect(page.locator('button[data-action="retry"]')).toBeVisible();
  });
});