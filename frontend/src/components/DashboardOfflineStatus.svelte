<script lang="ts">
  import { onMount } from 'svelte';
  import { isOnline, hasQueuedMessages, queuedMessageCount, syncInProgress } from '../stores/chat';
  import { ConnectionMonitor } from '../utils/offline-storage';
  import type { ChatSession } from '../types/chat';

  export let sessions: ChatSession[] = [];

  let connectionQuality = 'good'; // 'good', 'poor', 'offline'
  let lastSyncTime: Date | null = null;
  let offlineCapabilities: string[] = [];
  let onlineCapabilities: string[] = [];

  // Reactive statements
  $: isOffline = !$isOnline;
  $: totalMessages = sessions.reduce((total, session) => total + session.messages.length, 0);
  $: cachedSessions = sessions.length;
  $: statusSummary = getStatusSummary();

  function getStatusSummary() {
    if (isOffline) {
      return {
        title: 'Offline Mode',
        description: 'Working with cached data',
        color: 'hsl(0, 60%, 50%)',
        icon: '📴'
      };
    }

    if ($syncInProgress) {
      return {
        title: 'Syncing',
        description: 'Sending queued messages',
        color: 'hsl(45, 100%, 50%)',
        icon: '🔄'
      };
    }

    if ($hasQueuedMessages) {
      return {
        title: 'Messages Queued',
        description: `${$queuedMessageCount} waiting to send`,
        color: 'hsl(45, 100%, 50%)',
        icon: '⏳'
      };
    }

    return {
      title: 'Online',
      description: 'Fully connected',
      color: 'hsl(120, 50%, 50%)',
      icon: '🟢'
    };
  }

  function updateCapabilities() {
    if (isOffline) {
      offlineCapabilities = [
        'View cached conversations',
        'Compose new messages (queued for later)',
        'Access local settings',
        'View connection history'
      ];
      onlineCapabilities = [
        'Send messages instantly',
        'Start new conversations',
        'Real-time responses',
        'Server synchronization'
      ];
    } else {
      offlineCapabilities = [
        'View cached conversations',
        'Compose messages while offline',
        'Automatic sync when reconnected'
      ];
      onlineCapabilities = [
        'Send messages instantly',
        'Start new conversations',
        'Real-time AI responses',
        'Server synchronization'
      ];
    }
  }

  function updateConnectionQuality() {
    if (isOffline) {
      connectionQuality = 'offline';
    } else {
      // In a real implementation, this would measure actual latency
      connectionQuality = 'good';
    }
  }

  function formatLastSync() {
    if (!lastSyncTime) return 'Never';
    const now = new Date();
    const diffMs = now.getTime() - lastSyncTime.getTime();
    const diffMins = Math.floor(diffMs / (1000 * 60));

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;

    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;

    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
  }

  onMount(() => {
    updateCapabilities();
    updateConnectionQuality();

    // Listen for connection changes
    const unsubscribe = ConnectionMonitor.addListener((isOnline) => {
      updateCapabilities();
      updateConnectionQuality();
    });

    return unsubscribe;
  });

  // Update capabilities when online status changes
  $: if ($isOnline !== undefined) {
    updateCapabilities();
  }
</script>

