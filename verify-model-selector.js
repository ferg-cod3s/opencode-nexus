#!/usr/bin/env node

/*
 * Simple Model Selector Verification Script
 * Manually verify model selector is present and functional
 */

import { chromium } from 'playwright';

async function verifyModelSelector() {
  console.log('🔍 Verifying Model Selector Implementation...');

  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('📱 Opening chat page...');
    await page.goto('http://localhost:1420/chat');

    // Wait for page to load
    await page.waitForTimeout(5000);

    console.log('🔍 Checking page content...');

    // Check if we're on the login page (which would indicate auth issues)
    const loginForm = page.locator('input[type="password"], input[placeholder*="password"]').first();
    const hasLoginForm = await loginForm.isVisible().catch(() => false);

    if (hasLoginForm) {
      console.log('🔐 Login page detected - authentication required');
      console.log('⚠️ Manual testing needed: Please log in and navigate to chat manually');
      return;
    }

    // Check for model selector
    const modelSelector = page.locator('[data-testid="model-selector"]');
    const isVisible = await modelSelector.isVisible().catch(() => false);

    if (isVisible) {
      console.log('✅ Model selector found!');

      // Get trigger text
      const trigger = page.locator('[data-testid="model-selector-trigger"]');
      const triggerText = await trigger.textContent();
      console.log('📋 Model selector shows:', triggerText);

      // Test dropdown
      console.log('🔽 Testing dropdown interaction...');
      await trigger.click();
      await page.waitForTimeout(1000);

      const dropdown = page.locator('[data-testid="model-dropdown"]');
      const dropdownVisible = await dropdown.isVisible().catch(() => false);

      if (dropdownVisible) {
        console.log('✅ Dropdown opens successfully');

        // Check for options
        const serverDefault = page.locator('[data-testid="server-default-option"]');
        const hasServerDefault = await serverDefault.isVisible().catch(() => false);

        if (hasServerDefault) {
          console.log('✅ Server default option available');
        }

        const modelOptions = page.locator('[data-testid^="model-option-"]');
        const modelCount = await modelOptions.count().catch(() => 0);
        console.log(`📊 Found ${modelCount} model options`);

      } else {
        console.log('❌ Dropdown failed to open');
      }

    } else {
      console.log('❌ Model selector not found');

      // Debug: check what elements are present
      const allTestIds = await page.locator('[data-testid]').all();
      console.log('🔍 Available test IDs:');
      for (const element of allTestIds.slice(0, 10)) { // Limit to first 10
        const testId = await element.getAttribute('data-testid');
        console.log('  -', testId);
      }
    }

    console.log('🎯 Model selector verification complete');
    console.log('💡 Keep browser open for manual testing');

    // Keep browser open for manual inspection
    await page.waitForTimeout(30000);

  } catch (error) {
    console.error('❌ Verification failed:', error.message);
  } finally {
    await browser.close();
  }
}

// Run verification
verifyModelSelector();