// @ts-check
import { defineConfig } from 'astro/config';
import svelte from '@astrojs/svelte';

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
const devSecurityHeaders = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
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
  integrations: [svelte()],
  server: {
    port: 1420,
    host: true
  },
  vite: {
    server: {
      headers: {
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': cspDev
      }
    },
    plugins: [securityHeadersPlugin()],
  }
});
