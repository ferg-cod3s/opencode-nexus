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
  import { isOnline, queuedMessageCount } from '../stores/chat';

  export let disabled = false;
  export let placeholder = "Type your message...";
  export let onSend: ((content: string, model?: { provider_id: string; model_id: string }) => void) | undefined = undefined;

  let inputElement: HTMLTextAreaElement;
  let content = '';

  $: effectivePlaceholder = !$isOnline
    ? "Message will be queued for sending..."
    : placeholder;

  function handleSubmit() {
    const trimmedContent = content.trim();
    if (trimmedContent && !disabled && onSend) {
      onSend(trimmedContent);
      content = '';
      // Reset textarea height
      if (inputElement) {
        inputElement.style.height = 'auto';
      }
    }
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      handleSubmit();
    }
  }

  function handleInput() {
    // Auto-resize textarea
    if (inputElement) {
      inputElement.style.height = 'auto';
      inputElement.style.height = `${inputElement.scrollHeight}px`;
    }
  }

  function handlePaste(event: ClipboardEvent) {
    // Handle code paste with proper formatting
    const pastedText = event.clipboardData?.getData('text');
    if (pastedText && pastedText.includes('\n') && pastedText.length > 50) {
      // Multi-line paste - could be code
      event.preventDefault();
      const formattedCode = `\`\`\`\n${pastedText}\n\`\`\``;
      content += formattedCode;
      handleInput();
    }
  }
</script>

<div class="message-input-container">
  <div class="input-wrapper">
    <textarea
      bind:this={inputElement}
      bind:value={content}
      placeholder={effectivePlaceholder}
      {disabled}
      data-testid="message-input"
      aria-label="Type your message"
      aria-describedby="input-help"
      class:offline={!$isOnline}
      on:keydown={handleKeydown}
      on:input={handleInput}
      on:paste={handlePaste}
      rows="1"
      maxlength="10000"
    ></textarea>

    <button
      class="send-btn"
      disabled={!content.trim() || disabled || !onSend}
      data-testid="send-button"
      aria-label="Send message"
      on:click={handleSubmit}
      type="button"
    >
      <span aria-hidden="true">→</span>
    </button>
  </div>

  <div id="input-help" class="sr-only">
    Press Enter to send, Shift+Enter for new line. Supports code blocks with triple backticks.
  </div>

  <div class="input-footer">
    <span class="character-count" aria-live="polite">
      {content.length}/10000
    </span>
    {#if !$isOnline}
      <span class="offline-indicator" aria-live="polite">
        📴 Offline - Message will be queued
      </span>
    {:else if $queuedMessageCount > 0}
      <span class="queued-indicator" aria-live="polite">
        {$queuedMessageCount} queued message{$queuedMessageCount === 1 ? '' : 's'}
      </span>
    {:else}
      <span class="input-help-text">
        Press Enter to send, Shift+Enter for new line
      </span>
    {/if}
  </div>
</div>

<style>
  /* OpenCode-inspired Message Input Styling */
  .message-input-container {
    border-top: 1px solid var(--border-weak);
    padding: var(--spacing-3);
    background: var(--background-surface);
  }

  .input-wrapper {
    display: flex;
    align-items: flex-end;
    gap: var(--spacing-2);
    position: relative;
  }

  textarea {
    flex: 1;
    padding: var(--spacing-3) var(--spacing-4);
    border: 1px solid var(--input-border);
    border-radius: var(--radius-xl);
    background: var(--input-background);
    color: var(--text-strong);
    font-family: inherit;
    font-size: 16px; /* Prevent zoom on iOS */
    line-height: var(--line-height-base);
    resize: none;
    min-height: 44px;
    max-height: 120px;
    outline: none;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
    -webkit-appearance: none;
    appearance: none;
  }

  textarea::placeholder {
    color: var(--input-placeholder);
  }

  textarea:focus {
    border-color: var(--input-border-focus);
    box-shadow: var(--focus-ring);
  }

  textarea:disabled {
    background: var(--background-weak);
    cursor: not-allowed;
    opacity: 0.6;
  }

  textarea.offline {
    border-color: var(--accent-warning);
    background: rgba(252, 213, 58, 0.1);
  }

  /* Send button - OpenCode style */
  .send-btn {
    width: 44px;
    height: 44px;
    border: none;
    border-radius: var(--radius-full);
    background: var(--button-primary-bg);
    color: var(--button-primary-text);
    font-size: 1.125rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.15s ease;
    flex-shrink: 0;
    -webkit-tap-highlight-color: transparent;
  }

  .send-btn:hover:not(:disabled) {
    filter: brightness(1.1);
    transform: scale(1.05);
  }

  .send-btn:active:not(:disabled) {
    transform: scale(0.95);
  }

  .send-btn:disabled {
    background: var(--border-base);
    cursor: not-allowed;
    transform: none;
  }

  .send-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .input-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: var(--spacing-2);
    font-size: var(--font-size-small);
    color: var(--text-muted);
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-1);
  }

  .character-count {
    font-variant-numeric: tabular-nums;
    font-family: var(--font-family-mono);
  }

  .input-help-text {
    font-style: italic;
  }

  .offline-indicator {
    color: var(--accent-warning);
    font-weight: var(--font-weight-medium);
  }

  .queued-indicator {
    color: var(--text-muted);
    font-weight: var(--font-weight-medium);
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
    textarea {
      border: 2px solid currentColor;
    }

    textarea:focus {
      border-color: currentColor;
      box-shadow: 0 0 0 3px currentColor;
    }

    .send-btn {
      background: currentColor;
      border: 2px solid currentColor;
    }

    .send-btn:hover:not(:disabled) {
      filter: none;
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .send-btn,
    textarea {
      transition: none;
    }

    .send-btn:hover:not(:disabled),
    .send-btn:active:not(:disabled) {
      transform: none;
    }
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .message-input-container {
      padding: var(--spacing-4);
    }

    textarea {
      padding: var(--spacing-3) var(--spacing-4);
      border-radius: var(--radius-2xl);
      font-size: var(--font-size-base);
      min-height: 48px;
      max-height: 200px;
    }

    .send-btn {
      width: 48px;
      height: 48px;
      font-size: 1.25rem;
    }

    .input-footer {
      flex-direction: row;
      align-items: center;
      gap: 0;
    }
  }

  /* Desktop breakpoint (1024px+) */
  @media (min-width: 1024px) {
    .message-input-container {
      padding: var(--spacing-4) var(--spacing-6);
    }
  }
</style>
