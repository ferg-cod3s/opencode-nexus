/*
 * MIT License
 *
 * Copyright (c) 2025 OpenCode Nexus Contributors
 */

import { describe, test, expect, beforeEach, afterEach } from 'bun:test';
import { Logger } from '../../utils/logger';

// Minimal window mock so global error handlers can register safely
(global as any).window = (global as any).window || {
  addEventListener: () => {},
};

// Mock dynamic import of @tauri-apps/api/core to simulate browser environment
let tauriImportCalls = 0;

const originalImport = (global as any).import;

beforeEach(() => {
  tauriImportCalls = 0;
  (global as any).import = async (specifier: string) => {
    if (specifier === '@tauri-apps/api/core') {
      tauriImportCalls += 1;
      throw new Error('Tauri not available in test');
    }
    if (originalImport) {
      return originalImport(specifier);
    }
    throw new Error(`Unknown dynamic import: ${specifier}`);
  };
});

afterEach(() => {
  (global as any).import = originalImport;
});

describe('Logger backend logging in non-Tauri environment', () => {
  test('does not recurse when backend logging fails', async () => {
    const logger = (Logger as any).getInstance();

    let warnCount = 0;
    const originalWarn = console.warn;
    console.warn = (...args: any[]) => {
      warnCount += 1;
      originalWarn.apply(console, args);
    };

    try {
      // This will attempt to log to backend, which fails in our mocked env
      await logger.info('test message');

      // We only expect a small, bounded number of warnings, not an infinite loop
      expect(warnCount).toBeLessThan(10);
    } finally {
      console.warn = originalWarn;
    }
  });
});
