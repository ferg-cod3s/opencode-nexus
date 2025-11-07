import type { FullConfig } from '@playwright/test';
import { chromium } from '@playwright/test';

async function globalSetup(_config: FullConfig) {
  console.log('🔧 Setting up E2E test environment...');

  // Skip the complex setup for now - individual tests will handle their own setup
  console.log('✅ E2E test environment setup completed (simplified)');
}

export default globalSetup;