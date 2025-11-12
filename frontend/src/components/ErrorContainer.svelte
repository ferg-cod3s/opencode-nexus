<script lang="ts">
  /**
   * ErrorContainer Component
   *
   * Container for displaying all error notifications from the error store.
   * Positioned at the top of the screen for visibility.
   */

  import { errorStore, type ErrorNotification } from '../stores/errorStore';
  import ErrorToast from './ErrorToast.svelte';

  let errors: ErrorNotification[] = [];

  // Subscribe to error store
  errorStore.subscribe((store) => {
    errors = store.errors;
  });

  function handleClose(id: string) {
    errorStore.removeError(id);
  }
</script>

<div class="error-container" aria-live="polite">
  {#each errors as error (error.id)}
    <ErrorToast
      message={error.message}
      details={error.details || ''}
      isRetryable={error.isRetryable}
      onRetry={error.onRetry || null}
      onClose={() => handleClose(error.id)}
      autoDismiss={true}
      dismissTimeout={8000}
    />
  {/each}
</div>

<style>
  .error-container {
    position: fixed;
    top: 1rem;
    left: 50%;
    transform: translateX(-50%);
    z-index: 9999;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    pointer-events: none;
  }

  .error-container > :global(*) {
    pointer-events: auto;
  }

  /* Mobile optimizations */
  @media (max-width: 600px) {
    .error-container {
      top: 0.5rem;
      width: 100%;
      padding: 0 0.5rem;
    }
  }

  /* Ensure container doesn't block content */
  @media (max-height: 600px) {
    .error-container {
      max-height: 50vh;
      overflow-y: auto;
    }
  }
</style>
