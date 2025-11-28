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

import type { FullConfig } from '@playwright/test';

/**
 * Global setup for E2E tests
 * 
 * This setup can optionally start an OpenCode server for integration testing.
 * To use a real OpenCode server instead of mocks:
 * 
 * 1. Install opencode-ai globally: npm i -g opencode-ai
 * 2. Set USE_OPENCODE_SERVER=true in environment
 * 3. Run tests with: USE_OPENCODE_SERVER=true npm run test:e2e
 * 
 * The server will be started automatically using @opencode-ai/sdk's createOpencodeServer
 */

// Store server reference for cleanup
let opencodeServer: { url: string; close: () => void } | null = null;

async function globalSetup(_config: FullConfig) {
  console.log('🔧 Setting up E2E test environment...');

  // Check if we should start a real OpenCode server
  const useOpencodeServer = process.env.USE_OPENCODE_SERVER === 'true';
  
  if (useOpencodeServer) {
    console.log('🚀 Starting OpenCode server for integration testing...');
    
    try {
      // Dynamic import to avoid build issues when SDK is not available
      const { createOpencodeServer } = await import('@opencode-ai/sdk/server');
      
      opencodeServer = await createOpencodeServer({
        hostname: '127.0.0.1',
        port: 4096,
        timeout: 30000, // 30 seconds to start
      });
      
      console.log(`✅ OpenCode server started at ${opencodeServer.url}`);
      
      // Store the URL in environment for tests to use
      process.env.OPENCODE_SERVER_URL = opencodeServer.url;
      
    } catch (error) {
      console.error('⚠️ Failed to start OpenCode server:', error);
      console.log('💡 Make sure opencode-ai is installed: npm i -g opencode-ai');
      console.log('📝 Tests will use mock implementations instead');
    }
  } else {
    console.log('ℹ️ Using mock implementations (set USE_OPENCODE_SERVER=true for real server)');
  }

  console.log('✅ E2E test environment setup completed');
}

// Export cleanup function for global teardown
export async function globalTeardown() {
  if (opencodeServer) {
    console.log('🛑 Stopping OpenCode server...');
    opencodeServer.close();
    opencodeServer = null;
    console.log('✅ OpenCode server stopped');
  }
}

export default globalSetup;