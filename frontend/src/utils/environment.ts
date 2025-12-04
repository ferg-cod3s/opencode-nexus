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
 * Environment detection utilities for OpenCode Nexus
 * Provides robust detection of development vs production modes
 */

export enum AppMode {
  DEVELOPMENT = 'development',
  PRODUCTION = 'production',
  TEST = 'test'
}

export enum ConnectionMode {
  LOCALHOST = 'localhost',
  TUNNEL = 'tunnel',
  PROXY = 'proxy'
}

export interface EnvironmentInfo {
  appMode: AppMode;
  connectionMode: ConnectionMode;
  isTauri: boolean;
  isDevelopment: boolean;
  isProduction: boolean;
  isTest: boolean;
  devServerUrl?: string;
  tauriVersion?: string;
}

/**
 * Detects the application mode based on environment variables and runtime context
 */
export function detectAppMode(): AppMode {
  // Check for test environment FIRST (before development detection)
  if (typeof process !== 'undefined' && process.env.NODE_ENV === 'test') {
    return AppMode.TEST;
  }

  // Check for Playwright test environment FIRST
  if (typeof window !== 'undefined') {
    // Check for Playwright-specific properties
    if ('playwright' in window || 
        '__playwright' in window ||
        // Check for Playwright user agent
        navigator.userAgent.includes('Playwright') ||
        navigator.userAgent.includes('HeadlessChrome') ||
        // Check for window features that suggest testing
        'webdriver' in navigator ||
        'callPhantom' in window ||
        '_phantom' in window) {
      return AppMode.TEST;
    }
    
    // Additional check for automated testing environments
    // Check for common test automation signatures
    if (window.navigator && 
        (window.navigator.webdriver === true ||
         window.navigator.userAgent.includes('HeadlessChrome') ||
         // Check for Chrome automation flags
         (window as any).chrome && (window as any).chrome.runtime)) {
      return AppMode.TEST;
    }
  }

  // Check for explicit development environment variables
  if (typeof process !== 'undefined') {
    if (process.env.NODE_ENV === 'development') {
      return AppMode.DEVELOPMENT;
    }
    if (process.env.NODE_ENV === 'production') {
      return AppMode.PRODUCTION;
    }
  }

  // Check for development server indicators
  if (typeof window !== 'undefined') {
    const { hostname, port, protocol } = window.location;

    // Localhost with development ports
    const isLocalhost = hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '0.0.0.0';
    const devPorts = ['1420', '3000', '5173', '4173', '8080', '4000'];
    const isDevPort = devPorts.includes(port);

    if (isLocalhost && isDevPort) {
      return AppMode.DEVELOPMENT;
    }

    // Check for Vite dev server indicators
    if (protocol === 'http:' && isLocalhost) {
      return AppMode.DEVELOPMENT;
    }
  }

  // Default to production for safety
  return AppMode.PRODUCTION;
}

/**
 * Detects the connection mode based on environment
 */
export function detectConnectionMode(): ConnectionMode {
  const appMode = detectAppMode();

  switch (appMode) {
    case AppMode.DEVELOPMENT:
      return ConnectionMode.LOCALHOST;
    case AppMode.TEST:
      return ConnectionMode.PROXY;
    case AppMode.PRODUCTION:
    default:
      return ConnectionMode.TUNNEL; // Production apps connect to remote servers
  }
}

/**
 * Gets comprehensive environment information
 */
export function getEnvironmentInfo(): EnvironmentInfo {
  const appMode = detectAppMode();
  const connectionMode = detectConnectionMode();

  const isTauri = typeof window !== 'undefined' && '__TAURI__' in window;
  const isDevelopment = appMode === AppMode.DEVELOPMENT;
  const isProduction = appMode === AppMode.PRODUCTION;
  const isTest = appMode === AppMode.TEST;

  let devServerUrl: string | undefined;
  let tauriVersion: string | undefined;

  if (isDevelopment && typeof window !== 'undefined') {
    devServerUrl = `${window.location.protocol}//${window.location.host}`;
  }

  if (isTauri && typeof window !== 'undefined') {
    // @ts-expect-error - Tauri global not in TypeScript definitions
    tauriVersion = window.__TAURI__?.version;
  }

  return {
    appMode,
    connectionMode,
    isTauri,
    isDevelopment,
    isProduction,
    isTest,
    devServerUrl,
    tauriVersion
  };
}

/**
 * Checks if the app should use bundled static files vs dev server
 */
export function shouldUseBundledAssets(): boolean {
  const env = getEnvironmentInfo();
  return env.isProduction || env.isTauri;
}

/**
 * Gets the appropriate base URL for API calls
 */
export function getApiBaseUrl(): string {
  const env = getEnvironmentInfo();

  if (env.isDevelopment && env.devServerUrl) {
    // In development, API calls go to the dev server
    return env.devServerUrl;
  }

  if (env.isTauri) {
    // In Tauri production, API calls are handled by Tauri commands
    return '';
  }

  // Fallback
  return '';
}

/**
 * Determines if authentication should be enabled
 */
export function shouldEnableAuthentication(): boolean {
  const env = getEnvironmentInfo();
  return env.isTauri || env.isTest;
}