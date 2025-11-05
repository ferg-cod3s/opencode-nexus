<script lang="ts">
  import { chatActions, syncInProgress, hasQueuedMessages, queuedMessageCount } from '../stores/chat';
  import { messageSyncManager } from '../utils/message-sync-manager';

  let isManualSync = false;

  async function handleManualSync() {
    if ($syncInProgress || isManualSync) return;

    isManualSync = true;
    try {
      await chatActions.syncQueuedMessages();
    } catch (error) {
      console.error('Manual sync failed:', error);
    } finally {
      isManualSync = false;
    }
  }

  function cancelSync() {
    messageSyncManager.cancelSync();
  }
</script>

<div class="sync-controls" role="region" aria-labelledby="sync-controls-title">
  {#if $hasQueuedMessages && !$syncInProgress && !isManualSync}
    <div class="sync-prompt">
      <div class="sync-icon">🔄</div>
      <div class="sync-info">
        <p class="sync-title">Messages Ready to Sync</p>
        <p class="sync-description">
          {$queuedMessageCount} message{$queuedMessageCount === 1 ? '' : 's'} waiting to be sent
        </p>
      </div>
      <button
        class="sync-button"
        on:click={handleManualSync}
        aria-label="Sync {$queuedMessageCount} queued messages"
      >
        Sync Now
      </button>
    </div>
  {:else if $syncInProgress || isManualSync}
    <div class="sync-active">
      <div class="sync-icon spinning">🔄</div>
      <div class="sync-info">
        <p class="sync-title">Synchronizing...</p>
        <p class="sync-description">Sending queued messages</p>
      </div>
      <button
        class="cancel-button"
        on:click={cancelSync}
        aria-label="Cancel synchronization"
      >
        Cancel
      </button>
    </div>
  {:else if !$hasQueuedMessages}
    <div class="sync-complete">
      <div class="sync-icon">✅</div>
      <div class="sync-info">
        <p class="sync-title">All Synced</p>
        <p class="sync-description">No messages waiting to be sent</p>
      </div>
    </div>
  {/if}
</div>

<style>
  .sync-controls {
    background: hsl(220, 20%, 98%);
    border: 1px solid hsl(220, 20%, 90%);
    border-radius: 8px;
    padding: 1rem;
    margin: 1rem 0;
  }

  .sync-prompt,
  .sync-active,
  .sync-complete {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .sync-icon {
    font-size: 1.5rem;
    flex-shrink: 0;
  }

  .sync-icon.spinning {
    animation: spin 1s linear infinite;
  }

  .sync-info {
    flex: 1;
    min-width: 0;
  }

  .sync-title {
    margin: 0 0 0.25rem 0;
    font-size: 1rem;
    font-weight: 600;
    color: hsl(220, 20%, 15%);
  }

  .sync-description {
    margin: 0;
    font-size: 0.875rem;
    color: hsl(220, 10%, 60%);
  }

  .sync-button,
  .cancel-button {
    background: hsl(210, 100%, 50%);
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.5rem 1rem;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  .sync-button:hover {
    background: hsl(210, 100%, 45%);
  }

  .cancel-button {
    background: hsl(0, 70%, 50%);
  }

  .cancel-button:hover {
    background: hsl(0, 70%, 45%);
  }

  .sync-complete .sync-title {
    color: hsl(120, 60%, 35%);
  }

  .sync-active .sync-title {
    color: hsl(45, 100%, 35%);
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }

  /* Dark mode support */
  @media (prefers-color-scheme: dark) {
    .sync-controls {
      background: hsl(220, 20%, 12%);
      border-color: hsl(220, 20%, 20%);
    }

    .sync-title {
      color: hsl(220, 20%, 95%);
    }

    .sync-description {
      color: hsl(220, 10%, 70%);
    }

    .sync-complete .sync-title {
      color: hsl(120, 60%, 65%);
    }

    .sync-active .sync-title {
      color: hsl(45, 100%, 65%);
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .sync-controls {
      padding: 0.75rem;
    }

    .sync-prompt,
    .sync-active,
    .sync-complete {
      flex-direction: column;
      align-items: stretch;
      gap: 0.75rem;
      text-align: center;
    }

    .sync-button,
    .cancel-button {
      align-self: center;
      width: 100%;
      max-width: 200px;
    }
  }

  /* High contrast mode */
  @media (prefers-contrast: high) {
    .sync-controls {
      border-width: 2px;
    }

    .sync-button,
    .cancel-button {
      border: 2px solid hsl(0, 0%, 100%);
    }
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .sync-icon.spinning {
      animation: none;
    }

    .sync-button,
    .cancel-button {
      transition: none;
    }
  }

  /* Focus management */
  .sync-button:focus,
  .cancel-button:focus {
    outline: 2px solid hsl(210, 100%, 50%);
    outline-offset: 2px;
  }
</style>