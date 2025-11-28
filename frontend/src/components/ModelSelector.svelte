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
  import { onMount } from 'svelte';
  import {
    modelSelectorStore,
    availableModels,
    selectedModel,
    useServerDefault,
    modelSelectorLoading,
    modelSelectorError,
    modelsByProvider,
    type AvailableModel
  } from '../stores/modelSelector';
  import { getAvailableModels } from '../utils/chat-api';

  let isOpen = false;
  let loadError = '';

  onMount(async () => {
    // Load available models on mount
    try {
      modelSelectorStore.setLoading(true);
      modelSelectorStore.setError(null);
      
      const models = await getAvailableModels();
      
      // Convert to AvailableModel format
      const formattedModels: AvailableModel[] = models.map(([fullId, displayName]) => {
        const [providerId, modelId] = fullId.split('/');
        return {
          fullId,
          displayName,
          providerId,
          modelId
        };
      });
      
      modelSelectorStore.setAvailableModels(formattedModels);
      modelSelectorStore.setLoading(false);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      modelSelectorStore.setError(errorMsg);
      modelSelectorStore.setLoading(false);
      loadError = errorMsg;
    }
  });

  function handleModelSelect(model: AvailableModel) {
    modelSelectorStore.selectModel(model);
    isOpen = false;
  }

  function handleUseServerDefault() {
    modelSelectorStore.setUseServerDefault(true);
    isOpen = false;
  }

  function toggleDropdown() {
    isOpen = !isOpen;
  }
</script>

