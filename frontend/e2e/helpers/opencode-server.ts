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

/**
 * OpenCode Server Integration Helper for E2E Tests
 * 
 * Uses `opencode serve` to start a headless HTTP server for testing.
 * Docs: https://opencode.ai/docs/server/
 * 
 * To use:
 * 1. Install opencode-ai: npm i -g opencode-ai
 * 2. Run tests with: USE_OPENCODE_SERVER=true npm run test:e2e
 * 
 * Example usage in tests:
 * ```typescript
 * import { getOpencodeServerUrl, isOpencodeServerAvailable } from './helpers/opencode-server';
 * 
 * test('chat with real server', async ({ page }) => {
 *   if (!isOpencodeServerAvailable()) {
 *     test.skip();
 *     return;
 *   }
 *   
 *   const serverUrl = getOpencodeServerUrl();
 *   // ... test with real server
 * });
 * ```
 */

/**
 * Default OpenCode server port (as per docs: https://opencode.ai/docs/server/)
 */
export const OPENCODE_DEFAULT_PORT = 4096;

/**
 * Default OpenCode server hostname
 */
export const OPENCODE_DEFAULT_HOSTNAME = '127.0.0.1';

/**
 * Check if an OpenCode server is available for testing
 */
export function isOpencodeServerAvailable(): boolean {
  return process.env.USE_OPENCODE_SERVER === 'true' && !!process.env.OPENCODE_SERVER_URL;
}

/**
 * Get the URL of the running OpenCode server
 * @throws Error if server is not available
 */
export function getOpencodeServerUrl(): string {
  if (!isOpencodeServerAvailable()) {
    throw new Error(
      'OpenCode server is not available. Run tests with USE_OPENCODE_SERVER=true and ensure opencode-ai is installed.'
    );
  }
  return process.env.OPENCODE_SERVER_URL || `http://${OPENCODE_DEFAULT_HOSTNAME}:${OPENCODE_DEFAULT_PORT}`;
}

/**
 * Create a client configuration for connecting to the OpenCode server
 */
export function getOpencodeClientConfig() {
  const serverUrl = getOpencodeServerUrl();
  return {
    baseUrl: serverUrl,
    hostname: OPENCODE_DEFAULT_HOSTNAME,
    port: OPENCODE_DEFAULT_PORT,
  };
}

/**
 * Wait for the OpenCode server to be ready by checking the /app endpoint
 * @param timeout Maximum time to wait in milliseconds
 */
export async function waitForOpencodeServer(timeout = 10000): Promise<boolean> {
  if (!isOpencodeServerAvailable()) {
    return false;
  }

  const serverUrl = getOpencodeServerUrl();
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    try {
      // Use /app endpoint as per OpenCode server docs
      const response = await fetch(`${serverUrl}/app`);
      if (response.ok) {
        return true;
      }
    } catch {
      // Server not ready yet
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  return false;
}

/**
 * Get OpenAPI spec URL for the server
 * Available at http://<hostname>:<port>/doc
 */
export function getOpencodeDocUrl(): string {
  const serverUrl = getOpencodeServerUrl();
  return `${serverUrl}/doc`;
}
