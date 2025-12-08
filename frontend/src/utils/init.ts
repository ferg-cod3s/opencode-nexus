// Extend Window interface for Tauri
declare global {
  interface Window {
    __TAURI__?: any;
  }
}

// Application initialization
import { logger } from './logger';
import { invoke } from './tauri-api';

// Initialize application logging on startup
export async function initializeApp() {
  try {
    await logger.info('🚀 OpenCode Nexus application started');
    await logger.info(`User Agent: ${navigator.userAgent}`);
    await logger.info(`Platform: ${navigator.platform}`);
    await logger.info(`URL: ${window.location.href}`);

    // Log any startup environment info
    if (window.__TAURI__) {
      await logger.info('✅ Tauri environment detected');

      // Attempt to restore last server connection on startup
      try {
        await logger.info('🔄 Attempting to restore last server connection...');
        await invoke('restore_last_connection');
        await logger.info('✅ Connection restoration attempted');
      } catch (error) {
        await logger.warn(`⚠️ Connection restoration failed: ${error}`);
        // Don't fail app startup if connection restoration fails
      }
    } else {
      await logger.warn('❌ Tauri environment not detected - running in browser mode');
    }
  } catch (error) {
    console.error('Failed to initialize app logging:', error);
  }
}

// Auto-initialize when this module is imported
initializeApp();