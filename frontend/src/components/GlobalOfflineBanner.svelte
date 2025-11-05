<script lang="ts">
  import { onMount } from 'svelte';
  import { isOnline, hasQueuedMessages, syncInProgress, queuedMessageCount, chatError } from '../stores/chat';
  import { ConnectionMonitor } from '../utils/offline-storage';

  let showBanner = false;
  let lastConnectionChange = Date.now();
  let connectionQuality = 'good'; // 'good', 'poor', 'offline'
  let lastOnlineTime: Date | null = null;
  let lastOfflineTime: Date | null = null;

  // Reactive statements
  $: isOffline = !$isOnline;
  $: bannerVisible = showBanner && (isOffline || $hasQueuedMessages || $syncInProgress || $chatError);
  $: statusMessage = getStatusMessage();
  $: actionMessage = getActionMessage();

  function getStatusMessage(): string {
    if (isOffline) {
      const offlineDuration = lastOfflineTime ? Math.floor((Date.now() - lastOfflineTime.getTime()) / 1000 / 60) : 0;
      if (offlineDuration > 0) {
        return `Offline for ${offlineDuration} minute${offlineDuration === 1 ? '' : 's'}`;
      }
      return 'You are currently offline';
    }

    if ($syncInProgress) {
      return 'Syncing queued messages...';
    }

    if ($hasQueuedMessages) {
      return `${$queuedMessageCount} message${$queuedMessageCount === 1 ? '' : 's'} queued for sending`;
    }

    if ($chatError) {
      return 'Connection issue detected';
    }

    return '';
  }

  function getActionMessage(): string {
    if (isOffline) {
      return 'Messages will be sent when connection is restored';
    }

    if ($syncInProgress) {
      return 'Please wait while messages are being sent';
    }

    if ($hasQueuedMessages) {
      return 'Tap to view queued messages';
    }

    if ($chatError) {
      return 'Check your connection and try again';
    }

    return '';
  }

  function updateConnectionQuality() {
    // Simulate connection quality based on navigator.onLine and other factors
    // In a real implementation, this would use actual network metrics
    if (isOffline) {
      connectionQuality = 'offline';
    } else {
      // Could implement actual latency checks here
      connectionQuality = 'good';
    }
  }

  function handleConnectionChange(isOnline: boolean) {
    lastConnectionChange = Date.now();
    if (isOnline) {
      lastOnlineTime = new Date();
      showBanner = false; // Hide banner when coming back online
    } else {
      lastOfflineTime = new Date();
      showBanner = true; // Show banner when going offline
    }
    updateConnectionQuality();

    // Announce status change to screen readers
    announceStatusChange(isOnline);
  }

  function announceStatusChange(isOnline: boolean) {
    const message = isOnline ? 'Connection restored' : 'Connection lost';
    const announcement = `${message}. ${isOnline ? 'You are back online' : 'You are now offline'}`;

    // Use existing screen reader announcement system
    const srAnnouncements = document.getElementById('sr-announcements');
    if (srAnnouncements) {
      srAnnouncements.textContent = announcement;
    }
  }

  function dismissBanner() {
    showBanner = false;
  }

  function handleBannerClick() {
    if ($hasQueuedMessages && !isOffline) {
      // Could navigate to a queued messages view
      console.log('Show queued messages');
    }
  }

  onMount(() => {
    // Listen for connection changes
    const unsubscribe = ConnectionMonitor.addListener(handleConnectionChange);

    // Initial state
    updateConnectionQuality();

    // Auto-show banner for errors or queued messages
    if ($chatError || $hasQueuedMessages) {
      showBanner = true;
    }

    return unsubscribe;
  });

  // Auto-dismiss banner after successful sync
  $: if (!$syncInProgress && !$hasQueuedMessages && !$chatError && !isOffline) {
    // Delay dismissal to show success state briefly
    setTimeout(() => {
      if (!$syncInProgress && !$hasQueuedMessages && !$chatError && !isOffline) {
        showBanner = false;
      }
    }, 3000);
  }
