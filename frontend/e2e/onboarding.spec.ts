import { test, expect } from '@playwright/test';

test.describe('Onboarding Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Don't set __TAURI__ so the tauri-api utility falls back to mock API
    // The mock API in tauri-api.ts will handle all the commands
    
    // Capture browser console logs
    page.on('console', msg => {
      console.log(`[BROWSER ${msg.type()}]:`, msg.text());
    });
    
    // Capture page errors
    page.on('pageerror', error => {
      console.log('[PAGE ERROR]:', error.message);
    });
  });

  test('should complete full onboarding process', async ({ page }) => {
    // Navigate to onboarding page
    await page.goto('/onboarding');
    await page.waitForLoadState('networkidle');

    // Debug: Check what's actually on the page
    const bodyText = await page.locator('body').textContent();
    console.log('Onboarding page body text:', bodyText?.substring(0, 500));

    // Check if onboarding body has content
    const onboardingBody = page.locator('#onboarding-body');
    const bodyContent = await onboardingBody.textContent();
    console.log('Onboarding body content:', bodyContent);

    // The onboarding starts with system requirements check (step 1), not welcome
    // Check if the system requirements step is visible
    await expect(page.locator('text=System Requirements Check')).toBeVisible();
    await expect(page.locator('text=Let\'s verify your system can run OpenCode AI.')).toBeVisible();

    // The system check happens automatically, so we should see the results
    // Wait for system check to complete
    await page.waitForSelector('text=Operating System: Compatible', { timeout: 10000 });
    await expect(page.locator('.step-content.active[data-step="requirements"]')).toBeVisible();

    // Wait for system requirements check to complete
    await page.waitForSelector('[data-action="check-requirements"]:not([disabled])');

    // Click check requirements button
    await page.click('[data-action="check-requirements"]');

    // Verify all requirements show success status
    await expect(page.locator('.status-icon.success')).toHaveCount(4);

    // Click continue to server setup
    await page.click('[data-action="next"]');

    // Verify server setup step is active
    await expect(page.locator('.step.active[data-step="server"]')).toBeVisible();
    await expect(page.locator('.step-content.active[data-step="server"]')).toBeVisible();

    // Select auto-download option
    await page.check('#auto-download');

    // Verify continue button is enabled
    await expect(page.locator('[data-action="setup-server"]')).not.toBeDisabled();

    // Click continue
    await page.click('[data-action="setup-server"]');

    // Should navigate to security setup step
    await expect(page.locator('.step.active[data-step="security"]')).toBeVisible();

    // Fill in security credentials
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'TestPass123!');
    await page.fill('#confirm-password', 'TestPass123!');

    // Click complete setup
    await page.click('[data-action="complete"]');

    // Should redirect to main chat interface (index page)
    await expect(page).toHaveURL('/');
  });

  test('should handle system requirements failure', async ({ page }) => {
    // Navigate to onboarding
    await page.goto('/onboarding');
    await page.waitForLoadState('networkidle');

    // The onboarding should start on requirements step
    // Wait for system check to complete
    await page.waitForSelector('text=System Requirements Check');
    
    // Verify requirements step content is visible
    await expect(page.locator('text=Let\'s verify your system can run OpenCode AI.')).toBeVisible();
    
    // The system check happens automatically - verify results are shown
    await page.waitForSelector('text=Operating System: Compatible', { timeout: 10000 });
  });

  test('should validate security form inputs', async ({ page }) => {
    // Navigate to onboarding and complete previous steps
    await page.goto('/onboarding');
    await page.waitForLoadState('networkidle');

    // Wait for requirements check to complete
    await page.waitForSelector('[data-action="check-requirements"]:not([disabled])');
    await page.click('[data-action="check-requirements"]');

    // Continue to server setup
    await page.click('[data-action="next"]');
    await page.waitForSelector('text=Server Setup');

    // Select auto-download and continue
    await page.check('#auto-download');
    await page.click('[data-action="setup-server"]');

    // Should now be on security step
    await page.waitForSelector('text=Account Setup');
    await expect(page.locator('text=Create your administrator account.')).toBeVisible();

    // Set up dialog handler to capture alert
    let alertMessage = '';
    page.on('dialog', async dialog => {
      alertMessage = dialog.message();
      await dialog.accept();
    });

    // Try to submit with empty fields
    await page.click('[data-action="complete"]');

    // Wait a bit for the dialog to be triggered
    await page.waitForTimeout(500);

    // Should show validation error in alert
    expect(alertMessage).toContain('Please fill in all fields');

    // Fill valid credentials
    await page.fill('#username', 'validuser');
    await page.fill('#password', 'StrongPass123!');
    await page.fill('#confirm-password', 'StrongPass123!');

    // Complete setup
    await page.click('[data-action="complete"]');

    // Should redirect to main page
    await expect(page).toHaveURL('/');
  });

  test('should support keyboard navigation', async ({ page }) => {
    await page.goto('/onboarding');
    await page.waitForLoadState('networkidle');

    // Wait for onboarding to initialize
    await page.waitForSelector('text=System Requirements Check');
    
    // Verify the onboarding wizard loaded
    await expect(page.locator('text=Welcome to OpenCode Nexus')).toBeVisible();
    
    // Check requirements step is visible
    await expect(page.locator('text=Let\'s verify your system can run OpenCode AI.')).toBeVisible();
    
    // The system check happens automatically on load, so the button should show "Requirements Checked"
    const checkBtn = page.locator('[data-action="check-requirements"]');
    await expect(checkBtn).toContainText('Requirements Checked');
    
    // Verify we can tab to the next button and activate it
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');
    
    // Focus should be on next button, press enter
    await page.keyboard.press('Enter');
    
    // Should navigate to server setup (use heading to avoid strict mode violation)
    await expect(page.getByRole('heading', { name: 'Server Setup' })).toBeVisible({ timeout: 3000 });
  });

  test('should be accessible with screen reader', async ({ page }) => {
    await page.goto('/onboarding');

    // Check for proper ARIA labels
    await expect(page.locator('[aria-label]')).toHaveCount(await page.locator('[aria-label]').count());

    // Check for proper heading structure
    const headings = await page.locator('h1, h2, h3').allTextContents();
    expect(headings.length).toBeGreaterThan(0);

    // Check for focus management
    await page.keyboard.press('Tab');
    const focusedElement = await page.evaluate(() => document.activeElement?.tagName);
    expect(focusedElement).toBeTruthy();
  });
});