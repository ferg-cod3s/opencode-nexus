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
  import { createEventDispatcher, onMount } from 'svelte';
  import MessageBubble from './MessageBubble.svelte';
  import MessageInput from './MessageInput.svelte';
  import OfflineIndicator from './OfflineIndicator.svelte';
  import StreamingIndicator from './StreamingIndicator.svelte';
  import type { ChatSession, ChatMessage } from '../types/chat';
  import { activeSessionStore, chatStateStore } from '../stores/chat';

  // Accept external session prop OR use store
  export let session: ChatSession | undefined = undefined;
  export let loading = false;
  
  // Callback props for imperative mounting (optional)
  export let onSendMessage: ((content: string) => void) | undefined = undefined;
  export let onClose: (() => void) | undefined = undefined;

  const dispatch = createEventDispatcher<{
    sendMessage: { content: string };
    close: void;
    navigateMessage: { direction: 'prev' | 'next' };
    refresh: void;
  }>();

  // Use external prop if provided, otherwise subscribe to store
  $: activeSession = session !== undefined ? session : $activeSessionStore;
  $: isLoading = loading || $chatStateStore.loading;
  $: currentMessages = activeSession?.messages ?? [];
 
  let messagesContainer: HTMLElement;
  let autoScroll = true;
  let isRefreshing = false;

  let touchStartY = 0;
  let touchStartX = 0;
  let touchEndY = 0;
  let touchEndX = 0;
  let isSwipeGesture = false;
  let pullDistance = 0;
  let isPulling = false;
  let viewportHeight = 0;
  let keyboardVisible = false;

  // Virtual scrolling state
  let visibleMessages: ChatMessage[] = [];
  let startIndex = 0;
  let endIndex = 0;
  let itemHeight = 80; // Estimated height per message
  let containerHeight = 0;
  let scrollTop = 0;

  // Touch gesture thresholds
  const SWIPE_THRESHOLD = 50;
  const PULL_THRESHOLD = 80;

  $: if (messagesContainer && autoScroll && activeSession) {
    // Auto-scroll to bottom when new messages arrive
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }

  // Update virtual scrolling when messages change
  $: updateVirtualScroll(currentMessages);

  function updateVirtualScroll(messages: ChatMessage[]) {
    if (!messagesContainer) return;

    const totalHeight = messages.length * itemHeight;
    const visibleCount = Math.ceil(containerHeight / itemHeight) + 5; // Add buffer

    startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - 2);
    endIndex = Math.min(messages.length, startIndex + visibleCount);

    visibleMessages = messages.slice(startIndex, endIndex);
  }

  function handleSendMessage(content: string) {
    // Use callback if provided, otherwise dispatch event
    if (onSendMessage) {
      onSendMessage(content);
    } else {
      dispatch('sendMessage', { content });
    }
  }

  function handleClose() {
    // Use callback if provided, otherwise dispatch event
    if (onClose) {
      onClose();
    } else {
      dispatch('close');
    }
  }

  function handleScroll() {
    if (messagesContainer) {
      const { scrollTop: newScrollTop, scrollHeight, clientHeight } = messagesContainer;
      scrollTop = newScrollTop;
      containerHeight = clientHeight;

      // Enable auto-scroll if user is near bottom
      autoScroll = scrollTop + clientHeight >= scrollHeight - 100;
 
      // Update virtual scroll
      updateVirtualScroll(currentMessages);

    }
  }

  // Touch gesture handlers
  function handleTouchStart(event: TouchEvent) {
    touchStartY = event.touches[0].clientY;
    touchStartX = event.touches[0].clientX;
    isSwipeGesture = false;
    pullDistance = 0;
    isPulling = scrollTop === 0; // Only allow pull-to-refresh at top
  }

  function handleTouchMove(event: TouchEvent) {
    if (!messagesContainer) return;

    touchEndY = event.touches[0].clientY;
    touchEndX = event.touches[0].clientX;

    const deltaY = touchEndY - touchStartY;
    const deltaX = Math.abs(touchEndX - touchStartX);

    // Determine if this is a vertical scroll or horizontal swipe
    if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > 10) {
      // Vertical gesture - handle pull-to-refresh
      if (isPulling && deltaY > 0) {
        pullDistance = Math.min(deltaY * 0.5, PULL_THRESHOLD * 2);
        event.preventDefault(); // Prevent default scroll
      }
    } else if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 20) {
      // Horizontal gesture - potential swipe
      isSwipeGesture = true;
    }
  }

  function handleTouchEnd(event: TouchEvent) {
    const deltaY = touchEndY - touchStartY;
    const deltaX = touchEndX - touchStartX;

    // Handle pull-to-refresh
    if (isPulling && pullDistance >= PULL_THRESHOLD) {
      handleRefresh();
    }

    // Handle swipe gestures
    if (isSwipeGesture) {
      if (Math.abs(deltaX) > SWIPE_THRESHOLD) {
        const direction = deltaX > 0 ? 'prev' : 'next';
        dispatch('navigateMessage', { direction });
      }
    }

    // Reset touch state
    pullDistance = 0;
    isPulling = false;
    isSwipeGesture = false;
  }

  async function handleRefresh() {
    if (isRefreshing) return;

    isRefreshing = true;
    dispatch('refresh');

    // Reset after animation
    setTimeout(() => {
      isRefreshing = false;
      pullDistance = 0;
    }, 1000);
  }

  // Keyboard visibility detection
  function handleResize() {
    const newViewportHeight = window.innerHeight;
    keyboardVisible = newViewportHeight < viewportHeight - 150; // Threshold for keyboard
    viewportHeight = newViewportHeight;

    // Adjust scroll when keyboard appears
    if (keyboardVisible && messagesContainer) {
      setTimeout(() => {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }, 300);
    }
  }

  // Long press handler for message actions
  function handleMessageLongPress(message: ChatMessage) {
    // Could dispatch an event for message actions menu
    // For now, just prevent default
  }

  onMount(() => {
    viewportHeight = window.innerHeight;
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
    };
  });
