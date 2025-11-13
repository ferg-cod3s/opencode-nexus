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

test.describe('Dashboard Functionality - Static Tests', () => {
  // These tests verify dashboard structure without authentication
  // Full integration tests are in server-management.spec.ts
  
  test.beforeEach(async ({ page }) => {
    // Try to access dashboard directly to test redirect behavior
    await page.goto('/dashboard');
  });

  test('should redirect to login when not authenticated', async ({ page }) => {
    // Dashboard should redirect unauthenticated users to login
    await page.waitForURL('/login', { timeout: 5000 });
    await expect(page).toHaveURL('/login');
  });

  test('login page should have proper structure', async ({ page }) => {
    // After redirect, verify login page elements
    await page.waitForURL('/login');
    await expect(page.locator('[data-testid="username-input"]')).toBeAttached();
    await expect(page.locator('[data-testid="password-input"]')).toBeAttached();
    await expect(page.locator('[data-testid="login-button"]')).toBeAttached();
  });
});