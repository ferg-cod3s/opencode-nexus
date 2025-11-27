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

import { describe, it, expect, beforeEach } from 'bun:test';
import { OpencodeClientManager, type ServerConnection } from '../../lib/opencode-client';

describe('OpencodeClientManager', () => {
  let manager: OpencodeClientManager;
  const testConnection: ServerConnection = {
    name: 'Test Server',
    hostname: 'localhost',
    port: 4096,
    secure: false
  };

  beforeEach(() => {
    manager = new OpencodeClientManager();
  });

  it('should create an instance', () => {
    expect(manager).toBeDefined();
  });

  it('should not be connected initially', () => {
    expect(manager.isConnected()).toBe(false);
  });

  it('should return null for current connection initially', () => {
    expect(manager.getCurrentConnection()).toBeNull();
  });

  it('should throw error when getting client without connection', () => {
    expect(() => manager.getClient()).toThrow('Not connected to a server');
  });

  it('should accept a ServerConnection structure', () => {
    // Verify the test connection has required properties
    expect(testConnection.name).toBeDefined();
    expect(testConnection.hostname).toBeDefined();
    expect(testConnection.port).toBeDefined();
    expect(testConnection.secure).toBeDefined();
  });

  it('should handle disconnect when not connected', async () => {
    // Should not throw when disconnecting when already disconnected
    await expect(manager.disconnect()).resolves.toBeUndefined();
  });
});

describe('ServerConnection', () => {
  it('should support secure and insecure connections', () => {
    const insecure: ServerConnection = {
      name: 'Insecure',
      hostname: 'localhost',
      port: 4096,
      secure: false
    };

    const secure: ServerConnection = {
      name: 'Secure',
      hostname: 'api.example.com',
      port: 443,
      secure: true
    };

    expect(insecure.secure).toBe(false);
    expect(secure.secure).toBe(true);
  });

  it('should support optional lastConnected timestamp', () => {
    const connection: ServerConnection = {
      name: 'Test',
      hostname: 'localhost',
      port: 4096,
      secure: false,
      lastConnected: new Date().toISOString()
    };

    expect(connection.lastConnected).toBeDefined();
  });
});
