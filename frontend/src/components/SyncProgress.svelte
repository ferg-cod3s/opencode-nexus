<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { messageSyncManager, type SyncProgress, type SyncEvent, SyncEventType } from '../utils/message-sync-manager';
  import { syncInProgress } from '../stores/chat';

  let progress: SyncProgress | null = null;
  let currentEvent: SyncEvent | null = null;
  let unsubscribe: (() => void) | null = null;

  // Reactive statements
  $: isVisible = $syncInProgress && progress !== null;
  $: progressPercentage = progress ? Math.round((progress.processedMessages / progress.totalMessages) * 100) : 0;
  $: timeRemaining = progress ? formatTimeRemaining(progress.estimatedTimeRemaining) : '';
  $: statusMessage = getStatusMessage();

  function getStatusMessage(): string {
    if (!progress) return '';

    switch (currentEvent?.type) {
      case SyncEventType.STARTED:
        return 'Starting synchronization...';
      case SyncEventType.PROGRESS:
        return progress.currentOperation;
      case SyncEventType.BATCH_COMPLETE:
        return `Completed batch ${progress.currentBatch} of ${progress.totalBatches}`;
      case SyncEventType.MESSAGE_SENT:
        return `Sent ${progress.sentMessages} of ${progress.totalMessages} messages`;
      case SyncEventType.MESSAGE_FAILED:
        return `Failed to send ${progress.failedMessages} messages`;
      case SyncEventType.CONFLICT_DETECTED:
        return 'Resolving message conflicts...';
      case SyncEventType.COMPLETED:
        return 'Synchronization completed successfully';
      case SyncEventType.FAILED:
        return 'Synchronization failed';
      default:
        return progress.currentOperation;
    }
  }

  function formatTimeRemaining(ms: number): string {
    if (ms < 1000) return 'Less than 1 second';
    if (ms < 60000) return `${Math.round(ms / 1000)} seconds`;
    const minutes = Math.floor(ms / 60000);
    const seconds = Math.round((ms % 60000) / 1000);
    return `${minutes}m ${seconds}s`;
  }

  onMount(() => {
    // Listen for sync events
    unsubscribe = messageSyncManager.addEventListener((event: SyncEvent) => {
      currentEvent = event;

      if (event.type === SyncEventType.PROGRESS) {
        progress = event.data as SyncProgress;
      } else if (event.type === SyncEventType.STARTED) {
        progress = event.data as SyncProgress;
      } else if (event.type === SyncEventType.COMPLETED || event.type === SyncEventType.FAILED) {
        // Keep progress visible briefly to show final status
        setTimeout(() => {
          if (!$syncInProgress) {
            progress = null;
            currentEvent = null;
          }
        }, 3000);
      }
    });
  });

  onDestroy(() => {
    if (unsubscribe) {
      unsubscribe();
    }
  });
</script>

