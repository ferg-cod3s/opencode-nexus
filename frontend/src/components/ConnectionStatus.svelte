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
  .connection-status {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    background: hsl(0, 0%, 98%);
    border: 1px solid hsl(220, 14%, 90%);
  }

  .connection-status.connected {
    background: hsl(120, 80%, 98%);
    border-color: hsl(120, 70%, 85%);
  }

  .connection-status.error {
    background: hsl(0, 84%, 98%);
    border-color: hsl(0, 84%, 85%);
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 500;
    font-size: 0.95rem;
  }

  .icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 1.1rem;
    line-height: 1;
  }

  .label {
    color: hsl(220, 10%, 30%);
  }

  .connection-status.connected .label {
    color: hsl(120, 40%, 25%);
  }

  .connection-status.error .label {
    color: hsl(0, 84%, 25%);
  }

  .error-message {
    margin-left: 1.6rem;
    padding: 0.5rem 0;
    font-size: 0.85rem;
    color: hsl(0, 84%, 35%);
    border-left: 2px solid hsl(0, 84%, 60%);
    padding-left: 0.75rem;
    line-height: 1.4;
  }

  /* Accessibility: ensure visibility at all times */
  @media (prefers-reduced-motion: reduce) {
    .connection-status {
      transition: none;
    }
  }

  /* Dark mode support */
  @media (prefers-color-scheme: dark) {
    .connection-status {
      background: hsl(220, 20%, 15%);
      border-color: hsl(220, 20%, 25%);
    }

    .connection-status.connected {
      background: hsl(120, 30%, 20%);
      border-color: hsl(120, 30%, 30%);
    }

    .connection-status.error {
      background: hsl(0, 40%, 20%);
      border-color: hsl(0, 40%, 30%);
    }

    .label {
      color: hsl(220, 10%, 80%);
    }

    .connection-status.connected .label {
      color: hsl(120, 40%, 75%);
    }

    .connection-status.error .label {
      color: hsl(0, 70%, 75%);
    }

    .error-message {
      color: hsl(0, 70%, 70%);
      border-left-color: hsl(0, 70%, 50%);
    }
  }
</style>
