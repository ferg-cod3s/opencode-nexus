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

// @ts-check
import { defineConfig } from 'astro/config';
import svelte from '@astrojs/svelte';
import sentry from '@sentry/astro';

const cspDev = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-eval' 'unsafe-inline' 'wasm-unsafe-eval' http: https: tauri:",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob: https:",
  "font-src 'self' data:",
  "connect-src 'self' ws: http: https: tauri: ipc:",
  "media-src 'self' data: blob:",
  "object-src 'none'",
  "base-uri 'self'",
  "frame-ancestors 'self'",
  "form-action 'self'",
  "worker-src 'self' blob:"
].join('; ');

// Ensure security headers are present during Astro/Vite development.
// Some environments may ignore vite.server.headers; attach a Vite middleware as fallback.
// Note: Cross-Origin headers are relaxed for E2E testing to prevent browser crashes
const devSecurityHeaders = {
  // Disabled for E2E testing - these strict headers cause Playwright crashes
  // 'Cross-Origin-Opener-Policy': 'same-origin',
  // 'Cross-Origin-Embedder-Policy': 'require-corp',
  'X-Content-Type-Options': 'nosniff',
  'Content-Security-Policy': cspDev,
};

function securityHeadersPlugin() {
  return {
    name: 'opencode:security-headers',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        for (const [key, value] of Object.entries(devSecurityHeaders)) {
          try { res.setHeader(key, value); } catch {}
        }
        next();
      });
    },
  };
}

// https://astro.build/config
export default defineConfig({
  integrations: [
    svelte(),
    // Sentry disabled for E2E testing to prevent initialization crashes
    // sentry({
    //   // Sentry configuration is in sentry.client.config.ts and sentry.server.config.ts
    //   // authToken is required for source map uploads during production builds
    //   project: "opencode-nexus-frontend",
    //   org: "unforgettable-designs",
    //   authToken: process.env.SENTRY_AUTH_TOKEN,
    // }),
  ],
  server: {
    port: 1420,
    host: true
  },
  vite: {
    server: {
      headers: {
        // Disabled for E2E testing - these strict headers cause Playwright crashes
        // 'Cross-Origin-Opener-Policy': 'same-origin',
        // 'Cross-Origin-Embedder-Policy': 'require-corp',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': cspDev
      }
    },
    plugins: [securityHeadersPlugin()],
  }
});