{#if isVisible}
  <div class="sync-progress-overlay" role="dialog" aria-live="assertive" aria-label="Message synchronization progress">
    <div class="sync-progress-container">
      <div class="sync-header">
        <div class="sync-icon">
          {#if currentEvent?.type === SyncEventType.FAILED}
            ⚠️
          {:else if currentEvent?.type === SyncEventType.COMPLETED}
            ✅
          {:else}
            🔄
          {/if}
        </div>
        <div class="sync-title">
          <h3>Synchronizing Messages</h3>
          <p class="sync-status">{statusMessage}</p>
        </div>
      </div>

      <div class="sync-progress-bar">
        <div
          class="progress-fill"
          class:completed={currentEvent?.type === SyncEventType.COMPLETED}
          class:failed={currentEvent?.type === SyncEventType.FAILED}
          style="width: {progressPercentage}%"
        ></div>
      </div>

      <div class="sync-stats">
        <div class="stat-item">
          <span class="stat-label">Progress:</span>
          <span class="stat-value">{progress.processedMessages} / {progress.totalMessages}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Sent:</span>
          <span class="stat-value success">{progress.sentMessages}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Failed:</span>
          <span class="stat-value error">{progress.failedMessages}</span>
        </div>
        {#if timeRemaining}
          <div class="stat-item">
            <span class="stat-label">Time remaining:</span>
            <span class="stat-value">{timeRemaining}</span>
          </div>
        {/if}
      </div>

      {#if progress.totalBatches > 1}
        <div class="batch-progress">
          <span class="batch-label">Batch {progress.currentBatch} of {progress.totalBatches}</span>
          <div class="batch-bar">
            <div
              class="batch-fill"
              style="width: {(progress.currentBatch / progress.totalBatches) * 100}%"
            ></div>
          </div>
        </div>
      {/if}

      {#if currentEvent?.type === SyncEventType.FAILED}
        <div class="sync-error">
          <p>Synchronization encountered errors. Some messages may need manual retry.</p>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .sync-progress-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10000;
    backdrop-filter: blur(2px);
  }

  .sync-progress-container {
    background: hsl(220, 20%, 98%);
    border-radius: 12px;
    padding: 2rem;
    max-width: 500px;
    width: 90%;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
    border: 1px solid hsl(220, 20%, 90%);
  }

  .sync-header {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1.5rem;
  }

  .sync-icon {
    font-size: 2rem;
    flex-shrink: 0;
  }

  .sync-title h3 {
    margin: 0 0 0.25rem 0;
    font-size: 1.25rem;
    font-weight: 600;
    color: hsl(220, 20%, 15%);
  }

  .sync-status {
    margin: 0;
    font-size: 0.875rem;
    color: hsl(220, 10%, 50%);
    line-height: 1.4;
  }

  .sync-progress-bar {
    height: 8px;
    background: hsl(220, 20%, 90%);
    border-radius: 4px;
    overflow: hidden;
    margin-bottom: 1.5rem;
  }

  .progress-fill {
    height: 100%;
    background: hsl(210, 100%, 50%);
    border-radius: 4px;
    transition: width 0.3s ease;
  }

  .progress-fill.completed {
    background: hsl(120, 60%, 45%);
  }

  .progress-fill.failed {
    background: hsl(0, 70%, 50%);
  }

  .sync-stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 1rem;
    margin-bottom: 1.5rem;
  }

  .stat-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .stat-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: hsl(220, 10%, 60%);
    text-transform: uppercase;
    letter-spacing: 0.025em;
  }

  .stat-value {
    font-size: 1rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
  }

  .stat-value.success {
    color: hsl(120, 60%, 40%);
  }

  .stat-value.error {
    color: hsl(0, 70%, 45%);
  }

  .batch-progress {
    margin-bottom: 1rem;
  }

  .batch-label {
    display: block;
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
    margin-bottom: 0.5rem;
    text-align: center;
  }

  .batch-bar {
    height: 4px;
    background: hsl(220, 20%, 85%);
    border-radius: 2px;
    overflow: hidden;
  }

  .batch-fill {
    height: 100%;
    background: hsl(210, 100%, 60%);
    border-radius: 2px;
    transition: width 0.3s ease;
  }

  .sync-error {
    background: hsl(0, 100%, 97%);
    border: 1px solid hsl(0, 70%, 80%);
    border-radius: 6px;
    padding: 1rem;
  }

  .sync-error p {
    margin: 0;
    font-size: 0.875rem;
    color: hsl(0, 60%, 35%);
    line-height: 1.4;
  }

  /* Dark mode support */
  @media (prefers-color-scheme: dark) {
    .sync-progress-container {
      background: hsl(220, 20%, 12%);
      border-color: hsl(220, 20%, 20%);
    }

    .sync-title h3 {
      color: hsl(220, 20%, 95%);
    }

    .sync-status {
      color: hsl(220, 10%, 70%);
    }

    .sync-progress-bar {
      background: hsl(220, 20%, 25%);
    }

    .stat-label {
      color: hsl(220, 10%, 70%);
    }

    .stat-value {
      color: hsl(220, 20%, 90%);
    }

    .batch-label {
      color: hsl(220, 10%, 70%);
    }

    .batch-bar {
      background: hsl(220, 20%, 25%);
    }

    .sync-error {
      background: hsl(0, 100%, 5%);
      border-color: hsl(0, 70%, 30%);
    }

    .sync-error p {
      color: hsl(0, 60%, 75%);
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .sync-progress-container {
      padding: 1.5rem;
      margin: 1rem;
    }

    .sync-header {
      flex-direction: column;
      text-align: center;
      gap: 0.75rem;
    }

    .sync-stats {
      grid-template-columns: repeat(2, 1fr);
      gap: 0.75rem;
    }

    .stat-item {
      text-align: center;
    }
  }

  /* High contrast mode */
  @media (prefers-contrast: high) {
    .sync-progress-container {
      border-width: 2px;
    }

    .progress-fill,
    .batch-fill {
      border: 1px solid hsl(0, 0%, 100%);
    }
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .progress-fill,
    .batch-fill {
      transition: none;
    }
  }

  /* Focus management */
  .sync-progress-container:focus {
    outline: 2px solid hsl(210, 100%, 50%);
    outline-offset: 2px;
  }
</style>