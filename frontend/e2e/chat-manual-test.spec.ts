/**
 * Manual Chat Interface Tests
 * Simplified tests to verify basic functionality without complex setup
 */

import { test, expect } from '@playwright/test';

test.describe('Chat Interface - Manual Tests', () => {
  
  test('chat page loads successfully', async ({ page }) => {
    // Navigate directly to chat page
    await page.goto('/chat');
    
    // Wait for page to load
    await page.waitForLoadState('networkidle');
    
    // Check basic page structure
    await expect(page).toHaveTitle('OpenCode Nexus - Chat');
    
    // Check for main chat container
    const chatContainer = page.locator('.chat-container');
    await expect(chatContainer).toBeVisible();
    
    // Check for header
    const header = page.locator('.dashboard-header');
    await expect(header).toBeVisible();
    
    console.log('✅ Chat page loads successfully');
  });

  test('chat layout structure is present', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    
    // Check for session sidebar
    const sessionsSidebar = page.locator('#sessions-sidebar');
    await expect(sessionsSidebar).toBeVisible();
    
    // Check for chat root
    const chatRoot = page.locator('#chat-root');
    await expect(chatRoot).toBeVisible();
    
    // Check for offline banner component
    const offlineBanner = page.locator('global-offline-banner');
    // Note: This may not be visible but should be in DOM
    
    console.log('✅ Chat layout structure is present');
  });

  test('safe area CSS properties are applied', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    
    // Check if CSS supports env() for safe areas
    const hasEnvSupport = await page.evaluate(() => {
      const div = document.createElement('div');
      div.style.paddingTop = 'env(safe-area-inset-top)';
      return div.style.paddingTop !== '';
    });
    
    // This will be false in desktop browser, true on mobile with safe areas
    console.log(`Safe area support: ${hasEnvSupport ? 'Yes' : 'No (expected on desktop)'}`);
    
    // Check if .chat-interface has responsive classes
    const chatInterface = page.locator('[data-testid="chat-interface"]');
    if (await chatInterface.count() > 0) {
      const computedStyle = await chatInterface.evaluate((el) => {
        const style = window.getComputedStyle(el);
        return {
          display: style.display,
          flexDirection: style.flexDirection,
          height: style.height
        };
      });
      
      console.log('Chat interface computed styles:', computedStyle);
      expect(computedStyle.display).toBe('flex');
    }
    
    console.log('✅ Safe area CSS inspection complete');
  });

  test('mobile viewport responsive behavior', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 812 }); // iPhone X dimensions
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    
    // Check if sessions sidebar adapts to mobile
    const sessionsSidebar = page.locator('.sessions-sidebar');
    if (await sessionsSidebar.count() > 0) {
      const sidebarStyles = await sessionsSidebar.evaluate((el) => {
        const style = window.getComputedStyle(el);
        return {
          width: style.width,
          maxHeight: style.maxHeight,
          borderRight: style.borderRight,
          borderBottom: style.borderBottom
        };
      });
      
      console.log('Mobile sidebar styles:', sidebarStyles);
    }
    
    console.log('✅ Mobile viewport test complete');
  });

  test('keyboard accessibility', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    
    // Try tabbing through focusable elements
    await page.keyboard.press('Tab');
    let activeElement = await page.evaluate(() => document.activeElement?.tagName);
    console.log('First tab target:', activeElement);
    
    // Tab a few more times to see focus flow
    for (let i = 0; i < 5; i++) {
      await page.keyboard.press('Tab');
      activeElement = await page.evaluate(() => {
        const el = document.activeElement;
        return {
          tagName: el?.tagName,
          className: el?.className,
          testId: el?.getAttribute('data-testid')
        };
      });
      console.log(`Tab ${i + 2}:`, activeElement);
    }
    
    console.log('✅ Keyboard accessibility test complete');
  });

});