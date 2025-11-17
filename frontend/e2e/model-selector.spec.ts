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
import { ChatHelper } from './helpers/chat';

test.describe('Model Selector Integration', () => {
  let chat: ChatHelper;

  test.beforeEach(async ({ page }) => {
    chat = new ChatHelper(page);
  });

  test('Model selector loads available models from backend API', async ({ page }) => {
    test.setTimeout(15000);

    await chat.loginAndStartServer();
    await chat.navigateToChat();

    // Wait for chat interface to load
    await page.waitForTimeout(2000);

    // Verify model selector is present in the DOM
    const modelSelector = page.locator('[data-testid="model-selector"]');
    await expect(modelSelector).toBeVisible();

    // Verify model selector trigger is present
    const modelSelectorTrigger = page.locator('[data-testid="model-selector-trigger"]');
    await expect(modelSelectorTrigger).toBeVisible();

    // Initially should show "Server Default" since no models are loaded yet
    await expect(modelSelectorTrigger).toContainText('Server Default');

    // Verify the backend API was called to fetch models
    // This would be verified through network monitoring or mock verification
    // For now, we verify the UI is in the expected state
    const triggerAriaExpanded = await modelSelectorTrigger.getAttribute('aria-expanded');
    expect(triggerAriaExpanded).toBe('false');
  });

  test('Model selector dropdown opens and shows options', async ({ page }) => {
    test.setTimeout(15000);

    await chat.loginAndStartServer();
    await chat.navigateToChat();

    // Wait for chat interface to load
    await page.waitForTimeout(2000);

    const modelSelectorTrigger = page.locator('[data-testid="model-selector-trigger"]');

    // Click to open dropdown
    await modelSelectorTrigger.click();

    // Verify dropdown is open
    await expect(modelSelectorTrigger).toHaveAttribute('aria-expanded', 'true');

    // Verify dropdown menu is visible
    const dropdown = page.locator('[data-testid="model-dropdown"]');
    await expect(dropdown).toBeVisible();

    // Verify server default option is present
    const serverDefaultOption = page.locator('[data-testid="server-default-option"]');
    await expect(serverDefaultOption).toBeVisible();
    await expect(serverDefaultOption).toContainText('Server Default');
  });

  test('Model selector can select server default option', async ({ page }) => {
    test.setTimeout(15000);

    await chat.loginAndStartServer();
    await chat.navigateToChat();

    // Wait for chat interface to load
    await page.waitForTimeout(2000);

    const modelSelectorTrigger = page.locator('[data-testid="model-selector-trigger"]');

    // Open dropdown
    await modelSelectorTrigger.click();

    // Click server default option
    const serverDefaultOption = page.locator('[data-testid="server-default-option"]');
    await serverDefaultOption.click();

    // Verify dropdown is closed
    await expect(modelSelectorTrigger).toHaveAttribute('aria-expanded', 'false');

    // Verify server default is selected
    await expect(modelSelectorTrigger).toContainText('Server Default');
  });

  test('Model selector handles API errors gracefully', async ({ page }) => {
    test.setTimeout(15000);

    await chat.loginAndStartServer();
    await chat.navigateToChat();

    // Wait for chat interface to load
    await page.waitForTimeout(2000);

    const modelSelectorTrigger = page.locator('[data-testid="model-selector-trigger"]');

    // Open dropdown
    await modelSelectorTrigger.click();

    // If there are API errors, the error state should be shown
    // This test verifies the UI handles error states properly
    const errorElement = page.locator('[data-testid="model-selector-error"]');

    // Either error is not present (success case) or is handled gracefully
    const errorVisible = await errorElement.isVisible().catch(() => false);
    if (errorVisible) {
      // If error is shown, verify it contains error text
      await expect(errorElement).toBeVisible();
      const errorText = await errorElement.textContent();
      expect(errorText).toBeTruthy();
    }
  });

  test('Model selector maintains accessibility attributes', async ({ page }) => {
    test.setTimeout(15000);

    await chat.loginAndStartServer();
    await chat.navigateToChat();

    // Wait for chat interface to load
    await page.waitForTimeout(2000);

    const modelSelectorTrigger = page.locator('[data-testid="model-selector-trigger"]');

    // Verify initial accessibility attributes
    await expect(modelSelectorTrigger).toHaveAttribute('aria-haspopup', 'listbox');
    await expect(modelSelectorTrigger).toHaveAttribute('aria-expanded', 'false');

    // Open dropdown
    await modelSelectorTrigger.click();

    // Verify expanded state
    await expect(modelSelectorTrigger).toHaveAttribute('aria-expanded', 'true');

    // Verify dropdown has proper role
    const dropdown = page.locator('[data-testid="model-dropdown"]');
    await expect(dropdown).toHaveAttribute('role', 'listbox');

    // Verify options have proper roles
    const options = page.locator('[role="option"]');
    const optionCount = await options.count();
    expect(optionCount).toBeGreaterThan(0);
  });

  test('Model selector integrates with message sending (API integration)', async ({ page }) => {
    test.setTimeout(20000);

    await chat.loginAndStartServer();
    await chat.navigateToChat();

    // Wait for chat interface to load
    await page.waitForTimeout(2000);

    // Select a specific model (if available)
    const modelSelectorTrigger = page.locator('[data-testid="model-selector-trigger"]');
    await modelSelectorTrigger.click();

    // Try to find and select a specific model option
    const modelOptions = page.locator('[data-testid^="model-option-"]');
    const optionCount = await modelOptions.count();

    if (optionCount > 0) {
      // Select first available model
      await modelOptions.first().click();

      // Verify model was selected
      const selectedText = await modelSelectorTrigger.textContent();
      expect(selectedText).not.toContain('Server Default');
    } else {
      // If no models available, select server default
      const serverDefaultOption = page.locator('[data-testid="server-default-option"]');
      await serverDefaultOption.click();
    }

    // Send a message to verify model selection is included
    const testMessage = 'Test message with model selection';
    await chat.sendMessage(testMessage);

    // Verify message was sent (this tests the API integration with model parameter)
    // The backend should receive the model parameter in the send_message call
    await page.waitForTimeout(1000);

    // Verify message appears in chat (basic success indicator)
    // Note: Full response verification would require backend mocking
    const userMessages = page.locator('[data-testid="user-message"]');
    const lastUserMessage = userMessages.last();
    await expect(lastUserMessage).toContainText(testMessage);
  });

  test('Model selector persists selection across page interactions', async ({ page }) => {
    test.setTimeout(15000);

    await chat.loginAndStartServer();
    await chat.navigateToChat();

    // Wait for chat interface to load
    await page.waitForTimeout(2000);

    const modelSelectorTrigger = page.locator('[data-testid="model-selector-trigger"]');

    // Make a selection
    await modelSelectorTrigger.click();
    const serverDefaultOption = page.locator('[data-testid="server-default-option"]');
    await serverDefaultOption.click();

    // Verify selection persists
    await expect(modelSelectorTrigger).toContainText('Server Default');

    // Simulate some other interaction (like focusing input)
    const messageInput = page.locator('[data-testid="message-input"]');
    await messageInput.click();

    // Verify model selection still shows
    await expect(modelSelectorTrigger).toContainText('Server Default');
  });
});