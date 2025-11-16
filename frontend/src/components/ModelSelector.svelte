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
  .model-selector {
    position: relative;
    display: inline-block;
    width: 100%;
  }

  /* Trigger Button */
  .selector-trigger {
    width: 100%;
    padding: 0.625rem 0.875rem;
    border: 2px solid hsl(220, 20%, 90%);
    border-radius: 20px;
    background: hsl(0, 0%, 100%);
    font-family: inherit;
    font-size: 0.875rem;
    color: hsl(220, 20%, 20%);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
    transition: all 0.2s ease;
    min-height: 44px;
    -webkit-appearance: none;
    appearance: none;
  }

  .selector-trigger:hover:not(:disabled) {
    border-color: hsl(220, 90%, 60%);
    background: hsl(220, 20%, 98%);
  }

  .selector-trigger:focus {
    outline: none;
    border-color: hsl(220, 90%, 60%);
    box-shadow: 0 0 0 3px hsla(220, 90%, 60%, 0.1);
  }

  .selector-trigger:disabled {
    background: hsl(220, 20%, 96%);
    cursor: not-allowed;
    opacity: 0.6;
  }

  .model-label {
    flex: 1;
    text-align: left;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    min-width: 0;
  }

  .model-name {
    font-weight: 500;
    color: hsl(220, 20%, 20%);
  }

  .default-label {
    font-weight: 500;
    color: hsl(45, 100%, 40%);
  }

  .placeholder {
    color: hsl(220, 10%, 60%);
  }

  .loading-text {
    color: hsl(220, 90%, 60%);
    font-style: italic;
  }

  .dropdown-icon {
    flex-shrink: 0;
    font-size: 0.625rem;
    color: hsl(220, 10%, 60%);
    transition: transform 0.2s ease;
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
    background: hsl(0, 0%, 100%);
    border: 1px solid hsl(220, 20%, 90%);
    border-top: none;
    border-radius: 0 0 12px 12px;
    box-shadow: 0 4px 12px hsla(220, 20%, 20%, 0.1);
    margin-top: -2px;
    z-index: 100;
    max-height: 300px;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }

  /* Provider Group */
  .provider-group {
    padding: 0.5rem 0;
  }

  .provider-header {
    padding: 0.5rem 1rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    color: hsl(220, 10%, 60%);
    letter-spacing: 0.5px;
  }

  /* Dropdown Items */
  .dropdown-item {
    width: 100%;
    padding: 0.75rem 1rem;
    border: none;
    background: none;
    text-align: left;
    cursor: pointer;
    color: hsl(220, 20%, 20%);
    font-family: inherit;
    font-size: inherit;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    transition: background-color 0.15s ease;
  }

  .dropdown-item:hover {
    background: hsl(220, 20%, 95%);
  }

  .dropdown-item.selected {
    background: hsl(220, 90%, 95%);
    color: hsl(220, 90%, 40%);
    font-weight: 500;
  }

  .dropdown-item.server-default {
    font-weight: 500;
    color: hsl(45, 100%, 40%);
  }

  .dropdown-item.server-default.selected {
    background: hsl(45, 100%, 95%);
  }

  .option-label {
    font-weight: 500;
    display: block;
  }

  .option-description {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
    display: block;
  }

  .option-id {
    font-size: 0.75rem;
    color: hsl(220, 10%, 70%);
    font-family: 'Monaco', 'Courier New', monospace;
    display: block;
  }

  /* Divider */
  .dropdown-divider {
    height: 1px;
    background: hsl(220, 20%, 90%);
    margin: 0.5rem 0;
  }

  /* Error State */
  .dropdown-error {
    padding: 0.75rem 1rem;
    background: hsl(0, 100%, 95%);
    color: hsl(0, 100%, 40%);
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .error-icon {
    flex-shrink: 0;
    font-size: 1rem;
  }

  .error-text {
    flex: 1;
  }

  /* Empty State */
  .dropdown-empty {
    padding: 1rem;
    text-align: center;
    color: hsl(220, 10%, 60%);
    font-style: italic;
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .selector-trigger {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .selector-trigger:focus {
      border-color: hsl(0, 0%, 0%);
      box-shadow: 0 0 0 3px hsla(0, 0%, 0%, 0.3);
    }

    .dropdown-menu {
      border: 2px solid hsl(0, 0%, 0%);
      border-top: none;
    }

    .dropdown-item.selected {
      background: hsl(0, 0%, 0%);
      color: hsl(0, 0%, 100%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .selector-trigger,
    .dropdown-item {
      transition: none;
    }

    .dropdown-icon {
      transition: none;
    }
  }

  /* Touch device optimizations */
  @media (hover: none) and (pointer: coarse) {
    .dropdown-item:hover {
      background: hsl(220, 20%, 98%);
    }

    .dropdown-item:active {
      background: hsl(220, 20%, 90%);
    }
  }

  /* Responsive adjustments */
  @media (min-width: 768px) {
    .selector-trigger {
      font-size: 0.9375rem;
      border-radius: 24px;
    }

    .dropdown-menu {
      border-radius: 0 0 12px 12px;
      max-height: 400px;
    }
  }
</style>
