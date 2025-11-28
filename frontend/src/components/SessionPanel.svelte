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
  /* OpenCode-inspired Session Panel Styling */
  .session-panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--background-weak);
    border-right: 1px solid var(--border-weak);
    overflow: hidden;
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--spacing-4);
    border-bottom: 1px solid var(--border-weak);
    flex-shrink: 0;
    gap: var(--spacing-3);
  }

  .header-content {
    display: flex;
    align-items: center;
    gap: var(--spacing-3);
    flex: 1;
    min-width: 0;
  }

  .toggle-btn {
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 1.25rem;
    cursor: pointer;
    padding: var(--spacing-2);
    border-radius: var(--radius-md);
    transition: background-color 0.15s ease, transform 0.15s ease;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 44px;
    min-height: 44px;
  }

  .toggle-btn:hover {
    background: var(--button-ghost-hover);
    color: var(--text-strong);
  }

  .toggle-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .toggle-icon {
    display: inline-block;
    transition: transform 0.15s ease;
  }

  .panel-title {
    font-size: var(--font-size-large);
    font-weight: var(--font-weight-semibold);
    color: var(--text-strong);
    margin: 0;
    flex: 1;
    min-width: 0;
  }

  .session-count {
    font-size: var(--font-size-small);
    color: var(--text-muted);
    background: var(--button-ghost-hover);
    padding: var(--spacing-1) var(--spacing-2);
    border-radius: var(--radius-full);
    font-weight: var(--font-weight-medium);
    flex-shrink: 0;
  }

  .create-btn {
    background: var(--button-primary-bg);
    color: var(--button-primary-text);
    border: none;
    border-radius: var(--radius-md);
    font-size: 1.25rem;
    cursor: pointer;
    padding: var(--spacing-2);
    transition: filter 0.15s ease;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .create-btn:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  .create-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
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
    background: rgba(252, 83, 58, 0.1);
    border-bottom: 1px solid var(--accent-error);
    color: var(--accent-error);
    padding: var(--spacing-3) var(--spacing-4);
    font-size: var(--font-size-small);
    gap: var(--spacing-3);
    flex-shrink: 0;
  }

  .error-close {
    background: none;
    border: none;
    color: var(--accent-error);
    font-size: 1.25rem;
    cursor: pointer;
    padding: var(--spacing-2);
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 44px;
    min-height: 44px;
    border-radius: var(--radius-md);
    transition: background-color 0.15s ease;
  }

  .error-close:hover {
    background: rgba(252, 83, 58, 0.2);
  }

  .sessions-list {
    flex: 1;
    overflow-y: auto;
    padding: var(--spacing-3);
    display: flex;
    flex-direction: column;
    gap: var(--spacing-3);
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    color: var(--text-muted);
    text-align: center;
    padding: var(--spacing-8) var(--spacing-4);
  }

  .empty-state p {
    margin: var(--spacing-2) 0;
  }

  .empty-state p:first-child {
    font-weight: var(--font-weight-medium);
    color: var(--text-base);
  }

  .empty-hint {
    font-size: var(--font-size-small);
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
      border-right: 2px solid currentColor;
    }

    .panel-header {
      border-bottom: 2px solid currentColor;
    }

    .create-btn {
      background: currentColor;
      border: 2px solid currentColor;
    }

    .error-banner {
      border-bottom: 2px solid currentColor;
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .toggle-btn,
    .toggle-icon,
    .create-btn,
    .error-close {
      transition: none;
    }
  }

  /* Mobile-first responsive design */
  @media (max-width: 640px) {
    .session-panel {
      max-height: 200px;
    }

    .panel-title {
      font-size: var(--font-size-base);
    }

    .session-count {
      font-size: var(--font-size-small);
      padding: 2px var(--spacing-2);
    }
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .session-panel {
      width: 260px;
      max-height: none;
    }

    .panel-header {
      padding: var(--spacing-5);
    }

    .sessions-list {
      padding: var(--spacing-4);
      gap: var(--spacing-4);
    }
  }

  /* Desktop breakpoint (1024px+) */
  @media (min-width: 1024px) {
    .session-panel {
      width: 280px;
    }
  }
</style>
