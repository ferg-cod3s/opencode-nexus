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
  .message-bubble {
    max-width: 85%; /* Mobile-first: wider on small screens */
    margin-bottom: 0.75rem; /* Reduced margin for mobile */
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
    padding: 0.75rem 1rem;
    border-radius: 18px;
    word-wrap: break-word;
    white-space: pre-wrap;
    line-height: 1.4;
  }

  .message-bubble.user .message-content {
    background: hsl(220, 90%, 60%);
    color: white;
    border-bottom-right-radius: 4px;
  }

  .message-bubble.assistant .message-content {
    background: hsl(220, 20%, 95%);
    color: hsl(220, 20%, 20%);
    border-bottom-left-radius: 4px;
  }

  .message-footer {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    opacity: 0.7;
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
      background: hsl(0, 0%, 0%);
      border: 2px solid hsl(0, 0%, 100%);
    }

    .message-bubble.assistant .message-content {
      background: hsl(0, 0%, 100%);
      border: 2px solid hsl(0, 0%, 0%);
      color: hsl(0, 0%, 0%);
    }

  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .message-bubble {
      animation: none;
    }
  }

  /* Mobile-first responsive design */
  .message-content {
    padding: 0.625rem 0.875rem; /* Mobile-first padding */
    border-radius: 16px; /* Mobile-friendly border radius */
    word-wrap: break-word;
    white-space: pre-wrap;
    line-height: 1.4;
    font-size: 0.875rem; /* Mobile-first font size */
    min-height: 44px; /* Ensure touch-friendly minimum height */
    display: flex;
    align-items: center;
  }

  .message-footer {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    opacity: 0.7;
    padding: 0 0.25rem;
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .message-bubble {
      max-width: 80%;
      margin-bottom: 1rem;
    }

    .message-content {
      padding: 0.75rem 1rem;
      border-radius: 18px;
      font-size: 1rem;
      min-height: auto; /* Remove min-height constraint on larger screens */
    }

    .message-footer {
      margin-top: 0.25rem;
      font-size: 0.75rem;
    }
  }

  /* Desktop breakpoint (1024px+) */
  @media (min-width: 1024px) {
    .message-bubble {
      max-width: 75%;
    }
  }
</style>
