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

import { test, expect } from '@playwright/test';
import { ServerHelper } from './helpers/server-management';
import { ChatHelper } from './helpers/chat';

// Skip all server management tests - deprecated in client-only architecture
test.describe.skip('Server Management (DEPRECATED - Client-only architecture)', () => {
  let server: ServerHelper;

  test.beforeEach(async ({ page }) => {
    server = new ServerHelper(page);
  });

  test.describe('Server Lifecycle', () => {
    test('complete server lifecycle: start → running → stop', async ({ page }) => {
      test.setTimeout(30000); // Allow time for server startup
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Initial state: server should be stopped
      const initialStatus = await server.getServerStatus();
      expect(['Stopped', 'Not Running'].some(status => 
        initialStatus.toLowerCase().includes(status.toLowerCase())
      )).toBeTruthy();
      
      // Start server
      await server.startServer();
      
      // Verify server is running
      await server.waitForServerRunning();
      const runningStatus = await server.getServerStatus();
      expect(runningStatus.toLowerCase()).toContain('running');
      
      // Verify server details are displayed
      const port = await server.getServerPort();
      expect(port).toBeGreaterThan(0);
      
      const uptime = await server.getServerUptime();
      expect(uptime.length).toBeGreaterThan(0);
      
      // Stop server
      await server.stopServer();
      
      // Verify server is stopped
      await server.waitForServerStopped();
      const stoppedStatus = await server.getServerStatus();
      expect(stoppedStatus.toLowerCase()).toContain('stopped');
    });

    test('restart server works correctly', async ({ page }) => {
      test.setTimeout(30000);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Start server first
      await server.startServer();
      await server.waitForServerRunning();
      
      const originalPort = await server.getServerPort();
      
      // Restart server
      await server.restartServer();
      
      // Should be running again
      await server.waitForServerRunning();
      
      // Port should be the same (or different if configured to change)
      const newPort = await server.getServerPort();
      expect(newPort).toBeGreaterThan(0);
    });

    test('server startup performance is acceptable', async ({ page }) => {
      test.setTimeout(20000);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      const startTime = Date.now();
      await server.startServer();
      await server.waitForServerRunning();
      const startupTime = Date.now() - startTime;
      
      // Server should start within 10 seconds
      expect(startupTime).toBeLessThan(10000);
      
      console.log(`Server startup time: ${startupTime}ms`);
    });
  });

  test.describe('Server Configuration', () => {
    test('server configuration can be modified', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Configure custom server settings
      const newConfig = {
        port: 3001,
        host: 'localhost',
        dataDir: './test-workspace'
      };
      
      await server.configureServerSettings(newConfig);
      
      // Start server with new configuration
      await server.startServer();
      await server.waitForServerRunning();
      
      // Verify new port is being used
      const activePort = await server.getServerPort();
      expect(activePort).toBe(newConfig.port);
    });

    test('port conflict is handled gracefully', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      await server.testPortConflict();
      
      // Should show helpful error message and suggestions
      await expect(page.locator('[data-testid="port-conflict-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="suggested-ports"]')).toBeVisible();
    });

    test('invalid configuration shows validation errors', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Try to configure with invalid port
      await page.click('[data-testid="server-settings-button"]');
      await page.fill('[data-testid="port-input"]', '99999'); // Invalid port
      await page.click('[data-testid="save-config-button"]');
      
      // Should show validation error
      await expect(page.locator('[data-testid="port-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="port-error"]')).toContainText('Port must be between');
    });
  });

  test.describe('Server Monitoring', () => {
    test('server metrics are displayed and update', async ({ page }) => {
      test.setTimeout(25000);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Start server to get metrics
      await server.startServer();
      await server.waitForServerRunning();
      
      // Verify metrics are displayed
      await server.verifyServerMetrics();
      
      // Wait and verify metrics update
      await server.verifyRealTimeUpdates();
    });

    test('server health check works correctly', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Start server
      await server.startServer();
      await server.waitForServerRunning();
      
      // Verify health check
      await server.testServerHealthCheck();
    });

    test('server logs are accessible and readable', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Start server to generate logs
      await server.startServer();
      await server.waitForServerRunning();
      
      // Check server logs
      await server.checkServerLogs();
      
      // Should be able to filter logs
      await page.fill('[data-testid="log-filter-input"]', 'error');
      
      // Filtered logs should only show error messages
      const logEntries = page.locator('[data-testid="log-entry"]');
      const firstLogEntry = await logEntries.first().textContent();
      if (firstLogEntry) {
        expect(firstLogEntry.toLowerCase()).toContain('error');
      }
    });
  });

  test.describe('Error Handling', () => {
    test('server startup failure shows helpful error', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Mock server startup failure
      await page.route('**/server/start', route => {
        route.fulfill({
          status: 500,
          json: { error: 'Failed to start server: port 3000 already in use' }
        });
      });
      
      await server.startServer({ expectFailure: true });
      
      // Should show helpful error message
      await expect(page.locator('[data-testid="server-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="error-message"]')).toContainText('port 3000 already in use');
      
      // Should show retry option
      await expect(page.locator('[data-testid="retry-button"]')).toBeVisible();
    });

    test('server crash triggers auto-recovery', async ({ page }) => {
      test.setTimeout(30000);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Start server
      await server.startServer();
      await server.waitForServerRunning();
      
      // Test auto-recovery mechanism
      await server.testServerAutoRecovery();
      
      // Should eventually be running again
      await server.waitForServerRunning();
    });

    test('network connectivity issues are handled', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Start server normally
      await server.startServer();
      await server.waitForServerRunning();
      
      // Simulate network issues
      await page.context().setOffline(true);
      
      // UI should indicate connection issues
      await expect(page.locator('[data-testid="connection-status"]')).toContainText('Offline');
      
      // Restore connectivity
      await page.context().setOffline(false);
      
      // Should reconnect automatically
      await expect(page.locator('[data-testid="connection-status"]')).toContainText('Online');
    });
  });

  test.describe('Integration with Chat', () => {
    test('chat functionality requires running server', async ({ page }) => {
      const chat = new ChatHelper(page);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Try to access chat when server is stopped
      await chat.navigateToChat();
      
      // Should show message that server is required
      await expect(page.locator('[data-testid="server-required-message"]')).toBeVisible();
      await expect(page.locator('[data-testid="start-server-button"]')).toBeVisible();
      
      // Start server from chat interface
      await page.click('[data-testid="start-server-button"]');
      await server.waitForServerRunning();
      
      // Chat should now be available
      await expect(page.locator('[data-testid="message-input"]')).toBeVisible();
      await expect(page.locator('[data-testid="server-required-message"]')).not.toBeVisible();
    });

    test('stopping server during active chat shows appropriate warning', async ({ page }) => {
      const chat = new ChatHelper(page);
      
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Start a conversation
      await chat.sendMessage('Hello, this is a test');
      await chat.waitForResponse();
      
      // Navigate back to dashboard and stop server
      await server.navigateToDashboard();
      
      // Should warn about active chat sessions
      await page.click('[data-testid="stop-server-button"]');
      await expect(page.locator('[data-testid="active-chat-warning"]')).toBeVisible();
      
      // Confirm stopping server
      await page.click('[data-testid="confirm-stop-server"]');
      await server.waitForServerStopped();
      
      // Chat should show disconnection message
      await chat.navigateToChat();
      await expect(page.locator('[data-testid="server-disconnected"]')).toBeVisible();
    });

    test('server restart maintains chat session continuity', async ({ page }) => {
      const chat = new ChatHelper(page);
      
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send initial messages
      await chat.sendMessage('First message before restart');
      await chat.waitForResponse();
      
      const messageCountBefore = await chat.getMessageCount();
      
      // Restart server
      await server.navigateToDashboard();
      await server.restartServer();
      
      // Return to chat
      await chat.navigateToChat();
      
      // Previous messages should still be there
      const messageCountAfter = await chat.getMessageCount();
      expect(messageCountAfter).toBe(messageCountBefore);
      
      // Should be able to send new messages
      await chat.sendMessage('Message after server restart');
      await chat.waitForResponse();
      
      // Should have more messages now
      const finalMessageCount = await chat.getMessageCount();
      expect(finalMessageCount).toBe(messageCountBefore + 2);
    });
  });

  test.describe('Performance and Reliability', () => {
    test('server handles multiple concurrent requests', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      await server.startServer();
      await server.waitForServerRunning();
      
      // Simulate multiple concurrent operations
      const promises = [
        page.locator('[data-testid="refresh-metrics-button"]').click(),
        page.locator('[data-testid="refresh-logs-button"]').click(),
        server.verifyServerMetrics()
      ];
      
      // All operations should complete successfully
      await Promise.all(promises);
      
      // Server should still be running and responsive
      const status = await server.getServerStatus();
      expect(status.toLowerCase()).toContain('running');
    });

    test('server memory usage stays within bounds', async ({ page }) => {
      test.setTimeout(60000);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      await server.startServer();
      await server.waitForServerRunning();
      
      // Get initial memory usage
      await server.verifyServerMetrics();
      const initialMemory = await page.textContent('[data-testid="memory-usage"]');
      
      // Wait for extended period to check for memory leaks
      await page.waitForTimeout(30000);
      
      // Check memory usage hasn't increased dramatically
      const finalMemory = await page.textContent('[data-testid="memory-usage"]');
      
      // Parse memory values (assuming they're in MB)
      const initialMB = parseFloat(initialMemory?.replace(/[^\d.]/g, '') || '0');
      const finalMB = parseFloat(finalMemory?.replace(/[^\d.]/g, '') || '0');
      
      // Memory should not increase by more than 50% (indication of leak)
      expect(finalMB).toBeLessThan(initialMB * 1.5);
    });
  });

  test.describe('Accessibility', () => {
    test('server controls are keyboard accessible', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Tab to server controls
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab'); // Navigate to server controls area
      
      // Should be able to start server with keyboard
      const startButton = page.locator('[data-testid="start-server-button"]:focus');
      if (await startButton.isVisible()) {
        await page.keyboard.press('Enter');
        await server.waitForServerRunning();
      }
      
      // Should be able to access other controls
      await page.keyboard.press('Tab');
      const focusedElement = page.locator(':focus');
      await expect(focusedElement).toBeVisible();
    });

    test('server status is announced to screen readers', async ({ page }) => {
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Server status should have proper ARIA attributes
      const statusElement = page.locator('[data-testid="server-status"]');
      await expect(statusElement).toHaveAttribute('aria-live', 'polite');
      
      // Start server
      await server.startServer();
      
      // Status change should be announced
      await server.waitForServerRunning();
      await expect(statusElement).toContainText('Running');
    });
  });
});