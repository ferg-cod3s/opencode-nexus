import { describe, test, expect } from 'bun:test';
import {
  getIOSInstallInstructions,
  getPWASupport,
  getOptimalPromptTiming
} from '../utils/pwa-utils.js';

describe('PWA Utils', () => {
  test('getIOSInstallInstructions returns iOS installation instructions', () => {
    const instructions = getIOSInstallInstructions();
    expect(instructions).toContain('Share button');
    expect(instructions).toContain('Add to Home Screen');
    expect(instructions).toContain('home screen');
  });

  test('getPWASupport returns PWA support capabilities', () => {
    // Mock window and navigator for this test
    global.window = {
      onbeforeinstallprompt: true,
      navigator: { standalone: true }
    } as any;
    global.navigator = { serviceWorker: true } as any;
    global.document = { createElement: () => ({}) } as any;

    const support = getPWASupport();
    expect(typeof support.serviceWorker).toBe('boolean');
    expect(typeof support.beforeInstallPrompt).toBe('boolean');
    expect(typeof support.standalone).toBe('boolean');
    expect(typeof support.manifest).toBe('boolean');
  });

  test('getOptimalPromptTiming returns 45 seconds for iOS', () => {
    const platform = { platform: 'ios' as const, canInstall: true, installMethod: 'manual' as const };
    expect(getOptimalPromptTiming(platform)).toBe(45000);
  });

  test('getOptimalPromptTiming returns 30 seconds for Android', () => {
    const platform = { platform: 'android' as const, canInstall: true, installMethod: 'native' as const };
    expect(getOptimalPromptTiming(platform)).toBe(30000);
  });

  test('getOptimalPromptTiming returns 60 seconds for desktop', () => {
    const platform = { platform: 'desktop' as const, canInstall: false, installMethod: 'none' as const };
    expect(getOptimalPromptTiming(platform)).toBe(60000);
  });
});