<div class="model-selector" data-testid="model-selector">
  <button
    class="selector-trigger"
    on:click={toggleDropdown}
    aria-haspopup="listbox"
    aria-expanded={isOpen}
    data-testid="model-selector-trigger"
    disabled={$modelSelectorLoading}
    title={$useServerDefault ? 'Using server default model' : `Selected: ${$selectedModel?.displayName}`}
  >
    <span class="model-label">
      {#if $modelSelectorLoading}
        <span class="loading-text">Loading models...</span>
      {:else if $useServerDefault}
        <span class="default-label">Server Default</span>
      {:else if $selectedModel}
        <span class="model-name">{$selectedModel.displayName}</span>
      {:else}
        <span class="placeholder">Select Model</span>
      {/if}
    </span>
    <span class="dropdown-icon" aria-hidden="true">▼</span>
  </button>

  {#if isOpen}
    <div class="dropdown-menu" role="listbox" data-testid="model-dropdown">
      <!-- Server Default Option -->
      <button
        class="dropdown-item server-default"
        class:selected={$useServerDefault}
        on:click={handleUseServerDefault}
        role="option"
        aria-selected={$useServerDefault}
        data-testid="server-default-option"
      >
        <span class="option-label">Server Default</span>
        <span class="option-description">Use server's configured default model</span>
      </button>

      <!-- Divider -->
      {#if Object.keys($modelsByProvider).length > 0}
        <div class="dropdown-divider"></div>
      {/if}

      <!-- Models grouped by provider -->
      {#each Object.entries($modelsByProvider) as [providerId, providerModels]}
        <div class="provider-group">
          <div class="provider-header">{providerId}</div>
          {#each providerModels as model}
            <button
              class="dropdown-item model-item"
              class:selected={$selectedModel?.fullId === model.fullId && !$useServerDefault}
              on:click={() => handleModelSelect(model)}
              role="option"
              aria-selected={$selectedModel?.fullId === model.fullId && !$useServerDefault}
              data-testid="model-option-{model.fullId}"
            >
              <span class="option-label">{model.displayName}</span>
              <span class="option-id">{model.modelId}</span>
            </button>
          {/each}
        </div>
      {/each}

      <!-- Error or empty state -->
      {#if $modelSelectorError}
        <div class="dropdown-error" role="alert" data-testid="model-selector-error">
          <span class="error-icon">⚠</span>
          <span class="error-text">{$modelSelectorError}</span>
        </div>
      {:else if $availableModels.length === 0 && !$modelSelectorLoading}
        <div class="dropdown-empty" data-testid="model-selector-empty">
          No models available
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  /* OpenCode-inspired Model Selector Styling */
  .model-selector {
    position: relative;
    display: inline-block;
    width: 100%;
  }

  /* Trigger Button */
  .selector-trigger {
    width: 100%;
    padding: var(--spacing-3) var(--spacing-4);
    border: 1px solid var(--input-border);
    border-radius: var(--radius-xl);
    background: var(--input-background);
    font-family: inherit;
    font-size: var(--font-size-small);
    color: var(--text-strong);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--spacing-2);
    transition: all 0.15s ease;
    min-height: 44px;
    -webkit-appearance: none;
    appearance: none;
  }

  .selector-trigger:hover:not(:disabled) {
    border-color: var(--input-border-focus);
    background: var(--background-weak);
  }

  .selector-trigger:focus-visible {
    outline: none;
    border-color: var(--input-border-focus);
    box-shadow: var(--focus-ring);
  }

  .selector-trigger:disabled {
    background: var(--background-weak);
    cursor: not-allowed;
    opacity: 0.6;
  }

  .model-label {
    flex: 1;
    text-align: left;
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    min-width: 0;
  }

  .model-name {
    font-weight: var(--font-weight-medium);
    color: var(--text-strong);
  }

  .default-label {
    font-weight: var(--font-weight-medium);
    color: var(--accent-warning);
  }

  .placeholder {
    color: var(--text-muted);
  }

  .loading-text {
    color: var(--accent-primary);
    font-style: italic;
  }

  .dropdown-icon {
    flex-shrink: 0;
    font-size: 0.625rem;
    color: var(--text-muted);
    transition: transform 0.15s ease;
  }

  .selector-trigger[aria-expanded='true'] .dropdown-icon {
    transform: rotate(180deg);
  }

  /* Dropdown Menu */
  .dropdown-menu {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: var(--background-surface);
    border: 1px solid var(--border-base);
    border-top: none;
    border-radius: 0 0 var(--radius-lg) var(--radius-lg);
    box-shadow: var(--shadow-lg);
    margin-top: -1px;
    z-index: 100;
    max-height: 300px;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }

  /* Provider Group */
  .provider-group {
    padding: var(--spacing-2) 0;
  }

  .provider-header {
    padding: var(--spacing-2) var(--spacing-4);
    font-size: var(--font-size-small);
    font-weight: var(--font-weight-semibold);
    text-transform: uppercase;
    color: var(--text-muted);
    letter-spacing: 0.5px;
  }

  /* Dropdown Items */
  .dropdown-item {
    width: 100%;
    padding: var(--spacing-3) var(--spacing-4);
    border: none;
    background: none;
    text-align: left;
    cursor: pointer;
    color: var(--text-strong);
    font-family: inherit;
    font-size: inherit;
    display: flex;
    flex-direction: column;
    gap: var(--spacing-1);
    transition: background-color 0.1s ease;
  }

  .dropdown-item:hover {
    background: var(--button-ghost-hover);
  }

  .dropdown-item.selected {
    background: var(--active-highlight);
    color: var(--accent-primary);
  }

  .dropdown-item.server-default {
    font-weight: var(--font-weight-medium);
    color: var(--accent-warning);
  }

  .dropdown-item.server-default.selected {
    background: rgba(252, 213, 58, 0.1);
  }

  .option-label {
    font-weight: var(--font-weight-medium);
    display: block;
  }

  .option-description {
    font-size: var(--font-size-small);
    color: var(--text-muted);
    display: block;
  }

  .option-id {
    font-size: var(--font-size-small);
    color: var(--text-muted);
    font-family: var(--font-family-mono);
    display: block;
  }

  /* Divider */
  .dropdown-divider {
    height: 1px;
    background: var(--border-weak);
    margin: var(--spacing-2) 0;
  }

  /* Error State */
  .dropdown-error {
    padding: var(--spacing-3) var(--spacing-4);
    background: rgba(252, 83, 58, 0.1);
    color: var(--accent-error);
    display: flex;
    align-items: center;
    gap: var(--spacing-2);
    font-size: var(--font-size-small);
  }

  .error-icon {
    flex-shrink: 0;
    font-size: var(--font-size-base);
  }

  .error-text {
    flex: 1;
  }

  /* Empty State */
  .dropdown-empty {
    padding: var(--spacing-4);
    text-align: center;
    color: var(--text-muted);
    font-style: italic;
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .selector-trigger {
      border: 2px solid currentColor;
    }

    .selector-trigger:focus-visible {
      border-color: currentColor;
      box-shadow: 0 0 0 3px currentColor;
    }

    .dropdown-menu {
      border: 2px solid currentColor;
      border-top: none;
    }

    .dropdown-item.selected {
      background: currentColor;
      color: var(--background-base);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .selector-trigger,
    .dropdown-item,
    .dropdown-icon {
      transition: none;
    }
  }

  /* Touch device optimizations */
  @media (hover: none) and (pointer: coarse) {
    .dropdown-item:hover {
      background: transparent;
    }

    .dropdown-item:active {
      background: var(--button-ghost-hover);
    }
  }

  /* Responsive adjustments */
  @media (min-width: 768px) {
    .selector-trigger {
      font-size: var(--font-size-base);
      border-radius: var(--radius-2xl);
    }

    .dropdown-menu {
      border-radius: 0 0 var(--radius-lg) var(--radius-lg);
      max-height: 400px;
    }
  }
</style>
