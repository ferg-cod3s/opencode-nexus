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
  import type { ChatMessage } from '../types/chat';

  export let message: ChatMessage;
  

  $: isUser = message.role === "user";

  function formatTime(timestamp: string): string {
    try {
      const date = new Date(timestamp);
      return date.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return '';
    }
  }

</script>

<div class="message-bubble" class:user={isUser} class:assistant={!isUser} data-testid={isUser ? "user-message" : "ai-message"}>
  <div class="message-content">
    {message.content}
  </div>
  <div class="message-footer">
    <span class="message-time" aria-hidden="true">
      {formatTime(message.timestamp)}
    </span>
    <span class="sr-only">
      {isUser ? 'You' : 'Assistant'} said: {message.content}
    </span>
  </div>
</div>

<style>
  /* OpenCode-inspired Message Bubble Styling */
  .message-bubble {
    max-width: 85%;
    margin-bottom: var(--spacing-3);
    display: flex;
    flex-direction: column;
    position: relative;
  }

  .message-bubble.user {
    align-self: flex-end;
    align-items: flex-end;
  }

  .message-bubble.assistant {
    align-self: flex-start;
    align-items: flex-start;
  }

  .message-content {
    padding: var(--spacing-3) var(--spacing-4);
    border-radius: var(--radius-xl);
    word-wrap: break-word;
    white-space: pre-wrap;
    line-height: var(--line-height-base);
    font-size: var(--font-size-base);
    min-height: 44px;
    display: flex;
    align-items: center;
  }

  .message-bubble.user .message-content {
    background: var(--chat-user-bubble);
    color: var(--chat-user-text);
    border-bottom-right-radius: var(--radius-sm);
  }

  .message-bubble.assistant .message-content {
    background: var(--chat-assistant-bubble);
    color: var(--chat-assistant-text);
    border-bottom-left-radius: var(--radius-sm);
  }

  .message-footer {
    margin-top: var(--spacing-1);
    font-size: var(--font-size-small);
    color: var(--text-muted);
    padding: 0 var(--spacing-1);
  }

  .message-bubble.user .message-footer {
    text-align: right;
  }

  .message-bubble.assistant .message-footer {
    text-align: left;
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
    .message-bubble.user .message-content {
      background: currentColor;
      color: var(--background-base);
      border: 2px solid currentColor;
    }

    .message-bubble.assistant .message-content {
      background: var(--background-base);
      border: 2px solid currentColor;
      color: currentColor;
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .message-bubble {
      animation: none;
    }
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .message-bubble {
      max-width: 80%;
      margin-bottom: var(--spacing-4);
    }

    .message-content {
      padding: var(--spacing-3) var(--spacing-4);
      border-radius: var(--radius-2xl);
      font-size: var(--font-size-base);
      min-height: auto;
    }

    .message-bubble.user .message-content {
      border-bottom-right-radius: var(--radius-sm);
    }

    .message-bubble.assistant .message-content {
      border-bottom-left-radius: var(--radius-sm);
    }
  }

  /* Desktop breakpoint (1024px+) */
  @media (min-width: 1024px) {
    .message-bubble {
      max-width: 75%;
    }
  }
</style>
