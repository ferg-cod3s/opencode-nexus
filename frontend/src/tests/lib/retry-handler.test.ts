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

import { describe, it, expect } from 'bun:test';
import { withRetry, isRetryable, DEFAULT_RETRY_CONFIG } from '../../lib/retry-handler';

describe('Retry Handler', () => {
  describe('withRetry', () => {
    it('should return result on first success', async () => {
      const fn = async () => 'success';
      const result = await withRetry(fn);
      expect(result).toBe('success');
    });

    it('should retry on failure and eventually succeed', async () => {
      let attempts = 0;
      const fn = async () => {
        attempts++;
        if (attempts < 3) {
          throw new Error('Network timeout');
        }
        return 'success';
      };

      const result = await withRetry(fn, { maxRetries: 3, initialDelayMs: 10 });
      expect(result).toBe('success');
      expect(attempts).toBe(3);
    });

    it('should throw after max retries exhausted', async () => {
      let attempts = 0;
      const fn = async () => {
        attempts++;
        throw new Error('Network timeout');
      };

      let caughtError: any = null;
      try {
        await withRetry(fn, { maxRetries: 2, initialDelayMs: 10 });
      } catch (error) {
        caughtError = error;
      }

      expect(caughtError).not.toBeNull();
      expect(attempts).toBe(2);
    });

    it('should respect maxRetries config', async () => {
      let attempts = 0;
      const fn = async () => {
        attempts++;
        throw new Error('Test error');
      };

      try {
        await withRetry(fn, { maxRetries: 5, initialDelayMs: 10 });
      } catch {
        // Expected to fail
      }

      expect(attempts).toBe(5);
    });

    it('should apply exponential backoff', async () => {
      const times: number[] = [];
      let attempts = 0;

      const fn = async () => {
        times.push(Date.now());
        attempts++;
        if (attempts < 3) {
          throw new Error('Retry me');
        }
        return 'success';
      };

      const start = Date.now();
      await withRetry(fn, {
        maxRetries: 3,
        initialDelayMs: 50,
        backoffMultiplier: 2
      });

      const elapsed = Date.now() - start;
      // Should wait ~50ms between attempt 1-2, then ~100ms between attempt 2-3
      // Total: ~150ms plus execution time
      expect(elapsed).toBeGreaterThanOrEqual(100);
    });

    it('should cap maximum delay', async () => {
      let attempts = 0;
      const fn = async () => {
        attempts++;
        if (attempts < 4) {
          throw new Error('Retry me');
        }
        return 'success';
      };

      const start = Date.now();
      await withRetry(fn, {
        maxRetries: 5,
        initialDelayMs: 100,
        maxDelayMs: 150,
        backoffMultiplier: 2
      });

      const elapsed = Date.now() - start;
      // With max delay of 150ms, should be bounded
      expect(elapsed).toBeLessThan(500);
    });

    it('should include context in error message', async () => {
      const fn = async () => {
        throw new Error('Original error');
      };

      let caughtError: any = null;
      try {
        await withRetry(fn, { maxRetries: 1, initialDelayMs: 10 }, 'TestContext');
      } catch (error) {
        caughtError = error;
      }

      expect(caughtError).not.toBeNull();
      expect(caughtError?.message).toContain('TestContext');
    });

    it('should handle timeout correctly', async () => {
      const fn = async () => {
        // Simulate slow operation
        await new Promise(resolve => setTimeout(resolve, 100));
        return 'success';
      };

      let caughtError: any = null;
      try {
        await withRetry(fn, {
          maxRetries: 1,
          initialDelayMs: 10,
          timeoutMs: 50 // Timeout shorter than operation
        });
      } catch (error) {
        caughtError = error;
      }

      expect(caughtError).not.toBeNull();
    });

    it('should work with various return types', async () => {
      const fn1 = async () => ({ key: 'value' });
      const fn2 = async () => [1, 2, 3];
      const fn3 = async () => 42;

      const result1 = await withRetry(fn1);
      const result2 = await withRetry(fn2);
      const result3 = await withRetry(fn3);

      expect(result1).toEqual({ key: 'value' });
      expect(result2).toEqual([1, 2, 3]);
      expect(result3).toBe(42);
    });
  });

  describe('isRetryable', () => {
    it('should classify network errors as retryable', () => {
      expect(isRetryable(new Error('Network timeout'))).toBe(true);
      expect(isRetryable(new Error('ECONNREFUSED'))).toBe(true);
      expect(isRetryable(new Error('ECONNRESET'))).toBe(true);
    });

    it('should classify server errors as retryable', () => {
      expect(isRetryable(new Error('500 Internal Server Error'))).toBe(true);
      expect(isRetryable(new Error('502 Bad Gateway'))).toBe(true);
      expect(isRetryable(new Error('503 Service Unavailable'))).toBe(true);
      expect(isRetryable(new Error('504 Gateway Timeout'))).toBe(true);
    });

    it('should classify auth errors as non-retryable', () => {
      expect(isRetryable(new Error('401 Unauthorized'))).toBe(false);
      expect(isRetryable(new Error('403 Forbidden'))).toBe(false);
      expect(isRetryable(new Error('Authentication failed'))).toBe(false);
    });

    it('should classify not found as non-retryable', () => {
      expect(isRetryable(new Error('404 Not Found'))).toBe(false);
    });

    it('should classify certificate errors as non-retryable', () => {
      expect(isRetryable(new Error('SSL certificate error'))).toBe(false);
      expect(isRetryable(new Error('certificate validation failed'))).toBe(false);
    });

    it('should classify malformed errors as non-retryable', () => {
      expect(isRetryable(new Error('Malformed JSON'))).toBe(false);
      expect(isRetryable(new Error('Invalid input'))).toBe(false);
    });

    it('should classify availability issues as retryable', () => {
      expect(isRetryable(new Error('Service temporarily unavailable'))).toBe(true);
    });
  });

  describe('DEFAULT_RETRY_CONFIG', () => {
    it('should have sensible defaults', () => {
      expect(DEFAULT_RETRY_CONFIG.maxRetries).toBe(3);
      expect(DEFAULT_RETRY_CONFIG.initialDelayMs).toBe(1000);
      expect(DEFAULT_RETRY_CONFIG.maxDelayMs).toBe(10000);
      expect(DEFAULT_RETRY_CONFIG.backoffMultiplier).toBe(2);
      expect(DEFAULT_RETRY_CONFIG.timeoutMs).toBe(30000);
    });
  });

  describe('Edge cases', () => {
    it('should handle errors that are not Error objects', async () => {
      const fn = async () => {
        throw 'string error';
      };

      let caughtError: any = null;
      try {
        await withRetry(fn, { maxRetries: 1, initialDelayMs: 10 });
      } catch (error) {
        caughtError = error;
      }

      expect(caughtError).not.toBeNull();
    });

    it('should handle functions that return immediately', async () => {
      const fn = async () => 'instant success';
      const result = await withRetry(fn);
      expect(result).toBe('instant success');
    });

    it('should handle functions that succeed after many retries', async () => {
      let attempts = 0;
      const fn = async () => {
        attempts++;
        if (attempts < 10) {
          throw new Error('Keep trying');
        }
        return 'finally!';
      };

      const result = await withRetry(fn, {
        maxRetries: 10,
        initialDelayMs: 5
      });

      expect(result).toBe('finally!');
      expect(attempts).toBe(10);
    });
  });
});
