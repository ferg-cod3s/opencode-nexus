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

test.describe('Connection Flow', () => {
  test('Connection Page - should display connection form with all fields', async ({ page }) => {
    await page.goto('/connect');

    // Check page title
    await expect(page).toHaveTitle(/Connect to Server/);

    // Check main heading
    await expect(page.locator('h1')).toContainText('Connect to OpenCode Server');

    // Check connection method selector exists
    const methodSelect = page.getByTestId('connection-method-select');
    await expect(methodSelect).toBeVisible();

    // Check server URL input exists
    const serverUrlInput = page.getByTestId('server-url-input');
    await expect(serverUrlInput).toBeVisible();
    await expect(serverUrlInput).toHaveAttribute('placeholder', 'http://localhost:4096');

    // Check API key input exists
    const apiKeyInput = page.getByTestId('api-key-input');
    await expect(apiKeyInput).toBeVisible();

    // Check connection name input exists
    const connectionNameInput = page.getByTestId('connection-name-input');
    await expect(connectionNameInput).toBeVisible();

    // Check action buttons exist
    await expect(page.getByTestId('test-connection-button')).toBeVisible();
    await expect(page.getByTestId('connect-button')).toBeVisible();
  });

  test('Connection Page - should update placeholders when changing connection method', async ({ page }) => {
    await page.goto('/connect');

    const methodSelect = page.getByTestId('connection-method-select');
    const serverUrlInput = page.getByTestId('server-url-input');
    const apiKeyInput = page.getByTestId('api-key-input');

    // Default (localhost)
    await expect(serverUrlInput).toHaveAttribute('placeholder', 'http://localhost:4096');
    await expect(apiKeyInput).toHaveAttribute('placeholder', 'Not required for localhost');

    // Switch to Cloudflare Tunnel
    await methodSelect.selectOption('tunnel');
    await expect(serverUrlInput).toHaveAttribute('placeholder', 'https://your-tunnel.trycloudflare.com');
    await expect(apiKeyInput).toHaveAttribute('placeholder', 'Not required (Cloudflare handles auth)');

    // Switch to Reverse Proxy
    await methodSelect.selectOption('proxy');
    await expect(serverUrlInput).toHaveAttribute('placeholder', 'https://opencode.yourdomain.com');
    await expect(apiKeyInput).toHaveAttribute('placeholder', 'Enter your API key (required)');

    // Switch back to localhost
    await methodSelect.selectOption('localhost');
    await expect(serverUrlInput).toHaveAttribute('placeholder', 'http://localhost:4096');
  });

  test('Connection Page - should validate server URL format', async ({ page }) => {
    await page.goto('/connect');

    const serverUrlInput = page.getByTestId('server-url-input');
    const connectButton = page.getByTestId('connect-button');

    // Try invalid URL
    await serverUrlInput.fill('not-a-url');
    await connectButton.click();

    // Check for error message
    const errorMessage = page.getByTestId('server-url-error');
    await expect(errorMessage).toContainText('valid URL');
  });

  test('Connection Page - should validate HTTPS requirement for remote connections', async ({ page }) => {
    await page.goto('/connect');

    const methodSelect = page.getByTestId('connection-method-select');
    const serverUrlInput = page.getByTestId('server-url-input');
    const connectButton = page.getByTestId('connect-button');

    // Switch to tunnel method
    await methodSelect.selectOption('tunnel');

    // Try HTTP URL (should fail)
    await serverUrlInput.fill('http://example.com');
    await connectButton.click();

    // Check for error message
    const errorMessage = page.getByTestId('server-url-error');
    await expect(errorMessage).toContainText('HTTPS');
  });

  test('Connection Page - should require API key for proxy connections', async ({ page }) => {
    await page.goto('/connect');

    const methodSelect = page.getByTestId('connection-method-select');
    const serverUrlInput = page.getByTestId('server-url-input');
    const apiKeyInput = page.getByTestId('api-key-input');
    const connectButton = page.getByTestId('connect-button');

    // Switch to proxy method
    await methodSelect.selectOption('proxy');

    // Fill URL but not API key
    await serverUrlInput.fill('https://opencode.example.com');
    await connectButton.click();

    // Check for API key error
    const apiKeyError = page.getByTestId('api-key-error');
    await expect(apiKeyError).toContainText('required');

    // Now fill API key (should clear error)
    await apiKeyInput.fill('test-api-key-1234567890');
    await apiKeyInput.blur();
    await expect(apiKeyError).toBeEmpty();
  });

  test('Connection Page - should show inline help guide', async ({ page }) => {
    await page.goto('/connect');

    // Find the details/summary element
    const helpToggle = page.locator('summary').filter({ hasText: 'Connection Setup Guide' });
    await expect(helpToggle).toBeVisible();

    // Click to expand help
    await helpToggle.click();

    // Check help sections are visible
    await expect(page.locator('text=🏠 Localhost (Same Machine)')).toBeVisible();
    await expect(page.locator('text=☁️ Cloudflare Tunnel')).toBeVisible();
    await expect(page.locator('text=🔒 Reverse Proxy')).toBeVisible();

    // Check commands are shown
    await expect(page.locator('code').filter({ hasText: 'opencode serve' })).toBeVisible();
    await expect(page.locator('code').filter({ hasText: 'cloudflared tunnel' })).toBeVisible();
  });

  test('Connection Workflow - should redirect to connection page when not connected', async ({ page }) => {
    // Try to access main page without connection
    await page.goto('/');

    // Should redirect to /connect
    await expect(page).toHaveURL(/\/connect/);
  });

  test('Connection Workflow - should allow connection with valid localhost URL', async ({ page }) => {
    await page.goto('/connect');

    const serverUrlInput = page.getByTestId('server-url-input');
    const connectionNameInput = page.getByTestId('connection-name-input');

    // Fill in localhost connection details
    await serverUrlInput.fill('http://localhost:4096');
    await connectionNameInput.fill('Test Local Server');

    // Note: Actual connection will fail without a real OpenCode server
    // This test just verifies the form accepts localhost URLs
    await expect(serverUrlInput).toHaveValue('http://localhost:4096');
    await expect(connectionNameInput).toHaveValue('Test Local Server');
  });

  test('Accessibility - should have accessible form labels', async ({ page }) => {
    await page.goto('/connect');

    // Check all inputs have labels
    await expect(page.locator('label[for="connection-method"]')).toBeVisible();
    await expect(page.locator('label[for="server-url"]')).toBeVisible();
    await expect(page.locator('label[for="api-key"]')).toBeVisible();
    await expect(page.locator('label[for="connection-name"]')).toBeVisible();
  });

  test('Accessibility - should have aria attributes on inputs', async ({ page }) => {
    await page.goto('/connect');

    const serverUrlInput = page.getByTestId('server-url-input');
    const apiKeyInput = page.getByTestId('api-key-input');

    // Check aria attributes
    await expect(serverUrlInput).toHaveAttribute('aria-label', 'Server URL');
    await expect(serverUrlInput).toHaveAttribute('aria-invalid', 'false');

    await expect(apiKeyInput).toHaveAttribute('aria-label', 'API key');
    await expect(apiKeyInput).toHaveAttribute('aria-invalid', 'false');
  });

  test('Accessibility - should update aria-invalid when validation fails', async ({ page }) => {
    await page.goto('/connect');

    const serverUrlInput = page.getByTestId('server-url-input');
    const connectButton = page.getByTestId('connect-button');

    // Submit with invalid URL
    await serverUrlInput.fill('invalid-url');
    await connectButton.click();

    // Check aria-invalid is updated
    await expect(serverUrlInput).toHaveAttribute('aria-invalid', 'true');
  });

  test('Mobile Responsiveness - should display properly on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/connect');

    // Check form is visible
    const form = page.getByTestId('connect-form');
    await expect(form).toBeVisible();

    // Check buttons are stacked vertically (full width)
    const connectButton = page.getByTestId('connect-button');
    const testButton = page.getByTestId('test-connection-button');

    // Both buttons should be visible
    await expect(connectButton).toBeVisible();
    await expect(testButton).toBeVisible();
  });
});
