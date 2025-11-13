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
 * Sentry Client Configuration for OpenCode Nexus
 * Handles browser-side error tracking, performance monitoring, and session replay
 *
 * This file is automatically loaded by @sentry/astro for client-side initialization
 */

import * as Sentry from "@sentry/astro";

Sentry.init({
  // Frontend DSN for browser error tracking
  dsn: "https://1ca61080ceb639661e4da7e91914cb92@sentry.fergify.work/17",

  // Environment
  environment: import.meta.env.MODE || "production",

  // Release version (must match backend: 1.0.0)
  release: "1.0.0",

  // Performance monitoring: Sample 10% of transactions in production, 100% in dev
  tracesSampleRate:
    import.meta.env.MODE === "production" ? 0.1 : 1.0,

  // Session replay sampling
  // - 1% of normal sessions
  // - 100% of sessions with errors (per Sentry docs)
  replaysSessionSampleRate: import.meta.env.MODE === "production" ? 0.01 : 0.1,
  replaysOnErrorSampleRate: 1.0,

  // Debug mode: false in production
  debug: import.meta.env.MODE !== "production",

  // Privacy: Capture user IPs and headers (per Sentry docs for better debugging)
  sendDefaultPii: true,

  // Ignore certain errors that are not actionable
  ignoreErrors: [
    // Browser extensions
    /top\.GLOBALS/,
    // Random plugins/extensions
    "originalCreateNotification",
    "canvas.contentDocument",
    "MyApp_RemoveAllHighlights",
    // Network errors (not as critical for frontend)
    "NetworkError",
    "Network request failed",
    "Network error",
    "Failed to fetch",
    // User cancelled actions
    "AbortError",
    "User cancelled",
    // Security sandbox errors
    "NS_ERROR_",
    // Generic unhelpful messages
    "Non-Error promise rejection captured",
    // Tauri IPC errors
    "Command not found",
    "IPC error",
  ],

  // Hooks to filter and modify events before sending
  beforeSend(event, hint) {
    const error = hint.originalException;

    // Don't send certain types of errors
    if (error instanceof TypeError) {
      if (error.message?.includes("NetworkError")) {
        return null; // Don't send network errors
      }
    }

    // Downgrade non-critical network errors to warnings
    if (
      error instanceof Error &&
      error.message?.includes("fetch")
    ) {
      event.level = "warning";
    }

    // Sanitize request/response URLs
    if (event.request?.url) {
      event.request.url = event.request.url
        .replace(/\/Users\/\w+/g, "/Users/***")
        .replace(/([?&])key=[\w-]+/g, "$1key=***")
        .replace(/([?&])token=[\w-]+/g, "$1token=***")
        .replace(/([?&])password=[\w-]+/g, "$1password=***")
        .replace(/([?&])secret=[\w-]+/g, "$1secret=***");
    }

    // Remove sensitive headers
    if (event.request?.headers) {
      delete event.request.headers["Authorization"];
      delete event.request.headers["Cookie"];
      delete event.request.headers["X-API-Key"];
      delete event.request.headers["X-Auth-Token"];
    }

    // Remove user IP and other identifying information
    if (event.request?.env?.REMOTE_ADDR) {
      event.request.env.REMOTE_ADDR = "***";
    }

    // Redact user context PII
    if (event.user) {
      event.user.ip_address = "***";
      delete event.user.email;
      delete event.user.name;
    }

    return event;
  },

  // Integrations for capturing different error types and metrics
  integrations: [
    // Capture console warnings and errors
    Sentry.captureConsoleIntegration({
      levels: ["error", "warn"],
    }),

    // Session replay - capture user interactions for debugging errors
    Sentry.replayIntegration({
      maskAllText: true, // Mask all user text in replays (privacy)
      blockAllMedia: true, // Don't record media/images
      maskAllInputs: true, // Mask form inputs
    }),

    // Dedicated error boundary integration for Svelte/React components
    Sentry.browserTracingIntegration({
      // Set sampling rate for tracing
      tracePropagationTargets: [
        // Match API endpoints
        /^\//,
        // Match same-origin requests
        /^\//,
      ],
    }),
  ],
});

/**
 * Set user context for error reporting
 * Call this after successful authentication
 */
export function setSentryUser(userId: string, username?: string) {
  Sentry.setUser({
    id: userId,
    username: username,
    // Don't include email for privacy
  });
}

/**
 * Clear user context on logout
 */
export function clearSentryUser() {
  Sentry.setUser(null);
}

/**
 * Capture exception with custom context
 */
export function captureException(error: Error, context?: Record<string, any>) {
  Sentry.captureException(error, {
    contexts: context ? { custom: context } : undefined,
  });
}

/**
 * Capture message (info, warning, or error)
 */
export function captureMessage(
  message: string,
  level: "fatal" | "error" | "warning" | "info" | "debug" = "info"
) {
  Sentry.captureMessage(message, level);
}

/**
 * Add breadcrumb for debugging user interactions
 */
export function addBreadcrumb(
  message: string,
  data?: Record<string, any>,
  category: string = "user-action"
) {
  Sentry.addBreadcrumb({
    message,
    data,
    category,
    level: "info",
  });
}

/**
 * Set custom context for debugging
 */
export function setContext(name: string, data: Record<string, any>) {
  Sentry.setContext(name, data);
}
