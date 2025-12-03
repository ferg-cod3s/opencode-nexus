/*
 * MIT License
 *
 * Copyright (c) 2025 OpenCode Nexus Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { describe, test, expect, mock, beforeEach } from 'bun:test';
import { initializeConnection, isConnected, getCurrentConnection, disconnect } from '../../lib/sdk-api';

describe('Basic Connectivity API', () => {
  const mockConnection = {
    name: 'Test Server',
    hostname: 'localhost',
    port: 4096,
    secure: false,
  };

  beforeEach(() => {
    // Reset connection state before each test
    disconnect();
  });

  test('should initialize connection successfully', async () => {
    // This test would require a mock OpenCode server
    // For now, just test that the function exists and is callable
    expect(typeof initializeConnection).toBe('function');

    // TODO: Implement with mock server
    // await expect(initializeConnection(mockConnection)).resolves.toBeUndefined();
  });

  test('should report connection status', () => {
    expect(typeof isConnected).toBe('function');
    expect(isConnected()).toBe(false); // Should be false initially
  });

  test('should return current connection', () => {
    expect(typeof getCurrentConnection).toBe('function');
    expect(getCurrentConnection()).toBeNull(); // Should be null initially
  });

  test('should disconnect successfully', async () => {
    expect(typeof disconnect).toBe('function');

    // Should not throw even when not connected
    await expect(disconnect()).resolves.toBeUndefined();
  });
});