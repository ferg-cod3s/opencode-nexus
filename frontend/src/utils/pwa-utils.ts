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
 * PWA (Progressive Web App) utilities for OpenCode Nexus
 * Handles install prompts, platform detection, and user preferences
 */

export interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[];
  readonly userChoice: Promise<{
    outcome: 'accepted' | 'dismissed';
    platform: string;
  }>;
  prompt(): Promise<void>;
}

export interface PWAPreferences {
  dismissed: boolean;
  dismissedAt: Date | null;
  installed: boolean;
  lastShown: Date | null;
  showCount: number;
}

export interface PlatformInfo {
  platform: 'ios' | 'android' | 'desktop' | 'unknown';
  canInstall: boolean;
  installMethod: 'native' | 'manual' | 'none';
}

/**
 * Detect if app is already installed as a PWA
 */
export function isAppInstalled(): boolean {
  // Only check in browser environment, not during SSR
  if (typeof window === 'undefined' || typeof navigator === 'undefined') {
    return false;
  }

  // Check for standalone mode (iOS Safari)
  if ('standalone' in window.navigator && (window.navigator as any).standalone) {
    return true;
  }

  // Check for display-mode media query (Android Chrome)
  if (window.matchMedia('(display-mode: standalone)').matches) {
    return true;
  }

  // Check for PWA launch URL parameters
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('utm_source') === 'pwa') {
    return true;
  }

  return false;
}

/**
 * Detect platform and browser capabilities for PWA installation
 */
export function detectPlatform(): PlatformInfo {
  // Only detect in browser environment, not during SSR
  if (typeof window === 'undefined' || typeof navigator === 'undefined') {
    return {
      platform: 'desktop',
      canInstall: false,
      installMethod: 'none'
    };
  }

  const userAgent = navigator.userAgent.toLowerCase();
  const isIOS = /iphone|ipad|ipod/.test(userAgent);
  const isAndroid = /android/.test(userAgent);
  const isChrome = /chrome/.test(userAgent) && !/edg/.test(userAgent);
  const isSafari = /safari/.test(userAgent) && !/chrome/.test(userAgent);

  if (isIOS && isSafari) {
    return {
      platform: 'ios',
      canInstall: true,
      installMethod: 'manual'
    };
  }

  if (isAndroid && isChrome) {
    return {
      platform: 'android',
      canInstall: 'onbeforeinstallprompt' in window,
      installMethod: 'native'
    };
  }

  return {
    platform: 'desktop',
    canInstall: false,
    installMethod: 'none'
  };
}

/**
 * Load PWA preferences from localStorage
 */
export function loadPreferences(): PWAPreferences {
  // Only load in browser environment, not during SSR
  if (typeof window === 'undefined' || typeof localStorage === 'undefined') {
    return {
      dismissed: false,
      dismissedAt: null,
      installed: false,
      lastShown: null,
      showCount: 0
    };
  }

  try {
    const stored = localStorage.getItem('opencode-nexus-pwa-prefs');
    if (stored) {
      const prefs = JSON.parse(stored);
      // Convert date strings back to Date objects
      if (prefs.dismissedAt) prefs.dismissedAt = new Date(prefs.dismissedAt);
      if (prefs.lastShown) prefs.lastShown = new Date(prefs.lastShown);
      return prefs;
    }
  } catch (error) {
    console.warn('Failed to load PWA preferences:', error);
  }

  return {
    dismissed: false,
    dismissedAt: null,
    installed: false,
    lastShown: null,
    showCount: 0
  };
}

/**
 * Save PWA preferences to localStorage
 */
export function savePreferences(prefs: PWAPreferences): void {
  // Only save in browser environment, not during SSR
  if (typeof window === 'undefined' || typeof localStorage === 'undefined') {
    return;
  }
  
  try {
    localStorage.setItem('opencode-nexus-pwa-prefs', JSON.stringify(prefs));
  } catch (error) {
    console.warn('Failed to save PWA preferences:', error);
  }
}

/**
 * Check if install prompt should be shown based on user preferences
 */
export function shouldShowPrompt(prefs: PWAPreferences): boolean {
  if (prefs.installed) return false;
  if (prefs.dismissed) {
    // Check if enough time has passed since dismissal (7 days)
    const daysSinceDismissal = prefs.dismissedAt
      ? (Date.now() - prefs.dismissedAt.getTime()) / (1000 * 60 * 60 * 24)
      : 0;
    return daysSinceDismissal >= 7;
  }
  return true;
}

/**
 * Get iOS installation instructions
 */
export function getIOSInstallInstructions(): string {
  return `To install OpenCode Nexus on iOS:

1. Tap the Share button (📤) in Safari
2. Scroll down and tap "Add to Home Screen"
3. Tap "Add" in the top right corner

The app will appear on your home screen with offline access.`;
}

/**
 * Track PWA installation analytics (if analytics are enabled)
 */
export function trackInstallEvent(event: 'shown' | 'accepted' | 'dismissed' | 'installed'): void {
  // This could be extended to send analytics events
  console.log(`PWA install event: ${event}`);

  // Example: Send to analytics service
  // if (window.gtag) {
  //   window.gtag('event', `pwa_${event}`, {
  //     event_category: 'pwa',
  //     event_label: 'opencode-nexus'
  //   });
  // }
}

/**
 * Check if current browser supports PWA features
 */
export function getPWASupport(): {
  serviceWorker: boolean;
  beforeInstallPrompt: boolean;
  standalone: boolean;
  manifest: boolean;
} {
  return {
    serviceWorker: 'serviceWorker' in navigator,
    beforeInstallPrompt: 'onbeforeinstallprompt' in window,
    standalone: 'standalone' in window.navigator,
    manifest: 'manifest' in document.createElement('link')
  };
}

/**
 * Get optimal timing for showing install prompt based on user engagement
 */
export function getOptimalPromptTiming(platform: PlatformInfo): number {
  // Different timing for different platforms
  switch (platform.platform) {
    case 'ios':
      // iOS requires manual process, give more time
      return 45000; // 45 seconds
    case 'android':
      // Android has native prompt, can show sooner
      return 30000; // 30 seconds
    default:
      return 60000; // 60 seconds for other platforms
  }
}