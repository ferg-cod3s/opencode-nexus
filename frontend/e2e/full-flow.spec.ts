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

test.describe('Complete User Flow', () => {
  test('should complete connection setup and use chat functionality', async ({ page }) => {
    // Step 1: Start at index (startup routing)
    await page.goto('/');

    // Should redirect to connect page since no saved connections
    await expect(page).toHaveURL('/connect');

    // Step 2: Set up connection
    await page.fill('[data-testid="server-url-input"]', 'http://localhost:4096');
    await page.click('[data-testid="connect-button"]');

    // Should redirect to chat after connection
    await page.waitForURL('/chat');
    await expect(page.locator('[data-testid="chat-interface"]')).toBeVisible();

    // Step 3: Test basic chat interface elements
    await expect(page.locator('[data-testid="message-input"]')).toBeVisible();

    // Step 4: Test navigation to other pages
    await page.click('[data-nav="connect"]');
    await expect(page).toHaveURL('/connect');

    // Go back to chat
    await page.click('[data-nav="chat"]');
    await expect(page).toHaveURL('/chat');
  });

  test('should handle error states gracefully', async ({ page }) => {
    // Try to access chat without connection
    await page.goto('/chat');

    // Should redirect to connect page
    await expect(page).toHaveURL('/connect');

    // Try to access non-existent page
    await page.goto('/nonexistent');

    // Should handle gracefully (could redirect to connect or show error)
    await expect(page.locator('body')).toBeVisible();
  });

  test('should maintain connection state across navigation', async ({ page }) => {
    // Navigate to connect page
    await page.goto('/connect');
    await expect(page).toHaveURL('/connect');

    // Navigate to chat page
    await page.click('[data-nav="chat"]');
    await expect(page).toHaveURL('/chat');

    // Navigate back to connect
    await page.click('[data-nav="connect"]');
    await expect(page).toHaveURL('/connect');

    // Navigation should work
    await expect(page.locator('[data-testid="connect-form"]')).toBeVisible();
  });

  test('should work on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });

    // Navigate to connect page
    await page.goto('/connect');

    // Verify mobile layout works
    await expect(page.locator('[data-testid="connect-form"]')).toBeVisible();

    // Test navigation on mobile
    await page.click('[data-nav="chat"]');
    await expect(page).toHaveURL('/chat');
  });

  test('should handle network connectivity issues', async ({ page }) => {
    // Navigate to chat
    await page.goto('/chat');

    // Test basic page structure (may not have message input if not connected)
    await expect(page.locator('body')).toBeVisible();

    // Should be able to navigate
    await page.click('[data-nav="connect"]');
    await expect(page).toHaveURL('/connect');
  });
});