/**
 * Debug Chat Initialization Flow
 * Step-by-step debugging to find where initialization fails
 */

import { test, expect } from '@playwright/test';

test('debug initialization step by step', async ({ page }) => {
  // Capture all console messages in order
  const logs = [];
  page.on('console', msg => {
    const text = msg.text();
    logs.push(`${msg.type()}: ${text}`);
  });

  // Capture any errors
  const errors = [];
  page.on('pageerror', error => {
    errors.push(error.message);
  });

  await page.goto('/chat');
  await page.waitForLoadState('networkidle');
  
  // Wait for initialization to complete (or timeout)
  await page.waitForTimeout(10000);
  
  console.log('\n=== PAGE ERRORS ===');
  if (errors.length > 0) {
    errors.forEach(error => console.log('ERROR:', error));
  } else {
    console.log('No page errors detected');
  }
  
  console.log('\n=== CONSOLE LOGS (Initialization Related) ===');
  const chatLogs = logs.filter(log => 
    log.includes('Chat') || 
    log.includes('🔍') || 
    log.includes('Initialize') ||
    log.includes('ERROR') ||
    log.includes('WARN') ||
    log.includes('Failed') ||
    log.includes('DOMContentLoaded')
  );
  
  chatLogs.forEach((log, index) => {
    console.log(`${index + 1}. ${log}`);
  });
  
  console.log('\n=== DOM STATE AFTER INITIALIZATION ===');
  
  const domState = await page.evaluate(() => {
    const chatRoot = document.getElementById('chat-root');
    const loadingState = document.getElementById('loading-state');
    const connectionRequired = document.querySelector('.connection-required');
    const chatInterface = document.querySelector('[data-testid="chat-interface"]');
    
    return {
      chatRootExists: !!chatRoot,
      chatRootContent: chatRoot?.innerHTML?.substring(0, 200) || 'not found',
      loadingStateExists: !!loadingState,
      loadingStateVisible: loadingState ? !loadingState.hidden && 
        getComputedStyle(loadingState).display !== 'none' : false,
      connectionRequiredExists: !!connectionRequired,
      chatInterfaceExists: !!chatInterface,
      documentReady: document.readyState,
      scriptsLoaded: document.querySelectorAll('script').length,
      hasInitFunction: typeof (window as any).initializeChat === 'function'
    };
  });
  
  console.log('DOM State:', JSON.stringify(domState, null, 2));
  
  console.log('\n=== MANUAL SCRIPT EXECUTION TEST ===');
  
  // Try to manually trigger what should happen
  const manualTest = await page.evaluate(() => {
    try {
      // Check if the loading state can be manually removed
      const loadingState = document.getElementById('loading-state');
      if (loadingState) {
        loadingState.remove();
        return 'Successfully removed loading state manually';
      } else {
        return 'Loading state not found for manual removal';
      }
    } catch (error) {
      return `Manual removal failed: ${error.message}`;
    }
  });
  
  console.log('Manual test result:', manualTest);
  
  // Check final state after manual intervention
  const finalState = await page.evaluate(() => {
    return {
      loadingStateStillExists: !!document.getElementById('loading-state'),
      chatRootFinalContent: document.getElementById('chat-root')?.innerHTML?.substring(0, 100)
    };
  });
  
  console.log('\n=== FINAL STATE ===');
  console.log('Final state:', finalState);
  
  // The test should help us understand what's happening
  expect(logs.length).toBeGreaterThan(0); // At least some logs should exist
});