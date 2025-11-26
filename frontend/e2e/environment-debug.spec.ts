/**
 * Debug Environment Detection
 */

import { test, expect } from '@playwright/test';

test('debug environment detection', async ({ page }) => {
  await page.goto('/chat');
  await page.waitForLoadState('networkidle');
  
  const envInfo = await page.evaluate(() => {
    return {
      userAgent: navigator.userAgent,
      hasPlaywright: 'playwright' in window,
      hasWebdriver: 'webdriver' in navigator,
      windowKeys: Object.keys(window).filter(k => k.includes('playwright') || k.includes('webdriver') || k.includes('phantom')),
      location: window.location.href,
      process: typeof process !== 'undefined' ? {
        env: process.env?.NODE_ENV || 'undefined'
      } : 'no process'
    };
  });
  
  console.log('Environment info:', envInfo);
  
  // Try to import and run environment detection
  const envDetection = await page.evaluate(async () => {
    try {
      // Try to access the environment detection functions
      const envModule = await import('/src/utils/environment.ts');
      const apiModule = await import('/src/utils/tauri-api.ts');
      
      const envInfo = envModule.getEnvironmentInfo();
      const checkResult = apiModule.checkEnvironment();
      
      return {
        success: true,
        envInfo,
        checkResult,
        detectAppMode: envModule.detectAppMode()
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  });
  
  console.log('Environment detection result:', envDetection);
});