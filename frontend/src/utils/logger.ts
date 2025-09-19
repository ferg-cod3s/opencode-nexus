import { invoke } from '@tauri-apps/api/core';

export interface LogEntry {
  level: 'info' | 'warn' | 'error' | 'debug';
  message: string;
  details?: string;
  timestamp?: Date;
  source?: 'frontend' | 'backend';
}

export class Logger {
  private static instance: Logger;
  
  private constructor() {
    // Set up global error handlers
    this.setupGlobalErrorHandlers();
  }
  
  public static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  private setupGlobalErrorHandlers() {
    // Catch unhandled JavaScript errors
    window.addEventListener('error', (event) => {
      this.error('Unhandled JavaScript Error', `${event.error?.message || event.message} at ${event.filename}:${event.lineno}`);
    });

    // Catch unhandled promise rejections
    window.addEventListener('unhandledrejection', (event) => {
      this.error('Unhandled Promise Rejection', String(event.reason));
    });

    // Catch Tauri API errors
    const originalConsoleError = console.error;
    console.error = (...args) => {
      // Log to our system if it looks like a Tauri error
      const message = args.join(' ');
      if (message.includes('[TAURI]') || message.includes('tauri://')) {
        this.error('Tauri API Error', message);
      }
      originalConsoleError.apply(console, args);
    };
  }

  public async info(message: string, details?: string): Promise<void> {
    console.info(`[INFO] ${message}`, details || '');
    await this.logToBackend('info', message, details);
  }

  public async warn(message: string, details?: string): Promise<void> {
    console.warn(`[WARN] ${message}`, details || '');
    await this.logToBackend('warn', message, details);
  }

  public async error(message: string, details?: string): Promise<void> {
    console.error(`[ERROR] ${message}`, details || '');
    await this.logToBackend('error', message, details);
  }

  public async debug(message: string, details?: string): Promise<void> {
    console.debug(`[DEBUG] ${message}`, details || '');
    await this.logToBackend('debug', message, details);
  }

  private async logToBackend(level: string, message: string, details?: string): Promise<void> {
    try {
      await invoke('log_frontend_error', {
        level,
        message,
        details: details || null
      });
    } catch (error) {
      // Fallback to console if backend logging fails
      console.warn('Failed to log to backend:', error);
    }
  }

  public async getLogs(): Promise<string[]> {
    try {
      return await invoke<string[]>('get_application_logs');
    } catch (error) {
      console.error('Failed to get logs:', error);
      return [];
    }
  }

  public async clearLogs(): Promise<void> {
    try {
      await invoke('clear_application_logs');
      this.info('Application logs cleared by user');
    } catch (error) {
      console.error('Failed to clear logs:', error);
      throw error;
    }
  }
}

// Export singleton instance
export const logger = Logger.getInstance();

// Export convenience functions
export const logInfo = (message: string, details?: string) => logger.info(message, details);
export const logWarn = (message: string, details?: string) => logger.warn(message, details);
export const logError = (message: string, details?: string) => logger.error(message, details);
export const logDebug = (message: string, details?: string) => logger.debug(message, details);