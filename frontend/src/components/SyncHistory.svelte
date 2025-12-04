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
<!-- eslint-disable-next-line svelte/valid-compile -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { messageSyncManager, type SyncResult, type SyncError } from '../utils/message-sync-manager';
  import { hasQueuedMessages, queuedMessageCount } from '../stores/chat';

  let syncHistory: SyncResult[] = [];
  let showDetails = false;
  let selectedSync: SyncResult | null = null;

  // Reactive statements
  $: hasErrors = syncHistory.some(result => result.errors.length > 0);
  $: totalSynced = syncHistory.reduce((sum, result) => sum + result.sent, 0);
  $: totalFailed = syncHistory.reduce((sum, result) => sum + result.failed, 0);
  $: lastSyncTime = syncHistory.length > 0 ? formatTimeAgo(new Date(syncHistory[0].duration + Date.now() - syncHistory[0].duration)) : null;

  function formatTimeAgo(date: Date): string {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    return `${diffDays}d ago`;
  }

  function formatDuration(ms: number): string {
    if (ms < 1000) return `${ms}ms`;
    const seconds = Math.floor(ms / 1000);
    if (seconds < 60) return `${seconds}s`;
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds}s`;
  }

  function getSyncStatus(result: SyncResult): { text: string; class: string } {
    if (!result.success) return { text: 'Failed', class: 'error' };
    if (result.failed > 0) return { text: 'Partial', class: 'warning' };
    return { text: 'Success', class: 'success' };
  }

  function toggleDetails() {
    showDetails = !showDetails;
  }

  function showSyncDetails(sync: SyncResult) {
    selectedSync = sync;
  }

  function closeDetails() {
    selectedSync = null;
  }

  async function retryFailedMessages() {
    // This would trigger a new sync for failed messages
    console.log('Retrying failed messages...');
  }

  onMount(() => {
    // Load sync history
    syncHistory = messageSyncManager.getSyncHistory();
  });
</script>

<div class="sync-history" role="region" aria-labelledby="sync-history-title">
  <div class="sync-history-header">
    <h3 id="sync-history-title">Sync History</h3>
    <button
      class="details-toggle"
      on:click={toggleDetails}
      aria-expanded={showDetails}
      aria-label="{showDetails ? 'Hide' : 'Show'} sync details"
    >
      {showDetails ? 'Hide Details' : 'Show Details'}
      <span class="toggle-icon" aria-hidden="true">{showDetails ? '▼' : '▶'}</span>
    </button>
  </div>

  {#if $hasQueuedMessages}
    <div class="queued-notice" role="alert">
      <div class="notice-icon">⏳</div>
      <div class="notice-content">
        <p class="notice-title">Messages Queued</p>
        <p class="notice-text">{$queuedMessageCount} message{$queuedMessageCount === 1 ? '' : 's'} waiting to sync</p>
      </div>
    </div>
  {/if}

  <div class="sync-summary">
    <div class="summary-item">
      <span class="summary-label">Total Synced:</span>
      <span class="summary-value success">{totalSynced}</span>
    </div>
    <div class="summary-item">
      <span class="summary-label">Failed:</span>
      <span class="summary-value error">{totalFailed}</span>
    </div>
    {#if lastSyncTime}
      <div class="summary-item">
        <span class="summary-label">Last Sync:</span>
        <span class="summary-value">{lastSyncTime}</span>
      </div>
           {/if}
         </button>

  {#if showDetails && syncHistory.length > 0}
    <div class="sync-list" role="list">
      {#each syncHistory as sync (sync.duration + Math.random())}
        {@const status = getSyncStatus(sync)}
       <button
          class="sync-item"
          class:error={status.class === 'error'}
          class:warning={status.class === 'warning'}
          class:success={status.class === 'success'}
          type="button"
          on:click={() => showSyncDetails(sync)}
          aria-label="Sync result: {status.text}, sent {sync.sent} messages, failed {sync.failed}, duration {formatDuration(sync.duration)}"
        >
          <div class="sync-item-header">
            <div class="sync-status">
              <span class="status-icon" aria-hidden="true">
                {#if status.class === 'error'}❌{:else if status.class === 'warning'}⚠️{:else}✅{/if}
              </span>
              <span class="status-text">{status.text}</span>
            </div>
            <div class="sync-time">{formatTimeAgo(new Date(Date.now() - sync.duration))}</div>
          </div>

          <div class="sync-stats">
            <span class="stat">Sent: {sync.sent}</span>
            <span class="stat">Failed: {sync.failed}</span>
            <span class="stat">Duration: {formatDuration(sync.duration)}</span>
          </div>

          {#if sync.errors.length > 0}
            <div class="sync-errors">
              <span class="error-count">{sync.errors.length} error{sync.errors.length === 1 ? '' : 's'}</span>
            </div>
          {/if}
        </button>
      {/each}
    </div>
  {:else if showDetails && syncHistory.length === 0}
    <div class="no-history">
      <p>No sync history available</p>
    </div>
  {/if}
</div>

{#if selectedSync}
  <div class="sync-details-modal" role="dialog" aria-labelledby="sync-details-title" aria-modal="true">
     <button
       class="modal-backdrop"
       type="button"
       on:click={closeDetails}
       aria-label="Close sync details modal"
       tabindex="-1"
     ></button>
    <div class="modal-content">
      <div class="modal-header">
        <h3 id="sync-details-title">Sync Details</h3>
        <button
          class="close-button"
          on:click={closeDetails}
          aria-label="Close sync details"
        >
          ✕
        </button>
      </div>

      <div class="modal-body">
        {#if selectedSync}
          {@const status = getSyncStatus(selectedSync)}
          <div class="sync-overview">
          <div class="overview-item">
            <span class="overview-label">Status:</span>
            <span class="overview-value {status.class}">{status.text}</span>
          </div>
          <div class="overview-item">
            <span class="overview-label">Duration:</span>
            <span class="overview-value">{formatDuration(selectedSync.duration)}</span>
          </div>
          <div class="overview-item">
            <span class="overview-label">Messages Sent:</span>
            <span class="overview-value success">{selectedSync.sent}</span>
          </div>
          <div class="overview-item">
            <span class="overview-label">Messages Failed:</span>
            <span class="overview-value error">{selectedSync.failed}</span>
          </div>
          {#if selectedSync.conflicts > 0}
            <div class="overview-item">
              <span class="overview-label">Conflicts:</span>
              <span class="overview-value warning">{selectedSync.conflicts}</span>
            </div>
          {/if}
        </div>

        {#if selectedSync.errors.length > 0}
          <div class="error-section">
            <h4>Errors ({selectedSync.errors.length})</h4>
            <div class="error-list">
              {#each selectedSync.errors as error (error.messageId)}
                <div class="error-item">
                  <div class="error-header">
                    <span class="error-message">{error.error}</span>
                    <span class="error-time">{formatTimeAgo(new Date(error.timestamp))}</span>
                  </div>
                  <div class="error-details">
                    <span class="error-id">Message ID: {error.messageId}</span>
                    <span class="error-session">Session: {error.sessionId}</span>
                    <span class="error-retries">Retries: {error.retryCount}</span>
                  </div>
                </div>
              {/each}
            </div>

            {#if selectedSync.failed > 0}
              <button class="retry-button" on:click={retryFailedMessages}>
                Retry Failed Messages
              </button>
            {/if}
          </div>
        {/if}

        {#if selectedSync.sessionUpdates.length > 0}
          <div class="session-updates">
            <h4>Updated Sessions ({selectedSync.sessionUpdates.length})</h4>
            <ul class="session-list">
              {#each selectedSync.sessionUpdates as sessionId (sessionId)}
                <li>{sessionId}</li>
              {/each}
            </ul>
          </div>
        {/if}
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .sync-history {
    background: hsl(220, 20%, 98%);
    border: 1px solid hsl(220, 20%, 90%);
    border-radius: 8px;
    padding: 1.5rem;
    margin: 1rem 0;
  }

  .sync-history-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 1rem;
  }

  .sync-history-header h3 {
    margin: 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: hsl(220, 20%, 15%);
  }

  .details-toggle {
    background: none;
    border: 1px solid hsl(220, 20%, 80%);
    border-radius: 4px;
    padding: 0.375rem 0.75rem;
    font-size: 0.875rem;
    color: hsl(220, 20%, 40%);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.375rem;
    transition: all 0.2s ease;
  }

  .details-toggle:hover {
    background: hsl(220, 20%, 95%);
    border-color: hsl(220, 20%, 70%);
  }

  .toggle-icon {
    font-size: 0.75rem;
    transition: transform 0.2s ease;
  }

  .queued-notice {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    background: hsl(45, 100%, 95%);
    border: 1px solid hsl(45, 100%, 80%);
    border-radius: 6px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .notice-icon {
    font-size: 1.25rem;
    flex-shrink: 0;
  }

  .notice-content {
    flex: 1;
  }

  .notice-title {
    margin: 0 0 0.25rem 0;
    font-weight: 600;
    color: hsl(45, 60%, 30%);
  }

  .notice-text {
    margin: 0;
    font-size: 0.875rem;
    color: hsl(45, 40%, 35%);
  }

  .sync-summary {
    display: flex;
    gap: 1.5rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
  }

  .summary-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .summary-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: hsl(220, 10%, 60%);
    text-transform: uppercase;
    letter-spacing: 0.025em;
  }

  .summary-value {
    font-size: 1.125rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
  }

  .summary-value.success {
    color: hsl(120, 60%, 40%);
  }

  .summary-value.error {
    color: hsl(0, 70%, 45%);
  }

  .sync-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .sync-item {
    background: white;
    border: 1px solid hsl(220, 20%, 90%);
    border-radius: 6px;
    padding: 1rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .sync-item:hover {
    border-color: hsl(220, 20%, 70%);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .sync-item.error {
    border-color: hsl(0, 70%, 70%);
    background: hsl(0, 100%, 98%);
  }

  .sync-item.warning {
    border-color: hsl(45, 100%, 70%);
    background: hsl(45, 100%, 98%);
  }

  .sync-item.success {
    border-color: hsl(120, 60%, 70%);
    background: hsl(120, 100%, 98%);
  }

  .sync-item-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.5rem;
  }

  .sync-status {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .status-icon {
    font-size: 1rem;
  }

  .status-text {
    font-weight: 600;
    font-size: 0.875rem;
  }

  .sync-time {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
  }

  .sync-stats {
    display: flex;
    gap: 1rem;
    font-size: 0.875rem;
    color: hsl(220, 10%, 50%);
  }

  .sync-errors {
    margin-top: 0.5rem;
  }

  .error-count {
    font-size: 0.75rem;
    color: hsl(0, 70%, 45%);
    font-weight: 500;
  }

  .no-history {
    text-align: center;
    padding: 2rem;
    color: hsl(220, 10%, 60%);
  }

  .no-history p {
    margin: 0;
    font-style: italic;
  }

  /* Modal Styles */
  .sync-details-modal {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 10000;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .modal-backdrop {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(2px);
  }

  .modal-content {
    position: relative;
    background: white;
    border-radius: 12px;
    max-width: 600px;
    width: 90%;
    max-height: 80vh;
    overflow-y: auto;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.5rem;
    border-bottom: 1px solid hsl(220, 20%, 90%);
  }

  .modal-header h3 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
  }

  .close-button {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 4px;
    color: hsl(220, 10%, 60%);
    transition: all 0.2s ease;
  }

  .close-button:hover {
    background: hsl(220, 20%, 95%);
    color: hsl(220, 20%, 20%);
  }

  .modal-body {
    padding: 1.5rem;
  }

  .sync-overview {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }

  .overview-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem;
    background: hsl(220, 20%, 98%);
    border-radius: 6px;
  }

  .overview-label {
    font-weight: 500;
    color: hsl(220, 10%, 60%);
  }

  .overview-value {
    font-weight: 600;
  }

  .overview-value.success {
    color: hsl(120, 60%, 40%);
  }

  .overview-value.error {
    color: hsl(0, 70%, 45%);
  }

  .overview-value.warning {
    color: hsl(45, 100%, 40%);
  }

  .error-section {
    margin-bottom: 2rem;
  }

  .error-section h4 {
    margin: 0 0 1rem 0;
    font-size: 1rem;
    font-weight: 600;
    color: hsl(220, 20%, 15%);
  }

  .error-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .error-item {
    background: hsl(0, 100%, 98%);
    border: 1px solid hsl(0, 70%, 85%);
    border-radius: 6px;
    padding: 1rem;
  }

  .error-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 0.5rem;
  }

  .error-message {
    font-weight: 500;
    color: hsl(0, 60%, 35%);
    flex: 1;
    margin-right: 1rem;
  }

  .error-time {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
    flex-shrink: 0;
  }

  .error-details {
    display: flex;
    gap: 1rem;
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
  }

  .retry-button {
    background: hsl(210, 100%, 50%);
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.75rem 1.5rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .retry-button:hover {
    background: hsl(210, 100%, 45%);
  }

  .session-updates {
    margin-bottom: 1rem;
  }

  .session-updates h4 {
    margin: 0 0 0.5rem 0;
    font-size: 1rem;
    font-weight: 600;
    color: hsl(220, 20%, 15%);
  }

  .session-list {
    margin: 0;
    padding-left: 1.5rem;
  }

  .session-list li {
    font-size: 0.875rem;
    color: hsl(220, 10%, 50%);
  }

  /* Dark mode support */
  @media (prefers-color-scheme: dark) {
    .sync-history {
      background: hsl(220, 20%, 12%);
      border-color: hsl(220, 20%, 20%);
    }

    .sync-history-header h3 {
      color: hsl(220, 20%, 95%);
    }

    .details-toggle {
      border-color: hsl(220, 20%, 30%);
      color: hsl(220, 20%, 70%);
    }

    .details-toggle:hover {
      background: hsl(220, 20%, 15%);
      border-color: hsl(220, 20%, 40%);
    }

    .queued-notice {
      background: hsl(45, 100%, 10%);
      border-color: hsl(45, 100%, 25%);
    }

    .notice-title {
      color: hsl(45, 60%, 80%);
    }

    .notice-text {
      color: hsl(45, 40%, 75%);
    }

    .summary-value {
      color: hsl(220, 20%, 90%);
    }

    .sync-item {
      background: hsl(220, 20%, 15%);
      border-color: hsl(220, 20%, 25%);
    }

    .sync-item:hover {
      border-color: hsl(220, 20%, 35%);
    }

    .sync-time {
      color: hsl(220, 10%, 70%);
    }

    .sync-stats {
      color: hsl(220, 10%, 70%);
    }

    .modal-content {
      background: hsl(220, 20%, 12%);
    }

    .modal-header {
      border-color: hsl(220, 20%, 20%);
    }

    .modal-header h3 {
      color: hsl(220, 20%, 95%);
    }

    .close-button {
      color: hsl(220, 10%, 70%);
    }

    .close-button:hover {
      background: hsl(220, 20%, 15%);
      color: hsl(220, 20%, 90%);
    }

    .overview-item {
      background: hsl(220, 20%, 15%);
    }

    .overview-label {
      color: hsl(220, 10%, 70%);
    }

    .overview-value {
      color: hsl(220, 20%, 90%);
    }

    .error-section h4 {
      color: hsl(220, 20%, 95%);
    }

    .error-item {
      background: hsl(0, 100%, 5%);
      border-color: hsl(0, 70%, 25%);
    }

    .error-message {
      color: hsl(0, 60%, 75%);
    }

    .error-time {
      color: hsl(220, 10%, 70%);
    }

    .error-details {
      color: hsl(220, 10%, 70%);
    }

    .session-updates h4 {
      color: hsl(220, 20%, 95%);
    }

    .session-list li {
      color: hsl(220, 10%, 70%);
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .sync-history {
      padding: 1rem;
    }

    .sync-summary {
      flex-direction: column;
      gap: 0.75rem;
    }

    .sync-overview {
      grid-template-columns: 1fr;
    }

    .overview-item {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.25rem;
    }

    .error-details {
      flex-direction: column;
      gap: 0.25rem;
    }

    .modal-content {
      margin: 1rem;
      max-height: calc(100vh - 2rem);
    }
  }

  /* High contrast mode */
  @media (prefers-contrast: high) {
    .sync-history,
    .sync-item,
    .modal-content {
      border-width: 2px;
    }

    .details-toggle,
    .close-button,
    .retry-button {
      border-width: 2px;
    }
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .details-toggle,
    .close-button,
    .retry-button,
    .sync-item {
      transition: none;
    }
  }

  /* Focus management */
  .sync-item:focus,
  .details-toggle:focus,
  .close-button:focus,
  .retry-button:focus {
    outline: 2px solid hsl(210, 100%, 50%);
    outline-offset: 2px;
  }
</style>