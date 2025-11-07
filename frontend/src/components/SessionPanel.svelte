<script lang="ts">
  import { onMount } from 'svelte';
  import ChatSessionCard from './ChatSessionCard.svelte';
  import type { ChatSession } from '../types/chat';
  import {
    sessionsStore,
    activeSessionStore,
    chatStateStore,
    chatStore
  } from '../stores/chat';
  import { chatApiCallbacks } from '../utils/chat-api';

  let isCreating = false;
  let error: string | null = null;
  let expandedSessions = true;

  // Subscribe to store
  $: sessions = $sessionsStore;
  $: activeSession = $activeSessionStore;
  $: isLoading = $chatStateStore.loading;

  async function handleCreateSession() {
    if (isCreating) return;

    try {
      isCreating = true;
      error = null;

      const newSession = await chatStore.actions.createSession(
        chatApiCallbacks.sessionCreator
      );

      // Automatically select the new session
      chatStore.actions.selectSession(newSession);

      console.log('✨ [SESSION PANEL] Created and selected session:', newSession.id);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      error = `Failed to create session: ${errorMsg}`;
      console.error('❌ [SESSION PANEL]', error);
    } finally {
      isCreating = false;
    }
  }

  async function handleSelectSession(session: ChatSession) {
    try {
      error = null;
      chatStore.actions.selectSession(session);
      console.log('🔀 [SESSION PANEL] Selected session:', session.id);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      error = `Failed to select session: ${errorMsg}`;
      console.error('❌ [SESSION PANEL]', error);
    }
  }

  async function handleDeleteSession(sessionId: string) {
    if (!confirm('Are you sure you want to delete this session?')) {
      return;
    }

    try {
      isCreating = true;
      error = null;

      await chatStore.actions.deleteSession(
        sessionId,
        chatApiCallbacks.sessionDeleter
      );

      console.log('🗑️ [SESSION PANEL] Deleted session:', sessionId);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      error = `Failed to delete session: ${errorMsg}`;
      console.error('❌ [SESSION PANEL]', error);
    } finally {
      isCreating = false;
    }
  }

  onMount(() => {
    console.log('📋 [SESSION PANEL] Component mounted');
    return () => {
      console.log('📋 [SESSION PANEL] Component unmounted');
    };
  });
</script>

