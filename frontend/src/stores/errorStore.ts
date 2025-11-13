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

// Copyright (c) 2025 OpenCode Nexus Contributors
// SPDX-License-Identifier: MIT

/**
 * Error Notification Store
 *
 * Centralized error management for the application.
 * Handles displaying, dismissing, and retrying failed operations.
 */

import { writable } from 'svelte/store';

export interface ErrorNotification {
  id: string;
  message: string;
  details?: string;
  isRetryable: boolean;
  onRetry?: () => void;
  timestamp: number;
}

interface ErrorStore {
  errors: ErrorNotification[];
}

function createErrorStore() {
  const { subscribe, update } = writable<ErrorStore>({
    errors: [],
  });

  return {
    subscribe,

    /**
     * Add a new error notification
     */
    addError(
      message: string,
      details?: string,
      isRetryable: boolean = false,
      onRetry?: () => void
    ): string {
      const id = `error_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      update((store) => ({
        errors: [
          ...store.errors,
          {
            id,
            message,
            details,
            isRetryable,
            onRetry,
            timestamp: Date.now(),
          },
        ],
      }));

      return id;
    },

    /**
     * Add error from Tauri backend error response
     */
    addBackendError(error: any, onRetry?: () => void): string {
      let message = 'An error occurred';
      let details: string | undefined;
      let isRetryable = false;

      // Handle different error formats
      if (typeof error === 'string') {
        message = error;
      } else if (error?.message) {
        message = error.message;
        details = error.details;
        isRetryable = error.is_retryable ?? false;
      }

      return this.addError(message, details, isRetryable, onRetry);
    },

    /**
     * Add network error with retry
     */
    addNetworkError(operation: string, onRetry?: () => void): string {
      return this.addError(
        `Network error: ${operation}`,
        'Please check your connection and try again',
        true,
        onRetry
      );
    },

    /**
     * Add connection error
     */
    addConnectionError(serverUrl: string, onRetry?: () => void): string {
      return this.addError(
        'Failed to connect to server',
        `Unable to reach ${serverUrl}. Please check the server address and try again.`,
        true,
        onRetry
      );
    },

    /**
     * Add timeout error
     */
    addTimeoutError(operation: string, onRetry?: () => void): string {
      return this.addError(
        `Operation timed out: ${operation}`,
        'The operation took too long to complete. Please try again.',
        true,
        onRetry
      );
    },

    /**
     * Add authentication error
     */
    addAuthError(message?: string): string {
      return this.addError(
        'Authentication failed',
        message || 'Please check your credentials and try again',
        false
      );
    },

    /**
     * Add session error
     */
    addSessionError(sessionId: string, onRetry?: () => void): string {
      return this.addError(
        'Session error',
        `Unable to access session ${sessionId}. The session may have expired or been deleted.`,
        true,
        onRetry
      );
    },

    /**
     * Remove a specific error
     */
    removeError(id: string) {
      update((store) => ({
        errors: store.errors.filter((e) => e.id !== id),
      }));
    },

    /**
     * Clear all errors
     */
    clearAll() {
      update(() => ({ errors: [] }));
    },

    /**
     * Auto-clear errors older than specified time (default: 10 seconds)
     */
    clearOldErrors(maxAge: number = 10000) {
      const now = Date.now();
      update((store) => ({
        errors: store.errors.filter((e) => now - e.timestamp < maxAge),
      }));
    },
  };
}

export const errorStore = createErrorStore();

/**
 * Helper function to handle async operations with automatic error handling
 */
export async function handleAsyncError<T>(
  operation: () => Promise<T>,
  errorMessage: string,
  onRetry?: () => void
): Promise<T | null> {
  try {
    return await operation();
  } catch (error) {
    errorStore.addError(
      errorMessage,
      error instanceof Error ? error.message : String(error),
      true,
      onRetry
    );
    return null;
  }
}

/**
 * Helper function to parse Tauri command errors
 */
export function parseTauriError(error: any): {
  message: string;
  details?: string;
  isRetryable: boolean;
} {
  // Tauri errors come as strings
  if (typeof error === 'string') {
    // Parse our custom error format (from AppError)
    const patterns = [
      { regex: /^Network error: (.+)$/, type: 'network' },
      { regex: /^Server error: (.+)$/, type: 'server' },
      { regex: /^Authentication failed: (.+)$/, type: 'auth' },
      { regex: /^(.+) timed out after (\d+) seconds$/, type: 'timeout' },
      { regex: /^Not connected: (.+)$/, type: 'not_connected' },
    ];

    for (const { regex, type } of patterns) {
      const match = error.match(regex);
      if (match) {
        return {
          message: error,
          isRetryable: ['network', 'server', 'timeout', 'not_connected'].includes(type),
        };
      }
    }

    // Generic error
    return {
      message: error,
      isRetryable: false,
    };
  }

  // Structured error object
  return {
    message: error?.message || 'An error occurred',
    details: error?.details,
    isRetryable: error?.is_retryable ?? false,
  };
}
