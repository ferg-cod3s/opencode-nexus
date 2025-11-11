// Extend Window interface for Tauri
declare global {
  interface Window {
    __TAURI__?: any;
  }
}

// Application initialization
import { logger } from './logger';

// Initialize application logging on startup
export async function initializeApp() {
  try {
    // Check that we're in a browser environment before accessing browser APIs
    if (typeof window === 'undefined' || typeof navigator === 'undefined') {
      return; // Skip initialization if not in browser (e.g., during build)
    }

    await logger.info('🚀 OpenCode Nexus application started');
    await logger.info(`User Agent: ${navigator.userAgent}`);
    await logger.info(`Platform: ${navigator.platform}`);
    await logger.info(`URL: ${window.location.href}`);

    // Log any startup environment info
    if (window.__TAURI__) {
      await logger.info('✅ Tauri environment detected');
    } else {
      await logger.warn('❌ Tauri environment not detected - running in browser mode');
    }
  } catch (error) {
    console.error('Failed to initialize app logging:', error);
  }
}

// Defer initialization to avoid issues during static build
// This will be called from Layout.astro script
if (typeof window !== 'undefined') {
  // Defer execution to avoid build-time issues
  if (typeof navigator !== 'undefined') {
    // Schedule initialization for next tick to ensure we're definitely in browser
    if (typeof requestAnimationFrame === 'function') {
      requestAnimationFrame(() => initializeApp().catch(console.error));
    } else if (typeof setTimeout === 'function') {
      setTimeout(() => initializeApp().catch(console.error), 0);
    }
  }
}