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
  import { createEventDispatcher } from 'svelte';
  import type { ChatSession, ChatMessage } from '../types/chat';

  export let session: ChatSession;
  export let isActive = false;

  const dispatch = createEventDispatcher<{
    select: { session: ChatSession };
    delete: { sessionId: string };
  }>();

  $: lastMessage = session.messages[session.messages.length - 1];
  $: previewText = lastMessage?.content.slice(0, 100) + (lastMessage?.content.length > 100 ? '...' : '') || 'No messages yet';
  $: messageCount = session.messages.length;

  function handleClick() {
    dispatch('select', { session });
  }

  function handleDelete(event: Event) {
    event.stopPropagation();
    dispatch('delete', { sessionId: session.id });
  }

  function formatTime(timestamp: string): string {
    try {
      const date = new Date(timestamp);
      const now = new Date();
      const diffMs = now.getTime() - date.getTime();
      const diffHours = diffMs / (1000 * 60 * 60);

      if (diffHours < 24) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      } else {
        return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
      }
    } catch {
      return '';
    }
  }
</script>

<div
  class="session-card"
  class:active={isActive}
  data-testid="chat-session"
  role="button"
  tabindex="0"
  aria-label="Chat session: {session.title || 'Untitled'} with {messageCount} messages"
  on:click={handleClick}
  on:keydown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleClick();
    }
  }}
>
  <div class="session-header">
    <h3 class="session-title">{session.title || 'Untitled Session'}</h3>
    <button
      class="delete-btn"
      data-testid="delete-session-button"
      aria-label="Delete session"
      on:click={handleDelete}
      on:keydown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          handleDelete(e);
        }
      }}
    >
      <span aria-hidden="true">×</span>
    </button>
  </div>

  <div class="session-preview">
    <p class="preview-text">{previewText}</p>
  </div>

  <div class="session-footer">
    <span class="message-count">{messageCount} messages</span>
    <span class="session-time">{formatTime(session.created_at)}</span>
  </div>
</div>

<style>
  /* OpenCode-inspired Chat Session Card Styling */
  .session-card {
    background: var(--background-surface);
    border: 1px solid var(--border-weak);
    border-radius: var(--radius-lg);
    padding: var(--spacing-4);
    cursor: pointer;
    transition: all 0.15s ease;
    position: relative;
  }

  .session-card:hover {
    border-color: var(--border-base);
    background: var(--button-ghost-hover);
  }

  .session-card:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .session-card.active {
    border-color: var(--accent-primary);
    background: rgba(3, 76, 255, 0.05);
  }

  .session-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: var(--spacing-2);
  }

  .session-title {
    font-size: var(--font-size-base);
    font-weight: var(--font-weight-semibold);
    color: var(--text-strong);
    margin: 0;
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .delete-btn {
    background: none;
    border: none;
    color: var(--accent-error);
    font-size: 1.25rem;
    cursor: pointer;
    padding: var(--spacing-2);
    border-radius: var(--radius-md);
    transition: background-color 0.15s ease;
    flex-shrink: 0;
    min-width: 44px;
    min-height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: calc(var(--spacing-2) * -1);
  }

  .delete-btn:hover {
    background: rgba(252, 83, 58, 0.1);
  }

  .delete-btn:focus-visible {
    outline: 2px solid var(--accent-error);
    outline-offset: 2px;
  }

  .session-preview {
    margin-bottom: var(--spacing-3);
  }

  .preview-text {
    font-size: var(--font-size-small);
    color: var(--text-base);
    margin: 0;
    line-height: var(--line-height-base);
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .session-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: var(--font-size-small);
    color: var(--text-muted);
  }

  .message-count {
    font-weight: var(--font-weight-medium);
  }

  .session-time {
    font-family: var(--font-family-mono);
    font-size: 11px;
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .session-card {
      border: 2px solid currentColor;
    }

    .session-card:hover {
      border-color: currentColor;
    }

    .session-card:focus-visible {
      outline: 3px solid currentColor;
    }

    .session-card.active {
      border-color: currentColor;
      background: var(--button-ghost-hover);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .session-card,
    .delete-btn {
      transition: none;
    }
  }
</style>
