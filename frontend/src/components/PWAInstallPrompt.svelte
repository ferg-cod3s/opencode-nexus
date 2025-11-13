<!--
  ~ MIT License
  ~
  ~ Copyright (c) 2025 OpenCode Nexus Contributors
  ~
  ~ Permission is hereby granted, free of charge, to any person obtaining a copy
  ~ of this software and associated documentation files (the "Software"), to deal
  ~ in the Software without restriction, including without limitation the rights
  ~ to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  ~ copies of the Software, and to permit persons to whom the Software is
  ~ furnished to do so, subject to the following conditions:
  ~
  ~ The above copyright notice and this permission notice shall be included in all
  ~ copies or substantial portions of the Software.
  ~
  ~ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  ~ IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  ~ FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  ~ AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  ~ LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  ~ OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  ~ SOFTWARE.
-->

<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { writable } from 'svelte/store';
  import {
    type BeforeInstallPromptEvent,
    type PWAPreferences,
    type PlatformInfo,
    isAppInstalled,
    detectPlatform,
    loadPreferences,
    savePreferences,
    shouldShowPrompt,
    getIOSInstallInstructions,
    trackInstallEvent,
    getOptimalPromptTiming
  } from '../utils/pwa-utils.js';

  // User preference store
  const installPromptPrefs = writable<PWAPreferences>({
    dismissed: false,
    dismissedAt: null,
    installed: false,
    lastShown: null,
    showCount: 0
  });

  // Subscribe to preference changes
  installPromptPrefs.subscribe(savePreferences);

  // Component state
  let showPrompt = false;
  let deferredPrompt: BeforeInstallPromptEvent | null = null;
  let platform: PlatformInfo = detectPlatform();
  let userEngaged = false;
  let engagementTimer: number | null = null;
  let mounted = false;

  // Track user engagement
  function trackEngagement() {
    if (!userEngaged) {
      userEngaged = true;

      // Show prompt after platform-specific timing
      const delay = getOptimalPromptTiming(platform);
      engagementTimer = window.setTimeout(() => {
        if (mounted && deferredPrompt && !isAppInstalled()) {
          showInstallPrompt();
        }
      }, delay);
    }
  }

  // Show install prompt
  function showInstallPrompt() {
    installPromptPrefs.update(prefs => {
      if (!shouldShowPrompt(prefs)) {
        return prefs;
      }

      prefs.lastShown = new Date();
      prefs.showCount += 1;
      return prefs;
    });

    showPrompt = true;
    trackInstallEvent('shown');
  }

  // Handle install button click
  async function handleInstall() {
    if (!deferredPrompt) return;

    try {
      await deferredPrompt.prompt();
      const { outcome } = await deferredPrompt.userChoice;

      if (outcome === 'accepted') {
        console.log('User accepted PWA install');
        installPromptPrefs.update(prefs => ({ ...prefs, installed: true }));
        showPrompt = false;
        trackInstallEvent('accepted');
      } else {
        console.log('User dismissed PWA install');
        handleDismiss();
        trackInstallEvent('dismissed');
      }
    } catch (error) {
      console.error('PWA install failed:', error);
      handleDismiss();
      trackInstallEvent('dismissed');
    }

    deferredPrompt = null;
  }

  // Handle dismiss button
  function handleDismiss() {
    showPrompt = false;
    installPromptPrefs.update(prefs => ({
      ...prefs,
      dismissed: true,
      dismissedAt: new Date()
    }));
    trackInstallEvent('dismissed');
  }

  // Handle manual iOS install instructions
  function handleIOSInstall() {
    const instructions = getIOSInstallInstructions();

    if (navigator.share) {
      navigator.share({
        title: 'Install OpenCode Nexus',
        text: instructions
      });
    } else {
      alert(instructions);
    }

    handleDismiss();
  }

  // Listen for beforeinstallprompt event
  function handleBeforeInstallPrompt(event: Event) {
    event.preventDefault();
    deferredPrompt = event as BeforeInstallPromptEvent;

    // Only show if user has engaged and app isn't already installed
    if (userEngaged && !isAppInstalled()) {
      showInstallPrompt();
    }
  }

  // Listen for appinstalled event
  function handleAppInstalled() {
    console.log('PWA was installed');
    installPromptPrefs.update(prefs => ({ ...prefs, installed: true }));
    showPrompt = false;
    trackInstallEvent('installed');
  }

  onMount(() => {
    mounted = true;

    // Load existing preferences
    const prefs = loadPreferences();
    installPromptPrefs.set(prefs);

    // Check if already installed
    if (isAppInstalled()) {
      installPromptPrefs.update(prefs => ({ ...prefs, installed: true }));
      return;
    }

    // Listen for PWA events
    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    window.addEventListener('appinstalled', handleAppInstalled);

    // Track user engagement events
    const engagementEvents = ['click', 'touchstart', 'scroll', 'keydown'];
    engagementEvents.forEach(event => {
      document.addEventListener(event, trackEngagement, { once: true, passive: true });
    });

    // For iOS, show prompt after engagement without beforeinstallprompt
    if (platform.platform === 'ios' && platform.canInstall) {
      const delay = getOptimalPromptTiming(platform);
      engagementTimer = window.setTimeout(() => {
        if (mounted && !isAppInstalled()) {
          showInstallPrompt();
        }
      }, delay);
    }
  });

  onDestroy(() => {
    mounted = false;

    window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    window.removeEventListener('appinstalled', handleAppInstalled);

    if (engagementTimer) {
      clearTimeout(engagementTimer);
    }
  });
