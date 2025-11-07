/**
 * Sentry Server Configuration for OpenCode Nexus
 * Handles server-side error tracking and performance monitoring (SSR)
 *
 * This file is automatically loaded by @sentry/astro for server-side initialization
 */

import * as Sentry from "@sentry/astro";

Sentry.init({
  // Shared DSN with backend for unified error tracking
  dsn: "https://27a3e3d68747cda91305b45e394f768e@sentry.fergify.work/14",

  // Environment
  environment: import.meta.env.MODE || "production",

  // Release version (must match backend: 1.0.0)
  release: "1.0.0",

  // Performance monitoring: Sample transactions
  tracesSampleRate:
    import.meta.env.MODE === "production" ? 0.1 : 1.0,

  // Debug mode: false in production
  debug: import.meta.env.MODE !== "production",

  // Privacy: Don't send PII
  sendDefaultPii: false,

  // Ignore certain errors that are not actionable on server
  ignoreErrors: [
    // Network errors from external calls
    "ECONNREFUSED",
    "ETIMEDOUT",
    "EHOSTUNREACH",
    // Generic unhelpful messages
    "Non-Error promise rejection captured",
  ],

  // Filter and modify events before sending
  beforeSend(event, hint) {
    // Don't send network timeout errors
    if (
      hint.originalException instanceof Error &&
      hint.originalException.message?.includes("timeout")
    ) {
      return null;
    }

    // Remove sensitive request data
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
      delete event.request.headers["authorization"];
      delete event.request.headers["cookie"];
      delete event.request.headers["x-api-key"];
      delete event.request.headers["x-auth-token"];
    }

    return event;
  },

  // Server-side integrations
  integrations: [
    // Capture console warnings and errors
    Sentry.captureConsoleIntegration({
      levels: ["error", "warn"],
    }),

    // Capture HTTP client errors
    Sentry.httpClientIntegration(),

    // Server-side request/response tracking
    Sentry.requestDataIntegration({
      include: {
        cookies: false, // Don't include cookies (may contain sensitive data)
        query_string: true,
        request_body: false, // Don't include request body
      },
      exclude: [
        // URLs that typically have sensitive data
        /\/auth\//,
        /\/login/,
        /\/password/,
      ],
    }),
  ],
});

/**
 * Set context for server-side error tracking
 */
export function setServerContext(name: string, data: Record<string, any>) {
  Sentry.setContext(name, data);
}

/**
 * Capture server-side exception
 */
export function captureServerException(
  error: Error,
  context?: Record<string, any>
) {
  Sentry.captureException(error, {
    contexts: context ? { custom: context } : undefined,
  });
}

/**
 * Capture server-side message
 */
export function captureServerMessage(
  message: string,
  level: "fatal" | "error" | "warning" | "info" | "debug" = "info"
) {
  Sentry.captureMessage(message, level);
}
