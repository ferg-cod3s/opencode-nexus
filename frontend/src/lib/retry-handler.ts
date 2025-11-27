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

/**
 * Retry handler for transient failures with exponential backoff
 */

export interface RetryConfig {
  maxRetries: number;
  initialDelayMs: number;
  maxDelayMs: number;
  backoffMultiplier: number;
  timeoutMs: number;
}

export const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxRetries: 3,
  initialDelayMs: 1000,
  maxDelayMs: 10000,
  backoffMultiplier: 2,
  timeoutMs: 30000
};

/**
 * Retry a function with exponential backoff
 * @param fn - Function to retry
 * @param config - Retry configuration
 * @param context - Context for logging
 * @returns Result of the function
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  config: Partial<RetryConfig> = {},
  context: string = 'Operation'
): Promise<T> {
  const finalConfig = { ...DEFAULT_RETRY_CONFIG, ...config };
  let lastError: Error | undefined;

  for (let attempt = 1; attempt <= finalConfig.maxRetries; attempt++) {
    try {
      console.log(`🔄 [RETRY] ${context} - Attempt ${attempt}/${finalConfig.maxRetries}`);

      // Execute the function with timeout
      const timeoutPromise = new Promise<T>((_, reject) => {
        const timer = setTimeout(() => {
          reject(new Error('Operation timeout'));
        }, finalConfig.timeoutMs);
      });

      const result = await Promise.race([
        fn(),
        timeoutPromise
      ]);

      console.log(`✅ [RETRY] ${context} - Success on attempt ${attempt}`);
      return result;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      console.warn(`⚠️ [RETRY] ${context} - Attempt ${attempt} failed:`, error);

      // Don't retry on the last attempt
      if (attempt === finalConfig.maxRetries) {
        break;
      }

      // Calculate delay with exponential backoff
      const delay = Math.min(
        finalConfig.initialDelayMs * Math.pow(finalConfig.backoffMultiplier, attempt - 1),
        finalConfig.maxDelayMs
      );

      console.log(`⏳ [RETRY] ${context} - Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  console.error(`❌ [RETRY] ${context} - Failed after ${finalConfig.maxRetries} attempts`);
  throw lastError || new Error(`${context} failed after ${finalConfig.maxRetries} attempts`);
}

/**
 * Check if an error is retryable based on type
 */
export function isRetryable(error: unknown): boolean {
  const errorStr = String(error?.toString?.() || '').toLowerCase();

  // Explicitly non-retryable errors
  const nonRetryablePatterns = [
    '401', '403', '404', // Auth and not found errors
    'unauthorized', 'forbidden', 'not found',
    'authentication', 'certificate',
    'invalid', 'malformed'
  ];

  const isNonRetryable = nonRetryablePatterns.some(pattern =>
    errorStr.includes(pattern)
  );

  if (isNonRetryable) {
    return false;
  }

  // Explicitly retryable errors
  const retryablePatterns = [
    'timeout', 'network', 'econnrefused', 'econnreset',
    '500', '502', '503', '504',
    'unavailable', 'temporarily'
  ];

  return retryablePatterns.some(pattern =>
    errorStr.includes(pattern)
  );
}
