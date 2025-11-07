const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Enable console logging
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  
  await page.goto('http://localhost:4321/chat');
  await page.waitForLoadState('networkidle');
  
  console.log('📸 Taking initial screenshot...');
  await page.screenshot({ path: 'test-initial.png', fullPage: true });
  
  // Fill and send message
  console.log('✍️  Typing message...');
  await page.fill('.message-input-container textarea', 'Hello test');
  await page.click('button[data-testid="send-button"]');
  
  // Wait a bit for reactivity
  await page.waitForTimeout(1000);
  
  console.log('📸 Taking after-send screenshot...');
  await page.screenshot({ path: 'test-after-send.png', fullPage: true });
  
  // Check what's in the DOM
  const messagesHTML = await page.locator('.messages-container').innerHTML();
  console.log('Messages container HTML:', messagesHTML);
  
  await browser.close();
})();
