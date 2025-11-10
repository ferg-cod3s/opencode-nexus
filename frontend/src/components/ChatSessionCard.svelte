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

  // Swipe-to-delete state
  let touchStartX = 0;
  let touchStartY = 0;
  let touchCurrentX = 0;
  let swipeDistance = 0;
  let isSwiping = false;
  let cardElement: HTMLDivElement;

  const SWIPE_THRESHOLD = 80; // Minimum swipe distance to trigger delete
  const DELETE_THRESHOLD = 150; // Distance to auto-delete

  function handleClick() {
    // Only trigger select if not swiping
    if (!isSwiping && Math.abs(swipeDistance) < 10) {
      dispatch('select', { session });
    }
  }

  function handleDelete(event: Event) {
    event.stopPropagation();
    dispatch('delete', { sessionId: session.id });
  }

  function handleTouchStart(event: TouchEvent) {
    touchStartX = event.touches[0].clientX;
    touchStartY = event.touches[0].clientY;
    touchCurrentX = touchStartX;
    isSwiping = false;
  }

  function handleTouchMove(event: TouchEvent) {
    touchCurrentX = event.touches[0].clientX;
    const touchCurrentY = event.touches[0].clientY;

    const deltaX = touchCurrentX - touchStartX;
    const deltaY = touchCurrentY - touchStartY;

    // Only start swiping if horizontal movement is more significant
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 10) {
      isSwiping = true;

      // Only allow left swipe (negative delta)
      if (deltaX < 0) {
        swipeDistance = Math.max(deltaX, -DELETE_THRESHOLD);
        event.preventDefault(); // Prevent scrolling while swiping
      }
    }
  }

  function handleTouchEnd() {
    if (Math.abs(swipeDistance) >= DELETE_THRESHOLD) {
      // Auto-delete if swiped far enough
      handleDelete(new Event('delete'));
    } else if (Math.abs(swipeDistance) < SWIPE_THRESHOLD) {
      // Reset if didn't swipe enough
      swipeDistance = 0;
    } else {
      // Keep delete button visible
      swipeDistance = -SWIPE_THRESHOLD;
    }

    // Reset swiping flag after a short delay
    setTimeout(() => {
      isSwiping = false;
    }, 100);
  }

  function handleSwipeDelete(event: Event) {
    event.stopPropagation();
    swipeDistance = 0; // Reset swipe
    handleDelete(event);
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

<div class="session-card-wrapper">
  <!-- Delete action revealed by swipe -->
  <div class="swipe-delete-action">
    <button
      class="swipe-delete-btn"
      aria-label="Delete session"
      on:click={handleSwipeDelete}
    >
      Delete
    </button>
  </div>

  <!-- Main card content -->
  <div
    bind:this={cardElement}
    class="session-card"
    class:active={isActive}
    class:swiping={isSwiping}
    data-testid="chat-session"
    role="button"
    tabindex="0"
    aria-label="Chat session: {session.title || 'Untitled'} with {messageCount} messages"
    style="transform: translateX({swipeDistance}px); transition: {isSwiping ? 'none' : 'transform 0.3s ease'};"
    on:click={handleClick}
    on:touchstart={handleTouchStart}
    on:touchmove={handleTouchMove}
    on:touchend={handleTouchEnd}
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
</div>

<style>
  .session-card-wrapper {
    position: relative;
    overflow: hidden;
    border-radius: 8px;
  }

  .swipe-delete-action {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    width: 150px;
    background: hsl(0, 70%, 55%);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .swipe-delete-btn {
    background: none;
    border: none;
    color: white;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    padding: 1rem;
    width: 100%;
    height: 100%;
  }

  .session-card {
    background: hsl(220, 20%, 98%);
    border: 2px solid hsl(220, 20%, 90%);
    border-radius: 8px;
    padding: 1rem;
    cursor: pointer;
    position: relative;
    touch-action: pan-y; /* Allow vertical scrolling but handle horizontal swipes */
    user-select: none; /* Prevent text selection during swipe */
    -webkit-user-select: none;
  }

  .session-card.swiping {
    cursor: grabbing;
  }

  .session-card:hover {
    border-color: hsl(220, 60%, 60%);
    box-shadow: 0 2px 8px hsla(220, 60%, 60%, 0.2);
  }

  .session-card:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .session-card.active {
    border-color: hsl(220, 90%, 60%);
    background: hsl(220, 30%, 96%);
  }

  .session-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 0.5rem;
  }

  .session-title {
    font-size: 1rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    margin: 0;
    flex: 1;
    min-width: 0;
  }

  .delete-btn {
    background: none;
    border: none;
    color: hsl(0, 60%, 50%);
    font-size: 1.25rem;
    cursor: pointer;
    padding: 0.5rem; /* Mobile-friendly padding for 44px touch target */
    border-radius: 4px;
    transition: background-color 0.2s ease;
    flex-shrink: 0;
    min-width: 44px;
    min-height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .delete-btn:hover {
    background: hsl(0, 60%, 95%);
  }

  .delete-btn:focus {
    outline: 2px solid hsl(0, 60%, 50%);
    outline-offset: 2px;
  }

  .session-preview {
    margin-bottom: 0.75rem;
  }

  .preview-text {
    font-size: 0.875rem;
    color: hsl(220, 10%, 50%);
    margin: 0;
    line-height: 1.4;
  }

  .session-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
  }

  .message-count {
    font-weight: 500;
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .session-card {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .session-card:hover {
      border-color: hsl(0, 0%, 0%);
      box-shadow: 0 2px 8px hsla(0, 0%, 0%, 0.3);
    }

    .session-card:focus {
      outline: 3px solid hsl(0, 0%, 0%);
    }

    .session-card.active {
      border-color: hsl(0, 0%, 0%);
      background: hsl(0, 0%, 95%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .session-card {
      transition: none;
    }

    .delete-btn {
      transition: none;
    }
  }
</style>
