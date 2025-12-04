/*
 * MIT License
 *
 * Copyright (c) 2025 OpenCode Nexus Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { writable, derived, get } from 'svelte/store';
import type { ModelConfig } from '../types/chat';

export interface AvailableModel {
  fullId: string; // e.g., "anthropic/claude-3-5-sonnet-20241022"
  displayName: string; // e.g., "Claude 3.5 Sonnet"
  providerId: string; // e.g., "anthropic"
  modelId: string; // e.g., "claude-3-5-sonnet-20241022"
}

function createModelSelectorStore() {
  const { subscribe, set, update } = writable({
    availableModels: [] as AvailableModel[],
    selectedModel: null as AvailableModel | null,
    lastSelectedModel: null as AvailableModel | null, // Remember last selected model
    isLoading: false,
    error: null as string | null,
    useServerDefault: true // When true, send undefined to server (use its default)
  });

  return {
    subscribe,
    setAvailableModels: (models: AvailableModel[]) => {
      update(state => {
        // Check if currently selected model is still available in new models
        const selectedModelStillAvailable = state.selectedModel &&
          models.some(m => m.fullId === state.selectedModel!.fullId);

        const newState = { ...state, availableModels: models };

        if (selectedModelStillAvailable) {
          // Keep current selection
          newState.selectedModel = state.selectedModel;
        } else if (!state.selectedModel && !state.useServerDefault && models.length > 0) {
          // Auto-select first model if none selected and not using server default
          newState.selectedModel = models[0];
          newState.useServerDefault = false;
        } else if (state.selectedModel && !selectedModelStillAvailable) {
          // Clear selection if selected model is no longer available
          newState.selectedModel = null;
        }

        return newState;
      });
    },
    selectModel: (model: AvailableModel | null) => {
      update(state => ({
        ...state,
        selectedModel: model,
        lastSelectedModel: model || state.lastSelectedModel,
        useServerDefault: model === null
      }));
    },
    setUseServerDefault: (useDefault: boolean) => {
      update(state => {
        if (useDefault) {
          return {
            ...state,
            useServerDefault: true,
            selectedModel: null
          };
        } else {
          // When disabling server default, select the last selected model or first available model
          const modelToSelect = state.lastSelectedModel || (state.availableModels.length > 0 ? state.availableModels[0] : null);
          return {
            ...state,
            useServerDefault: false,
            selectedModel: modelToSelect
          };
        }
      });
    },
    setLoading: (isLoading: boolean) => {
      update(state => ({ ...state, isLoading }));
    },
    setError: (error: string | null) => {
      update(state => ({ ...state, error }));
    },
    clear: () => {
      set({
        availableModels: [],
        selectedModel: null,
        lastSelectedModel: null,
        isLoading: false,
        error: null,
        useServerDefault: true
      });
    },
    // Get the ModelConfig to send to backend, or undefined if using server default
    getSelectedModelConfig: (): ModelConfig | undefined => {
      const state = get({ subscribe });
      if (state.useServerDefault || !state.selectedModel) {
        return undefined;
      }
      return {
        provider_id: state.selectedModel.providerId,
        model_id: state.selectedModel.modelId
      };
    }
  };
}

export const modelSelectorStore = createModelSelectorStore();

// Derived stores
export const availableModels = derived(
  modelSelectorStore,
  $store => $store.availableModels
);

export const selectedModel = derived(
  modelSelectorStore,
  $store => $store.selectedModel
);

export const modelSelectorLoading = derived(
  modelSelectorStore,
  $store => $store.isLoading
);

export const modelSelectorError = derived(
  modelSelectorStore,
  $store => $store.error
);

export const useServerDefault = derived(
  modelSelectorStore,
  $store => $store.useServerDefault
);

// Grouped models by provider for easier UI organization
export const modelsByProvider = derived(availableModels, $models => {
  const grouped: { [key: string]: AvailableModel[] } = {};
  
  for (const model of $models) {
    if (!grouped[model.providerId]) {
      grouped[model.providerId] = [];
    }
    grouped[model.providerId].push(model);
  }
  
  return grouped;
});
