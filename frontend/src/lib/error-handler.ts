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
 * Comprehensive error handling system for OpenCode Nexus
 * Provides error classification, user-friendly messages, and recovery suggestions
 */

export enum ErrorType {
  // Network errors
  NETWORK_UNREACHABLE = 'NETWORK_UNREACHABLE',
  CONNECTION_TIMEOUT = 'CONNECTION_TIMEOUT',
  CONNECTION_REFUSED = 'CONNECTION_REFUSED',
  CONNECTION_LOST = 'CONNECTION_LOST',
  SSL_CERTIFICATE_ERROR = 'SSL_CERTIFICATE_ERROR',

  // Server errors
  SERVER_UNAVAILABLE = 'SERVER_UNAVAILABLE',
  SERVER_ERROR = 'SERVER_ERROR',
  AUTHENTICATION_FAILED = 'AUTHENTICATION_FAILED',
  INVALID_API_KEY = 'INVALID_API_KEY',

  // Session errors
  SESSION_NOT_FOUND = 'SESSION_NOT_FOUND',
  SESSION_EXPIRED = 'SESSION_EXPIRED',
  INVALID_SESSION = 'INVALID_SESSION',

  // Chat errors
  MESSAGE_TOO_LONG = 'MESSAGE_TOO_LONG',
  RATE_LIMIT_EXCEEDED = 'RATE_LIMIT_EXCEEDED',
  MODEL_NOT_AVAILABLE = 'MODEL_NOT_AVAILABLE',

  // Client errors
  NOT_CONNECTED = 'NOT_CONNECTED',
  OFFLINE = 'OFFLINE',
  INVALID_INPUT = 'INVALID_INPUT',
  UNKNOWN = 'UNKNOWN'
}

export interface AppError {
  type: ErrorType;
  message: string;
  userMessage: string;
  details?: string;
  code?: number;
  retryable: boolean;
  timestamp: number;
}

/**
 * Classify error based on message content and type
 */
export function classifyError(error: unknown): AppError {
  const timestamp = Date.now();

  if (error && typeof error === 'object' && 'type' in error) {
    const err = error as Record<string, unknown>;
    if (typeof err.type === 'string' && err.type in ErrorType) {
      return err as unknown as AppError;
    }
  }

  const errorStr = String(error?.toString?.() || error || 'Unknown error');
  const errorLower = errorStr.toLowerCase();

  // Network errors
  if (
    errorLower.includes('network') ||
    errorLower.includes('econnrefused') ||
    errorLower.includes('unreachable')
  ) {
    return {
      type: ErrorType.NETWORK_UNREACHABLE,
      message: errorStr,
      userMessage: 'Network connection failed. Please check your internet connection.',
      details: 'Unable to reach the OpenCode server. The server may be offline or unreachable.',
      retryable: true,
      timestamp
    };
  }

  // Connection timeout
  if (
    errorLower.includes('timeout') ||
    errorLower.includes('etimedout')
  ) {
    return {
      type: ErrorType.CONNECTION_TIMEOUT,
      message: errorStr,
      userMessage: 'Connection timed out. The server is taking too long to respond.',
      details: 'The request exceeded the timeout limit. Try again with a slower connection.',
      retryable: true,
      timestamp
    };
  }

  // Connection refused
  if (errorLower.includes('econnrefused')) {
    return {
      type: ErrorType.CONNECTION_REFUSED,
      message: errorStr,
      userMessage: 'Connection refused. The server is not accepting connections.',
      details: 'The OpenCode server may not be running or the port is incorrect.',
      retryable: true,
      timestamp
    };
  }

  // SSL/TLS errors
  if (
    errorLower.includes('ssl') ||
    errorLower.includes('certificate') ||
    errorLower.includes('https')
  ) {
    return {
      type: ErrorType.SSL_CERTIFICATE_ERROR,
      message: errorStr,
      userMessage: 'SSL certificate verification failed.',
      details: 'There\'s a problem with the server\'s SSL certificate. Check server configuration.',
      retryable: false,
      timestamp
    };
  }

  // Authentication errors
  if (
    errorLower.includes('401') ||
    errorLower.includes('unauthorized') ||
    errorLower.includes('auth')
  ) {
    return {
      type: ErrorType.AUTHENTICATION_FAILED,
      message: errorStr,
      userMessage: 'Authentication failed. Please check your API key.',
      details: 'The API key or credentials you provided are invalid.',
      retryable: false,
      timestamp
    };
  }

  // API key errors
  if (errorLower.includes('api key') || errorLower.includes('key')) {
    return {
      type: ErrorType.INVALID_API_KEY,
      message: errorStr,
      userMessage: 'Invalid API key. Please check your credentials.',
      details: 'The API key format is incorrect or the key has been revoked.',
      retryable: false,
      timestamp
    };
  }

  // Server errors
  if (errorLower.includes('500') || errorLower.includes('server error')) {
    return {
      type: ErrorType.SERVER_ERROR,
      message: errorStr,
      userMessage: 'Server encountered an error. Please try again later.',
      details: 'The OpenCode server returned an internal error.',
      retryable: true,
      timestamp
    };
  }

  // Service unavailable
  if (
    errorLower.includes('503') ||
    errorLower.includes('unavailable') ||
    errorLower.includes('service unavailable')
  ) {
    return {
      type: ErrorType.SERVER_UNAVAILABLE,
      message: errorStr,
      userMessage: 'The server is temporarily unavailable. Please try again later.',
      details: 'The OpenCode service is under maintenance or overloaded.',
      retryable: true,
      timestamp
    };
  }

  // Session errors
  if (errorLower.includes('not found') || errorLower.includes('404')) {
    return {
      type: ErrorType.SESSION_NOT_FOUND,
      message: errorStr,
      userMessage: 'Session not found. It may have been deleted.',
      details: 'The session you\'re trying to access no longer exists.',
      retryable: false,
      timestamp
    };
  }

  // Message errors
  if (
    errorLower.includes('message') &&
    (errorLower.includes('long') || errorLower.includes('length'))
  ) {
    return {
      type: ErrorType.MESSAGE_TOO_LONG,
      message: errorStr,
      userMessage: 'Message is too long. Please shorten it.',
      details: 'The message exceeds the maximum length allowed.',
      retryable: false,
      timestamp
    };
  }

  // Rate limiting
  if (
    errorLower.includes('rate') ||
    errorLower.includes('429') ||
    errorLower.includes('too many')
  ) {
    return {
      type: ErrorType.RATE_LIMIT_EXCEEDED,
      message: errorStr,
      userMessage: 'Rate limit exceeded. Please wait before trying again.',
      details: 'You\'ve sent too many requests. The server has limited your access.',
      retryable: true,
      timestamp
    };
  }

  // Connection status
  if (errorLower.includes('not connected')) {
    return {
      type: ErrorType.NOT_CONNECTED,
      message: errorStr,
      userMessage: 'Not connected to a server. Please connect first.',
      details: 'You need to establish a connection before performing this action.',
      retryable: true,
      timestamp
    };
  }

  // Offline
  if (errorLower.includes('offline')) {
    return {
      type: ErrorType.OFFLINE,
      message: errorStr,
      userMessage: 'You are offline. Check your internet connection.',
      details: 'This action requires an active internet connection.',
      retryable: true,
      timestamp
    };
  }

  // Default unknown error
  return {
    type: ErrorType.UNKNOWN,
    message: errorStr,
    userMessage: 'An unexpected error occurred. Please try again.',
    details: errorStr,
    retryable: true,
    timestamp
  };
}

