// Application initialization
import { logger } from './logger';

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
    } else {
      await logger.warn('❌ Tauri environment not detected - running in browser mode');
    }
  } catch (error) {
    console.error('Failed to initialize app logging:', error);
  }
}

// Auto-initialize when this module is imported
initializeApp();