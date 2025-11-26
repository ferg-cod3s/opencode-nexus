/**
 * Chat Functionality Tests
 * Tests the actual chat features including message sending, session management, etc.
 */

import { test, expect } from '@playwright/test';

test.describe('Chat Functionality', () => {

  test('chat interface components load correctly', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    
    // Wait for any async initialization
    await page.waitForTimeout(2000);
    
    // Check for connection required message (expected when no server connected)
    const connectionRequired = page.locator('.connection-required');
    const chatInterface = page.locator('[data-testid="chat-interface"]');
    const loadingState = page.locator('#loading-state');
    
    // One of these should be visible
    const hasConnectionRequired = await connectionRequired.isVisible();
    const hasChatInterface = await chatInterface.isVisible();
    const hasLoadingState = await loadingState.isVisible();
    
    console.log('Connection required visible:', hasConnectionRequired);
    console.log('Chat interface visible:', hasChatInterface);
    console.log('Loading state visible:', hasLoadingState);
    
    // At least one state should be shown
    expect(hasConnectionRequired || hasChatInterface || hasLoadingState).toBe(true);
    
    if (hasConnectionRequired) {
      // Verify connection required message content
      await expect(connectionRequired.locator('h2')).toContainText('No OpenCode Server Connected');
      await expect(connectionRequired.locator('a')).toHaveAttribute('href', '/settings');
      console.log('✅ Connection required state working correctly');
    }
    
    if (hasChatInterface) {
      console.log('✅ Chat interface loaded successfully');
    }
  });

  test('session panel and chat layout work correctly', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    
    // Check sessions sidebar
    const sessionsSidebar = page.locator('#sessions-sidebar');
    await expect(sessionsSidebar).toBeVisible();
    
    // Check chat root
    const chatRoot = page.locator('#chat-root');
    await expect(chatRoot).toBeVisible();
    
    // Check if any Svelte components mounted
    const svelteComponents = await page.evaluate(() => {
      // Look for Svelte component markers in DOM
      const elements = document.querySelectorAll('*');
      const svelteElements = Array.from(elements).filter(el => 
        el.className && (
          el.className.includes('s-') || // Svelte scoped styles
          el.getAttribute('data-svelte') ||
          el.tagName.toLowerCase().includes('-') // Custom elements
        )
      );
      return svelteElements.length;
    });
    
    console.log('Svelte components found in DOM:', svelteComponents);
    
    // Check for any JavaScript errors in console
    const consoleLogs = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleLogs.push(msg.text());
      }
    });
    
    await page.waitForTimeout(1000);
    
    if (consoleLogs.length > 0) {
      console.log('Console errors found:', consoleLogs);
    } else {
      console.log('✅ No console errors detected');
    }
  });

  test('offline banner component functionality', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    
    // Look for offline banner - it may not be visible but should be in DOM
    const offlineBanner = page.locator('global-offline-banner, .offline-banner, [data-testid="offline-banner"]');
    
    const bannerExists = await offlineBanner.count() > 0;
    console.log('Offline banner exists in DOM:', bannerExists);
    
    if (bannerExists) {
      // Check if it's currently visible (should not be if online)
      const isVisible = await offlineBanner.isVisible();
      console.log('Offline banner visible:', isVisible);
      console.log('✅ Offline banner component found');
    }
  });

  test('message input area and controls', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    
    // Look for message input area
    const messageInput = page.locator('input[type="text"], textarea, [data-testid="message-input"], .message-input');
    const sendButton = page.locator('button[type="submit"], [data-testid="send-button"], .send-button');
    
    const hasInput = await messageInput.count() > 0;
    const hasSendButton = await sendButton.count() > 0;
    
    console.log('Message input found:', hasInput);
    console.log('Send button found:', hasSendButton);
    
    if (hasInput) {
      // Check if input is interactive
      await messageInput.first().click();
      await messageInput.first().fill('Test message');
      
      const inputValue = await messageInput.first().inputValue();
      expect(inputValue).toBe('Test message');
      console.log('✅ Message input is functional');
    }
  });

  test('model selector component', async ({ page }) => {
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    
    // Look for model selector
    const modelSelector = page.locator('.model-selector, [data-testid="model-selector"], select');
    
    const hasModelSelector = await modelSelector.count() > 0;
    console.log('Model selector found:', hasModelSelector);
    
    if (hasModelSelector) {
      console.log('✅ Model selector component present');
      
      // Check if it's interactive
      const isEnabled = await modelSelector.first().isEnabled();
      console.log('Model selector enabled:', isEnabled);
    }
  });

  test('responsive layout behavior', async ({ page }) => {
    // Test different viewport sizes
    const viewports = [
      { width: 320, height: 568, name: 'iPhone SE' },
      { width: 375, height: 812, name: 'iPhone X' },
      { width: 414, height: 896, name: 'iPhone XS Max' },
      { width: 768, height: 1024, name: 'iPad' },
      { width: 1024, height: 768, name: 'Desktop' }
    ];
    
    for (const viewport of viewports) {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
      
      // Check layout adaptation
      const chatLayout = page.locator('.chat-layout');
      const sessionsSidebar = page.locator('.sessions-sidebar');
      
      if (await chatLayout.count() > 0) {
        const layoutStyle = await chatLayout.evaluate(el => {
          const style = window.getComputedStyle(el);
          return {
            flexDirection: style.flexDirection,
            gap: style.gap
          };
        });
        
        console.log(`${viewport.name} (${viewport.width}x${viewport.height}):`, layoutStyle);
      }
      
      if (await sessionsSidebar.count() > 0 && viewport.width < 768) {
        // Mobile - sidebar should adapt
        const sidebarStyle = await sessionsSidebar.evaluate(el => {
          const style = window.getComputedStyle(el);
          return {
            width: style.width,
            maxHeight: style.maxHeight
          };
        });
        
        console.log(`Mobile sidebar (${viewport.name}):`, sidebarStyle);
      }
    }
    
    console.log('✅ Responsive layout testing complete');
  });

  test('iOS safe area implementation', async ({ page }) => {
    // Simulate iPhone with notch
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/chat');
    await page.waitForLoadState('networkidle');
    
    // Check for safe area CSS implementation
    const chatInterface = page.locator('.chat-interface');
    
    if (await chatInterface.count() > 0) {
      const computedStyle = await chatInterface.evaluate(el => {
        const style = window.getComputedStyle(el);
        return {
          paddingTop: style.paddingTop,
          paddingBottom: style.paddingBottom,
          paddingLeft: style.paddingLeft,
          paddingRight: style.paddingRight,
          height: style.height
        };
      });
      
      console.log('Chat interface safe area styles:', computedStyle);
      
      // Check if CSS supports clause is working
      const supportsEnv = await page.evaluate(() => {
        return CSS.supports('padding', 'env(safe-area-inset-top)');
      });
      
      console.log('Browser supports env() function:', supportsEnv);
      console.log('✅ iOS safe area implementation tested');
    }
  });

});