/**
 * Get recovery suggestions based on error type
 */
export function getRecoverySuggestions(errorType: ErrorType): string[] {
  switch (errorType) {
    case ErrorType.NETWORK_UNREACHABLE:
      return [
        'Check your internet connection',
        'Verify the server address is correct',
        'Try using a different network',
        'Check if the server is running'
      ];

    case ErrorType.CONNECTION_TIMEOUT:
      return [
        'Check your internet connection quality',
        'Try again in a moment',
        'Reduce the network load if possible',
        'Move closer to your router'
      ];

    case ErrorType.CONNECTION_REFUSED:
      return [
        'Verify the OpenCode server is running',
        'Check the server port number',
        'Ensure the server is accessible from your location',
        'Check firewall settings'
      ];

    case ErrorType.SSL_CERTIFICATE_ERROR:
      return [
        'Verify the server is using HTTPS correctly',
        'Update your system certificates',
        'Contact your server administrator'
      ];

    case ErrorType.AUTHENTICATION_FAILED:
      return [
        'Re-enter your API key',
        'Verify the API key hasn\'t been revoked',
        'Reset your credentials if necessary'
      ];

    case ErrorType.SERVER_UNAVAILABLE:
      return [
        'Wait a few moments and try again',
        'Check if the server is under maintenance',
        'Monitor the server status'
      ];

    case ErrorType.RATE_LIMIT_EXCEEDED:
      return [
        'Wait several minutes before trying again',
        'Reduce the frequency of requests',
        'Contact your server administrator'
      ];

    case ErrorType.NOT_CONNECTED:
      return [
        'Go to Settings to configure a server connection',
        'Verify your saved connection details',
        'Test the connection before chatting'
      ];

    case ErrorType.OFFLINE:
      return [
        'Reconnect to your internet',
        'Switch to a different network',
        'Retry once connection is restored'
      ];

    default:
      return [
        'Try the action again',
        'Refresh the page',
        'Contact support if the problem persists'
      ];
  }
}

/**
 * Error handler event emitter
 * Allows components to subscribe to error events
 */
class ErrorHandlerEmitter {
  private listeners: ((error: AppError) => void)[] = [];

  subscribe(listener: (error: AppError) => void): () => void {
    this.listeners.push(listener);
    // Return unsubscribe function
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener);
    };
  }

  emit(error: AppError): void {
    console.error(`❌ [ERROR] ${error.type}: ${error.message}`);
    this.listeners.forEach(listener => {
      try {
        listener(error);
      } catch (e) {
        console.error('Error in error listener:', e);
      }
    });
  }

  clear(): void {
    this.listeners = [];
  }
}

export const errorEmitter = new ErrorHandlerEmitter();

/**
 * Handle an error, classify it, and emit to listeners
 */
export function handleError(error: unknown, context?: string): AppError {
  const appError = classifyError(error);
  if (context) {
    console.error(`[${context}]`, appError);
  }
  errorEmitter.emit(appError);
  return appError;
}
