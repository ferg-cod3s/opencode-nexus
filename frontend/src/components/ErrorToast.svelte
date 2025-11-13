<!--
Copyright (c) 2025 OpenCode Nexus Contributors
SPDX-License-Identifier: MIT
-->

<script lang="ts">
  /**
   * ErrorToast Component
   *
   * Displays user-friendly error messages with retry options.
   * Automatically dismisses after a timeout or can be manually closed.
   *
   * Features:
   * - User-friendly error messages
   * - Retry button for retryable errors
   * - Auto-dismiss after 8 seconds
   * - Accessibility support (ARIA labels, keyboard navigation)
   * - Mobile-optimized touch targets
   */

  export let message: string = '';
  export let details: string = '';
  export let isRetryable: boolean = false;
  export let onRetry: (() => void) | null = null;
  export let onClose: () => void = () => {};
  export let autoDismiss: boolean = true;
  export let dismissTimeout: number = 8000;

  let visible = true;
  let timeoutId: number | null = null;

  // Auto-dismiss after timeout
  $: if (visible && autoDismiss) {
    if (timeoutId) clearTimeout(timeoutId);
    timeoutId = window.setTimeout(() => {
      visible = false;
      onClose();
    }, dismissTimeout);
  }

  function handleClose() {
    if (timeoutId) clearTimeout(timeoutId);
    visible = false;
    onClose();
  }

  function handleRetry() {
    if (onRetry) {
      if (timeoutId) clearTimeout(timeoutId);
      visible = false;
      onRetry();
    }
  }

  // Cleanup timeout on component destroy
  import { onDestroy } from 'svelte';
  onDestroy(() => {
    if (timeoutId) clearTimeout(timeoutId);
  });
</script>

{#if visible}
  <div
    class="error-toast"
    role="alert"
    aria-live="assertive"
    aria-atomic="true"
  >
    <div class="error-icon" aria-hidden="true">⚠️</div>

    <div class="error-content">
      <div class="error-message">{message}</div>
      {#if details}
        <div class="error-details">{details}</div>
      {/if}
    </div>

    <div class="error-actions">
      {#if isRetryable && onRetry}
        <button
          class="retry-button"
          on:click={handleRetry}
          aria-label="Retry operation"
        >
          Retry
        </button>
      {/if}
      <button
        class="close-button"
        on:click={handleClose}
        aria-label="Dismiss error message"
      >
        ×
      </button>
    </div>
  </div>
{/if}

<style>
  .error-toast {
    display: flex;
    align-items: flex-start;
    gap: 1rem;
    padding: 1rem;
    background-color: hsl(0, 70%, 95%);
    border: 2px solid hsl(0, 70%, 70%);
    border-radius: 8px;
    box-shadow: 0 4px 12px hsla(0, 0%, 0%, 0.15);
    max-width: 500px;
    width: 90vw;
    margin: 1rem auto;
    animation: slideIn 0.3s ease-out;
  }

  @keyframes slideIn {
    from {
      transform: translateY(-20px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  .error-icon {
    font-size: 1.5rem;
    line-height: 1;
    flex-shrink: 0;
  }

  .error-content {
    flex: 1;
    min-width: 0;
  }

  .error-message {
    font-weight: 600;
    color: hsl(0, 70%, 25%);
    margin-bottom: 0.25rem;
  }

  .error-details {
    font-size: 0.875rem;
    color: hsl(0, 50%, 40%);
    word-break: break-word;
  }

  .error-actions {
    display: flex;
    gap: 0.5rem;
    flex-shrink: 0;
  }

  .retry-button,
  .close-button {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.875rem;
    font-weight: 500;
    transition: all 0.2s ease;
    min-width: 44px; /* WCAG touch target size */
    min-height: 44px;
  }

  .retry-button {
    background-color: hsl(210, 70%, 50%);
    color: white;
  }

  .retry-button:hover {
    background-color: hsl(210, 70%, 45%);
  }

  .retry-button:focus {
    outline: 2px solid hsl(210, 70%, 50%);
    outline-offset: 2px;
  }

  .close-button {
    background-color: transparent;
    color: hsl(0, 50%, 40%);
    font-size: 1.5rem;
    padding: 0.25rem 0.75rem;
  }

  .close-button:hover {
    background-color: hsla(0, 0%, 0%, 0.1);
  }

  .close-button:focus {
    outline: 2px solid hsl(0, 50%, 40%);
    outline-offset: 2px;
  }

  /* Mobile optimizations */
  @media (max-width: 600px) {
    .error-toast {
      width: 95vw;
      padding: 0.875rem;
      gap: 0.75rem;
    }

    .error-message {
      font-size: 0.9375rem;
    }

    .error-details {
      font-size: 0.8125rem;
    }
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .error-toast {
      border-width: 3px;
    }

    .retry-button,
    .close-button {
      border: 2px solid currentColor;
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .error-toast {
      animation: none;
    }
  }
</style>
