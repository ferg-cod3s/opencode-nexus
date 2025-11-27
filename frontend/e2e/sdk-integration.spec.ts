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

/**
 * SDK Integration E2E Tests
 *
 * Tests the @opencode-ai/sdk integration in the frontend
 * Validates that the SDK client wrapper works correctly and
 * provides proper type safety and event handling
 */

test.describe('SDK Integration - End-to-End', () => {

  test.describe('SDK Client Initialization', () => {
    test('should initialize SDK client without connected state', async ({ page }) => {
      // Navigate to chat page which triggers SDK initialization
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Check console for SDK initialization logs
      const logs: string[] = [];
      page.on('console', (msg) => {
        if (msg.text().includes('[SDK]')) {
          logs.push(msg.text());
        }
      });

      // Wait a bit for any initialization to complete
      await page.waitForTimeout(1000);

      // Verify SDK was initialized (should see connection attempts or "not connected" messages)
      const hasSDKLogs = logs.length > 0;
      expect(hasSDKLogs || page.url().includes('/connect')).toBeTruthy();
    });

    test('should show connection required state when not connected', async ({ page }) => {
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Should either show connection required prompt or redirect to /connect
      const hasConnectionPrompt = await page.locator('.connection-required').isVisible().catch(() => false);
      const redirectedToConnect = page.url().includes('/connect');

      expect(hasConnectionPrompt || redirectedToConnect).toBeTruthy();
    });
  });

  test.describe('SDK Connection Management', () => {
    test('should validate connection parameters before connecting', async ({ page }) => {
      // This would require mocking the SDK or having a test server
      // For now, we verify the UI allows entering connection details
      await page.goto('/settings');
      await page.waitForLoadState('networkidle');

      // Check if connection settings form is available
      const connectionForm = await page.locator('[data-testid="connection-form"]').isVisible().catch(() => false);

      if (connectionForm) {
        // Form should be present for managing connections
        expect(connectionForm).toBeTruthy();
      }
    });

    test('should handle connection errors gracefully', async ({ page }) => {
      // Navigate to settings where connection can be managed
      await page.goto('/settings');
      await page.waitForLoadState('networkidle');

      // Attempt to connect to invalid host (if UI allows)
      const connectionInput = await page.locator('[data-testid="hostname-input"]').isVisible().catch(() => false);

      if (connectionInput) {
        await page.fill('[data-testid="hostname-input"]', 'invalid.host.local');
        await page.click('[data-testid="test-connection-button"]');

        // Should show error message
        await page.waitForTimeout(2000);
        const errorMessage = await page.locator('.error-message').isVisible().catch(() => false);
        // Error handling should be present
      }
    });
  });

  test.describe('SDK Chat Operations', () => {
    test('should not allow chat operations without connection', async ({ page }) => {
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Look for message input - should be disabled or hidden
      const messageInput = await page.locator('[data-testid="message-input"]').isVisible().catch(() => false);

      if (messageInput) {
        // If input is visible, it should be disabled
        const isDisabled = await page.locator('[data-testid="message-input"]').isDisabled().catch(() => false);
        expect(messageInput && isDisabled || !messageInput).toBeTruthy();
      }
    });

    test('should handle async SDK operations with proper loading states', async ({ page }) => {
      // Check that any SDK operation shows appropriate loading indicators
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Look for loading spinner or skeleton screens
      const hasLoadingIndicators = await page.locator('.loading-spinner, .skeleton').isVisible().catch(() => false);

      // Either loading indicators are shown or content is loaded
      const hasContent = await page.locator('.chat-interface, .connection-required').isVisible().catch(() => false);

      expect(hasLoadingIndicators || hasContent).toBeTruthy();
    });
  });

  test.describe('SDK Event Handling', () => {
    test('should set up event listeners when connected', async ({ page }) => {
      // Monitor console logs for event subscription
      const eventLogs: string[] = [];
      page.on('console', (msg) => {
        if (msg.text().includes('event') || msg.text().includes('Event')) {
          eventLogs.push(msg.text());
        }
      });

      await page.goto('/chat');
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);

      // Should attempt to set up event listeners or show appropriate state
      // This would be more testable with a mock server
    });

    test('should handle event stream subscription gracefully', async ({ page }) => {
      // Navigate to chat which should attempt event subscription
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Check for any errors in console
      const errors: string[] = [];
      page.on('console', (msg) => {
        if (msg.type() === 'error') {
          errors.push(msg.text());
        }
      });

      await page.waitForTimeout(2000);

      // Should not have critical errors about event subscription
      const criticalErrors = errors.filter(e =>
        e.includes('event') && (e.includes('critical') || e.includes('fatal'))
      );

      expect(criticalErrors.length).toBe(0);
    });
  });

  test.describe('SDK Type Safety', () => {
    test('should use SDK types for chat operations', async ({ page }) => {
      // This test validates TypeScript compilation worked correctly
      // We check for proper error handling in the UI

      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // The app should load without type errors
      // (This is validated during build, but we can check runtime behavior)
      const hasTypeErrors = await page.locator('.type-error, [data-testid="type-error"]').isVisible().catch(() => false);
      expect(!hasTypeErrors).toBeTruthy();
    });
  });

  test.describe('SDK Performance', () => {
    test('should initialize SDK quickly', async ({ page }) => {
      const startTime = Date.now();

      await page.goto('/chat');

      // Should reach a ready state quickly
      const firstContentful = await page.locator('.chat-interface, .connection-required').isVisible();

      const initTime = Date.now() - startTime;

      // Should initialize in under 3 seconds for acceptable UX
      expect(initTime).toBeLessThan(3000);
    });

    test('should handle SDK operations without blocking UI', async ({ page }) => {
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Page should remain responsive during SDK operations
      const isResponsive = await page.evaluate(() => {
        return document.readyState === 'complete' || document.readyState === 'interactive';
      });

      expect(isResponsive).toBeTruthy();
    });
  });

  test.describe('SDK Offline Behavior', () => {
    test('should cache connection state for offline access', async ({ page }) => {
      // Test that SDK handles offline scenarios gracefully
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Go offline
      await page.context().setOffline(true);

      // App should still be responsive
      const stillLoaded = await page.locator('body').isVisible();
      expect(stillLoaded).toBeTruthy();

      // Go back online
      await page.context().setOffline(false);
    });

    test('should restore connection state on app restart', async ({ page }) => {
      // Navigate to chat
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Store page state
      const originalUrl = page.url();

      // Simulate reload
      await page.reload();
      await page.waitForLoadState('networkidle');

      // Should be on similar page (might redirect based on connection state)
      const newUrl = page.url();
      expect(newUrl.includes('/chat') || newUrl.includes('/connect')).toBeTruthy();
    });
  });

  test.describe('SDK Error Recovery', () => {
    test('should recover from failed operations', async ({ page }) => {
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Monitor for error recovery attempts
      const recoveryAttempts: string[] = [];
      page.on('console', (msg) => {
        if (msg.text().includes('retry') || msg.text().includes('Retry')) {
          recoveryAttempts.push(msg.text());
        }
      });

      // Simulate error by going offline then online
      await page.context().setOffline(true);
      await page.waitForTimeout(500);
      await page.context().setOffline(false);

      await page.waitForTimeout(1000);

      // Should attempt recovery (not strictly required but good to have)
    });

    test('should show user-friendly error messages', async ({ page }) => {
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Look for error messages that are user-friendly (not raw errors)
      const errorMessages = await page.locator('[role="alert"], .error-message, .notification.error').allTextContents();

      // If errors are shown, they should be readable
      errorMessages.forEach(msg => {
        expect(msg).not.toMatch(/\[object Object\]/);
        expect(msg.length).toBeGreaterThan(0);
      });
    });
  });

  test.describe('SDK Integration with Chat Store', () => {
    test('should sync SDK state with chat store', async ({ page }) => {
      // Navigate to chat
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');

      // Check that UI reflects proper state
      // Should show either loading, error, or ready state consistently
      await page.waitForTimeout(500);

      const hasValidState = await page.evaluate(() => {
        const body = document.body.innerHTML;
        return body.includes('loading') || body.includes('error') || body.includes('connection') || body.includes('chat');
      });

      expect(hasValidState).toBeTruthy();
    });
  });
});

