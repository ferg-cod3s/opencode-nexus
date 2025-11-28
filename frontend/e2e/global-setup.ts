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
import { spawn, type ChildProcess } from 'child_process';

/**
 * Global setup for E2E tests
 * 
 * This setup starts an OpenCode server using `opencode serve` for integration testing.
 * Based on: https://opencode.ai/docs/server/
 * 
 * Usage:
 * 1. Install opencode-ai globally: npm i -g opencode-ai
 * 2. Run tests with: USE_OPENCODE_SERVER=true npm run test:e2e
 * 
 * The server runs on http://127.0.0.1:4096 by default.
 */

// Store server process for cleanup
let opencodeProcess: ChildProcess | null = null;

const OPENCODE_PORT = 4096;
const OPENCODE_HOSTNAME = '127.0.0.1';
const SERVER_TIMEOUT = 30000; // 30 seconds to start

async function globalSetup(_config: FullConfig) {
  console.log('🔧 Setting up E2E test environment...');

  // Check if we should start a real OpenCode server
  const useOpencodeServer = process.env.USE_OPENCODE_SERVER === 'true';
  
  if (useOpencodeServer) {
    console.log('🚀 Starting OpenCode server with `opencode serve`...');
    
    try {
      const serverUrl = await startOpencodeServer();
      console.log(`✅ OpenCode server started at ${serverUrl}`);
      
      // Store the URL in environment for tests to use
      process.env.OPENCODE_SERVER_URL = serverUrl;
      
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

/**
 * Start the OpenCode server using `opencode serve`
 * Docs: https://opencode.ai/docs/server/
 */
async function startOpencodeServer(): Promise<string> {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      if (opencodeProcess) {
        opencodeProcess.kill();
        opencodeProcess = null;
      }
      reject(new Error(`Timeout waiting for server to start after ${SERVER_TIMEOUT}ms`));
    }, SERVER_TIMEOUT);

    // Run `opencode serve --port 4096 --hostname 127.0.0.1`
    opencodeProcess = spawn('opencode', [
      'serve',
      '--port', String(OPENCODE_PORT),
      '--hostname', OPENCODE_HOSTNAME
    ], {
      stdio: ['ignore', 'pipe', 'pipe']
    });

    let output = '';

    opencodeProcess.stdout?.on('data', (chunk) => {
      output += chunk.toString();
      const lines = output.split('\n');
      for (const line of lines) {
        // Look for the server listening message
        if (line.includes('opencode server listening') || line.includes('listening on')) {
          clearTimeout(timeout);
          resolve(`http://${OPENCODE_HOSTNAME}:${OPENCODE_PORT}`);
          return;
        }
      }
    });

    opencodeProcess.stderr?.on('data', (chunk) => {
      output += chunk.toString();
    });

    opencodeProcess.on('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });

    opencodeProcess.on('exit', (code) => {
      clearTimeout(timeout);
      if (code !== 0) {
        let msg = `Server exited with code ${code}`;
        if (output.trim()) {
          msg += `\nServer output: ${output}`;
        }
        reject(new Error(msg));
      }
    });
  });
}

// Export cleanup function for global teardown
export async function globalTeardown() {
  if (opencodeProcess) {
    console.log('🛑 Stopping OpenCode server...');
    opencodeProcess.kill();
    opencodeProcess = null;
    console.log('✅ OpenCode server stopped');
  }
}

export default globalSetup;