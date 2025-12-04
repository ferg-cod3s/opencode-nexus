import { test, expect } from '@playwright/test';

test.describe('Mobile Chat Interface', () => {
  test.beforeEach(async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 390, height: 844 });
    
    // Mock mobile user agent
    await page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15');
  });

  test('should display mobile-optimized chat interface', async ({ page }) => {
    await page.goto('/');
    
    // Check mobile-specific elements
    await expect(page.locator('[data-testid="mobile-header"]')).toBeVisible();
    await expect(page.locator('[data-testid="mobile-chat-input"]')).toBeVisible();
    await expect(page.locator('[data-testid="mobile-send-button"]')).toBeVisible();
    
    // Verify mobile layout
    const chatContainer = page.locator('[data-testid="chat-container"]');
    await expect(chatContainer).toHaveCSS('padding', '16px');
  });

  test('should handle mobile touch interactions', async ({ page }) => {
    await page.goto('/');
    
    const sendButton = page.locator('[data-testid="mobile-send-button"]');
    const chatInput = page.locator('[data-testid="mobile-chat-input"]');
    
    // Test touch events
    await chatInput.tap();
    await chatInput.fill('Hello from mobile!');
    
    // Test tap to send
    await sendButton.tap();
    
    // Verify message was sent
    await expect(page.locator('[data-testid="message-user"]')).toContainText('Hello from mobile!');
  });

  test('should support mobile gestures', async ({ page }) => {
    await page.goto('/');
    
    const chatContainer = page.locator('[data-testid="chat-messages"]');
    
    // Test swipe gestures for navigation
    await chatContainer.tap();
    await page.mouse.move(200, 400);
    await page.mouse.down();
    await page.mouse.move(50, 400);
    await page.mouse.up();
    
    // Verify gesture was handled (could open menu or navigate)
    await expect(page.locator('[data-testid="mobile-menu"]')).toBeVisible();
  });

  test('should handle mobile keyboard properly', async ({ page }) => {
    await page.goto('/');
    
    const chatInput = page.locator('[data-testid="mobile-chat-input"]');
    
    // Focus input to trigger mobile keyboard
    await chatInput.tap();
    
    // Verify keyboard appears (simulated)
    await expect(chatInput).toBeFocused();
    
    // Test typing with mobile keyboard
    await page.keyboard.type('Mobile test message');
    await expect(chatInput).toHaveValue('Mobile test message');
  });

  test('should adapt to orientation changes', async ({ page }) => {
    await page.goto('/');
    
    // Test portrait mode
    await page.setViewportSize({ width: 390, height: 844 });
    await expect(page.locator('[data-testid="mobile-layout"]')).toBeVisible();
    
    // Test landscape mode
    await page.setViewportSize({ width: 844, height: 390 });
    await expect(page.locator('[data-testid="mobile-landscape-layout"]')).toBeVisible();
    
    // Verify layout adapts properly
    const chatInput = page.locator('[data-testid="mobile-chat-input"]');
    await expect(chatInput).toBeVisible();
  });
});

test.describe('Mobile Model Selection', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15');
  });

  test('should show mobile model selector', async ({ page }) => {
    await page.goto('/');
    
    const modelSelector = page.locator('[data-testid="mobile-model-selector"]');
    await expect(modelSelector).toBeVisible();
    
    // Test model selection on mobile
    await modelSelector.tap();
    await expect(page.locator('[data-testid="model-dropdown"]')).toBeVisible();
    
    // Select a model
    await page.locator('[data-testid="model-gpt-4"]').tap();
    await expect(modelSelector).toContainText('GPT-4');
  });

  test('should handle model switching on mobile', async ({ page }) => {
    await page.goto('/');
    
    const modelSelector = page.locator('[data-testid="mobile-model-selector"]');
    
    // Switch models multiple times
    await modelSelector.tap();
    await page.locator('[data-testid="model-gpt-3.5-turbo"]').tap();
    
    await modelSelector.tap();
    await page.locator('[data-testid="model-claude-3"]').tap();
    
    // Verify final selection
    await expect(modelSelector).toContainText('Claude-3');
  });
});

test.describe('Mobile Performance', () => {
  test('should load quickly on mobile', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('/');
    
    const loadTime = Date.now() - startTime;
    
    // Should load in under 3 seconds on mobile
    expect(loadTime).toBeLessThan(3000);
    
    // Verify critical elements are loaded
    await expect(page.locator('[data-testid="mobile-header"]')).toBeVisible({ timeout: 1000 });
    await expect(page.locator('[data-testid="mobile-chat-input"]')).toBeVisible({ timeout: 1000 });
  });

  test('should handle memory efficiently on mobile', async ({ page }) => {
    await page.goto('/');
    
    // Simulate heavy usage
    for (let i = 0; i < 10; i++) {
      await page.fill('[data-testid="mobile-chat-input"]', `Test message ${i}`);
      await page.tap('[data-testid="mobile-send-button"]');
      await page.waitForTimeout(100);
    }
    
    // Check that app is still responsive
    await expect(page.locator('[data-testid="mobile-chat-input"]')).toBeVisible();
    await expect(page.locator('[data-testid="mobile-send-button"]')).toBeEnabled();
  });
});