<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import MessageBubble from './MessageBubble.svelte';
  import MessageInput from './MessageInput.svelte';
  import type { ChatSession, ChatMessage } from '../types/chat';

  export let session: ChatSession;
  export let loading = false;

  const dispatch = createEventDispatcher<{
    sendMessage: { content: string };
    close: void;
  }>();

  let messagesContainer: HTMLElement;
  let autoScroll = true;

  $: if (messagesContainer && autoScroll) {
    // Auto-scroll to bottom when new messages arrive
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }

  function handleSendMessage(event: CustomEvent<{ content: string }>) {
    dispatch('sendMessage', event.detail);
  }

  function handleClose() {
    dispatch('close');
  }

  function handleScroll() {
    if (messagesContainer) {
      const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
      // Enable auto-scroll if user is near bottom
      autoScroll = scrollTop + clientHeight >= scrollHeight - 100;
    }
  }
</script>

<div class="chat-interface">
  <div class="chat-header">
    <div class="session-info">
      <h3 class="session-title" data-testid="current-session-title">{session.title || 'Untitled Session'}</h3>
      <span class="message-count">{session.messages.length} messages</span>
    </div>
    <button
      class="close-btn"
      on:click={handleClose}
      aria-label="Close chat"
    >
      <span aria-hidden="true">×</span>
    </button>
  </div>

  <div
    class="messages-container"
    bind:this={messagesContainer}
    on:scroll={handleScroll}
    role="log"
    aria-label="Chat messages"
    aria-live="polite"
    aria-atomic="false"
  >
    {#each session.messages as message (message.id)}
      <MessageBubble {message} />
    {/each}

    {#if loading}
      <div class="loading-indicator" data-testid="typing-indicator" aria-live="polite">
        <div class="typing-dots" aria-hidden="true">
          <span></span>
          <span></span>
          <span></span>
        </div>
        <span class="sr-only">AI is typing...</span>
      </div>
    {/if}
  </div>

  <MessageInput
    disabled={loading}
    on:send={handleSendMessage}
  />
</div>

<style>
  .chat-interface {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: hsl(0, 0%, 100%);
    border-radius: 12px;
    box-shadow: 0 4px 20px hsla(220, 20%, 20%, 0.1);
    overflow: hidden;
  }

  .chat-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid hsl(220, 20%, 90%);
    background: hsl(220, 20%, 98%);
  }

  .session-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .session-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    margin: 0;
  }

  .message-count {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
  }

  .close-btn {
    background: none;
    border: none;
    color: hsl(220, 10%, 60%);
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 4px;
    transition: all 0.2s ease;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-btn:hover {
    background: hsl(220, 20%, 90%);
    color: hsl(220, 20%, 20%);
  }

  .close-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .messages-container {
    flex: 1;
    overflow-y: auto;
    padding: 1rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    scroll-behavior: smooth;
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
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .chat-interface {
      border-radius: 0;
      box-shadow: none;
    }

    .chat-header {
      padding: 0.75rem 1rem;
    }

    .session-title {
      font-size: 1rem;
    }

    .messages-container {
      padding: 0.75rem 1rem;
    }

    .close-btn {
      font-size: 1.25rem;
      width: 28px;
      height: 28px;
    }
  }
</style>