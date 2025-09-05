import { test, expect } from '@playwright/test';
import { ChatHelper } from './helpers/chat';

test.describe('Chat Interface', () => {
  let chat: ChatHelper;

  test.beforeEach(async ({ page }) => {
    chat = new ChatHelper(page);
  });

  test.describe('Core Chat Functionality', () => {
    test('send message and receive streaming response', async ({ page }) => {
      test.setTimeout(15000); // Allow time for server startup and AI response
      
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send a coding-related message to OpenCode AI
      const message = 'Write a Python function to calculate factorial';
      await chat.sendMessage(message);
      
      // Verify message appears immediately
      await expect(page.locator('[data-testid="user-message"]').last()).toContainText(message);
      
      // Verify streaming response appears
      await chat.waitForStreamingResponse();
      
      // Verify AI response contains expected content
      const aiResponse = page.locator('[data-testid="ai-message"]').last();
      await expect(aiResponse).toBeVisible();
      await expect(aiResponse).toContainText('def');
      await expect(aiResponse).toContainText('factorial');
      
      // Verify streaming is complete (no typing indicator)
      await expect(page.locator('[data-testid="typing-indicator"]')).not.toBeVisible();
    });

    test('keyboard shortcuts work correctly', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Test Ctrl+Enter to send message
      const message = 'Testing keyboard shortcut';
      await chat.sendMessageWithKeyboard(message);
      
      // Verify message was sent
      await expect(page.locator('[data-testid="user-message"]').last()).toContainText(message);
      
      // Test Escape to clear input
      await page.fill('[data-testid="message-input"]', 'This should be cleared');
      await page.keyboard.press('Escape');
      
      // Verify input is cleared
      await expect(page.locator('[data-testid="message-input"]')).toHaveValue('');
    });

    test('message history persists across sessions', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send multiple messages
      await chat.sendMessage('First message');
      await chat.waitForResponse();
      await chat.sendMessage('Second message');
      await chat.waitForResponse();
      
      const initialMessageCount = await chat.getMessageCount();
      expect(initialMessageCount).toBe(4); // 2 user + 2 AI messages
      
      // Reload page to test persistence
      await page.reload();
      await chat.navigateToChat();
      
      // Verify messages persist
      const persistedMessageCount = await chat.getMessageCount();
      expect(persistedMessageCount).toBe(initialMessageCount);
      
      // Verify specific message content persists
      await expect(page.locator('[data-testid="user-message"]').first()).toContainText('First message');
      await expect(page.locator('[data-testid="user-message"]').last()).toContainText('Second message');
    });

    test('chat interface is accessible (WCAG 2.2 AA)', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      await chat.verifyAccessibilityFeatures();
      
      // Test screen reader announcements for new messages
      await chat.sendMessage('Accessibility test message');
      
      // Verify ARIA live region updates for streaming
      const liveRegion = page.locator('[aria-live="polite"]');
      await expect(liveRegion).toBeVisible();
      
      // Test keyboard navigation through message history
      await page.keyboard.press('Tab');
      await page.keyboard.press('ArrowUp'); // Should navigate to previous message
      
      // Verify focus management
      const focusedElement = page.locator(':focus');
      await expect(focusedElement).toBeVisible();
    });
  });

  test.describe('Session Management', () => {
    test('create and switch between multiple chat sessions', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send message in first session
      await chat.sendMessage('Message in session 1');
      await chat.waitForResponse();
      
      // Create new session
      await chat.createNewSession();
      
      // Send message in second session
      await chat.sendMessage('Message in session 2');
      await chat.waitForResponse();
      
      // Verify we have 2 sessions
      const sessionCount = await chat.getSessionCount();
      expect(sessionCount).toBe(2);
      
      // Switch back to first session
      await chat.switchToSession(0);
      
      // Verify we see the first session's messages
      await expect(page.locator('[data-testid="user-message"]').last()).toContainText('Message in session 1');
      
      // Switch to second session
      await chat.switchToSession(1);
      
      // Verify we see the second session's messages
      await expect(page.locator('[data-testid="user-message"]').last()).toContainText('Message in session 2');
    });

    test('session titles update based on conversation content', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send message that should influence session title
      await chat.sendMessage('Help me create a React component for a todo list');
      await chat.waitForResponse();
      
      // Session title should update (may take a moment)
      await page.waitForTimeout(2000);
      
      const sessionTitle = page.locator('[data-testid="current-session-title"]');
      const titleText = await sessionTitle.textContent();
      
      // Title should be related to the conversation content
      expect(titleText?.toLowerCase()).toMatch(/react|todo|component/);
    });

    test('delete session removes it from session list', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Create multiple sessions
      await chat.sendMessage('First session message');
      await chat.waitForResponse();
      
      await chat.createNewSession();
      await chat.sendMessage('Second session message');
      await chat.waitForResponse();
      
      const initialSessionCount = await chat.getSessionCount();
      expect(initialSessionCount).toBe(2);
      
      // Delete current session
      await page.click('[data-testid="session-menu-button"]');
      await page.click('[data-testid="delete-session-button"]');
      await page.click('[data-testid="confirm-delete-button"]');
      
      // Verify session count decreased
      const finalSessionCount = await chat.getSessionCount();
      expect(finalSessionCount).toBe(1);
      
      // Should switch to remaining session
      await expect(page.locator('[data-testid="user-message"]').last()).toContainText('First session message');
    });
  });

  test.describe('File Context Sharing', () => {
    test.skip('upload and share file context with AI', async ({ page }) => {
      // Skip this test if file upload isn't implemented yet
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Create a test file
      const testFilePath = './test-fixtures/sample-code.py';
      
      // Upload file
      await chat.uploadFile(testFilePath);
      
      // Verify file appears in context
      await expect(page.locator('[data-testid="file-context"]')).toContainText('sample-code.py');
      
      // Send message referencing the file
      await chat.sendMessage('Explain this code and suggest improvements');
      await chat.waitForResponse();
      
      // AI response should reference the uploaded file
      const aiResponse = page.locator('[data-testid="ai-message"]').last();
      await expect(aiResponse).toContainText('sample-code.py');
    });

    test.skip('remove file from context', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Upload a file first
      await chat.uploadFile('./test-fixtures/sample-code.py');
      
      // Remove file from context
      await page.click('[data-testid="remove-file-button"]');
      
      // Verify file is removed
      await expect(page.locator('[data-testid="file-context"]')).not.toBeVisible();
    });
  });

  test.describe('Error Handling', () => {
    test('handles server disconnection gracefully', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send initial message to ensure chat is working
      await chat.sendMessage('Initial test message');
      await chat.waitForResponse();
      
      // Simulate server going offline
      await page.route('**/chat', route => route.abort());
      
      // Try to send message while offline
      await chat.sendMessage('Message during offline period');
      
      // Should show connection error
      await expect(page.locator('[data-testid="connection-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="retry-button"]')).toBeVisible();
      
      // Message should be queued
      await expect(page.locator('[data-testid="message-queued"]')).toBeVisible();
    });

    test('retry mechanism works after connection restored', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Simulate temporary network failure
      let requestCount = 0;
      await page.route('**/chat', route => {
        requestCount++;
        if (requestCount <= 2) {
          // Fail first 2 requests
          route.abort();
        } else {
          // Allow subsequent requests
          route.continue();
        }
      });
      
      // Send message (should initially fail, then retry and succeed)
      await chat.sendMessage('Test retry mechanism');
      
      // Should eventually succeed after retries
      await chat.waitForResponse();
      
      // Verify message appeared in chat
      await expect(page.locator('[data-testid="user-message"]').last()).toContainText('Test retry mechanism');
    });

    test('handles extremely long messages appropriately', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Create a very long message
      const longMessage = 'This is a very long message. '.repeat(1000);
      
      await page.fill('[data-testid="message-input"]', longMessage);
      
      // Should show character count warning
      await expect(page.locator('[data-testid="message-length-warning"]')).toBeVisible();
      
      // Send button might be disabled or show warning
      const sendButton = page.locator('[data-testid="send-button"]');
      const isDisabled = await sendButton.isDisabled();
      
      if (!isDisabled) {
        await sendButton.click();
        // Should handle gracefully (truncate or show error)
        const errorOrWarning = page.locator('[data-testid="message-error"], [data-testid="message-truncated"]');
        await expect(errorOrWarning).toBeVisible();
      }
    });
  });

  test.describe('Performance', () => {
    test('chat response time is under 2 seconds for simple queries', async ({ page }) => {
      test.setTimeout(10000);
      
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      const startTime = Date.now();
      await chat.sendMessage('What is 2 + 2?');
      
      // Wait for first token of response
      await chat.waitForFirstResponseToken();
      
      const responseTime = Date.now() - startTime;
      
      expect(responseTime).toBeLessThan(2000);
    });

    test('chat interface remains responsive during message streaming', async ({ page }) => {
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send message that will generate long response
      await chat.sendMessage('Write a detailed explanation of React hooks with code examples');
      
      // While response is streaming, interface should remain responsive
      await expect(page.locator('[data-testid="typing-indicator"]')).toBeVisible();
      
      // Should be able to interact with UI during streaming
      await page.click('[data-testid="new-session-button"]');
      await expect(page.locator('[data-testid="chat-messages"]')).toBeEmpty();
      
      // Can navigate back to original session
      await chat.switchToSession(0);
      
      // Streaming should still be happening or complete
      const messages = page.locator('[data-testid="chat-message"]');
      const messageCount = await messages.count();
      expect(messageCount).toBeGreaterThanOrEqual(1);
    });
  });
});