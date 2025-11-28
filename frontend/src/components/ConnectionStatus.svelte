<!--
  Connection Status Indicator Component
  Displays real-time connection state with visual feedback and error messages
  Subscribes to chatStateStore for connection status and error information
-->

<script lang="ts">
  import { chatStateStore } from '../stores/chat';
  import { onDestroy } from 'svelte';

  let connected = false;
  let error: string | null = null;

  // Subscribe to store changes
  const unsubscribeConnected = chatStateStore.subscribe((state) => {
    connected = state.connected;
    error = state.error;
  });

  // Cleanup on component destroy
  onDestroy(() => {
    unsubscribeConnected();
  });

  function getStatusLabel(): string {
    if (error) return 'Error';
    if (connected) return 'Connected';
    return 'Disconnected';
  }

  function getStatusIcon(): string {
    if (error) return '⚠️';
    if (connected) return '🟢';
    return '🔴';
  }

  function getStatusColor(): string {
    if (error) return 'var(--color-danger, #dc2626)';
    if (connected) return 'var(--color-success, #16a34a)';
    return 'var(--color-warning, #ea580c)';
  }
</script>

<div class="connection-status" class:error class:connected>
  <div class="status-indicator">
    <span class="icon" style="color: {getStatusColor()}">
      {getStatusIcon()}
    </span>
    <span class="label">{getStatusLabel()}</span>
  </div>

  {#if error}
    <div class="error-message" role="alert">
      {error}
    </div>
  {/if}
</div>

<style>
  /* OpenCode-inspired Connection Status Styling */
  .connection-status {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-2);
    padding: var(--spacing-3) var(--spacing-4);
    border-radius: var(--radius-lg);
    background: var(--background-weak);
    border: 1px solid var(--border-weak);
  }

  .connection-status.connected {
    background: rgba(18, 201, 5, 0.1);
    border-color: var(--accent-success);
  }

  .connection-status.error {
    background: rgba(252, 83, 58, 0.1);
    border-color: var(--accent-error);
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    font-weight: var(--font-weight-medium);
    font-size: var(--font-size-small);
  }

  .icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    line-height: 1;
  }

  .label {
    color: var(--text-base);
  }

  .connection-status.connected .label {
    color: var(--accent-success);
  }

  .connection-status.error .label {
    color: var(--accent-error);
  }

  .error-message {
    margin-left: 1.5rem;
    padding: var(--spacing-2) 0;
    font-size: var(--font-size-small);
    color: var(--accent-error);
    border-left: 2px solid var(--accent-error);
    padding-left: var(--spacing-3);
    line-height: var(--line-height-base);
  }

  /* Accessibility: ensure visibility at all times */
  @media (prefers-reduced-motion: reduce) {
    .connection-status {
      transition: none;
    }
  }
</style>
