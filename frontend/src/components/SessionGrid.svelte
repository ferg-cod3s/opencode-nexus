<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import ChatSessionCard from './ChatSessionCard.svelte';
  import type { ChatSession } from '../types/chat';

  export let sessions: ChatSession[] = [];
  export let activeSessionId: string | null = null;
  export let loading = false;
  
  // Callback props for imperative mounting (optional)
  export let onCreateSession: (() => void) | undefined = undefined;
  export let onSelectSession: ((session: ChatSession) => void) | undefined = undefined;
  export let onDeleteSession: ((sessionId: string) => void) | undefined = undefined;

  const dispatch = createEventDispatcher<{
    createSession: void;
    selectSession: { session: ChatSession };
    deleteSession: { sessionId: string };
  }>();

  function handleCreateSession() {
    if (onCreateSession) {
      onCreateSession();
    } else {
      dispatch('createSession');
    }
  }

  function handleSelectSession(event: CustomEvent<{ session: ChatSession }>) {
    if (onSelectSession) {
      onSelectSession(event.detail.session);
    } else {
      dispatch('selectSession', event.detail);
    }
  }

  function handleDeleteSession(event: CustomEvent<{ sessionId: string }>) {
    if (onDeleteSession) {
      onDeleteSession(event.detail.sessionId);
    } else {
      dispatch('deleteSession', event.detail);
    }
  }
</script>

<div class="session-grid-container">
  <div class="grid-header">
    <h2 class="grid-title">Chat Sessions</h2>
    <button
      class="create-btn"
      data-testid="new-session-button"
      on:click={handleCreateSession}
      disabled={loading}
      aria-label="Create new chat session"
    >
      <span aria-hidden="true">+</span>
      New Session
    </button>
  </div>

  {#if loading}
    <div class="loading-state" aria-live="polite">
      <div class="spinner" aria-hidden="true"></div>
      <span>Loading sessions...</span>
    </div>
  {:else if sessions.length === 0}
    <div class="empty-state">
      <div class="empty-icon" aria-hidden="true">💬</div>
      <h3 class="empty-title">No chat sessions yet</h3>
      <p class="empty-description">
        Create your first session to start chatting with OpenCode AI.
      </p>
      <button
        class="create-btn primary"
        data-testid="create-first-session-button"
        on:click={handleCreateSession}
        aria-label="Create your first chat session"
      >
        Start Chatting
      </button>
    </div>
  {:else}
    <div class="session-grid" role="grid" aria-label="Chat sessions">
      {#each sessions as session (session.id)}
        <div role="gridcell">
          <ChatSessionCard
            {session}
            isActive={session.id === activeSessionId}
            on:select={handleSelectSession}
            on:delete={handleDeleteSession}
          />
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .session-grid-container {
    padding: 1.5rem;
    max-width: 1200px;
    margin: 0 auto;
  }

  .grid-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
  }

  .grid-title {
    font-size: 1.5rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    margin: 0;
  }

  .create-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.625rem 1rem;
    border: 2px solid hsl(220, 90%, 60%);
    background: hsl(220, 90%, 60%);
    color: white;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .create-btn:hover:not(:disabled) {
    background: hsl(220, 80%, 50%);
    border-color: hsl(220, 80%, 50%);
    transform: translateY(-1px);
  }

  .create-btn:active:not(:disabled) {
    transform: translateY(0);
  }

  .create-btn:disabled {
    background: hsl(220, 20%, 80%);
    border-color: hsl(220, 20%, 80%);
    cursor: not-allowed;
    transform: none;
  }

  .create-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .create-btn.primary {
    background: hsl(220, 90%, 60%);
    border-color: hsl(220, 90%, 60%);
  }

  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    color: hsl(220, 10%, 60%);
  }

  .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid hsl(220, 20%, 90%);
    border-top: 3px solid hsl(220, 90%, 60%);
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 1rem;
  }

  .empty-state {
    text-align: center;
    padding: 3rem 1rem;
    color: hsl(220, 10%, 60%);
  }

  .empty-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .empty-title {
    font-size: 1.25rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    margin: 0 0 0.5rem 0;
  }

  .empty-description {
    font-size: 1rem;
    margin: 0 0 1.5rem 0;
    max-width: 400px;
    margin-left: auto;
    margin-right: auto;
  }

  .session-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1rem;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .create-btn {
      border: 2px solid hsl(0, 0%, 0%);
      background: hsl(0, 0%, 0%);
      color: hsl(0, 0%, 100%);
    }

    .create-btn:hover:not(:disabled) {
      background: hsl(0, 0%, 20%);
      border-color: hsl(0, 0%, 0%);
    }

    .create-btn:focus {
      outline: 3px solid hsl(0, 0%, 0%);
    }

    .spinner {
      border: 3px solid hsl(0, 0%, 0%);
      border-top: 3px solid hsl(0, 0%, 100%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .create-btn {
      transition: none;
    }

    .create-btn:hover:not(:disabled) {
      transform: none;
    }

    .create-btn:active:not(:disabled) {
      transform: none;
    }

    .spinner {
      animation: none;
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .session-grid-container {
      padding: 1rem;
    }

    .grid-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 1rem;
    }

    .grid-title {
      font-size: 1.25rem;
    }

    .session-grid {
      grid-template-columns: 1fr;
      gap: 0.75rem;
    }

    .empty-state {
      padding: 2rem 1rem;
    }
  }
</style>
