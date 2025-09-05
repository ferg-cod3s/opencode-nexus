<script lang="ts">
  import type { ChatMessage, MessageRole } from '../types/chat';

  export let message: ChatMessage;
  export let isUser: boolean;

  $: isUser = message.role === MessageRole.User;

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

  function renderContent(content: string): string {
    // Basic markdown-like formatting for code blocks
    return content
      .replace(/```([\s\S]*?)```/g, '<pre class="code-block"><code>$1</code></pre>')
      .replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>')
      .replace(/\n/g, '<br>');
  }
</script>

<div class="message-bubble" class:user={isUser} class:assistant={!isUser} data-testid={isUser ? "user-message" : "ai-message"}>
  <div class="message-content">
    {@html renderContent(message.content)}
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
    max-width: 80%;
    margin-bottom: 1rem;
    display: flex;
    flex-direction: column;
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

  /* CSS classes used dynamically in renderContent() function */
  .code-block {
    background: hsl(220, 10%, 10%);
    color: hsl(120, 100%, 80%);
    padding: 1rem;
    border-radius: 8px;
    margin: 0.5rem 0;
    overflow-x: auto;
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: 0.875rem;
    line-height: 1.5;
  }

  .inline-code {
    background: hsl(220, 20%, 90%);
    color: hsl(220, 20%, 20%);
    padding: 0.125rem 0.25rem;
    border-radius: 3px;
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: 0.875rem;
  }

  .message-bubble.user .inline-code {
    background: hsla(0, 0%, 100%, 0.2);
    color: white;
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

    /* High contrast mode overrides for dynamically generated classes */
    .code-block {
      background: hsl(0, 0%, 0%);
      color: hsl(120, 100%, 50%);
      border: 2px solid hsl(0, 0%, 100%);
    }

    .inline-code {
      background: hsl(0, 0%, 0%);
      color: hsl(0, 0%, 100%);
      border: 1px solid hsl(0, 0%, 100%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .message-bubble {
      animation: none;
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .message-bubble {
      max-width: 90%;
    }

    .message-content {
      padding: 0.625rem 0.875rem;
      font-size: 0.875rem;
    }

    /* Mobile responsiveness for dynamically generated classes */
    .code-block {
      font-size: 0.75rem;
      padding: 0.75rem;
    }
  }
</style>