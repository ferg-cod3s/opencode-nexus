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

import { describe, it, expect, beforeEach } from 'bun:test';
import {
  classifyError,
  ErrorType,
  getRecoverySuggestions,
  handleError,
  errorEmitter
} from '../../lib/error-handler';

describe('Error Handler', () => {
  beforeEach(() => {
    // Clear listeners before each test
    errorEmitter.clear();
  });

  describe('classifyError', () => {
    it('should classify network unreachable errors', () => {
      const error = new Error('NETWORK: unreachable');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.NETWORK_UNREACHABLE);
      expect(classified.retryable).toBe(true);
    });

    it('should classify connection timeout errors', () => {
      const error = new Error('ETIMEDOUT: connection timeout');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.CONNECTION_TIMEOUT);
      expect(classified.retryable).toBe(true);
    });

    it('should classify authentication errors', () => {
      const error = new Error('401 Unauthorized');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.AUTHENTICATION_FAILED);
      expect(classified.retryable).toBe(false);
    });

    it('should classify SSL certificate errors', () => {
      const error = new Error('SSL certificate error');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.SSL_CERTIFICATE_ERROR);
      expect(classified.retryable).toBe(false);
    });

    it('should classify server errors', () => {
      const error = new Error('500 Internal Server Error');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.SERVER_ERROR);
      expect(classified.retryable).toBe(true);
    });

    it('should classify service unavailable errors', () => {
      const error = new Error('503 Service Unavailable');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.SERVER_UNAVAILABLE);
      expect(classified.retryable).toBe(true);
    });

    it('should classify session not found errors', () => {
      const error = new Error('404 Not Found');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.SESSION_NOT_FOUND);
      expect(classified.retryable).toBe(false);
    });

    it('should classify rate limit errors', () => {
      const error = new Error('429 Too Many Requests');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.RATE_LIMIT_EXCEEDED);
      expect(classified.retryable).toBe(true);
    });

    it('should classify offline errors', () => {
      const error = new Error('You are offline');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.OFFLINE);
      expect(classified.retryable).toBe(true);
    });

    it('should default to unknown error type', () => {
      const error = new Error('Something random happened');
      const classified = classifyError(error);
      expect(classified.type).toBe(ErrorType.UNKNOWN);
      expect(classified.retryable).toBe(true);
    });

    it('should include timestamp on classified errors', () => {
      const error = new Error('Test error');
      const classified = classifyError(error);
      expect(classified.timestamp).toBeGreaterThan(0);
    });

    it('should provide user-friendly messages', () => {
      const error = new Error('NETWORK: unreachable');
      const classified = classifyError(error);
      expect(classified.userMessage).toContain('Network connection failed');
      expect(classified.userMessage.length).toBeGreaterThan(10);
    });
  });

  describe('getRecoverySuggestions', () => {
    it('should provide network error recovery suggestions', () => {
      const suggestions = getRecoverySuggestions(ErrorType.NETWORK_UNREACHABLE);
      expect(suggestions.length).toBeGreaterThan(0);
      expect(suggestions.some(s => s.includes('internet'))).toBe(true);
    });

    it('should provide timeout recovery suggestions', () => {
      const suggestions = getRecoverySuggestions(ErrorType.CONNECTION_TIMEOUT);
      expect(suggestions.length).toBeGreaterThan(0);
      expect(suggestions.some(s => s.includes('internet'))).toBe(true);
    });

    it('should provide authentication recovery suggestions', () => {
      const suggestions = getRecoverySuggestions(ErrorType.AUTHENTICATION_FAILED);
      expect(suggestions.length).toBeGreaterThan(0);
      expect(suggestions.some(s => s.includes('API key'))).toBe(true);
    });

    it('should provide offline recovery suggestions', () => {
      const suggestions = getRecoverySuggestions(ErrorType.OFFLINE);
      expect(suggestions.length).toBeGreaterThan(0);
      expect(suggestions.some(s => s.includes('internet'))).toBe(true);
    });
  });

  describe('errorEmitter', () => {
    it('should emit errors to subscribers', () => {
      let emittedError: any = null;
      const unsubscribe = errorEmitter.subscribe((error) => {
        emittedError = error;
      });

      const error = new Error('Test error');
      const classified = classifyError(error);
      errorEmitter.emit(classified);

      expect(emittedError).not.toBeNull();
      expect(emittedError?.message).toBe('Error: Test error');

      unsubscribe();
    });

    it('should handle multiple subscribers', () => {
      const results: any[] = [];

      const unsub1 = errorEmitter.subscribe((error) => {
        results.push('listener1');
      });

      const unsub2 = errorEmitter.subscribe((error) => {
        results.push('listener2');
      });

      const error = new Error('Test');
      errorEmitter.emit(classifyError(error));

      expect(results).toEqual(['listener1', 'listener2']);

      unsub1();
      unsub2();
    });

    it('should allow unsubscribing from events', () => {
      const results: any[] = [];

      const unsubscribe = errorEmitter.subscribe((error) => {
        results.push('error');
      });

      const error = new Error('Test');
      errorEmitter.emit(classifyError(error));
      expect(results.length).toBe(1);

      unsubscribe();
      errorEmitter.emit(classifyError(error));
      expect(results.length).toBe(1); // Should still be 1
    });
  });

  describe('handleError', () => {
    it('should classify and emit errors', () => {
      let emittedError: any = null;
      errorEmitter.subscribe((error) => {
        emittedError = error;
      });

      const error = new Error('Test error');
      const result = handleError(error);

      expect(result).not.toBeNull();
      expect(result.type).toBeDefined();
      expect(emittedError).not.toBeNull();
    });

    it('should include context in error handling', () => {
      const error = new Error('Test error');
      const result = handleError(error, 'TestContext');

      expect(result).not.toBeNull();
      // Context should be logged (we're just verifying no error is thrown)
    });
  });

  describe('Error classification edge cases', () => {
    it('should handle null errors', () => {
      const classified = classifyError(null);
      expect(classified.type).toBe(ErrorType.UNKNOWN);
    });

    it('should handle undefined errors', () => {
      const classified = classifyError(undefined);
      expect(classified.type).toBe(ErrorType.UNKNOWN);
    });

    it('should handle string errors', () => {
      const classified = classifyError('Network error');
      expect(classified.type).toBe(ErrorType.NETWORK_UNREACHABLE);
    });

    it('should handle objects without toString', () => {
      const classified = classifyError({});
      expect(classified.type).toBeDefined();
    });
  });
});
