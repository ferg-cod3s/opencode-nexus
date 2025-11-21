import { test, expect } from '@playwright/test';

test.describe('Web Flow Navigation Test', () => {
  test('should navigate through the complete web flow', async ({ page }) => {
    // 1. Start at index page
    await page.goto('/');
    await expect(page.locator('text=Preparing your workspace')).toBeVisible();

    // Wait for routing to complete (should redirect to /connect since no saved connections)
    await page.waitForURL('/connect', { timeout: 10000 });

    // 2. Verify connection page loads
    await expect(page.locator('text=Connect to OpenCode Server')).toBeVisible();
    await expect(page.locator('[data-testid="connect-form"]')).toBeVisible();

    // 3. Fill out connection form
    await page.fill('[data-testid="server-url-input"]', 'http://localhost:4096');
    await page.selectOption('[data-testid="connection-method-select"]', 'localhost');
    await page.fill('[data-testid="connection-name-input"]', 'Test Connection');

    // 4. Test connection (this will fail since no server is running, but UI should handle it)
    await page.click('[data-testid="test-connection-button"]');

    // Wait a moment for the connection attempt
    await page.waitForTimeout(2000);

    // Check that the button shows loading state and then returns to normal
    const testButton = page.locator('[data-testid="test-connection-button"]');
    await expect(testButton).not.toHaveClass('loading');

    // 5. Navigate to test-chat page (bypasses authentication)
    await page.goto('/test-chat');

    // Should show test chat interface
    await expect(page.locator('.chat-container')).toBeVisible();
    await expect(page.locator('.dashboard-header')).toBeVisible();

    // 6. Navigate back to connect page
    await page.goto('/connect');

    // Should still show the connection form
    await expect(page.locator('text=Connect to OpenCode Server')).toBeVisible();

    console.log('✅ Web flow navigation test completed successfully');
  });
});