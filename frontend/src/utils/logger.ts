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

export interface LogEntry {
  level: 'info' | 'warn' | 'error' | 'debug';
  message: string;
  details?: string;
  timestamp?: Date;
  source?: 'frontend' | 'backend';
}

export class Logger {
  private static instance: Logger;
  private tauriInvoke: any = null;
  private backendLoggingEnabled = true;
  private originalConsole = {
    log: console.log.bind(console),
    info: console.info.bind(console),
    warn: console.warn.bind(console),
    error: console.error.bind(console),
    debug: console.debug.bind(console),
  };
  
  private constructor() {
    // Set up global error handlers
    this.setupGlobalErrorHandlers();
    // Wrap console methods to intercept all console output
    this.wrapConsoleMethods();
  }
  
  public static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }
 
  private async getTauriInvoke() {
    if (!this.backendLoggingEnabled) {
      return null;
    }
 
    // Only attempt to use Tauri invoke when running in a Tauri environment
    if (typeof window === 'undefined' || !('__TAURI__' in window)) {
      this.backendLoggingEnabled = false;
      return null;
    }
 
    if (!this.tauriInvoke) {
      try {
        const { invoke } = await import('@tauri-apps/api/core');
        this.tauriInvoke = invoke;
      } catch (error) {
        this.backendLoggingEnabled = false;
        this.originalConsole.warn('Tauri API not available, disabling backend logging');
        this.tauriInvoke = null;
      }
    }
    return this.tauriInvoke;
  }


  private wrapConsoleMethods() {
    const wrapMethod = (level: 'info' | 'warn' | 'error' | 'debug' | 'log', originalMethod: any) => {
      return (...args: any[]) => {
        originalMethod(...args);
        const message = args.map(a => {
          if (a instanceof Error) return `${a.name}: ${a.message}`;
          if (typeof a === 'string') return a;
          try {
            return JSON.stringify(a);
          } catch {
            return String(a);
          }
        }).join(' ');
        
        const mappedLevel = level === 'log' ? 'info' : level;
        void this.logToBackend(mappedLevel, message);
      };
    };

    console.log = wrapMethod('log', this.originalConsole.log);
    console.info = wrapMethod('info', this.originalConsole.info);
    console.warn = wrapMethod('warn', this.originalConsole.warn);
    console.error = wrapMethod('error', this.originalConsole.error);
    console.debug = wrapMethod('debug', this.originalConsole.debug);
  }

  private setupGlobalErrorHandlers() {
    if (typeof window === 'undefined') return;

    window.addEventListener('error', (event) => {
      const { message, filename, lineno, colno, error } = event;
      const ctx = error?.stack ? `Stack: ${error.stack}` : `at ${filename}:${lineno}:${colno}`;
      void this.logToBackend('error', `Unhandled Error: ${message}`, ctx);
    });

    window.addEventListener('unhandledrejection', (event) => {
      const reason = event.reason;
      const msg = reason instanceof Error
        ? `${reason.name}: ${reason.message}`
        : typeof reason === 'string'
        ? reason
        : 'Unhandled rejection';
      const ctx = reason instanceof Error ? `Stack: ${reason.stack}` : String(reason);
      void this.logToBackend('error', `Unhandled Promise Rejection: ${msg}`, ctx);
    });
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
      const invoke = await this.getTauriInvoke();
      if (invoke) {
        await invoke('log_frontend_error', {
          level,
          message,
          details: details || null
        });
      }
    } catch (error) {
      this.backendLoggingEnabled = false;
      this.originalConsole.warn('Failed to log to backend, disabling backend logging:', error);
    }
  }

  public async getLogs(): Promise<string[]> {
    try {
      const invoke = await this.getTauriInvoke();
      if (invoke) {
        return await invoke('get_application_logs') as Promise<string[]>;
      }
      return [];
    } catch (error) {
      console.error('Failed to get logs:', error);
      return [];
    }
  }

  public async clearLogs(): Promise<void> {
    try {
      const invoke = await this.getTauriInvoke();
      if (invoke) {
        await invoke('clear_application_logs');
        await this.info('Application logs cleared by user');
      }
    } catch (error) {
      console.error('Failed to clear logs:', error);
      throw error;
    }
  }

  public installNetworkLogging() {
    if (typeof window === 'undefined' || typeof window.fetch === 'undefined') return;

    const originalFetch = window.fetch.bind(window);
    window.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
      const start = performance.now();
      const url = typeof input === 'string' ? input : (input as Request).url;
      const method = (init?.method || (input as Request)?.method || 'GET').toUpperCase();

      try {
        const response = await originalFetch(input, init);
        const duration = Math.round(performance.now() - start);
        void this.logToBackend('info', `HTTP ${method} ${url}`, `status=${response.status} duration=${duration}ms`);
        return response;
      } catch (err) {
        const duration = Math.round(performance.now() - start);
        const error = err instanceof Error ? err.message : String(err);
        void this.logToBackend('error', `HTTP ${method} ${url}`, `error="${error}" duration=${duration}ms`);
        throw err;
      }
    };
  }
}

// Export singleton instance
export const logger = Logger.getInstance();

// Export convenience functions
export const logInfo = (message: string, details?: string) => logger.info(message, details);
export const logWarn = (message: string, details?: string) => logger.warn(message, details);
export const logError = (message: string, details?: string) => logger.error(message, details);
export const logDebug = (message: string, details?: string) => logger.debug(message, details);

// Install network logging by default
if (typeof window !== 'undefined') {
  logger.installNetworkLogging();
}