/**
 * Debug Chat Loading Issues
 */

import { test, expect } from '@playwright/test';

test('debug chat page DOM structure', async ({ page }) => {
  // Capture console logs
  const consoleLogs = [];
  page.on('console', msg => consoleLogs.push(`${msg.type()}: ${msg.text()}`));
  
  await page.goto('/chat');
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(3000); // Wait for any async loading
  
  // Get full DOM structure of chat-root
  const chatRootContent = await page.locator('#chat-root').innerHTML();
  console.log('Chat root HTML content:');
  console.log(chatRootContent);
  
  // Check for any error elements
  const errorElements = await page.locator('.error-state').count();
  console.log('Error elements found:', errorElements);
  
  // Check if loading state exists but is hidden
  const loadingStateExists = await page.locator('#loading-state').count();
  const loadingStateVisible = await page.locator('#loading-state').isVisible();
  console.log('Loading state - exists:', loadingStateExists, 'visible:', loadingStateVisible);
  
  // Check for connection required elements
  const connectionRequiredExists = await page.locator('.connection-required').count();
  console.log('Connection required elements:', connectionRequiredExists);
  
  // Check console logs for errors
  console.log('Console logs:', consoleLogs.slice(-10)); // Last 10 logs
  
  // Check if scripts are loading
  const scriptTags = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('script')).map(s => ({
      src: s.src,
      type: s.type,
      hasContent: s.innerHTML.length > 0
    }));
  });
  
  console.log('Script tags loaded:', scriptTags.slice(-5)); // Last 5 scripts
  
  // Check global state
  const globalState = await page.evaluate(() => {
    return {
      windowMeta: {
        location: window.location.href,
        userAgent: navigator.userAgent.includes('Chrome') ? 'Chrome' : 'Other'
      },
      hasAstro: typeof window.__astro !== 'undefined',
      hasSentry: typeof window.Sentry !== 'undefined',
      hasInvoke: typeof window.__TAURI__ !== 'undefined',
      documentReady: document.readyState
    };
  });
  
  console.log('Global state:', globalState);
});

test('debug chat initialization process', async ({ page }) => {
  let initLogs = [];
  
  // Capture all console messages
  page.on('console', msg => {
    const text = msg.text();
    if (text.includes('Chat') || text.includes('🔍') || text.includes('ERROR') || text.includes('WARN')) {
      initLogs.push(`${msg.type()}: ${text}`);
    }
  });
  
  await page.goto('/chat');
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(5000); // Wait longer for initialization
  
  console.log('Chat initialization logs:');
  initLogs.forEach(log => console.log(log));
  
  // Check if DOMContentLoaded fired
  const domState = await page.evaluate(() => {
    return {
      readyState: document.readyState,
      hasUsername: !!sessionStorage.getItem('username'),
      chatInitialized: window.chatInitialized || false
    };
  });
  
  console.log('DOM state:', domState);
  
  // Try to trigger chat initialization manually
  const manualInit = await page.evaluate(() => {
    try {
      // Check if initializeChat function exists
      if (typeof window.initializeChat === 'function') {
        window.initializeChat();
        return 'Manually triggered initializeChat()';
      } else {
        return 'initializeChat function not found';
      }
    } catch (error) {
      return `Manual init error: ${error.message}`;
    }
  });
  
  console.log('Manual initialization attempt:', manualInit);
});