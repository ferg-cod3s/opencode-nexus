import { chromium } from '@playwright/test';

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable console logging
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  
  await page.goto('http://localhost:4321/chat');
  await page.waitForLoadState('networkidle');
  
  console.log('✅ Page loaded');
  
  // Check if interface rendered
  const interfaceVisible = await page.locator('[data-testid="chat-interface"]').isVisible();
  console.log('Chat interface visible:', interfaceVisible);
  
  // Check active session in store
  const activeSession = await page.evaluate(() => {
    return window.__DEBUG_ACTIVE_SESSION__;
  });
  console.log('Active session from window:', activeSession);
  
  // Fill and send message
  console.log('✍️  Typing message...');
  await page.fill('.message-input-container textarea', 'Hello test');
  await page.click('button[data-testid="send-button"]');
  
  // Wait a bit for reactivity
  await page.waitForTimeout(2000);
  
  // Check message count
  const messageCount = await page.locator('.message-bubble').count();
  console.log('Message bubble count:', messageCount);
  
  // Check what's in the DOM
  const messagesHTML = await page.locator('.messages-container').innerHTML();
  console.log('Messages container HTML:', messagesHTML.substring(0, 500));
  
  await browser.close();
})();
