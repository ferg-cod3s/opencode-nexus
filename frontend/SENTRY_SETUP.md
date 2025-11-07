# Sentry Error Tracking Setup Guide

## Overview

OpenCode Nexus uses Sentry for unified error tracking across frontend (browser) and backend (Rust). This guide explains the development and production setup.

## Configuration Files

### Client-Side (`sentry.client.config.ts`)
- **Browser Error Tracking**: Captures JavaScript errors, unhandled promise rejections
- **Performance Monitoring**: Traces all HTTP requests and user interactions (100% in dev, 10% in prod)
- **Session Replay**: Records user interactions for debugging errors (10% in dev, 1% in prod, 50% on errors)
- **Privacy**: Masks all text, removes sensitive headers, redacts API keys

### Server-Side (`sentry.server.config.ts`)
- **SSR/Astro Errors**: Server-side rendering errors
- **Network Errors**: HTTP client failures from Tauri backend calls
- **Request Filtering**: Excludes sensitive routes like `/auth`, `/login`, `/password`

### Build Configuration (`astro.config.mjs`)
- **Source Map Uploads**: Requires `SENTRY_AUTH_TOKEN` for production
- **Release Tracking**: Version 1.0.0 for both frontend and backend

## Development Setup

### Environment Variables

1. **Copy the example environment file:**
   ```bash
   cp frontend/.env.example frontend/.env
   ```

2. **Get Sentry Auth Token (optional for dev, required for production):**
   - Go to: https://sentry.fergify.work/settings/account/api/auth-tokens/
   - Click "Create New Token"
   - Scopes needed:
     - ✅ `project:releases` (read & write)
     - ✅ `org:read`
   - Copy the token to `frontend/.env`:
     ```
     SENTRY_AUTH_TOKEN=sntrys_eyJ...
     ```

3. **Development Mode Automatically Enables:**
   - ✅ 100% trace sampling (capture ALL performance data)
   - ✅ 10% session replays (more frequent recordings)
   - ✅ Debug logging enabled
   - ✅ All error types captured

### Running in Development

```bash
cd frontend
bun run dev
```

**Sentry will:**
- Automatically initialize when the browser loads
- Capture all JavaScript errors
- Log performance metrics
- Record session replays for errors
- Display debug info in console

**Test Error Capture:**
1. Open browser DevTools
2. Run in console: `throw new Error("Test Sentry")`
3. Check Sentry dashboard: https://sentry.fergify.work/fergify/opencode-nexus/

## Production Setup

### Build with Source Maps

```bash
# Ensure SENTRY_AUTH_TOKEN is set
export SENTRY_AUTH_TOKEN="sntrys_eyJ..."

cd frontend
bun run build
```

**Production Configuration:**
- ✅ 10% trace sampling (reduced load)
- ✅ 1% session replays (privacy-first)
- ✅ Debug logging disabled
- ✅ Source maps uploaded to Sentry
- ✅ Errors linked to source code

### Privacy Settings

All Sentry configurations include privacy protections:

**PII Never Sent:**
- ❌ Email addresses
- ❌ User names
- ❌ IP addresses
- ❌ Form data

**Sensitive Data Redacted:**
- Authorization headers
- API keys and tokens
- Request bodies
- Passwords

**Text Masking:**
- All text in replays is masked (`[Redacted]`)
- Media and images not recorded
- Form inputs are masked

## Features by Environment

### Development (import.meta.env.MODE === "development")
```
Traces:        100% (all requests)
Replays:       10% (normal), 50% (on error)
Debug:         Enabled
Sample Rate:   Unlimited
Cost Impact:   High (for testing only)
```

### Production (import.meta.env.MODE === "production")
```
Traces:        10% (sampled)
Replays:       1% (normal), 50% (on error)
Debug:         Disabled
Sample Rate:   10% of users
Cost Impact:   Optimized
```

## Error Capture Points

### Login Page (`src/pages/login.astro`)
- ✅ Authentication attempts (success/failure)
- ✅ Validation errors
- ✅ Unexpected errors during login
- ✅ User context tracking

### Chat Page (`src/pages/chat.astro`)
- ✅ Session initialization
- ✅ Component mounting errors
- ✅ Message sending failures
- ✅ Real-time event streaming errors
- ✅ Logout errors

### Global Error Handler
- ✅ Unhandled exceptions
- ✅ Promise rejections
- ✅ Network failures
- ✅ Component errors

## Breadcrumb Tracking

Sentry automatically tracks user actions as breadcrumbs:

```
[Login] → [Enter Credentials] → [Submit] → [Success/Failure]
[Chat] → [Load Sessions] → [Create Session] → [Send Message]
```

Each breadcrumb captures:
- Timestamp
- Event category (authentication, chat, error)
- Severity level (info, warning, error)
- Custom context data

## Viewing Errors

**Dashboard:** https://sentry.fergify.work/fergify/opencode-nexus/

**View Error Details:**
1. Click on an event
2. See full stack trace with source maps
3. View breadcrumb trail
4. Check session replays
5. Review affected users

## Troubleshooting

### Errors Not Appearing?

1. **Check SENTRY_AUTH_TOKEN:**
   ```bash
   echo $SENTRY_AUTH_TOKEN
   ```

2. **Verify Configuration:**
   - Are `sentry.client.config.ts` and `sentry.server.config.ts` present?
   - Does `astro.config.mjs` include Sentry integration?

3. **Check Sentry Dashboard:**
   - Are there any errors in the issues list?
   - Check the "Releases" page for version 1.0.0

4. **Browser Console:**
   - Look for Sentry initialization messages
   - Check for CORS issues with sentry.fergify.work

### Source Maps Not Uploading?

1. Ensure `SENTRY_AUTH_TOKEN` is set before build
2. Run `bun run build` (not dev)
3. Check build output for Sentry upload messages
4. Verify token has `project:releases` scope

### High Cost from Traces?

1. Only run dev with 100% sampling during testing
2. Reduce `replaysSessionSampleRate` in production if needed
3. Check Sentry quota settings: https://sentry.fergify.work/settings/billing/

## Related Documentation

- [Sentry Astro Integration](https://docs.sentry.io/platforms/javascript/guides/astro/)
- [Performance Monitoring](https://docs.sentry.io/platforms/javascript/performance/)
- [Session Replay Privacy](https://docs.sentry.io/platforms/javascript/session-replay/)
- [Release Tracking](https://docs.sentry.io/product/releases/)