<div class="session-panel" data-testid="session-panel">
  <!-- Panel Header -->
  <div class="panel-header">
    <div class="header-content">
      <button
        class="toggle-btn"
        on:click={() => (expandedSessions = !expandedSessions)}
        aria-label={expandedSessions ? 'Collapse sessions' : 'Expand sessions'}
        title={expandedSessions ? 'Collapse' : 'Expand'}
      >
        <span class="toggle-icon" style="transform: rotate({expandedSessions ? 0 : -90}deg)">›</span>
      </button>
      <h2 class="panel-title">Conversations</h2>
      <span class="session-count">{sessions.length}</span>
    </div>

    <!-- Create Session Button -->
    <button
      class="create-btn"
      on:click={handleCreateSession}
      disabled={isCreating || isLoading}
      aria-label="Create new chat session"
      title="Create new session (Ctrl+N)"
      data-testid="create-session-button"
      style="min-width: 44px; min-height: 44px;"
    >
      <span aria-hidden="true">+</span>
      <span class="sr-only">Create new session</span>
    </button>
  </div>

  <!-- Error Message -->
  {#if error}
    <div class="error-banner" role="alert" data-testid="session-error">
      <span>{error}</span>
      <button
        class="error-close"
        on:click={() => (error = null)}
        aria-label="Dismiss error"
      >
        ×
      </button>
    </div>
  {/if}

  <!-- Sessions List -->
  {#if expandedSessions}
    <div class="sessions-list" data-testid="sessions-list">
      {#if sessions.length === 0}
        <div class="empty-state">
          <p>No conversations yet</p>
          <p class="empty-hint">Click + to start a new chat</p>
        </div>
      {:else}
        {#each sessions as session (session.id)}
          <ChatSessionCard
            {session}
            isActive={activeSession?.id === session.id}
            on:select={({ detail }) => handleSelectSession(detail.session)}
            on:delete={({ detail }) => handleDeleteSession(detail.sessionId)}
          />
        {/each}
      {/if}
    </div>
  {/if}
</div>

<style>
  .session-panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: hsl(220, 20%, 96%);
    border-right: 1px solid hsl(220, 20%, 90%);
    overflow: hidden;
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem;
    border-bottom: 1px solid hsl(220, 20%, 90%);
    flex-shrink: 0;
    gap: 0.75rem;
  }

  .header-content {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex: 1;
    min-width: 0;
  }

  .toggle-btn {
    background: none;
    border: none;
    color: hsl(220, 20%, 40%);
    font-size: 1.25rem;
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 4px;
    transition: background-color 0.2s ease, transform 0.2s ease;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 32px;
    min-height: 32px;
  }

  .toggle-btn:hover {
    background: hsl(220, 20%, 88%);
  }

  .toggle-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .toggle-icon {
    display: inline-block;
    transition: transform 0.2s ease;
  }

  .panel-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    margin: 0;
    flex: 1;
    min-width: 0;
  }

  .session-count {
    font-size: 0.875rem;
    color: hsl(220, 10%, 60%);
    background: hsl(220, 20%, 88%);
    padding: 0.25rem 0.5rem;
    border-radius: 12px;
    font-weight: 500;
    flex-shrink: 0;
  }

  .create-btn {
    background: hsl(220, 90%, 60%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1.25rem;
    cursor: pointer;
    padding: 0.5rem;
    transition: background-color 0.2s ease;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .create-btn:hover:not(:disabled) {
    background: hsl(220, 90%, 50%);
  }

  .create-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .create-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .error-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: hsl(0, 80%, 95%);
    border-bottom: 1px solid hsl(0, 60%, 50%);
    color: hsl(0, 60%, 30%);
    padding: 0.75rem 1rem;
    font-size: 0.875rem;
    gap: 0.75rem;
    flex-shrink: 0;
  }

  .error-close {
    background: none;
    border: none;
    color: hsl(0, 60%, 50%);
    font-size: 1.25rem;
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .error-close:hover {
    color: hsl(0, 60%, 30%);
  }

  .sessions-list {
    flex: 1;
    overflow-y: auto;
    padding: 0.75rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .sessions-list::-webkit-scrollbar {
    width: 6px;
  }

  .sessions-list::-webkit-scrollbar-track {
    background: transparent;
  }

  .sessions-list::-webkit-scrollbar-thumb {
    background: hsl(220, 20%, 80%);
    border-radius: 3px;
  }

  .sessions-list::-webkit-scrollbar-thumb:hover {
    background: hsl(220, 20%, 70%);
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    color: hsl(220, 10%, 60%);
    text-align: center;
    padding: 2rem 1rem;
  }

  .empty-state p {
    margin: 0.5rem 0;
  }

  .empty-state p:first-child {
    font-weight: 500;
    color: hsl(220, 20%, 40%);
  }

  .empty-hint {
    font-size: 0.875rem;
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .session-panel {
      border-right: 2px solid hsl(0, 0%, 0%);
    }

    .panel-header {
      border-bottom: 2px solid hsl(0, 0%, 0%);
    }

    .create-btn {
      background: hsl(0, 0%, 0%);
      color: hsl(0, 0%, 100%);
      border: 2px solid hsl(0, 0%, 0%);
    }

    .error-banner {
      border-bottom: 2px solid hsl(0, 100%, 30%);
      background: hsl(0, 100%, 95%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .toggle-btn,
    .toggle-icon,
    .create-btn {
      transition: none;
    }
  }

  /* Mobile-first responsive design */
  @media (max-width: 640px) {
    .session-panel {
      max-height: 200px;
    }

    .panel-title {
      font-size: 1rem;
    }

    .session-count {
      font-size: 0.75rem;
      padding: 0.125rem 0.375rem;
    }
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .session-panel {
      width: 280px;
      max-height: none;
    }

    .panel-header {
      padding: 1.25rem;
    }

    .sessions-list {
      padding: 1rem;
      gap: 1rem;
    }
  }

  /* Desktop breakpoint (1024px+) */
  @media (min-width: 1024px) {
    .session-panel {
      width: 320px;
    }
  }
</style>
