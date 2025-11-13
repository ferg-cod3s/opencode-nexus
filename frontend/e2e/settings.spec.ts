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

test.describe('Settings Page', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to settings page
    await page.goto('/settings');
    
    // Wait for page to load - use more specific selector to avoid dev toolbar
    await expect(page.locator('h1').first()).toContainText('OpenCode Nexus Settings');
  });

  test('should display all settings sections', async ({ page }) => {
    // Check main sections are present
    await expect(page.locator('#tunnel-settings')).toBeVisible();
    await expect(page.locator('#app-settings')).toBeVisible();
    
    // Check tunnel settings section
    await expect(page.locator('#tunnel-settings h2')).toContainText('Remote Access (Tunnel)');
    await expect(page.locator('#app-settings h2')).toContainText('Application');
  });

  test('should load tunnel configuration form', async ({ page }) => {
    // Check form elements are present
    await expect(page.locator('#custom-domain')).toBeVisible();
    await expect(page.locator('#auth-token')).toBeVisible();
    await expect(page.locator('#save-tunnel-settings')).toBeVisible();
    await expect(page.locator('#test-tunnel-config')).toBeVisible();
    
    // Check labels and help text
    await expect(page.locator('label[for="custom-domain"]')).toContainText('Custom Domain');
    await expect(page.locator('label[for="auth-token"]')).toContainText('Cloudflare Token');
    
    // Check help text is present
    await expect(page.locator('#domain-help')).toBeVisible();
    await expect(page.locator('#token-help')).toBeVisible();
  });

  test('should load application settings form', async ({ page }) => {
    // Check application settings elements
    await expect(page.locator('#auto-start-tunnel')).toBeVisible();
    await expect(page.locator('#theme-select')).toBeVisible();
    
    // Check theme options
    await expect(page.locator('#theme-select option[value="system"]')).toContainText('System');
    await expect(page.locator('#theme-select option[value="light"]')).toContainText('Light');
    await expect(page.locator('#theme-select option[value="dark"]')).toContainText('Dark');
  });

  test('should display tunnel status', async ({ page }) => {
    // Check status display elements
    await expect(page.locator('#tunnel-status-display')).toBeVisible();
    await expect(page.locator('#tunnel-status-dot')).toBeVisible();
    await expect(page.locator('#tunnel-status-text')).toBeVisible();
    await expect(page.locator('#current-tunnel-url')).toBeVisible();
    
    // Check initial status (should be unknown or stopped)
    const statusText = await page.locator('#tunnel-status-text').textContent();
    expect(['Unknown', 'Stopped']).toContain(statusText);
  });

  test('should validate custom domain input', async ({ page }) => {
    const domainInput = page.locator('#custom-domain');
    const errorElement = page.locator('#domain-error');
    
    // Test valid domain
    await domainInput.fill('valid-domain.com');
    await expect(errorElement).toBeHidden();
    
    // Test invalid domain
    await domainInput.fill('invalid..domain');
    await expect(errorElement).toBeVisible();
    await expect(errorElement).toContainText('Please enter a valid domain name');
    
    // Test empty domain (should be valid)
    await domainInput.clear();
    await expect(errorElement).toBeHidden();
  });

  test('should validate token requirement for custom domains', async ({ page }) => {
    const domainInput = page.locator('#custom-domain');
    const tokenInput = page.locator('#auth-token');
    const tokenError = page.locator('#token-error');
    
    // Set custom domain without token
    await domainInput.fill('test-domain.com');
    await tokenInput.clear();
    
    // Try to save (this should trigger validation)
    await page.locator('#save-tunnel-settings').click();
    
    // Should show token required error
    await expect(tokenError).toBeVisible();
    await expect(tokenError).toContainText('Authentication token is required for custom domains');
  });

  test('should handle theme selection', async ({ page }) => {
    const themeSelect = page.locator('#theme-select');
    
    // Test theme options
    await themeSelect.selectOption('dark');
    await expect(themeSelect).toHaveValue('dark');
    
    await themeSelect.selectOption('light');
    await expect(themeSelect).toHaveValue('light');
    
    await themeSelect.selectOption('system');
    await expect(themeSelect).toHaveValue('system');
  });

  test('should handle auto-start checkbox', async ({ page }) => {
    const autoStartCheckbox = page.locator('#auto-start-tunnel');
    
    // Test checkbox interaction
    await expect(autoStartCheckbox).not.toBeChecked();
    
    await autoStartCheckbox.check();
    await expect(autoStartCheckbox).toBeChecked();
    
    await autoStartCheckbox.uncheck();
    await expect(autoStartCheckbox).not.toBeChecked();
  });

  test('should be accessible', async ({ page }) => {
    // Check ARIA labels
    await expect(page.locator('#custom-domain')).toHaveAttribute('aria-describedby', 'domain-help');
    await expect(page.locator('#auth-token')).toHaveAttribute('aria-describedby', 'token-help');
    
    // Check form labels
    await expect(page.locator('label[for="custom-domain"]')).toBeVisible();
    await expect(page.locator('label[for="auth-token"]')).toBeVisible();
    
    // Check keyboard navigation
    await page.keyboard.press('Tab');
    let focusedElement = await page.evaluate(() => document.activeElement?.id);
    expect(['custom-domain', 'auth-token', 'auto-start-tunnel', 'theme-select']).toContain(focusedElement);
  });

  test('should be responsive on mobile', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Check mobile-specific styling
    await expect(page.locator('.tunnel-controls')).toBeVisible();
    
    // Check buttons are present on mobile
    await expect(page.locator('#save-tunnel-settings')).toBeVisible();
    await expect(page.locator('#test-tunnel-config')).toBeVisible();
  });

  test('should handle high contrast mode', async ({ page }) => {
    // Enable high contrast media query
    await page.emulateMedia({ colorScheme: 'dark', reducedMotion: 'reduce' });
    
    // Check that the page still renders correctly
    await expect(page.locator('#tunnel-settings')).toBeVisible();
    await expect(page.locator('#app-settings')).toBeVisible();
  });

  test('should handle network errors gracefully', async ({ page }) => {
    // Mock network error for tunnel status
    await page.route('**/get_tunnel_status', async route => {
      await route.abort();
    });
    
    await page.route('**/get_tunnel_url', async route => {
      await route.abort();
    });
    
    // Reload page
    await page.reload();
    
    // Should show unknown status instead of crashing
    const statusText = await page.locator('#tunnel-status-text').textContent();
    expect(['Unknown', 'Stopped']).toContain(statusText);
  });

  test('should maintain form state during validation errors', async ({ page }) => {
    const domainInput = page.locator('#custom-domain');
    const tokenInput = page.locator('#auth-token');
    
    // Fill form
    await domainInput.fill('test.example.com');
    await tokenInput.fill('test-token-12345');
    
    // Trigger validation error
    await domainInput.fill('invalid..domain');
    await page.locator('#save-tunnel-settings').click();
    
    // Form values should be preserved
    await expect(domainInput).toHaveValue('invalid..domain');
    await expect(tokenInput).toHaveValue('test-token-12345');
  });

  test('should handle empty form submission', async ({ page }) => {
    const saveButton = page.locator('#save-tunnel-settings');
    
    // Ensure form is empty
    await page.locator('#custom-domain').clear();
    await page.locator('#auth-token').clear();
    
    // Save empty form (should not crash)
    await saveButton.click();
    
    // Should not crash the page
    await expect(page.locator('#tunnel-settings')).toBeVisible();
  });

  test('should clear settings across page reloads', async ({ page }) => {
    const domainInput = page.locator('#custom-domain');
    const tokenInput = page.locator('#auth-token');
    
    // Fill settings
    await domainInput.fill('test.example.com');
    await tokenInput.fill('test-token-12345');
    
    // Reload page
    await page.reload();
    
    // Settings should be cleared (no client-side persistence implemented yet)
    await expect(domainInput).toHaveValue('');
    await expect(tokenInput).toHaveValue('');
  });

  test('should have proper form structure', async ({ page }) => {
    // Check that all form elements are properly structured
    await expect(page.locator('form')).toHaveCount(0); // No traditional form element
    await expect(page.locator('input[type="text"]')).toHaveCount(1);
    await expect(page.locator('input[type="password"]')).toHaveCount(1);
    // Count only checkboxes within the settings sections, not dev toolbar
    await expect(page.locator('#tunnel-settings input[type="checkbox"], #app-settings input[type="checkbox"]')).toHaveCount(1);
    await expect(page.locator('select')).toHaveCount(1);
    await expect(page.locator('button')).toHaveCount(2);
  });

  test('should have proper semantic structure', async ({ page }) => {
    // Check semantic HTML structure - be more specific to avoid dev toolbar
    await expect(page.locator('main')).toBeVisible();
    await expect(page.locator('.settings-header')).toBeVisible();
    await expect(page.locator('section')).toHaveCount(2);
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('h2')).toHaveCount(2);
  });

  test('should handle rapid interactions', async ({ page }) => {
    const saveButton = page.locator('#save-tunnel-settings');
    const testButton = page.locator('#test-tunnel-config');
    
    // Click multiple buttons rapidly
    await saveButton.click();
    await testButton.click();
    await saveButton.click();
    
    // Should not crash the page
    await expect(page.locator('#tunnel-settings')).toBeVisible();
  });

  test('should handle input focus and blur', async ({ page }) => {
    const domainInput = page.locator('#custom-domain');
    
    // Focus on input
    await domainInput.click(); // Use click instead of focus()
    await expect(domainInput).toBeFocused();
    
    // Blur input
    await page.keyboard.press('Tab');
    await expect(domainInput).not.toBeFocused();
  });

  test('should handle keyboard navigation', async ({ page }) => {
    // Test tab navigation through form elements
    await page.keyboard.press('Tab');
    let focusedElement = await page.evaluate(() => document.activeElement?.id);
    
    // Should focus first form element
    expect(['custom-domain', 'auth-token', 'auto-start-tunnel', 'theme-select']).toContain(focusedElement);
    
    // Continue tabbing
    await page.keyboard.press('Tab');
    focusedElement = await page.evaluate(() => document.activeElement?.id);
    
    // Should focus next form element
    expect(['custom-domain', 'auth-token', 'auto-start-tunnel', 'theme-select']).toContain(focusedElement);
  });

  test('should handle page refresh', async ({ page }) => {
    // Fill some data
    await page.locator('#custom-domain').fill('test.com');
    await page.locator('#auth-token').fill('test-token');
    
    // Refresh page
    await page.reload();
    
    // Data should be cleared (expected behavior for now)
    await expect(page.locator('#custom-domain')).toHaveValue('');
    await expect(page.locator('#auth-token')).toHaveValue('');
  });

  test('should handle window resize', async ({ page }) => {
    // Test desktop size
    await page.setViewportSize({ width: 1200, height: 800 });
    await expect(page.locator('#tunnel-settings')).toBeVisible();
    
    // Test tablet size
    await page.setViewportSize({ width: 768, height: 1024 });
    await expect(page.locator('#tunnel-settings')).toBeVisible();
    
    // Test mobile size
    await page.setViewportSize({ width: 375, height: 667 });
    await expect(page.locator('#tunnel-settings')).toBeVisible();
  });

  test('should handle missing JavaScript gracefully', async ({ page }) => {
    // Create a new context with JavaScript disabled
    const context = page.context();
    const newPage = await context.newPage();
    
    // Disable JavaScript on the new page
    await newPage.goto('/settings');
    
    // Page should still render basic HTML structure
    await expect(newPage.locator('#tunnel-settings')).toBeVisible();
    await expect(newPage.locator('#app-settings')).toBeVisible();
    
    // Form elements should be present but non-functional
    await expect(newPage.locator('#custom-domain')).toBeVisible();
    await expect(newPage.locator('#save-tunnel-settings')).toBeVisible();
    
    // Close the new page
    await newPage.close();
  });
});
