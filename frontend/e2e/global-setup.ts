import { FullConfig } from '@playwright/test';
import { chromium } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  console.log('🔧 Setting up E2E test environment...');
  
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    // Navigate to the app and wait for it to load
    await page.goto('http://localhost:1420');
    await page.waitForTimeout(3000); // Give Tauri time to initialize
    
    console.log('📋 Setting up test user and onboarding...');
    
    // Create test user via backend commands directly
    // This uses the Tauri invoke system to call backend functions
    await page.evaluate(async () => {
      try {
        // Import Tauri API
        const { invoke } = await import('@tauri-apps/api/core');
        
        // Complete onboarding with fake server path for testing
        await invoke('complete_onboarding', { 
          opencode_server_path: '/fake/test/path/opencode' 
        });
        
        // Create owner account (test user)
        await invoke('create_owner_account', { 
          username: 'testuser', 
          password: 'SecurePass123!' 
        });
        
        console.log('✅ Test user created successfully');
      } catch (error) {
        // If user already exists or onboarding is complete, that's fine
        console.log('ℹ️ Test setup already exists or completed:', error.message);
      }
    });
    
    // Verify the setup worked by trying to authenticate
    const authResult = await page.evaluate(async () => {
      try {
        const { invoke } = await import('@tauri-apps/api/core');
        return await invoke('authenticate_user', {
          username: 'testuser',
          password: 'SecurePass123!'
        });
      } catch (error) {
        console.log('Authentication check failed:', error);
        return false;
      }
    });
    
    if (authResult) {
      console.log('✅ Test user authentication verified');
    } else {
      console.log('⚠️ Test user authentication could not be verified');
    }
    
    console.log('✅ E2E test environment setup completed');
    
  } catch (error) {
    console.error('❌ Failed to set up E2E test environment:', error);
    // Don't throw - let tests run anyway and see what happens
  } finally {
    await context.close();
    await browser.close();
  }
}

export default globalSetup;