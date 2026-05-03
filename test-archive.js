const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  const networkRequests = [];
  page.on('request', request => {
    networkRequests.push({
      url: request.url(),
      method: request.method(),
      postData: request.postData(),
      resourceType: request.resourceType()
    });
  });
  
  page.on('response', response => {
    const req = response.request();
    const idx = networkRequests.findIndex(r => r.url === req.url());
    if (idx !== -1) {
      networkRequests[idx].status = response.status();
      networkRequests[idx].statusText = response.statusText();
    }
  });
  
  console.log('Opening http://localhost:8080...');
  await page.goto('http://localhost:8080', { waitUntil: 'networkidle' });
  
  await page.waitForTimeout(2000);
  
  console.log('\n--- Looking for session list and archive buttons ---');
  const sessions = await page.locator('text=archive').count();
  console.log(`Found ${sessions} elements containing "archive":`);
  
  const allLinks = await page.locator('a').all();
  for (const link of allLinks) {
    const text = await link.textContent();
    const href = await link.getAttribute('href');
    if (text && text.toLowerCase().includes('archive')) {
      console.log(`  Link text: "${text.trim()}" href: ${href}`);
    }
  }
  
  const buttons = await page.locator('button').all();
  for (const btn of buttons) {
    const text = await btn.textContent();
    const aria = await btn.getAttribute('aria-label');
    if (text && text.toLowerCase().includes('archive')) {
      console.log(`  Button text: "${text.trim()}" aria-label: ${aria}`);
    }
  }
  
  console.log('\n--- All POST/PATCH/DELETE requests ---');
  for (const req of networkRequests) {
    if (['POST', 'PATCH', 'DELETE', 'PUT'].includes(req.method)) {
      console.log(`${req.method} ${req.url}`);
    }
  }
  
  console.log('\n--- Clicking first archive button found ---');
  const archiveBtn = page.locator('button:has-text("archive"), a:has-text("archive")').first();
  if (await archiveBtn.isVisible()) {
    await archiveBtn.click();
    await page.waitForTimeout(3000);
  }
  
  console.log('\n--- Network requests AFTER clicking archive ---');
  for (const req of networkRequests) {
    const urlLower = req.url.toLowerCase();
    if (urlLower.includes('archive') || urlLower.includes('session')) {
      console.log(`${req.method} ${req.url}`);
      if (req.postData) {
        console.log(`  Body: ${req.postData}`);
      }
      if (req.status) {
        console.log(`  Status: ${req.status}`);
      }
    }
  }
  
  await browser.close();
})();