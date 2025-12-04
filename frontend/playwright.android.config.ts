import { defineConfig, devices } from '@playwright/test';

/**
 * Android-specific Playwright configuration for testing Android Emulator
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false, // Android tests should run sequentially
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 3 : 1,
  workers: 1, // Single worker for Android tests
  timeout: 60000, // Longer timeout for Android
  expect: {
    timeout: 10000, // Longer timeout for assertions
  },

  reporter: [
    ['html'],
    ['list'],
    ['junit', { outputFile: 'test-results/android-junit.xml' }]
  ],

  use: {
    baseURL: 'http://localhost:4321',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // Android-specific settings
    isMobile: true,
    hasTouch: true,
    // Simulate Android device characteristics
    userAgent: 'Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
    viewport: { width: 360, height: 780 }, // Samsung Galaxy S23 dimensions
    deviceScaleFactor: 3,
    // Slower actions for mobile
    actionTimeout: 15000,
  },

  projects: [
    {
      name: 'android-emulator',
      use: {
        ...devices['Galaxy S23'],
        // Additional Android-specific settings
        launchOptions: {
          args: [
            '--disable-web-security',
            '--disable-features=VizDisplayCompositor',
            '--ignore-certificate-errors',
            '--disable-blink-features=AutomationControlled',
          ],
        },
      },
    },
  ],

  // No webServer for Android - we'll launch app directly
});