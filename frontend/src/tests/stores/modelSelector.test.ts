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

import { describe, test, expect, beforeEach, mock } from 'bun:test';
import { get } from 'svelte/store';
import { modelSelectorStore, availableModels, selectedModel, useServerDefault, modelSelectorLoading, modelSelectorError, modelsByProvider } from '../../stores/modelSelector';
import type { AvailableModel } from '../../stores/modelSelector';

describe('ModelSelector Store', () => {
  beforeEach(() => {
    // Reset store to initial state
    modelSelectorStore.clear();
  });

  describe('Initial State', () => {
    test('should initialize with correct default values', () => {
      expect(get(availableModels)).toEqual([]);
      expect(get(selectedModel)).toBeNull();
      expect(get(useServerDefault)).toBe(true);
      expect(get(modelSelectorLoading)).toBe(false);
      expect(get(modelSelectorError)).toBeNull();
    });
  });

  describe('setAvailableModels', () => {
    test('should set available models without auto-selection when using server default', () => {
      const models: AvailableModel[] = [
        {
          fullId: 'anthropic/claude-3-5-sonnet-20241022',
          displayName: 'Claude 3.5 Sonnet',
          providerId: 'anthropic',
          modelId: 'claude-3-5-sonnet-20241022'
        },
        {
          fullId: 'openai/gpt-4',
          displayName: 'GPT-4',
          providerId: 'openai',
          modelId: 'gpt-4'
        }
      ];

      modelSelectorStore.setAvailableModels(models);

      expect(get(availableModels)).toEqual(models);
      expect(get(selectedModel)).toBeNull();
      expect(get(useServerDefault)).toBe(true);
    });

    test('should preserve selection when new models are loaded', () => {
      const initialModels: AvailableModel[] = [
        {
          fullId: 'anthropic/claude-3-5-sonnet-20241022',
          displayName: 'Claude 3.5 Sonnet',
          providerId: 'anthropic',
          modelId: 'claude-3-5-sonnet-20241022'
        }
      ];

      const newModels: AvailableModel[] = [
        ...initialModels,
        {
          fullId: 'openai/gpt-4',
          displayName: 'GPT-4',
          providerId: 'openai',
          modelId: 'gpt-4'
        }
      ];

      // First select a model
      modelSelectorStore.selectModel(initialModels[0]);
      modelSelectorStore.setAvailableModels(newModels);

      expect(get(selectedModel)).toEqual(initialModels[0]);
    });
  });

  describe('selectModel', () => {
    test('should select a specific model and disable server default', () => {
      const model: AvailableModel = {
        fullId: 'anthropic/claude-3-5-sonnet-20241022',
        displayName: 'Claude 3.5 Sonnet',
        providerId: 'anthropic',
        modelId: 'claude-3-5-sonnet-20241022'
      };

      modelSelectorStore.selectModel(model);

      expect(get(selectedModel)).toEqual(model);
      expect(get(useServerDefault)).toBe(false);
    });

    test('should allow selecting null to use server default', () => {
      const model: AvailableModel = {
        fullId: 'anthropic/claude-3-5-sonnet-20241022',
        displayName: 'Claude 3.5 Sonnet',
        providerId: 'anthropic',
        modelId: 'claude-3-5-sonnet-20241022'
      };

      modelSelectorStore.selectModel(model);
      expect(get(useServerDefault)).toBe(false);

      modelSelectorStore.selectModel(null);
      expect(get(selectedModel)).toBeNull();
      expect(get(useServerDefault)).toBe(true);
    });
  });

  describe('setUseServerDefault', () => {
    test('should enable server default and clear selected model', () => {
      const model: AvailableModel = {
        fullId: 'anthropic/claude-3-5-sonnet-20241022',
        displayName: 'Claude 3.5 Sonnet',
        providerId: 'anthropic',
        modelId: 'claude-3-5-sonnet-20241022'
      };

      modelSelectorStore.selectModel(model);
      expect(get(useServerDefault)).toBe(false);

      modelSelectorStore.setUseServerDefault(true);
      expect(get(useServerDefault)).toBe(true);
      expect(get(selectedModel)).toBeNull();
    });

    test('should disable server default and select first available model when no previous selection', () => {
      const model: AvailableModel = {
        fullId: 'anthropic/claude-3-5-sonnet-20241022',
        displayName: 'Claude 3.5 Sonnet',
        providerId: 'anthropic',
        modelId: 'claude-3-5-sonnet-20241022'
      };

      modelSelectorStore.setAvailableModels([model]);
      modelSelectorStore.setUseServerDefault(true);
      expect(get(useServerDefault)).toBe(true);
      expect(get(selectedModel)).toBeNull();

      modelSelectorStore.setUseServerDefault(false);
      expect(get(useServerDefault)).toBe(false);
      expect(get(selectedModel)).toEqual(model);
    });
  });

  describe('Loading and Error States', () => {
    test('should set and clear loading state', () => {
      modelSelectorStore.setLoading(true);
      expect(get(modelSelectorLoading)).toBe(true);

      modelSelectorStore.setLoading(false);
      expect(get(modelSelectorLoading)).toBe(false);
    });

    test('should set and clear error state', () => {
      const error = 'Failed to load models';
      modelSelectorStore.setError(error);
      expect(get(modelSelectorError)).toBe(error);

      modelSelectorStore.setError(null);
      expect(get(modelSelectorError)).toBeNull();
    });
  });

  describe('getSelectedModelConfig', () => {
    test('should return undefined when using server default', () => {
      modelSelectorStore.setUseServerDefault(true);
      expect(modelSelectorStore.getSelectedModelConfig()).toBeUndefined();
    });

    test('should return model config when specific model is selected', () => {
      const model: AvailableModel = {
        fullId: 'anthropic/claude-3-5-sonnet-20241022',
        displayName: 'Claude 3.5 Sonnet',
        providerId: 'anthropic',
        modelId: 'claude-3-5-sonnet-20241022'
      };

      modelSelectorStore.setAvailableModels([model]);
      modelSelectorStore.selectModel(model); // Explicitly select the model
      expect(modelSelectorStore.getSelectedModelConfig()).toEqual({
        provider_id: 'anthropic',
        model_id: 'claude-3-5-sonnet-20241022'
      });
    });

    test('should return undefined when no model is selected', () => {
      modelSelectorStore.clear();
      expect(modelSelectorStore.getSelectedModelConfig()).toBeUndefined();
    });
  });

  describe('clear', () => {
    test('should reset store to initial state', () => {
      const model: AvailableModel = {
        fullId: 'anthropic/claude-3-5-sonnet-20241022',
        displayName: 'Claude 3.5 Sonnet',
        providerId: 'anthropic',
        modelId: 'claude-3-5-sonnet-20241022'
      };

      modelSelectorStore.setAvailableModels([model]);
      modelSelectorStore.setLoading(true);
      modelSelectorStore.setError('Test error');

      modelSelectorStore.clear();

      expect(get(availableModels)).toEqual([]);
      expect(get(selectedModel)).toBeNull();
      expect(get(useServerDefault)).toBe(true);
      expect(get(modelSelectorLoading)).toBe(false);
      expect(get(modelSelectorError)).toBeNull();
    });
  });

  describe('Derived Stores', () => {
    test('should group models by provider correctly', () => {
      const models: AvailableModel[] = [
        {
          fullId: 'anthropic/claude-3-5-sonnet-20241022',
          displayName: 'Claude 3.5 Sonnet',
          providerId: 'anthropic',
          modelId: 'claude-3-5-sonnet-20241022'
        },
        {
          fullId: 'anthropic/claude-3-haiku',
          displayName: 'Claude 3 Haiku',
          providerId: 'anthropic',
          modelId: 'claude-3-haiku'
        },
        {
          fullId: 'openai/gpt-4',
          displayName: 'GPT-4',
          providerId: 'openai',
          modelId: 'gpt-4'
        }
      ];

      modelSelectorStore.setAvailableModels(models);

      expect(get(modelsByProvider)).toEqual({
        anthropic: [models[0], models[1]],
        openai: [models[2]]
      });
    });
  });
});