</script>

{#if bannerVisible}
  <div
    class="global-offline-banner"
    class:offline={isOffline}
    class:syncing={$syncInProgress}
    class:has-queued={$hasQueuedMessages}
    class:has-error={$chatError}
    class:quality-good={connectionQuality === 'good'}
    class:quality-poor={connectionQuality === 'poor'}
    class:quality-offline={connectionQuality === 'offline'}
    role="banner"
    aria-live="assertive"
    aria-atomic="true"
    aria-label="Connection status banner"
  >
    <div class="banner-content">
      <div class="status-indicator">
        <div class="status-icon" aria-hidden="true">
          {#if isOffline}
            📴
          {:else if $syncInProgress}
            🔄
          {:else if $hasQueuedMessages}
            ⏳
          {:else if $chatError}
            ⚠️
          {:else}
            ✅
          {/if}
        </div>
        <div class="status-text">
          <div class="primary-message">{statusMessage}</div>
          {#if actionMessage}
            <div class="secondary-message">{actionMessage}</div>
          {/if}
        </div>
      </div>

      {#if $hasQueuedMessages && !isOffline}
        <button
          class="action-button"
          on:click={handleBannerClick}
          aria-label="View {$queuedMessageCount} queued messages"
        >
          View Messages
        </button>
      {/if}

      <button
        class="dismiss-button"
        on:click={dismissBanner}
        aria-label="Dismiss notification"
        title="Dismiss"
      >
        ✕
      </button>
    </div>

    <!-- Connection quality indicator -->
    {#if !isOffline}
      <div class="connection-quality" aria-label="Connection quality: {connectionQuality}">
        <div class="quality-bars">
          <div class="quality-bar" class:active={connectionQuality === 'good' || connectionQuality === 'poor'}></div>
          <div class="quality-bar" class:active={connectionQuality === 'good'}></div>
          <div class="quality-bar" class:active={false}></div>
        </div>
        <span class="quality-text">{connectionQuality}</span>
      </div>
    {/if}
  </div>
{/if}

<style>
  .global-offline-banner {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 10000;
    background: hsl(220, 90%, 25%);
    color: white;
    box-shadow: 0 2px 8px hsla(0, 0%, 0%, 0.15);
    animation: slideDown 0.3s ease-out;
  }

  .banner-content {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem 1rem;
    max-width: 1200px;
    margin: 0 auto;
    gap: 1rem;
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex: 1;
    min-width: 0;
  }

  .status-icon {
    font-size: 1.25rem;
    flex-shrink: 0;
  }

  .status-text {
    min-width: 0;
    flex: 1;
  }

  .primary-message {
    font-weight: 600;
    font-size: 0.875rem;
    line-height: 1.2;
  }

  .secondary-message {
    font-size: 0.75rem;
    opacity: 0.9;
    margin-top: 0.125rem;
    line-height: 1.2;
  }

  .action-button {
    background: hsla(0, 0%, 100%, 0.1);
    color: white;
    border: 1px solid hsla(0, 0%, 100%, 0.2);
    border-radius: 0.375rem;
    padding: 0.375rem 0.75rem;
    font-size: 0.75rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  .action-button:hover {
    background: hsla(0, 0%, 100%, 0.2);
    border-color: hsla(0, 0%, 100%, 0.3);
  }

  .dismiss-button {
    background: none;
    border: none;
    color: hsla(0, 0%, 100%, 0.7);
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 0.25rem;
    font-size: 1rem;
    line-height: 1;
    flex-shrink: 0;
    transition: all 0.2s ease;
  }

  .dismiss-button:hover {
    background: hsla(0, 0%, 100%, 0.1);
    color: white;
  }

  /* Banner variants */
  .global-offline-banner.offline {
    background: hsl(0, 70%, 45%);
  }

  .global-offline-banner.syncing {
    background: hsl(45, 100%, 45%);
    color: hsl(220, 20%, 20%);
  }

  .global-offline-banner.has-queued {
    background: hsl(45, 100%, 50%);
    color: hsl(220, 20%, 20%);
  }

  .global-offline-banner.has-error {
    background: hsl(0, 70%, 50%);
  }

  .global-offline-banner.syncing .action-button,
  .global-offline-banner.has-queued .action-button {
    background: hsla(220, 20%, 20%, 0.1);
    border-color: hsla(220, 20%, 20%, 0.2);
    color: hsl(220, 20%, 20%);
  }

  .global-offline-banner.syncing .dismiss-button,
  .global-offline-banner.has-queued .dismiss-button {
    color: hsla(220, 20%, 20%, 0.7);
  }

  .global-offline-banner.syncing .dismiss-button:hover,
  .global-offline-banner.has-queued .dismiss-button:hover {
    background: hsla(220, 20%, 20%, 0.1);
    color: hsl(220, 20%, 20%);
  }

  /* Connection quality indicator */
  .connection-quality {
    position: absolute;
    top: 100%;
    right: 1rem;
    display: flex;
    align-items: center;
    gap: 0.375rem;
    background: inherit;
    padding: 0.25rem 0.5rem;
    border-radius: 0 0 0.375rem 0.375rem;
    font-size: 0.625rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.025em;
  }

  .quality-bars {
    display: flex;
    gap: 0.125rem;
  }

  .quality-bar {
    width: 3px;
    height: 8px;
    background: hsla(0, 0%, 100%, 0.3);
    border-radius: 1px;
    transition: background-color 0.2s ease;
  }

  .quality-bar.active {
    background: hsla(0, 0%, 100%, 0.9);
  }

  .quality-text {
    font-size: 0.625rem;
    opacity: 0.9;
  }

  /* Animations */
  @keyframes slideDown {
    from {
      transform: translateY(-100%);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  /* Syncing animation */
  .global-offline-banner.syncing .status-icon {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .banner-content {
      padding: 0.625rem 0.75rem;
      flex-wrap: wrap;
      gap: 0.5rem;
    }

    .status-indicator {
      flex-basis: 100%;
      order: 1;
    }

    .action-button {
      order: 2;
      flex-shrink: 0;
    }

    .dismiss-button {
      order: 3;
      align-self: flex-start;
    }

    .connection-quality {
      position: static;
      order: 4;
      margin-top: 0.25rem;
      border-radius: 0.25rem;
      align-self: flex-start;
    }

    .primary-message {
      font-size: 0.8125rem;
    }

    .secondary-message {
      font-size: 0.6875rem;
    }
  }

  /* High contrast mode */
  @media (prefers-contrast: high) {
    .global-offline-banner {
      border: 2px solid hsl(0, 0%, 100%);
    }

    .action-button {
      border-width: 2px;
    }

    .quality-bar {
      border: 1px solid hsl(0, 0%, 100%);
    }
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .global-offline-banner {
      animation: none;
    }

    .global-offline-banner.syncing .status-icon {
      animation: none;
    }

    .quality-bar {
      transition: none;
    }
  }

  /* Focus management */
  .action-button:focus,
  .dismiss-button:focus {
    outline: 2px solid hsla(0, 0%, 100%, 0.8);
    outline-offset: 2px;
  }

  /* Dark mode support */
  @media (prefers-color-scheme: dark) {
    .global-offline-banner {
      background: hsl(220, 50%, 15%);
    }

    .global-offline-banner.offline {
      background: hsl(0, 70%, 35%);
    }

    .global-offline-banner.syncing {
      background: hsl(45, 100%, 35%);
    }

    .global-offline-banner.has-queued {
      background: hsl(45, 100%, 40%);
    }

    .global-offline-banner.has-error {
      background: hsl(0, 70%, 40%);
    }
  }
</style>