</script>

{#if showPrompt && !isAppInstalled()}
  <!-- PWA Install Prompt -->
  <div
    class="pwa-install-prompt"
    role="dialog"
    aria-labelledby="install-title"
    aria-describedby="install-description"
  >
    <div class="prompt-content">
      <div class="prompt-header">
        <div class="app-icon">🚀</div>
        <div class="prompt-text">
          <h3 id="install-title">Install OpenCode Nexus</h3>
          <p id="install-description">
            {#if platform.platform === 'ios'}
              Add to your home screen for quick access and offline support.
            {:else if platform.platform === 'android'}
              Install as an app for a better experience.
            {:else}
              Install for offline access and native app features.
            {/if}
          </p>
        </div>
      </div>

      <div class="prompt-actions">
        {#if platform.installMethod === 'native'}
          <button class="install-btn" on:click={handleInstall}>
            Install App
          </button>
        {:else if platform.installMethod === 'manual'}
          <button class="install-btn" on:click={handleIOSInstall}>
            Show Instructions
          </button>
        {/if}

        <button class="dismiss-btn" on:click={handleDismiss}>
          Not Now
        </button>
      </div>

      {#if platform.platform === 'ios'}
        <div class="ios-instructions">
          <small>
            Tap the Share button (📤) → Add to Home Screen
          </small>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .pwa-install-prompt {
    position: fixed;
    bottom: 20px;
    left: 20px;
    right: 20px;
    z-index: 1000;
    animation: slideUp 0.3s ease-out;
  }

  @keyframes slideUp {
    from {
      transform: translateY(100%);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  .prompt-content {
    background: white;
    border-radius: 16px;
    padding: 20px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15);
    border: 1px solid hsl(0, 0%, 90%);
    max-width: 400px;
    margin: 0 auto;
  }

  .prompt-header {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 20px;
  }

  .app-icon {
    font-size: 2.5rem;
    flex-shrink: 0;
  }

  .prompt-text h3 {
    margin: 0 0 8px 0;
    color: hsl(220, 90%, 25%);
    font-size: 1.25rem;
    font-weight: 600;
  }

  .prompt-text p {
    margin: 0;
    color: hsl(220, 20%, 40%);
    font-size: 0.875rem;
    line-height: 1.4;
  }

  .prompt-actions {
    display: flex;
    gap: 12px;
    justify-content: flex-end;
  }

  .install-btn,
  .dismiss-btn {
    padding: 10px 20px;
    border-radius: 8px;
    border: none;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .install-btn {
    background: hsl(220, 90%, 60%);
    color: white;
  }

  .install-btn:hover {
    background: hsl(220, 90%, 50%);
    transform: translateY(-1px);
  }

  .dismiss-btn {
    background: hsl(0, 0%, 95%);
    color: hsl(220, 20%, 40%);
    border: 1px solid hsl(0, 0%, 90%);
  }

  .dismiss-btn:hover {
    background: hsl(0, 0%, 90%);
  }

  .ios-instructions {
    margin-top: 16px;
    padding-top: 16px;
    border-top: 1px solid hsl(0, 0%, 95%);
    text-align: center;
  }

  .ios-instructions small {
    color: hsl(220, 20%, 60%);
    font-size: 0.75rem;
  }

  /* Mobile responsive */
  @media (max-width: 480px) {
    .pwa-install-prompt {
      bottom: 10px;
      left: 10px;
      right: 10px;
    }

    .prompt-content {
      padding: 16px;
    }

    .prompt-header {
      gap: 12px;
    }

    .app-icon {
      font-size: 2rem;
    }

    .prompt-text h3 {
      font-size: 1.125rem;
    }

    .prompt-actions {
      flex-direction: column;
    }

    .install-btn,
    .dismiss-btn {
      width: 100%;
      padding: 12px;
    }
  }

  /* High contrast mode */
  @media (prefers-contrast: high) {
    .prompt-content {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .install-btn {
      background: hsl(0, 0%, 0%);
      border: 2px solid hsl(0, 0%, 0%);
    }
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .pwa-install-prompt {
      animation: none;
    }

    .install-btn,
    .dismiss-btn {
      transition: none;
    }

    .install-btn:hover {
      transform: none;
    }
  }

  /* Dark mode */
  @media (prefers-color-scheme: dark) {
    .prompt-content {
      background: hsl(220, 15%, 15%);
      border-color: hsl(220, 15%, 25%);
    }

    .prompt-text h3 {
      color: hsl(220, 85%, 75%);
    }

    .prompt-text p {
      color: hsl(220, 15%, 70%);
    }

    .dismiss-btn {
      background: hsl(220, 15%, 20%);
      color: hsl(220, 15%, 70%);
      border-color: hsl(220, 15%, 25%);
    }

    .dismiss-btn:hover {
      background: hsl(220, 15%, 25%);
    }

    .ios-instructions small {
      color: hsl(220, 15%, 60%);
    }

    .ios-instructions {
      border-top-color: hsl(220, 15%, 25%);
    }
  }

  /* Focus management */
  .install-btn:focus,
  .dismiss-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  /* Screen reader only */
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }
</style>