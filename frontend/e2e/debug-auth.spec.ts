import { test, expect } from '@playwright/test';

test.describe('Debug Authentication', () => {
  test('debug login flow step by step', async ({ page }) => {
    // Enable console logging
    page.on('console', msg => console.log(`BROWSER: ${msg.text()}`));
    page.on('pageerror', err => console.log(`PAGE ERROR: ${err.message}`));

    // Navigate to app
    await page.goto('/');
    console.log('✅ Navigated to app');

    // Check current URL
    const currentUrl = page.url();
    console.log(`📍 Current URL: ${currentUrl}`);

    // Try to create test user directly via Tauri commands
    console.log('🔧 Setting up test environment...');
    await page.evaluate(async () => {
      try {
        const { invoke } = await import('@tauri-apps/api/core');
        
        console.log('Completing onboarding...');
        await invoke('complete_onboarding', { 
          opencode_server_path: '/fake/test/path/opencode' 
        });
        
        console.log('Creating test user...');
        await invoke('create_owner_account', { 
          username: 'testuser', 
          password: 'SecurePass123!' 
        });
        
        console.log('✅ Test setup complete');
      } catch (error) {
        console.log(`⚠️ Setup error (may be normal): ${error.message}`);
      }
    });

    // Navigate to login page
    await page.goto('/login');
    await page.waitForLoadState('networkidle');
    console.log('📍 Navigated to login page');

    // Check if login form is visible
    await expect(page.locator('[data-testid="login-form"]')).toBeVisible();
    console.log('✅ Login form is visible');

    // Fill in credentials
    await page.fill('[data-testid="username-input"]', 'testuser');
    await page.fill('[data-testid="password-input"]', 'SecurePass123!');
    console.log('✅ Credentials filled');

    // Click login and capture any errors
    console.log('🔐 Attempting login...');
    await page.click('[data-testid="login-button"]');

    // Wait a bit for processing
    await page.waitForTimeout(2000);

    // Check current URL after login attempt
    const newUrl = page.url();
    console.log(`📍 URL after login attempt: ${newUrl}`);

    // Check for error messages
    const errorElement = page.locator('[data-testid="login-error"]');
    if (await errorElement.isVisible()) {
      const errorText = await errorElement.textContent();
      console.log(`❌ Login error displayed: ${errorText}`);
    } else {
      console.log('✅ No login error displayed');
    }

    // Check authentication status via backend
    const authStatus = await page.evaluate(async () => {
      try {
        const { invoke } = await import('@tauri-apps/api/core');
        const isConfigured = await invoke('is_auth_configured');
        console.log(`Auth configured: ${isConfigured}`);
        
        const authResult = await invoke('authenticate_user', {
          username: 'testuser',
          password: 'SecurePass123!'
        });
        console.log(`Auth result: ${authResult}`);
        
        return { isConfigured, authResult };
      } catch (error) {
        console.log(`Backend auth check failed: ${error.message}`);
        return { error: error.message };
      }
    });

    console.log('🔍 Backend auth status:', authStatus);

    // If login was successful, we should be redirected to dashboard
    if (newUrl.includes('/dashboard')) {
      console.log('✅ Login successful - redirected to dashboard');
    } else {
      console.log('❌ Login failed - still on login page');
    }
  });
});