</script>

<div class="chat-interface" class:keyboard-visible={keyboardVisible} data-testid="chat-interface">
  <!-- Offline indicator -->
  <OfflineIndicator />

  <!-- Streaming indicator -->
  <StreamingIndicator />

  <!-- Pull-to-refresh indicator -->
  {#if pullDistance > 0}
    <div class="pull-refresh-indicator" class:active={pullDistance >= PULL_THRESHOLD}>
      <div class="refresh-icon" style="transform: rotate({(pullDistance / PULL_THRESHOLD) * 180}deg)">
        ↻
      </div>
      <span class="refresh-text">
        {pullDistance >= PULL_THRESHOLD ? 'Release to refresh' : 'Pull to refresh'}
      </span>
    </div>
  {/if}

  {#if activeSession}
  <header class="chat-header">
    <div class="session-info">
      <h3 class="session-title" data-testid="current-session-title">{activeSession.title || 'Untitled Session'}</h3>
      <span class="message-count">{activeSession.messages.length} messages</span>
    </div>
    <button
      class="close-btn"
      on:click={handleClose}
      aria-label="Close chat"
      style="min-width: 44px; min-height: 44px;"
    >
      <span aria-hidden="true">×</span>
    </button>
  </header>

  <div
    class="messages-container"
    bind:this={messagesContainer}
    on:scroll={handleScroll}
    on:touchstart={handleTouchStart}
    on:touchmove={handleTouchMove}
    on:touchend={handleTouchEnd}
    role="log"
    aria-label="Chat messages"
    aria-live="polite"
    aria-atomic="false"
    style="transform: translateY({pullDistance}px);"
  >
    <!-- Virtual scrolling spacer for messages above viewport -->
    {#if startIndex > 0}
      <div class="virtual-spacer" style="height: {startIndex * itemHeight}px;"></div>
    {/if}

    {#each visibleMessages as message (message.id)}
      <div
        class="message-wrapper"
        on:contextmenu|preventDefault={handleMessageLongPress(message)}
      >
        <MessageBubble {message} />
      </div>
    {/each}

    {#if isLoading}
      <div class="loading-indicator" data-testid="typing-indicator" aria-live="polite">
        <div class="typing-dots" aria-hidden="true">
          <span></span>
          <span></span>
          <span></span>
        </div>
        <span class="sr-only">AI is typing...</span>
      </div>
    {/if}

    <!-- Virtual scrolling spacer for messages below viewport -->
    {#if endIndex < currentMessages.length}
      <div class="virtual-spacer" style="height: {(currentMessages.length - endIndex) * itemHeight}px;"></div>
    {/if}
  </div>

  <MessageInput
    disabled={loading || isRefreshing}
    onSend={handleSendMessage}
  />
  {/if}
</div>

<style>
  /* Mobile-first responsive design */
  .chat-interface {
    display: flex;
    flex-direction: column;
    height: 100vh; /* Full viewport height on mobile */
    height: 100%; /* Fallback for desktop */
    background: hsl(0, 0%, 100%);
    border-radius: 0; /* Mobile-first: no border radius */
    box-shadow: none; /* Mobile-first: no shadow */
    overflow: hidden;
    position: relative;
  }

  /* Pull-to-refresh indicator */
  .pull-refresh-indicator {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 60px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    background: hsl(220, 20%, 95%);
    border-bottom: 1px solid hsl(220, 20%, 90%);
    z-index: 10;
    transform: translateY(-100%);
    transition: transform 0.3s ease;
  }

  .pull-refresh-indicator.active {
    transform: translateY(0);
  }

  .refresh-icon {
    font-size: 1.25rem;
    color: hsl(220, 10%, 60%);
    transition: transform 0.3s ease;
  }

  .refresh-text {
    font-size: 0.875rem;
    color: hsl(220, 10%, 60%);
  }

  /* Header - touch-friendly sizing */
  .chat-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 1rem; /* Mobile-first padding */
    border-bottom: 1px solid hsl(220, 20%, 90%);
    background: hsl(220, 20%, 98%);
    flex-shrink: 0;
    min-height: 56px; /* Ensure touch-friendly header height */
  }

  .session-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    min-width: 0; /* Allow text truncation */
    flex: 1;
  }

  .session-title {
    font-size: 1rem; /* Mobile-first font size */
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .message-count {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
  }

  /* Touch-friendly close button - 44px minimum */
  .close-btn {
    background: none;
    border: none;
    color: hsl(220, 10%, 60%);
    font-size: 1.25rem;
    cursor: pointer;
    padding: 0.5rem;
    border-radius: 6px;
    transition: all 0.2s ease;
    min-width: 44px;
    min-height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: -0.25rem; /* Compensate for padding to maintain layout */
  }

  .close-btn:hover {
    background: hsl(220, 20%, 90%);
    color: hsl(220, 20%, 20%);
  }

  .close-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .close-btn:active {
    background: hsl(220, 20%, 85%);
    transform: scale(0.95);
  }

  /* Messages container with touch optimizations */
  .messages-container {
    flex: 1;
    overflow-y: auto;
    padding: 0.75rem 1rem; /* Mobile-first padding */
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    scroll-behavior: smooth;
    -webkit-overflow-scrolling: touch; /* iOS smooth scrolling */
    overscroll-behavior: contain; /* Prevent scroll chaining */
    transition: transform 0.3s ease;
  }

  /* Virtual scrolling spacers */
  .virtual-spacer {
    flex-shrink: 0;
  }

  /* Message wrapper for touch interactions */
  .message-wrapper {
    position: relative;
  }

  .message-wrapper:active {
    background: hsla(220, 20%, 95%, 0.5);
    border-radius: 8px;
  }

  .loading-indicator {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: hsl(220, 20%, 95%);
    border-radius: 18px;
    align-self: flex-start;
    margin-bottom: 1rem;
    min-height: 44px; /* Touch-friendly */
  }

  .typing-dots {
    display: flex;
    gap: 0.25rem;
  }

  .typing-dots span {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: hsl(220, 10%, 60%);
    animation: typing 1.4s infinite ease-in-out;
  }

  .typing-dots span:nth-child(1) {
    animation-delay: -0.32s;
  }

  .typing-dots span:nth-child(2) {
    animation-delay: -0.16s;
  }

  @keyframes typing {
    0%, 80%, 100% {
      transform: scale(0.8);
      opacity: 0.5;
    }
    40% {
      transform: scale(1);
      opacity: 1;
    }
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

  /* Keyboard visible adjustments */
  .chat-interface.keyboard-visible .messages-container {
    padding-bottom: 1rem; /* Extra space when keyboard is visible */
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .chat-interface {
      border-radius: 12px;
      box-shadow: 0 4px 20px hsla(220, 20%, 20%, 0.1);
      height: 100%; /* Use container height instead of viewport */
    }

    .chat-header {
      padding: 1rem 1.5rem;
    }

    .session-title {
      font-size: 1.125rem;
    }

    .messages-container {
      padding: 1rem 1.5rem;
    }

    .close-btn {
      font-size: 1.5rem;
      min-width: 48px;
      min-height: 48px;
    }
  }

  /* Desktop breakpoint (1024px+) */
  @media (min-width: 1024px) {
    .chat-interface {
      max-width: 800px;
      margin: 0 auto;
    }

    .messages-container {
      padding: 1.5rem 2rem;
    }
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .chat-header {
      border-bottom: 2px solid hsl(0, 0%, 0%);
      background: hsl(0, 0%, 100%);
    }

    .close-btn:hover {
      background: hsl(0, 0%, 0%);
      color: hsl(0, 0%, 100%);
    }

    .close-btn:focus {
      outline: 3px solid hsl(0, 0%, 0%);
    }

    .loading-indicator {
      background: hsl(0, 0%, 100%);
      border: 2px solid hsl(0, 0%, 0%);
    }

    .typing-dots span {
      background: hsl(0, 0%, 0%);
    }

    .pull-refresh-indicator {
      background: hsl(0, 0%, 100%);
      border-bottom: 2px solid hsl(0, 0%, 0%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .messages-container {
      scroll-behavior: auto;
    }

    .close-btn {
      transition: none;
    }

    .typing-dots span {
      animation: none;
    }

    .pull-refresh-indicator {
      transition: none;
    }

    .refresh-icon {
      transition: none;
    }

    .messages-container {
      transition: none;
    }
  }

  /* Touch device optimizations */
  @media (hover: none) and (pointer: coarse) {
    .close-btn:hover {
      background: none; /* Remove hover effects on touch devices */
    }

    .message-wrapper:active {
      background: hsla(220, 20%, 95%, 0.3);
    }
  }

  /* Safe area insets for notched devices */
  @supports (padding: max(0px)) {
    .chat-interface {
      padding-top: env(safe-area-inset-top);
      padding-bottom: env(safe-area-inset-bottom);
      padding-left: env(safe-area-inset-left);
      padding-right: env(safe-area-inset-right);
    }
  }
</style>
