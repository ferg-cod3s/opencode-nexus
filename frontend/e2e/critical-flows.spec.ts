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

/**
 * @deprecated These tests are for the OLD architecture (server management).
 * After the client pivot, these flows no longer apply.
 * Tests need to be rewritten for connection-based architecture.
 */

import { test, expect } from '@playwright/test';
import { ChatHelper } from './helpers/chat';
import { ServerHelper } from './helpers/server-management';

// Skip all tests in this file - they test deprecated server management flows
test.describe.skip('Critical End-to-End User Flows (DEPRECATED - Server Management)', () => {
  test.describe('First-Time User Journey', () => {
    test('complete first-time user experience: onboarding → chat', async ({ page }) => {
      test.setTimeout(120000); // 2 minutes for complete flow

      // const auth = new AuthHelper(page); // Removed - deprecated
      const server = new ServerHelper(page);
      const chat = new ChatHelper(page);
      
      // 1. Initial navigation to app
      await page.goto('/');
      
      // Should redirect to onboarding for new user
      await expect(page).toHaveURL(/onboarding/);
      
      // 2. Complete 6-step onboarding process
      await test.step('Complete onboarding wizard', async () => {
        // Step 1: Welcome
        await expect(page.locator('[data-testid="onboarding-step-1"]')).toBeVisible();
        await page.click('[data-testid="next-button"]');
        
        // Step 2: System Requirements
        await expect(page.locator('[data-testid="onboarding-step-2"]')).toBeVisible();
        await page.waitForTimeout(3000); // Allow system scan
        await expect(page.locator('[data-testid="requirements-complete"]')).toBeVisible();
        await page.click('[data-testid="next-button"]');
        
        // Step 3: Dependencies
        await expect(page.locator('[data-testid="onboarding-step-3"]')).toBeVisible();
        await page.click('[data-testid="next-button"]');
        
        // Step 4: Server Configuration
        await expect(page.locator('[data-testid="onboarding-step-4"]')).toBeVisible();
        await page.fill('[data-testid="server-port-input"]', '3000');
        await page.fill('[data-testid="workspace-dir-input"]', './workspace');
        await page.click('[data-testid="next-button"]');
        
        // Step 5: Account Creation
        await expect(page.locator('[data-testid="onboarding-step-5"]')).toBeVisible();
        const timestamp = Date.now();
        await page.fill('[data-testid="username-input"]', `newuser${timestamp}`);
        await page.fill('[data-testid="password-input"]', 'SecurePass123!');
        await page.fill('[data-testid="confirm-password-input"]', 'SecurePass123!');
        await page.click('[data-testid="create-account-button"]');
        
        // Step 6: Completion
        await expect(page.locator('[data-testid="onboarding-step-6"]')).toBeVisible();
        await page.click('[data-testid="finish-onboarding-button"]');
      });
      
      // 3. Should be redirected to dashboard and logged in
      await test.step('Access dashboard', async () => {
        await expect(page).toHaveURL('/dashboard');
        await expect(page.locator('[data-testid="welcome-message"]')).toBeVisible();
        await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
      });
      
      // 4. Start OpenCode server
      await test.step('Start OpenCode server', async () => {
        // Server should initially be stopped
        await expect(page.locator('[data-testid="server-status"]')).toContainText('Stopped');
        
        // Start server
        await page.click('[data-testid="start-server-button"]');
        await server.waitForServerRunning();
        
        // Verify server is running
        await expect(page.locator('[data-testid="server-status"]')).toContainText('Running');
      });
      
      // 5. Navigate to chat and have first AI conversation
      await test.step('First AI conversation', async () => {
        await chat.navigateToChat();
        
        // Send welcome message
        const welcomeMessage = 'Hello! I just set up OpenCode. Can you help me get started with coding?';
        await chat.sendMessage(welcomeMessage);
        
        // Wait for AI response
        await chat.waitForStreamingResponse();
        
        // Verify conversation is working
        await expect(page.locator('[data-testid="user-message"]')).toContainText(welcomeMessage);
        await expect(page.locator('[data-testid="ai-message"]')).toBeVisible();
        
        // Send follow-up question
        await chat.sendMessage('What programming languages do you support?');
        await chat.waitForResponse();
        
        // Should have a complete conversation
        const messageCount = await chat.getMessageCount();
        expect(messageCount).toBe(4); // 2 user + 2 AI messages
      });
      
      // 6. Verify complete setup is functional
      await test.step('Verify complete functionality', async () => {
        // Dashboard should show active server
        await server.navigateToDashboard();
        await expect(page.locator('[data-testid="server-status"]')).toContainText('Running');
        
        // Chat should be accessible
        await chat.navigateToChat();
        await expect(page.locator('[data-testid="chat-interface"]')).toBeVisible();
        
        // User should be able to create new sessions
        await chat.createNewSession();
        const sessionCount = await chat.getSessionCount();
        expect(sessionCount).toBe(2);
      });
    });

    test('onboarding handles system requirement failures', async ({ page }) => {
      test.setTimeout(60000);
      
      await page.goto('/onboarding');
      
      // Navigate to system requirements step
      await page.click('[data-testid="next-button"]'); // Skip welcome
      
      // Mock system requirements failure
      await page.route('**/system/requirements', route => {
        route.fulfill({
          status: 200,
          json: {
            requirements: {
              nodejs: { available: false, version: null, required: '18+' },
              git: { available: false, version: null, required: '2.0+' },
              disk: { available: true, space: '10GB', required: '2GB' },
              memory: { available: false, amount: '2GB', required: '4GB' }
            }
          }
        });
      });
      
      await page.waitForTimeout(3000); // Allow system scan
      
      // Should show requirement failures
      await expect(page.locator('[data-testid="requirement-failed"]')).toBeVisible();
      await expect(page.locator('[data-testid="nodejs-missing"]')).toBeVisible();
      await expect(page.locator('[data-testid="memory-insufficient"]')).toBeVisible();
      
      // Should show installation instructions
      await expect(page.locator('[data-testid="installation-help"]')).toBeVisible();
      
      // Next button should be disabled until requirements are met
      await expect(page.locator('[data-testid="next-button"]')).toBeDisabled();
    });
  });

  test.describe('Returning User Workflows', () => {
    test('returning user quick access flow', async ({ page }) => {
      test.setTimeout(45000);

      // const auth = new AuthHelper(page); // Removed - deprecated
      const server = new ServerHelper(page);
      const chat = new ChatHelper(page);
      
      // Simulate existing user setup
      await test.step('Setup existing user state', async () => {
        // Login as existing user
        // await auth.loginAsTestUser(); // Removed - deprecated
        await expect(page).toHaveURL('/dashboard');
      });
      
      // Quick server startup
      await test.step('Quick server startup', async () => {
        // Start server (should use saved configuration)
        await server.startServer();
        await server.waitForServerRunning();
        
        // Should be faster than first-time setup
        const startTime = Date.now();
        await server.waitForServerRunning();
        const startupTime = Date.now() - startTime;
        expect(startupTime).toBeLessThan(8000); // Should be under 8 seconds
      });
      
      // Resume existing chat sessions
      await test.step('Resume existing chat sessions', async () => {
        await chat.navigateToChat();
        
        // Should show existing sessions in sidebar
        const sessions = page.locator('[data-testid="chat-session"]');
        const sessionCount = await sessions.count();
        
        if (sessionCount > 0) {
          // Click on most recent session
          await sessions.first().click();
          
          // Should load existing messages
          const messageCount = await chat.getMessageCount();
          expect(messageCount).toBeGreaterThan(0);
        }
        
        // Should be able to continue conversation immediately
        await chat.sendMessage('I\'m back! Can we continue where we left off?');
        await chat.waitForResponse();
        
        // Response should be contextual if session has history
        const aiResponse = page.locator('[data-testid="ai-message"]').last();
        await expect(aiResponse).toBeVisible();
      });
      
      // Verify saved preferences are applied
      await test.step('Verify user preferences', async () => {
        // Check that server configuration is maintained
        await server.navigateToDashboard();
        const port = await server.getServerPort();
        expect(port).toBeGreaterThan(0);
        
        // Check that user session is maintained
        await expect(page.locator('[data-testid="user-menu"]')).toContainText('testuser');
      });
    });

    test('user can pick up interrupted workflow', async ({ page }) => {
      test.setTimeout(60000);
      
      const chat = new ChatHelper(page);
      
      // Start a conversation
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      await chat.sendMessage('I want to build a React component');
      await chat.waitForResponse();
      
      // Simulate interruption (close and reopen)
      await page.close();
      
      // Reopen and resume
      const newPage = await page.context().newPage();
      const newChat = new ChatHelper(newPage);
      
      // Should automatically login due to persistent session
      await newPage.goto('/dashboard');
      
      // Server might need to be restarted
      const serverHelper = new ServerHelper(newPage);
      await serverHelper.startServer();
      await serverHelper.waitForServerRunning();
      
      // Navigate back to chat
      await newChat.navigateToChat();
      
      // Previous conversation should be there
      const messageCount = await newChat.getMessageCount();
      expect(messageCount).toBeGreaterThanOrEqual(2);
      
      // Should be able to continue the conversation
      await newChat.sendMessage('Let\'s continue with that React component');
      await newChat.waitForResponse();
    });
  });

  test.describe('Server Integration Workflows', () => {
    test('chat → server management → chat continuity', async ({ page }) => {
      test.setTimeout(90000);
      
      const chat = new ChatHelper(page);
      const server = new ServerHelper(page);
      
      // Start with active chat
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Have active conversation
      await chat.sendMessage('I\'m working on a Python project');
      await chat.waitForResponse();
      
      const initialMessageCount = await chat.getMessageCount();
      
      // Navigate to server management
      await test.step('Server management while chat active', async () => {
        await server.navigateToDashboard();
        
        // Should show warning about active chat when stopping server
        await page.click('[data-testid="stop-server-button"]');
        
        if (await page.locator('[data-testid="active-chat-warning"]').isVisible()) {
          await expect(page.locator('[data-testid="active-chat-warning"]')).toContainText('active chat');
          await page.click('[data-testid="confirm-stop-server"]');
        }
        
        await server.waitForServerStopped();
      });
      
      // Return to chat - should show disconnection
      await test.step('Chat handles server disconnection', async () => {
        await chat.navigateToChat();
        
        // Should show server disconnected state
        await expect(page.locator('[data-testid="server-disconnected"]')).toBeVisible();
        
        // Should offer to restart server
        await expect(page.locator('[data-testid="restart-server-button"]')).toBeVisible();
      });
      
      // Restart server from chat interface
      await test.step('Restart server from chat', async () => {
        await page.click('[data-testid="restart-server-button"]');
        await server.waitForServerRunning();
        
        // Chat should reconnect automatically
        await expect(page.locator('[data-testid="server-disconnected"]')).not.toBeVisible();
        await expect(page.locator('[data-testid="message-input"]')).toBeEnabled();
      });
      
      // Verify conversation continuity
      await test.step('Verify conversation continuity', async () => {
        // Previous messages should still be there
        const currentMessageCount = await chat.getMessageCount();
        expect(currentMessageCount).toBe(initialMessageCount);
        
        // Should be able to continue conversation
        await chat.sendMessage('Great, I can continue working now');
        await chat.waitForResponse();
        
        // New messages should be added
        const finalMessageCount = await chat.getMessageCount();
        expect(finalMessageCount).toBe(initialMessageCount + 2);
      });
    });

    test('server configuration changes affect chat connectivity', async ({ page }) => {
      test.setTimeout(75000);
      
      const chat = new ChatHelper(page);
      const server = new ServerHelper(page);
      
      // Start with working chat
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      await chat.sendMessage('Testing server configuration');
      await chat.waitForResponse();
      
      // Change server configuration
      await test.step('Change server port configuration', async () => {
        await server.navigateToDashboard();
        
        // Stop server
        await server.stopServer();
        
        // Change port configuration
        await server.configureServerSettings({ port: 3001 });
        
        // Start server with new configuration
        await server.startServer();
        await server.waitForServerRunning();
        
        // Verify new port is active
        const newPort = await server.getServerPort();
        expect(newPort).toBe(3001);
      });
      
      // Chat should automatically reconnect to new port
      await test.step('Chat reconnects to new server configuration', async () => {
        await chat.navigateToChat();
        
        // Might show brief reconnection message
        const reconnectMessage = page.locator('[data-testid="reconnecting"]');
        if (await reconnectMessage.isVisible()) {
          await expect(reconnectMessage).not.toBeVisible({ timeout: 10000 });
        }
        
        // Should be able to send messages on new port
        await chat.sendMessage('Testing with new server configuration');
        await chat.waitForResponse();
        
        // Both old and new messages should be visible
        await expect(page.locator('[data-testid="user-message"]').first()).toContainText('Testing server configuration');
        await expect(page.locator('[data-testid="user-message"]').last()).toContainText('Testing with new server configuration');
      });
    });
  });

  test.describe('Error Recovery Workflows', () => {
    test('graceful handling of complete system failure and recovery', async ({ page }) => {
      test.setTimeout(120000);

      const chat = new ChatHelper(page);
      const server = new ServerHelper(page);
      // const auth = new AuthHelper(page); // Removed - deprecated
      
      // Establish working system
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      await chat.sendMessage('System is working perfectly');
      await chat.waitForResponse();
      
      // Simulate catastrophic failure
      await test.step('Simulate system failure', async () => {
        // Mock all API endpoints to fail
        await page.route('**/api/**', route => route.abort());
        
        // Try to interact with system
        await chat.sendMessage('This should fail');
        
        // Should show system-wide error state
        await expect(page.locator('[data-testid="system-error"]')).toBeVisible();
      });
      
      // Simulate recovery
      await test.step('System recovery', async () => {
        // Remove API route mocking
        await page.unroute('**/api/**');
        
        // Reload page to reset state
        await page.reload();
        
        // Should prompt for re-authentication if session was lost
        if (await page.locator('[data-testid="login-form"]').isVisible()) {
          // await auth.login('testuser', 'SecurePass123!'); // Removed - deprecated
        }
        
        // Should return to functional state
        await expect(page).toHaveURL('/dashboard');
      });
      
      // Verify full system recovery
      await test.step('Verify complete functionality restored', async () => {
        // Restart server if needed
        const serverStatus = await server.getServerStatus();
        if (serverStatus.toLowerCase().includes('stopped')) {
          await server.startServer();
          await server.waitForServerRunning();
        }
        
        // Chat should work again
        await chat.navigateToChat();
        
        // Previous messages might be lost, but new functionality should work
        await chat.sendMessage('System recovered successfully');
        await chat.waitForResponse();
        
        // Verify we have a working conversation
        const messageCount = await chat.getMessageCount();
        expect(messageCount).toBeGreaterThanOrEqual(2);
      });
    });

    test('handles network interruptions during active chat', async ({ page }) => {
      test.setTimeout(60000);
      
      const chat = new ChatHelper(page);
      
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Start normal conversation
      await chat.sendMessage('Tell me about async programming');
      await chat.waitForStreamingResponse();
      
      // Simulate network failure during response
      await test.step('Network failure during streaming response', async () => {
        await page.context().setOffline(true);
        
        // Send message while offline
        await chat.sendMessage('This message should be queued');
        
        // Should show offline indicator
        await expect(page.locator('[data-testid="offline-indicator"]')).toBeVisible();
        await expect(page.locator('[data-testid="message-queued"]')).toBeVisible();
      });
      
      // Restore connectivity
      await test.step('Network recovery', async () => {
        await page.context().setOffline(false);
        
        // Should automatically reconnect
        await expect(page.locator('[data-testid="offline-indicator"]')).not.toBeVisible({ timeout: 10000 });
        
        // Queued message should be sent
        await chat.waitForResponse();
        
        // Should be able to continue conversation normally
        await chat.sendMessage('Network is back, continuing conversation');
        await chat.waitForResponse();
        
        // All messages should be present
        const messageCount = await chat.getMessageCount();
        expect(messageCount).toBeGreaterThanOrEqual(6); // Original + queued + recovery messages
      });
    });
  });

  test.describe('Performance Integration', () => {
    test('complete user workflow meets performance targets', async ({ page }) => {
      test.setTimeout(180000); // 3 minutes for complete performance test

      const chat = new ChatHelper(page);
      const server = new ServerHelper(page);
      // const auth = new AuthHelper(page); // Removed - deprecated
      
      const performanceMetrics = {
        loginTime: 0,
        serverStartTime: 0,
        chatResponseTime: 0,
        navigationTime: 0
      };
      
      // Time login process
      await test.step('Timed login', async () => {
        const startTime = Date.now();
        // await auth.loginAsTestUser(); // Removed - deprecated
        performanceMetrics.loginTime = Date.now() - startTime;

        expect(performanceMetrics.loginTime).toBeLessThan(3000); // < 3 seconds
      });
      
      // Time server startup
      await test.step('Timed server startup', async () => {
        const startTime = Date.now();
        await server.startServer();
        await server.waitForServerRunning();
        performanceMetrics.serverStartTime = Date.now() - startTime;
        
        expect(performanceMetrics.serverStartTime).toBeLessThan(10000); // < 10 seconds
      });
      
      // Time chat response
      await test.step('Timed chat response', async () => {
        await chat.navigateToChat();
        
        const startTime = Date.now();
        await chat.sendMessage('Quick performance test question');
        await chat.waitForFirstResponseToken();
        performanceMetrics.chatResponseTime = Date.now() - startTime;
        
        expect(performanceMetrics.chatResponseTime).toBeLessThan(2000); // < 2 seconds
      });
      
      // Time navigation between sections
      await test.step('Timed navigation', async () => {
        const startTime = Date.now();
        await server.navigateToDashboard();
        await expect(page.locator('[data-testid="server-dashboard"]')).toBeVisible();
        await chat.navigateToChat();
        await expect(page.locator('[data-testid="chat-interface"]')).toBeVisible();
        performanceMetrics.navigationTime = Date.now() - startTime;
        
        expect(performanceMetrics.navigationTime).toBeLessThan(1000); // < 1 second
      });
      
      // Log performance results
      console.log('Performance Metrics:', performanceMetrics);
      
      // Overall workflow should complete within reasonable time
      const totalTime = Object.values(performanceMetrics).reduce((a, b) => a + b, 0);
      expect(totalTime).toBeLessThan(20000); // Total workflow under 20 seconds
    });
  });
});