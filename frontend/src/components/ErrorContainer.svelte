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

<!--
Copyright (c) 2025 OpenCode Nexus Contributors
SPDX-License-Identifier: MIT
-->

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
