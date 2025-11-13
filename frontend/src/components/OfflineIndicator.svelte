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
  import { isOnline, hasQueuedMessages, syncInProgress, queuedMessageCount } from '../stores/chat';
  import { chatActions } from '../stores/chat';

  let showDetails = false;

  function toggleDetails() {
    showDetails = !showDetails;
  }

  async function handleManualSync() {
    // This would need to be implemented with access to the message sender
    console.log('Manual sync requested');
  }
</script>

<div class="offline-indicator" class:offline={!$isOnline} class:has-queued={$hasQueuedMessages}>
  {#if !$isOnline}
    <div class="status-indicator">
      <div class="status-icon" aria-hidden="true">📴</div>
      <span class="status-text">Offline</span>
      {#if $hasQueuedMessages}
        <button
          class="details-toggle"
          on:click={toggleDetails}
          aria-label="Show queued messages"
          aria-expanded={showDetails}
        >
          {$queuedMessageCount} queued
          <span class="toggle-icon" aria-hidden="true">{showDetails ? '▼' : '▶'}</span>
        </button>
      {/if}
    </div>

    {#if showDetails && $hasQueuedMessages}
      <div class="queued-details" role="region" aria-label="Queued messages">
        <p class="details-text">
          {$queuedMessageCount} message{$queuedMessageCount === 1 ? '' : 's'} queued for sending.
        </p>
        <p class="sync-hint">
          Messages will be sent automatically when connection is restored.
        </p>
      </div>
    {/if}
  {:else if $syncInProgress}
    <div class="status-indicator">
      <div class="status-icon syncing" aria-hidden="true">🔄</div>
      <span class="status-text">Syncing...</span>
    </div>
  {:else if $hasQueuedMessages}
    <div class="status-indicator">
      <div class="status-icon" aria-hidden="true">✅</div>
      <span class="status-text">Synced</span>
      <span class="sync-complete">{$queuedMessageCount} sent</span>
    </div>
  {/if}
</div>

<style>
  .offline-indicator {
    position: fixed;
    top: 1rem;
    right: 1rem;
    z-index: 1000;
    max-width: 300px;
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: hsl(0, 0%, 100%);
    border: 1px solid hsl(220, 20%, 90%);
    border-radius: 8px;
    box-shadow: 0 2px 8px hsla(220, 20%, 20%, 0.1);
    font-size: 0.875rem;
    transition: all 0.2s ease;
  }

  .offline-indicator.offline {
    animation: pulse 2s infinite;
  }

  .offline-indicator.has-queued .status-indicator {
    border-color: hsl(45, 100%, 60%);
    background: hsl(45, 100%, 97%);
  }

  .status-icon {
    font-size: 1rem;
    flex-shrink: 0;
  }

  .status-icon.syncing {
    animation: spin 1s linear infinite;
  }

  .status-text {
    font-weight: 500;
    color: hsl(220, 20%, 20%);
  }

  .offline-indicator.offline .status-text {
    color: hsl(0, 60%, 40%);
  }

  .details-toggle {
    margin-left: auto;
    background: none;
    border: none;
    color: hsl(220, 10%, 60%);
    font-size: 0.75rem;
    cursor: pointer;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .details-toggle:hover {
    background: hsl(220, 20%, 95%);
    color: hsl(220, 20%, 20%);
  }

  .toggle-icon {
    font-size: 0.625rem;
    transition: transform 0.2s ease;
  }

  .queued-details {
    margin-top: 0.5rem;
    padding: 0.75rem 1rem;
    background: hsl(45, 100%, 97%);
    border: 1px solid hsl(45, 100%, 60%);
    border-radius: 8px;
    font-size: 0.8125rem;
    line-height: 1.4;
  }

  .details-text {
    margin: 0 0 0.5rem 0;
    color: hsl(220, 20%, 20%);
  }

  .sync-hint {
    margin: 0;
    color: hsl(220, 10%, 60%);
    font-style: italic;
  }

  .sync-complete {
    font-size: 0.75rem;
    color: hsl(120, 60%, 40%);
    font-weight: 500;
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.7;
    }
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
    .offline-indicator {
      top: 0.5rem;
      right: 0.5rem;
      max-width: calc(100vw - 1rem);
    }

    .status-indicator {
      padding: 0.5rem 0.75rem;
      font-size: 0.8125rem;
    }

    .queued-details {
      padding: 0.5rem 0.75rem;
      font-size: 0.75rem;
    }
  }

  /* High contrast mode */
  @media (prefers-contrast: high) {
    .status-indicator {
      border-width: 2px;
    }

    .queued-details {
      border-width: 2px;
    }
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .offline-indicator.offline {
      animation: none;
    }

    .status-icon.syncing {
      animation: none;
    }

    .details-toggle,
    .toggle-icon {
      transition: none;
    }
  }
</style>