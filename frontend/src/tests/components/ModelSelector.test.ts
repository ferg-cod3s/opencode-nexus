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
import ModelSelector from '../../components/ModelSelector.svelte';
import { modelSelectorStore } from '../../stores/modelSelector';

// Mock the chat API
mock.module('../utils/chat-api', () => ({
  getAvailableModels: mock(async () => [
    ['anthropic/claude-3-5-sonnet-20241022', 'Claude 3.5 Sonnet'],
    ['openai/gpt-4', 'GPT-4']
  ])
}));

describe('ModelSelector Component', () => {
  beforeEach(() => {
    // Reset store before each test
    modelSelectorStore.clear();
  });

  test('can be imported without errors', () => {
    expect(ModelSelector).toBeDefined();
  });

  test('store integration works correctly', () => {
    // Test that the store can be manipulated
    modelSelectorStore.setLoading(true);
    expect(modelSelectorStore.getSelectedModelConfig()).toBeUndefined();

    modelSelectorStore.setLoading(false);
    expect(modelSelectorStore.getSelectedModelConfig()).toBeUndefined();
  });

  test('model configuration is properly formatted', () => {
    const testModel = {
      fullId: 'anthropic/claude-3-5-sonnet-20241022',
      displayName: 'Claude 3.5 Sonnet',
      providerId: 'anthropic',
      modelId: 'claude-3-5-sonnet-20241022'
    };

    modelSelectorStore.setAvailableModels([testModel]);
    modelSelectorStore.selectModel(testModel);

    const config = modelSelectorStore.getSelectedModelConfig();
    expect(config).toEqual({
      provider_id: 'anthropic',
      model_id: 'claude-3-5-sonnet-20241022'
    });
  });

  test('server default mode returns undefined config', () => {
    modelSelectorStore.setUseServerDefault(true);
    expect(modelSelectorStore.getSelectedModelConfig()).toBeUndefined();
  });
});