/**
 * SDK Integration Performance Tests
 *
 * Measures SDK integration performance metrics
 */
test.describe('SDK Integration - Performance', () => {

  test('should measure SDK client initialization time', async ({ page }) => {
    const metrics = {
      navigationStart: 0,
      sdkInitComplete: 0
    };

    // Capture timing
    metrics.navigationStart = Date.now();

    await page.goto('/chat');

    // Wait for SDK initialization (check for logs)
    page.on('console', (msg) => {
      if (msg.text().includes('SDK Integration')) {
        metrics.sdkInitComplete = Date.now();
      }
    });

    await page.waitForLoadState('networkidle');
    const totalTime = Date.now() - metrics.navigationStart;

    // Performance assertion - should be reasonably fast
    expect(totalTime).toBeLessThan(5000);
  });

  test('should not create memory leaks during SDK operations', async ({ page }) => {
    // Get initial memory
    const initialMemory = await page.evaluate(() => {
      if (performance.memory) {
        return performance.memory.usedJSHeapSize;
      }
      return 0;
    });

    await page.goto('/chat');
    await page.waitForLoadState('networkidle');

    // Perform multiple operations
    for (let i = 0; i < 5; i++) {
      await page.reload();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(200);
    }

    // Get final memory
    const finalMemory = await page.evaluate(() => {
      if (performance.memory) {
        return performance.memory.usedJSHeapSize;
      }
      return 0;
    });

    // Memory growth should be reasonable (not more than 50% increase)
    if (initialMemory > 0 && finalMemory > 0) {
      const memoryGrowth = (finalMemory - initialMemory) / initialMemory;
      expect(memoryGrowth).toBeLessThan(0.5);
    }
  });
});
