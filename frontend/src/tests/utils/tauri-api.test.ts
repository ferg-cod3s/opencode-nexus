import { describe, test, expect, mock } from 'bun:test';

// Force environment module to report test environment
mock.module('../../utils/environment', () => ({
  getEnvironmentInfo: () => ({
    appMode: 'test',
    connectionMode: 'proxy',
    isTauri: false,
    isDevelopment: false,
    isProduction: false,
    isTest: true,
    devServerUrl: undefined,
    tauriVersion: undefined
  }),
  shouldEnableAuthentication: () => false
}));

// Minimal browser-like globals for mock APIs
const mockLocalStorage = (() => {
  let store: Record<string, string> = {};

  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value.toString();
    },
    removeItem: (key: string) => {
      delete store[key];
    },
    clear: () => {
      store = {};
    },
    key: (index: number) => Object.keys(store)[index] || null,
    get length() {
      return Object.keys(store).length;
    }
  };
})();

(globalThis as any).localStorage = mockLocalStorage;
(globalThis as any).window = (globalThis as any).window || {
  addEventListener: () => {},
  dispatchEvent: () => {},
  location: {
    hostname: 'localhost',
    port: '1420',
    protocol: 'http:'
  }
};

import { invoke } from '../../utils/tauri-api';

describe('tauri-api invoke behavior (test environment)', () => {
  test('uses mock API for known commands in test environment', async () => {
    const result = await invoke('get_saved_connections');

    expect(Array.isArray(result)).toBe(true);
  });

  test('throws for unknown commands in test environment', async () => {
    await expect(invoke('unknown_command')).rejects.toThrow(/not implemented/i);
  });
});
