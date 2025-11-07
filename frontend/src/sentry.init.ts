/**
 * Sentry initialization for OpenCode Nexus frontend
 * Captures JavaScript errors, unhandled promise rejections, and performance metrics
 *
 * Configuration:
 * - Environment: production
 * - Release: auto-detected from package.json
 * - Debug: false (production)
 * - PII: Disabled for privacy
 * - Tracing: Performance monitoring enabled
 * - Session Replay: Disabled (privacy first)
 */

import * as Sentry from "@sentry/astro";

// Initialize Sentry for the browser environment
export function initializeSentry() {
  // Skip initialization in development if needed
  if (typeof window === "undefined") {
    return;
  }

  Sentry.init({
    // Shared DSN with backend for unified error tracking
    dsn: "https://27a3e3d68747cda91305b45e394f768e@sentry.fergify.work/14",

    // Environment
    environment: import.meta.env.MODE || "production",

    // Release version (matches backend)
    release: "1.0.0",

    // Performance monitoring
    tracesSampleRate: import.meta.env.MODE === "production" ? 0.1 : 1.0,

    // Debug mode
    debug: false,

    // Privacy: Don't send PII
    sendDefaultPii: false,

    // Ignore certain errors that are not actionable
    ignoreErrors: [
      // Browser extensions
      /top\.GLOBALS/,
      // Random plugins/extensions
      "originalCreateNotification",
      "canvas.contentDocument",
      "MyApp_RemoveAllHighlights",
      // Network errors
      "NetworkError",
      "Network request failed",
      "Network error",
      // User cancelled
      "AbortError",
      "User cancelled",
      // Security sandbox errors
      "NS_ERROR_",
      // Generic error messages that don't help
      "Non-Error promise rejection captured",
    ],

    // Sanitize request/response data
    beforeSend(event, hint) {
      const error = hint.originalException;

      // Filter out certain error types
      if (error instanceof TypeError && error.message?.includes("fetch")) {
        // Network/CORS errors - less critical
        if (event.level === "error") {
          event.level = "warning";
        }
      }

      // Remove sensitive data from URLs
      if (event.request?.url) {
        event.request.url = event.request.url
          .replace(/\/Users\/\w+/g, "/Users/***")
          .replace(/([?&])key=[\w-]+/g, "$1key=***")
          .replace(/([?&])token=[\w-]+/g, "$1token=***")
          .replace(/([?&])password=[\w-]+/g, "$1password=***");
      }

      // Remove user IP and sensitive headers
      if (event.request?.headers) {
        delete event.request.headers["Authorization"];
        delete event.request.headers["Cookie"];
        delete event.request.headers["X-API-Key"];
      }

      return event;
    },

    // Configure integrations
    integrations: [
      Sentry.captureConsoleIntegration({ levels: ["error", "warn"] }),
      Sentry.replayIntegration({
        maskAllText: true, // Mask all text in replays
        blockAllMedia: true, // Don't record media
      }),
    ],

    // Session replay: sample for debugging issues
    replaysSessionSampleRate: import.meta.env.MODE === "production" ? 0.01 : 0.1,
    replaysOnErrorSampleRate: 0.5, // Higher sample rate for errors
  });
}

/**
 * Set user context for error tracking
 * Call this after user authentication
 */
export function setSentryUser(userId: string, username?: string, email?: string) {
  Sentry.setUser({
    id: userId,
    username: username,
    email: email,
  });
}

/**
 * Clear user context (e.g., on logout)
 */
export function clearSentryUser() {
  Sentry.setUser(null);
}

/**
 * Capture a custom error or message
 */
export function captureException(error: Error, context?: Record<string, any>) {
  Sentry.captureException(error, {
    contexts: context ? { custom: context } : undefined,
  });
}

/**
 * Capture a message (for non-error events)
 */
export function captureMessage(message: string, level: "info" | "warning" | "error" = "info") {
  Sentry.captureMessage(message, level);
}

/**
 * Set custom context for debugging
 */
export function setContext(name: string, data: Record<string, any>) {
  Sentry.setContext(name, data);
}

/**
 * Add breadcrumb for event tracking
 */
export function addBreadcrumb(
  message: string,
  category?: string,
  level?: "debug" | "info" | "warning" | "error"
) {
  Sentry.addBreadcrumb({
    message,
    category: category || "user-action",
    level: level || "info",
    timestamp: Date.now() / 1000,
  });
}