<article class="offline-status-card" role="region" aria-labelledby="offline-status-heading">
  <header class="card-header">
    <h2 id="offline-status-heading">Connection Status</h2>
    <div class="status-indicator" style="color: {statusSummary.color}">
      <span class="status-icon" aria-hidden="true">{statusSummary.icon}</span>
      <span class="status-text">{statusSummary.title}</span>
    </div>
  </header>

  <div class="card-content">
    <div class="status-overview">
      <div class="status-description">{statusSummary.description}</div>

      {#if !isOffline}
        <div class="connection-quality">
          <span class="quality-label">Connection:</span>
          <div class="quality-indicator" aria-label="Connection quality: {connectionQuality}">
            <div class="quality-bars">
              <div class="quality-bar" class:active={connectionQuality === 'good' || connectionQuality === 'poor'}></div>
              <div class="quality-bar" class:active={connectionQuality === 'good'}></div>
              <div class="quality-bar" class:active={false}></div>
            </div>
            <span class="quality-text">{connectionQuality}</span>
          </div>
        </div>
      {/if}

      {#if lastSyncTime}
        <div class="last-sync">
          <span class="sync-label">Last synced:</span>
          <span class="sync-time">{formatLastSync()}</span>
        </div>
      {/if}
    </div>

    <div class="capabilities-section">
      <div class="capabilities-group">
        <h3 class="capabilities-title">Available Now</h3>
        <ul class="capabilities-list" role="list">
          {#each offlineCapabilities as capability}
            <li class="capability-item" role="listitem">
              <span class="capability-icon" aria-hidden="true">✓</span>
              <span class="capability-text">{capability}</span>
            </li>
          {/each}
        </ul>
      </div>

      {#if onlineCapabilities.length > 0}
        <div class="capabilities-group">
          <h3 class="capabilities-title">When Online</h3>
          <ul class="capabilities-list" role="list">
            {#each onlineCapabilities as capability}
              <li class="capability-item" role="listitem" class:disabled={isOffline}>
                <span class="capability-icon" aria-hidden="true">{isOffline ? '⏳' : '✓'}</span>
                <span class="capability-text">{capability}</span>
              </li>
            {/each}
          </ul>
        </div>
      {/if}
    </div>

    <div class="offline-stats">
      <div class="stat-item">
        <span class="stat-label">Cached Sessions:</span>
        <span class="stat-value">{cachedSessions}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">Total Messages:</span>
        <span class="stat-value">{totalMessages}</span>
      </div>
      {#if $hasQueuedMessages}
        <div class="stat-item">
          <span class="stat-label">Queued Messages:</span>
          <span class="stat-value" style="color: hsl(45, 100%, 50%)">{$queuedMessageCount}</span>
        </div>
      {/if}
    </div>

    {#if isOffline}
      <div class="offline-notice" role="note" aria-live="polite">
        <div class="notice-icon" aria-hidden="true">💡</div>
        <div class="notice-content">
          <div class="notice-title">Offline Mode Active</div>
          <div class="notice-text">
            You're working offline. New messages will be queued and sent automatically when connection is restored.
          </div>
        </div>
      </div>
    {/if}
  </div>
</article>

<style>
  .offline-status-card {
    background: white;
    border-radius: 1rem;
    padding: 1.5rem;
    box-shadow: 0 4px 6px hsla(0, 0%, 0%, 0.1);
    border: 1px solid hsl(0, 0%, 90%);
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid hsl(0, 0%, 90%);
  }

  .card-header h2 {
    margin: 0;
    font-size: 1.25rem;
    color: hsl(220, 90%, 25%);
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 600;
  }

  .status-icon {
    font-size: 1rem;
  }

  .status-text {
    font-size: 0.875rem;
  }

  .card-content {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .status-overview {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .status-description {
    font-size: 0.875rem;
    color: hsl(220, 20%, 60%);
    font-weight: 500;
  }

  .connection-quality,
  .last-sync {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.8125rem;
  }

  .quality-label,
  .sync-label {
    color: hsl(220, 20%, 60%);
    font-weight: 500;
    min-width: 80px;
  }

  .quality-indicator {
    display: flex;
    align-items: center;
    gap: 0.375rem;
  }

  .quality-bars {
    display: flex;
    gap: 0.125rem;
  }

  .quality-bar {
    width: 3px;
    height: 10px;
    background: hsl(220, 20%, 80%);
    border-radius: 1px;
    transition: background-color 0.2s ease;
  }

  .quality-bar.active {
    background: hsl(120, 50%, 50%);
  }

  .quality-text {
    font-size: 0.75rem;
    color: hsl(220, 20%, 60%);
    font-weight: 500;
    text-transform: capitalize;
  }

  .sync-time {
    color: hsl(220, 20%, 40%);
    font-weight: 500;
  }

  .capabilities-section {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .capabilities-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .capabilities-title {
    font-size: 0.875rem;
    font-weight: 600;
    color: hsl(220, 20%, 30%);
    margin: 0;
  }

  .capabilities-list {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .capability-item {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    font-size: 0.8125rem;
    color: hsl(220, 20%, 50%);
    line-height: 1.4;
  }

  .capability-item.disabled {
    opacity: 0.6;
  }

  .capability-icon {
    font-size: 0.75rem;
    flex-shrink: 0;
    margin-top: 0.125rem;
  }

  .capability-text {
    flex: 1;
  }

  .offline-stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 1rem;
    padding: 1rem;
    background: hsl(0, 0%, 98%);
    border-radius: 0.5rem;
    border: 1px solid hsl(0, 0%, 90%);
  }

  .stat-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
  }

  .stat-label {
    font-size: 0.75rem;
    color: hsl(220, 20%, 60%);
    font-weight: 500;
  }

  .stat-value {
    font-size: 1.25rem;
    color: hsl(220, 20%, 30%);
    font-weight: 600;
  }

  .offline-notice {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 1rem;
    background: hsl(45, 100%, 97%);
    border: 1px solid hsl(45, 100%, 60%);
    border-radius: 0.5rem;
    color: hsl(45, 100%, 30%);
  }

  .notice-icon {
    font-size: 1.25rem;
    flex-shrink: 0;
  }

  .notice-content {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .notice-title {
    font-size: 0.875rem;
    font-weight: 600;
  }

  .notice-text {
    font-size: 0.8125rem;
    line-height: 1.4;
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .offline-status-card {
      padding: 1rem;
    }

    .card-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }

    .capabilities-section {
      gap: 0.75rem;
    }

    .offline-stats {
      grid-template-columns: 1fr;
      gap: 0.75rem;
    }

    .stat-item {
      flex-direction: row;
      justify-content: space-between;
      align-items: center;
    }

    .offline-notice {
      padding: 0.75rem;
      flex-direction: column;
      gap: 0.5rem;
      text-align: center;
    }
  }

  /* High contrast mode */
  @media (prefers-contrast: high) {
    .offline-status-card {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .quality-bar.active {
      background: hsl(0, 0%, 0%);
    }

    .offline-notice {
      border: 2px solid hsl(0, 0%, 0%);
    }
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .quality-bar {
      transition: none;
    }
  }
</style>