import { Page, expect } from '@playwright/test';

export class ChatHelper {
  constructor(private page: Page) {}

  async loginAndStartServer() {
    // Quick setup for tests - login and ensure server is running
    await this.page.goto('/login');
    await this.page.fill('[data-testid="username-input"]', 'testuser');
    await this.page.fill('[data-testid="password-input"]', 'SecurePass123!');
    await this.page.click('[data-testid="login-button"]');
    
    // Wait for dashboard
    await expect(this.page).toHaveURL('/dashboard');
    
    // Start server if not running
    const serverStatus = await this.page.textContent('[data-testid="server-status"]');
    if (serverStatus?.includes('Stopped')) {
      await this.page.click('[data-testid="start-server-button"]');
      await this.waitForServerRunning();
    }
  }

  async navigateToChat() {
    await this.page.click('[data-testid="chat-tab"]');
    await expect(this.page.locator('[data-testid="chat-interface"]')).toBeVisible();
  }

  async sendMessage(message: string) {
    await this.page.fill('[data-testid="message-input"]', message);
    await this.page.click('[data-testid="send-button"]');
    
    // Verify message appears in chat
    await expect(this.page.locator('[data-testid="user-message"]').last()).toContainText(message);
  }

  async sendMessageWithKeyboard(message: string) {
    await this.page.fill('[data-testid="message-input"]', message);
    await this.page.keyboard.press('Control+Enter');
    
    // Verify message appears in chat
    await expect(this.page.locator('[data-testid="user-message"]').last()).toContainText(message);
  }

  async waitForStreamingResponse() {
    // Wait for typing indicator
    await expect(this.page.locator('[data-testid="typing-indicator"]')).toBeVisible();
    
    // Wait for AI response to start streaming
    await expect(this.page.locator('[data-testid="ai-message"]').last()).toBeVisible();
    
    // Wait for streaming to complete (typing indicator disappears)
    await expect(this.page.locator('[data-testid="typing-indicator"]')).not.toBeVisible({ timeout: 10000 });
  }

  async waitForResponse() {
    // Simplified version without streaming details
    await expect(this.page.locator('[data-testid="ai-message"]').last()).toBeVisible({ timeout: 5000 });
  }

  async waitForFirstResponseToken() {
    // For performance testing - wait for first character of response
    await expect(this.page.locator('[data-testid="ai-message"]').last()).not.toBeEmpty({ timeout: 3000 });
  }

  async createNewSession() {
    await this.page.click('[data-testid="new-session-button"]');
    
    // Verify new empty chat
    await expect(this.page.locator('[data-testid="chat-messages"]')).toBeEmpty();
    
    // Verify new session appears in session list
    const sessions = this.page.locator('[data-testid="chat-session"]');
    const sessionCount = await sessions.count();
    expect(sessionCount).toBeGreaterThan(1);
  }

  async switchToSession(sessionIndex: number) {
    const sessions = this.page.locator('[data-testid="chat-session"]');
    await sessions.nth(sessionIndex).click();
    
    // Wait for session to load
    await this.page.waitForLoadState('networkidle');
  }

  async uploadFile(filePath: string) {
    // Set up file chooser
    const fileChooser = await this.page.waitForEvent('filechooser', {
      timeout: 5000
    });
    fileChooser.setFiles(filePath);
    
    // Trigger file upload
    await this.page.click('[data-testid="upload-file-button"]');
    
    // Verify file appears in context
    await expect(this.page.locator('[data-testid="file-context"]')).toBeVisible();
  }

  async waitForServerRunning() {
    await expect(this.page.locator('[data-testid="server-status"]')).toContainText('Running', { timeout: 15000 });
  }

  async verifyAccessibilityFeatures() {
    // Check ARIA labels and screen reader support
    await expect(this.page.locator('[data-testid="message-input"]')).toHaveAttribute('aria-label');
    await expect(this.page.locator('[data-testid="send-button"]')).toHaveAttribute('aria-label');
    
    // Check keyboard navigation
    await this.page.keyboard.press('Tab');
    await expect(this.page.locator('[data-testid="message-input"]')).toBeFocused();
  }

  async verifyErrorHandling() {
    // Test chat when server is offline
    const errorMessage = this.page.locator('[data-testid="connection-error"]');
    if (await errorMessage.isVisible()) {
      await expect(errorMessage).toContainText('Unable to connect to server');
      await expect(this.page.locator('[data-testid="retry-button"]')).toBeVisible();
    }
  }

  async getMessageCount(): Promise<number> {
    const messages = this.page.locator('[data-testid="chat-message"]');
    return await messages.count();
  }

  async getSessionCount(): Promise<number> {
    const sessions = this.page.locator('[data-testid="chat-session"]');
    return await sessions.count();
  }

  async clearChatHistory() {
    await this.page.click('[data-testid="chat-settings-button"]');
    await this.page.click('[data-testid="clear-history-button"]');
    await this.page.click('[data-testid="confirm-clear-button"]');
    
    // Verify chat is cleared
    await expect(this.page.locator('[data-testid="chat-messages"]')).toBeEmpty();
  }
}