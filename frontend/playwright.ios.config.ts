import { defineConfig, devices } from '@playwright/test';

/**
 * iOS-specific Playwright configuration for testing iOS Simulator
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false, // iOS tests should run sequentially
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 3 : 1,
  workers: 1, // Single worker for iOS tests
  timeout: 60000, // Longer timeout for iOS
  expect: {
    timeout: 10000, // Longer timeout for assertions
  },

  reporter: [
    ['html'],
    ['list'],
    ['junit', { outputFile: 'test-results/ios-junit.xml' }]
  ],

  use: {
    baseURL: 'http://localhost:4321',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // iOS-specific settings
    isMobile: true,
    hasTouch: true,
    // Simulate iOS device characteristics
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    viewport: { width: 390, height: 844 }, // iPhone 14 dimensions
    deviceScaleFactor: 3,
    // Slower actions for mobile
    actionTimeout: 15000,
  },

  projects: [
    {
      name: 'ios-simulator',
      use: {
        ...devices['iPhone 14'],
        // Additional iOS-specific settings
        launchOptions: {
          args: [
            '--disable-web-security',
            '--disable-features=VizDisplayCompositor',
            '--ignore-certificate-errors',
          ],
        },
      },
    },
  ],

  // No webServer for iOS - we'll launch the app directly
});