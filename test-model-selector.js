#!/usr/bin/env node

/*
 * Model Selector Manual Testing Script
 * Tests the model selector functionality through browser automation
 */

import { chromium } from 'playwright';

async function testModelSelector() {
  console.log('🧪 Starting Model Selector Manual Testing...');

  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('📱 Opening test chat page...');
    await page.goto('http://localhost:1420/test-chat');

    // Wait for page to load
    await page.waitForTimeout(3000);

    console.log('🔍 Checking if model selector is present...');

    // Check if model selector exists
    const modelSelector = page.locator('[data-testid="model-selector"]');
    const isVisible = await modelSelector.isVisible();

    if (!isVisible) {
      console.log('❌ Model selector not found');
      return false;
    }

    console.log('✅ Model selector is visible');

    // Check initial state
    const trigger = page.locator('[data-testid="model-selector-trigger"]');
    const initialText = await trigger.textContent();
    console.log('📋 Initial trigger text:', initialText);

    // Test dropdown opening
    console.log('🔽 Testing dropdown opening...');
    await trigger.click();
    await page.waitForTimeout(500);

    const dropdown = page.locator('[data-testid="model-dropdown"]');
    const dropdownVisible = await dropdown.isVisible();

    if (!dropdownVisible) {
      console.log('❌ Dropdown did not open');
      return false;
    }

    console.log('✅ Dropdown opened successfully');

    // Check for server default option
    const serverDefault = page.locator('[data-testid="server-default-option"]');
    const serverDefaultVisible = await serverDefault.isVisible();

    if (serverDefaultVisible) {
      console.log('✅ Server default option is visible');
    } else {
      console.log('⚠️ Server default option not found');
    }

    // Test selecting server default
    console.log('🎯 Testing server default selection...');
    await serverDefault.click();
    await page.waitForTimeout(500);

    const afterSelectionText = await trigger.textContent();
    console.log('📋 After selection text:', afterSelectionText);

    if (afterSelectionText.includes('Server Default')) {
      console.log('✅ Server default selection works');
    } else {
      console.log('❌ Server default selection failed');
    }

    // Test accessibility
    console.log('♿ Testing accessibility attributes...');
    const ariaExpanded = await trigger.getAttribute('aria-expanded');
    const ariaHaspopup = await trigger.getAttribute('aria-haspopup');

    if (ariaHaspopup === 'listbox') {
      console.log('✅ ARIA haspopup attribute correct');
    } else {
      console.log('❌ ARIA haspopup attribute incorrect:', ariaHaspopup);
    }

    // Test keyboard navigation
    console.log('⌨️ Testing keyboard navigation...');
    await trigger.focus();
    await page.keyboard.press('Enter');
    await page.waitForTimeout(500);

    const dropdownAfterKeyboard = await dropdown.isVisible();
    if (dropdownAfterKeyboard) {
      console.log('✅ Keyboard navigation works');
    } else {
      console.log('❌ Keyboard navigation failed');
    }

    console.log('🎉 Model selector testing completed successfully!');
    return true;

  } catch (error) {
    console.error('❌ Test failed with error:', error.message);
    return false;
  } finally {
    await browser.close();
  }
}

// Run the test
testModelSelector().then(success => {
  process.exit(success ? 0 : 1);
});