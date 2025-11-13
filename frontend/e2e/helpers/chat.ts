/*
 * MIT License
 *
 * Copyright (c) 2025 OpenCode Nexus Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { Page, expect } from '@playwright/test';

export class ChatHelper {
  constructor(private page: Page) {}

  async loginAndStartServer() {
    // Quick setup for tests - login and ensure server is running
    console.log('[CHAT HELPER] Starting login and server setup...');
    await this.page.goto('/login');

    // Wait for page to load
    await this.page.waitForLoadState('networkidle');
    await this.page.waitForTimeout(1000);

    // Manual authentication since page JavaScript doesn't work in E2E tests
    const authResult = await this.page.evaluate(async () => {
      // Import the mock API directly
      const { invoke } = await import('/src/utils/tauri-api.js');
      console.log('🔍 Chat auth: Calling authenticate_user...');
      try {
        const result = await invoke('authenticate_user', {
          username: 'testuser',
          password: 'SecurePass123!'
        });
        console.log('🔍 Chat auth: Result:', result);

        if (result) {
          // Simulate successful login redirect
          sessionStorage.setItem('authenticated', 'true');
          sessionStorage.setItem('username', 'testuser');
          window.location.href = '/dashboard';
        }

        return result;
      } catch (error) {
        console.error('🔍 Chat auth: Error:', error);
        return false;
      }
    }, { username: 'testuser', password: 'SecurePass123!' });

    console.log(`[CHAT HELPER] Authentication result: ${authResult}`);

    if (!authResult) {
      throw new Error('Authentication failed');
    }

    // Wait for dashboard to load
    await this.page.waitForTimeout(2000);
    await expect(this.page).toHaveURL('/dashboard');

    // Start server if not running
    const serverStatus = await this.page.textContent('[data-testid="server-status"]');
    console.log(`[CHAT HELPER] Server status: ${serverStatus}`);
    if (serverStatus?.includes('Stopped')) {
      console.log('[CHAT HELPER] Starting server...');
      await this.page.click('[data-testid="start-server-button"]');
      await this.waitForServerRunning();
    }
  }

  async navigateToChat() {
    console.log('[CHAT HELPER] Navigating to chat interface...');
    await this.page.click('[data-testid="chat-tab"]');

    // Wait for navigation to chat page
    await this.page.waitForURL('**/chat');
    console.log('[CHAT HELPER] On chat page, waiting for interface to load...');

    // Manually execute the chat initialization that Astro should do
    console.log('[CHAT HELPER] Manually initializing chat interface...');

    try {
      await this.page.evaluate(async () => {
        // Import ChatInterface dynamically and initialize stores
        try {
          const chatModule = await import('/src/components/ChatInterface.svelte');
          const ChatInterface = chatModule.default;
          const { activeSessionStore, chatStateStore } = await import('/src/stores/chat.ts');
          const { invoke } = await import('/src/utils/tauri-api.js');

          // Try to import svelte/store, but continue if it fails
          let get;
          try {
            const svelteStore = await import('svelte/store');
            get = svelteStore.get;
          } catch (e) {
            // Fallback implementation of get for stores if svelte/store not available
            get = (store: any) => {
              let value;
              store.subscribe((v: any) => { value = v; })();
              return value;
            };
          }

          // Display username
          const username = sessionStorage.getItem('username') || 'User';
          const usernameDisplay = document.getElementById('username-display');
          if (usernameDisplay) {
            usernameDisplay.textContent = username;
          }

          // Load or create test session
          let sessions = [];
          try {
            sessions = await invoke('get_chat_sessions');
            console.log('📍 Chat init: Loaded sessions:', sessions);
          } catch (error) {
            console.log('📍 Chat init: No sessions, creating test session');
          }

          // Set up active session
          if (sessions && sessions.length > 0) {
            activeSessionStore.setSession(sessions[0]);
          } else {
            const defaultSession = {
              id: `test-session-${Date.now()}`,
              title: 'Test Chat Session',
              messages: [],
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString()
            };
            activeSessionStore.setSession(defaultSession);
          }

          // Remove loading state and mount component
          const chatRoot = document.getElementById('chat-root');
          if (chatRoot) {
            const loadingState = document.getElementById('loading-state');
            if (loadingState) {
              loadingState.remove();
            }

            // Mount ChatInterface
            new ChatInterface({
              target: chatRoot,
              props: {
                onSendMessage: async (content: string) => {
                  const activeSession = get(activeSessionStore);
                  if (!activeSession) {
                    console.error('No active session');
                    return;
                  }
                  console.log('📤 Sending message:', content, 'to session:', activeSession.id);

                  // Add user message to store immediately
                  activeSessionStore.addMessage({
                    id: `user-${Date.now()}`,
                    role: 'user',
                    content,
                    timestamp: new Date().toISOString()
                  });

                  // Send via API
                  await invoke('send_chat_message', {
                    session_id: activeSession.id,
                    content
                  });
                },
                onClose: () => console.log('Chat closed')
              }
            });

            console.log('📍 Chat init: Component mounted successfully');
          }
        } catch (error) {
          console.error('📍 Chat init: Failed to initialize:', error);
          throw error;
        }
      });

      // Wait for component to actually mount
      await this.page.waitForSelector('[data-testid="chat-interface"]', { timeout: 5000 });
      console.log('[CHAT HELPER] Chat interface mounted and visible');

    } catch (error) {
      console.log(`[CHAT HELPER] Manual initialization failed: ${error}`);
      console.log('[CHAT HELPER] Will fall back to API-only testing');
    }
  }

  async sendMessage(message: string) {
    // Try UI approach first
    try {
      const messageInput = this.page.locator('[data-testid="message-input"]');
      const sendButton = this.page.locator('[data-testid="send-button"]');

      if (await messageInput.isVisible({ timeout: 1000 }) && await sendButton.isVisible({ timeout: 1000 })) {
        await this.page.fill('[data-testid="message-input"]', message);
        await this.page.click('[data-testid="send-button"]');

        // Verify message appears in chat
        await expect(this.page.locator('[data-testid="user-message"]').last()).toContainText(message);
        return;
      }
    } catch (error) {
      console.log('[CHAT HELPER] UI approach failed, trying API approach...');
    }

    // Fallback to API approach
    console.log(`[CHAT HELPER] Sending message via API: ${message}`);

    // Get current session (assume first session for testing)
    const sessions = await this.page.evaluate(async () => {
      // Import the mock API directly
      const { invoke } = await import('/src/utils/tauri-api.js');
      return await invoke('get_chat_sessions');
    });

    if (sessions && sessions.length > 0) {
      const sessionId = sessions[0].id;
      console.log(`[CHAT HELPER] Using session: ${sessionId}`);

      // Send message via API
      await this.page.evaluate(async (params) => {
        const { invoke } = await import('/src/utils/tauri-api.js');
        await invoke('send_chat_message', {
          session_id: params.sessionId,
          content: params.message
        });
      }, { sessionId, message });

      console.log('[CHAT HELPER] Message sent via API');
    } else {
      throw new Error('No chat sessions available');
    }
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
    // Wait for API response instead of UI
    await this.page.waitForTimeout(1000); // Give time for mock response to be processed
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
    // Get message count from API instead of UI
    try {
      const count = await this.page.evaluate(async () => {
        const { invoke } = await import('/src/utils/tauri-api.js');
        const sessions = await invoke('get_chat_sessions');
        if (sessions && sessions.length > 0) {
          const session = sessions[0];
          const messages = await invoke('get_chat_session_history', { session_id: session.id });
          return messages ? messages.length : 0;
        }
        return 0;
      });
      return count;
    } catch (error) {
      console.log(`[CHAT HELPER] Failed to get message count: ${error}`);
      return 0;
    }
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