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
  import { chatStateStore } from '../stores/chat';

  // Reactive binding to streaming state
  $: isStreaming = $chatStateStore.isStreaming;
</script>

<!-- Only show when streaming is active -->
{#if isStreaming}
  <div class="streaming-indicator" role="status" aria-live="polite" aria-label="AI is typing">
    <div class="indicator-content">
      <div class="typing-dots" aria-hidden="true">
        <span></span>
        <span></span>
        <span></span>
      </div>
      <span class="indicator-text">AI is responding...</span>
    </div>
  </div>
{/if}

<style>
  .streaming-indicator {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
    background: hsl(220, 90%, 95%);
    border-top: 1px solid hsl(220, 70%, 80%);
    gap: 0.75rem;
    font-size: 0.875rem;
    color: hsl(220, 70%, 40%);
    font-weight: 500;
    animation: slideUp 0.3s ease-out;
  }

  .indicator-content {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .typing-dots {
    display: flex;
    gap: 0.25rem;
    align-items: center;
  }

  .typing-dots span {
    width: 0.375rem;
    height: 0.375rem;
    background: hsl(220, 70%, 40%);
    border-radius: 50%;
    animation: bounce 1.4s infinite;
  }

  .typing-dots span:nth-child(1) {
    animation-delay: 0s;
  }

  .typing-dots span:nth-child(2) {
    animation-delay: 0.2s;
  }

  .typing-dots span:nth-child(3) {
    animation-delay: 0.4s;
  }

  @keyframes bounce {
    0%, 80%, 100% {
      transform: translateY(0);
      opacity: 1;
    }
    40% {
      transform: translateY(-0.5rem);
      opacity: 0.8;
    }
  }

  @keyframes slideUp {
    from {
      transform: translateY(100%);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  /* Mobile-first responsive design */
  @media (max-width: 600px) {
    .streaming-indicator {
      padding: 0.75rem;
      font-size: 0.8125rem;
    }

    .typing-dots span {
      width: 0.3125rem;
      height: 0.3125rem;
    }
  }

  /* Tablet breakpoint (768px+) */
  @media (min-width: 768px) {
    .streaming-indicator {
      padding: 1.25rem;
      font-size: 0.9375rem;
    }
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .streaming-indicator {
      background: hsl(0, 0%, 100%);
      border-top: 2px solid hsl(0, 0%, 0%);
      color: hsl(0, 0%, 0%);
    }

    .typing-dots span {
      background: hsl(0, 0%, 0%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .streaming-indicator {
      animation: none;
    }

    .typing-dots span {
      animation: none;
      opacity: 0.5;
    }
  }
</style>
