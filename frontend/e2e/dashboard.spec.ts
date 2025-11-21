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

// Skip dashboard tests - dashboard page not available in client-only architecture
test.describe.skip('Dashboard Functionality - Static Tests (SKIPPED - Client-only architecture)', () => {
  // These tests verify dashboard structure in client-only architecture

  test('should load dashboard page directly', async ({ page }) => {
    // Dashboard should load in client-only mode
    await page.goto('/dashboard');
    await expect(page.locator('h1')).toContainText('OpenCode Nexus');
  });

  test('dashboard should have basic structure', async ({ page }) => {
    await page.goto('/dashboard');

    // Verify basic page structure exists
    await expect(page.locator('.dashboard-content')).toBeVisible();
    await expect(page.locator('.dashboard-header')).toBeVisible();
  });
});