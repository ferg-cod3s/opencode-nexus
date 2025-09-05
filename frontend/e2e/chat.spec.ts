import { test, expect } from '@playwright/test';

// Helper function to complete onboarding flow
async function completeOnboarding(page: any) {
  // Navigate to onboarding if not already there
  await page.goto('/onboarding');
  await page.waitForLoadState('networkidle');

  // Click "Get Started"
  await page.click('[data-action="next"]');

  // Wait for requirements check and continue
  await page.waitForSelector('[data-action="check-requirements"]:not([disabled])');
  await page.click('[data-action="check-requirements"]');
  await page.click('[data-action="next"]');

  // Configure server setup
  await page.check('#auto-download');
  await page.click('[data-action="setup-server"]');

  // Complete security setup
  await page.fill('#username', 'testuser');
  await page.fill('#password', 'TestPass123!');
  await page.fill('#confirm-password', 'TestPass123!');
  await page.click('[data-action="complete"]');

  // Wait for redirect to dashboard
  await page.waitForURL('/dashboard');
}

test.describe('Chat Interface', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to main chat interface
    await page.goto('/');

    // Wait for page to load and handle potential redirect to onboarding
    await page.waitForLoadState('networkidle');

    // If redirected to onboarding, complete it first
    if (page.url().includes('/onboarding')) {
      await completeOnboarding(page);
      await page.goto('/');
      await page.waitForLoadState('networkidle');
    }

    // Wait for the start button to be enabled (app initialization)
    await page.waitForSelector('#start-chat-btn:not([disabled])', { timeout: 10000 });
  });

  test('should display welcome screen initially', async ({ page }) => {
    // Verify welcome screen is shown
    await expect(page.locator('#welcome-screen')).toBeVisible();
    await expect(page.locator('.welcome-title')).toContainText('Welcome to OpenCode Nexus');
    await expect(page.locator('#start-chat-btn')).toBeVisible();
    await expect(page.locator('#start-chat-btn')).not.toBeDisabled();
  });

  test('should create new chat session', async ({ page }) => {
    // Click start chat button
    await page.click('#start-chat-btn');

    // Welcome screen should disappear
    await expect(page.locator('#welcome-screen')).not.toBeVisible();

    // Chat interface should appear
    await expect(page.locator('.chat-interface')).toBeVisible();

    // Should have a session in the sidebar
    await expect(page.locator('.session-card')).toHaveCount(1);
  });

  test('should send and display messages', async ({ page }) => {
    // Create a new session first
    await page.click('#start-chat-btn');

    // Wait for chat interface to load
    await expect(page.locator('.chat-interface')).toBeVisible();

    // Type a message
    await page.fill('.message-input textarea', 'Hello, can you help me with coding?');

    // Click send button
    await page.click('button[data-action="send"]');

    // Message should appear in chat
    await expect(page.locator('.message-bubble.user')).toContainText('Hello, can you help me with coding?');

    // Should show typing indicator for AI response
    await expect(page.locator('.typing-dots')).toBeVisible();
  });

  test('should handle message input validation', async ({ page }) => {
    // Create a new session
    await page.click('#start-chat-btn');

    // Try to send empty message
    await page.click('button[data-action="send"]');

    // Should not send empty message
    await expect(page.locator('.message-bubble')).toHaveCount(0);

    // Type message with only whitespace
    await page.fill('.message-input textarea', '   ');
    await page.click('button[data-action="send"]');

    // Should not send whitespace-only message
    await expect(page.locator('.message-bubble')).toHaveCount(0);
  });

  test('should support keyboard shortcuts', async ({ page }) => {
    // Create a new session
    await page.click('#start-chat-btn');

    // Type message
    await page.fill('.message-input textarea', 'Test message');

    // Press Ctrl+Enter to send
    await page.keyboard.press('Control+Enter');

    // Message should be sent
    await expect(page.locator('.message-bubble.user')).toContainText('Test message');
  });

  test('should display message timestamps', async ({ page }) => {
    // Create session and send message
    await page.click('.start-btn');
    await page.fill('.message-input textarea', 'Test message');
    await page.click('button[data-action="send"]');

    // Should display timestamp
    await expect(page.locator('.message-time')).toBeVisible();
  });

  test('should handle message formatting', async ({ page }) => {
    // Create session
    await page.click('.start-btn');

    // Send message with markdown
    await page.fill('.message-input textarea', 'Here is some `inline code` and a code block:\n\n```javascript\nconsole.log("Hello World");\n```');
    await page.click('button[data-action="send"]');

    // Should render formatted content
    await expect(page.locator('.inline-code')).toContainText('inline code');
    await expect(page.locator('.code-block')).toContainText('console.log("Hello World");');
  });

  test('should maintain message history', async ({ page }) => {
    // Create session and send multiple messages
    await page.click('.start-btn');

    const messages = ['First message', 'Second message', 'Third message'];

    for (const message of messages) {
      await page.fill('.message-input textarea', message);
      await page.click('button[data-action="send"]');
      await expect(page.locator('.message-bubble.user').last()).toContainText(message);
    }

    // Should display all messages
    await expect(page.locator('.message-bubble.user')).toHaveCount(3);
  });

  test('should handle long messages gracefully', async ({ page }) => {
    // Create session
    await page.click('#start-chat-btn');

    // Send a very long message
    const longMessage = 'A'.repeat(1000);
    await page.fill('.message-input textarea', longMessage);
    await page.click('button[data-action="send"]');

    // Should handle long message without breaking layout
    await expect(page.locator('.message-bubble.user')).toContainText(longMessage.substring(0, 100));
  });

  test('should auto-scroll to new messages', async ({ page }) => {
    // Create session
    await page.click('#start-chat-btn');

    // Send multiple messages to create scroll
    for (let i = 1; i <= 10; i++) {
      await page.fill('.message-input textarea', `Message ${i}`);
      await page.click('button[data-action="send"]');
      await expect(page.locator('.message-bubble.user').last()).toContainText(`Message ${i}`);
    }

    // Messages container should be scrolled to bottom
    const scrollTop = await page.evaluate(() => {
      const container = document.querySelector('.messages-container') as HTMLElement;
      return container.scrollTop;
    });

    const scrollHeight = await page.evaluate(() => {
      const container = document.querySelector('.messages-container') as HTMLElement;
      return container.scrollHeight - container.clientHeight;
    });

    // Should be scrolled near the bottom
    expect(scrollTop).toBeGreaterThan(scrollHeight - 100);
  });

  test('should be accessible with screen reader', async ({ page }) => {
    // Create session
    await page.click('.start-btn');

    // Send a message
    await page.fill('.message-input textarea', 'Test message');
    await page.click('button[data-action="send"]');

    // Check ARIA attributes
    await expect(page.locator('[role="log"]')).toBeVisible();
    await expect(page.locator('[aria-live="polite"]')).toBeVisible();
    await expect(page.locator('[aria-label="Chat messages"]')).toBeVisible();
  });
});