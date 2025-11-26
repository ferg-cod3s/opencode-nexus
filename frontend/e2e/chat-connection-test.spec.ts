/**
 * Test Connection Required State
 */

import { test, expect } from '@playwright/test';

test('connection required state shows correctly', async ({ page }) => {
  await page.goto('/chat');
  await page.waitForLoadState('networkidle');
  
  // Wait longer for async initialization to complete
  await page.waitForTimeout(8000);
  
  // Check what's in chat-root after full initialization
  const chatRootContent = await page.locator('#chat-root').innerHTML();
  console.log('Final chat root content:');
  console.log(chatRootContent.substring(0, 500)); // First 500 chars
  
  // Check specifically for connection required elements
  const connectionRequired = page.locator('.connection-required');
  const connectionRequiredCount = await connectionRequired.count();
  const connectionRequiredVisible = connectionRequiredCount > 0 ? await connectionRequired.isVisible() : false;
  
  console.log('Connection required count:', connectionRequiredCount);
  console.log('Connection required visible:', connectionRequiredVisible);
  
  // Check for loading state
  const loadingState = page.locator('#loading-state');
  const loadingStateCount = await loadingState.count();
  const loadingStateVisible = loadingStateCount > 0 ? await loadingState.isVisible() : false;
  
  console.log('Loading state count:', loadingStateCount);
  console.log('Loading state visible:', loadingStateVisible);
  
  // Check for chat interface
  const chatInterface = page.locator('[data-testid="chat-interface"]');
  const chatInterfaceCount = await chatInterface.count();
  const chatInterfaceVisible = chatInterfaceCount > 0 ? await chatInterface.isVisible() : false;
  
  console.log('Chat interface count:', chatInterfaceCount);
  console.log('Chat interface visible:', chatInterfaceVisible);
  
  // The app should show either connection required OR a working chat interface
  // Loading state should not persist after initialization
  if (connectionRequiredVisible) {
    console.log('✅ Connection required state is properly shown');
    expect(connectionRequiredVisible).toBe(true);
  } else if (chatInterfaceVisible && !loadingStateVisible) {
    console.log('✅ Chat interface is working (no connection issues)');
    expect(chatInterfaceVisible).toBe(true);
  } else {
    console.log('❌ App is stuck in loading state or has other issues');
    expect.fail('App should show either connection required state or working chat interface, not loading state');
  }
});