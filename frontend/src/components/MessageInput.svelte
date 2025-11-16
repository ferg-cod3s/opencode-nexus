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
  .message-input-container {
    border-top: 1px solid hsl(220, 20%, 90%);
    padding: 1rem;
    background: hsl(0, 0%, 100%);
  }

  .input-wrapper {
    display: flex;
    align-items: flex-end;
    gap: 0.5rem;
    position: relative;
  }

  textarea {
    flex: 1;
    padding: 0.625rem 0.875rem; /* Mobile-first padding */
    border: 2px solid hsl(220, 20%, 90%);
    border-radius: 20px; /* Mobile-friendly border radius */
    font-family: inherit;
    font-size: 16px; /* Prevent zoom on iOS - critical for mobile */
    line-height: 1.4;
    resize: none;
    min-height: 44px; /* Touch-friendly minimum height */
    max-height: 120px; /* Lower max height for mobile */
    outline: none;
    transition: border-color 0.2s ease;
    -webkit-appearance: none; /* Remove iOS styling */
    appearance: none;
  }

  textarea:focus {
    border-color: hsl(220, 90%, 60%);
    box-shadow: 0 0 0 3px hsla(220, 90%, 60%, 0.1);
  }

  textarea:disabled {
    background: hsl(220, 20%, 96%);
    cursor: not-allowed;
  }

  textarea.offline {
    border-color: hsl(45, 100%, 60%);
    background: hsl(45, 100%, 97%);
  }

  .send-btn {
    width: 44px; /* Mobile-first: 44px minimum touch target */
    height: 44px;
    border: none;
    border-radius: 50%;
    background: hsl(220, 90%, 60%);
    color: white;
    font-size: 1.125rem; /* Slightly smaller for mobile */
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
    flex-shrink: 0;
    margin-left: 0.5rem;
    -webkit-tap-highlight-color: transparent; /* Remove tap highlight on iOS */
  }

  .send-btn:hover:not(:disabled) {
    background: hsl(220, 80%, 50%);
    transform: scale(1.05);
  }

  .send-btn:active:not(:disabled) {
    transform: scale(0.95);
  }

  .send-btn:disabled {
    background: hsl(220, 20%, 80%);
    cursor: not-allowed;
    transform: none;
  }

  .send-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .input-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 0.5rem;
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
  }

  .character-count {
    font-variant-numeric: tabular-nums;
  }

  .input-help-text {
    font-style: italic;
  }

  .offline-indicator {
    color: hsl(45, 100%, 40%);
    font-weight: 500;
  }

  .queued-indicator {
    color: hsl(220, 10%, 60%);
    font-weight: 500;
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
      border: 2px solid hsl(0, 0%, 0%);
    }

    textarea:focus {
      border-color: hsl(0, 0%, 0%);
      box-shadow: 0 0 0 3px hsla(0, 0%, 0%, 0.3);
    }

    .send-btn {
      background: hsl(0, 0%, 0%);
      border: 2px solid hsl(0, 0%, 100%);
    }

    .send-btn:hover:not(:disabled) {
      background: hsl(0, 0%, 20%);
    }

    .send-btn:focus {
      outline: 3px solid hsl(0, 0%, 0%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .send-btn {
      transition: none;
    }

    .send-btn:hover:not(:disabled) {
      transform: none;
    }

    .send-btn:active:not(:disabled) {
      transform: none;
    }

    textarea {
      transition: none;
    }
  }

  /* Mobile-first responsive design */
  .message-input-container {
    border-top: 1px solid hsl(220, 20%, 90%);
    padding: 0.75rem; /* Mobile-first padding */
    background: hsl(0, 0%, 100%);
  }

  .input-wrapper {
    display: flex;
    align-items: flex-end;
    gap: 0.5rem;
    position: relative;
  }

  .input-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 0.5rem;
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
    flex-direction: column; /* Mobile-first: stacked layout */
    align-items: flex-start;
    gap: 0.25rem;
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .message-input-container {
      padding: 1rem;
    }

    textarea {
      padding: 0.75rem 1rem;
      border-radius: 24px;
      font-size: 1rem;
      min-height: 48px;
      max-height: 200px;
    }

    .send-btn {
      width: 48px;
      height: 48px;
      font-size: 1.25rem;
      margin-left: 0.5rem;
    }

    .input-footer {
      flex-direction: row; /* Horizontal layout on larger screens */
      align-items: center;
      gap: 0;
    }
  }

  /* Desktop breakpoint (1024px+) */
  @media (min-width: 1024px) {
    .message-input-container {
      padding: 1rem 1.5rem;
    }
  }
</style>
