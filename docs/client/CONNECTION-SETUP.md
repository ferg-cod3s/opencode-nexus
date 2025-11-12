# OpenCode Server Connection Setup Guide

**Version**: 1.0
**Last Updated**: 2025-11-12
**Target**: OpenCode Nexus Mobile Client Users

## Overview

OpenCode Nexus is a mobile-first client that connects to **OpenCode servers** running elsewhere. The OpenCode server itself has no built-in authentication - security is provided by the **connection method** you choose to expose your server.

This guide covers the three supported connection methods and their security requirements.

---

## Connection Security Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌──────────────┐
│   Client        │         │   Host Machine   │         │  OpenCode    │
│  (Mobile/       │◄──auth─▶│  (Your server/   │────────▶│  Server      │
│   Desktop)      │         │   computer)      │  local  │  (localhost) │
│                 │         │                  │         │              │
│  OpenCode       │         │  cloudflared OR  │         │  Port 4096   │
│  Nexus          │         │  reverse proxy   │         │  No auth     │
└─────────────────┘         └──────────────────┘         └──────────────┘
```

### Three Connection Methods

**1. Localhost (Direct)**
```
Client = Host (same machine)
No auth needed - you're already on the machine
Client → http://localhost:4096
```

**2. Cloudflare Tunnel**
```
Client → Cloudflare (tunnel auth) → Host → OpenCode (localhost:4096)
Security: Cloudflare Tunnel authentication
```

**3. Reverse Proxy**
```
Client → nginx/Caddy (API key) → Host → OpenCode (localhost:4096)
Security: Reverse proxy authentication (API key + HMAC)
```

**Key Points**:
- OpenCode server **always runs on localhost** (no auth needed at OpenCode level)
- Security is about **accessing the host machine**, not OpenCode itself
- Client authenticates to **HOST**, not directly to OpenCode

---

## Method 1: Direct Localhost Connection

### When to Use
- ✅ Development and testing
- ✅ Running client and server on the same machine
- ✅ Maximum performance (no network latency)
- ❌ Cannot access remotely

### Security
- **Transport**: HTTP (acceptable for localhost)
- **Authentication**: None (implicit trust - same machine)
- **Encryption**: Not required (data never leaves machine)

### Server Setup
```bash
# Start OpenCode server on localhost
opencode serve --port 4096 (default)
```

### Client Setup
```
Connection URL: http://localhost:4096
API Key: (leave blank)
```

### Connection Details
- **URL Format**: `http://localhost:4096` or `http://127.0.0.1:4096`
- **Port**: Default 4096 (configurable)
- **SSL Required**: No (localhost only)

---

## Method 2: Cloudflare Tunnel Connection

### When to Use
- ✅ Remote access without port forwarding
- ✅ No static IP or domain required
- ✅ Automatic HTTPS with Cloudflare certificate
- ✅ Free tier available
- ❌ Depends on Cloudflare service availability

### Security
- **Transport**: HTTPS (enforced by Cloudflare)
- **Authentication**: Tunnel credentials (managed by Cloudflare)
- **Encryption**: TLS 1.3 with Cloudflare certificate

### Server Setup

#### Option A: Quick Tunnel (No Account Required)
```bash
# Install cloudflared
# macOS: brew install cloudflare/cloudflare/cloudflared
# Linux: see https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/

# Start OpenCode server
opencode serve --port 4096 (default)

# In another terminal, start tunnel
cloudflared tunnel --url http://localhost:4096
```

**Output**:
```
Your tunnel is available at: https://random-name.trycloudflare.com
```

#### Option B: Named Tunnel (Cloudflare Account Required)
```bash
# Login to Cloudflare
cloudflared tunnel login

# Create named tunnel
cloudflared tunnel create opencode-server

# Configure tunnel
cat > ~/.cloudflared/config.yml <<EOF
tunnel: opencode-server
credentials-file: /path/to/credentials.json

ingress:
  - hostname: opencode.yourdomain.com
    service: http://localhost:4096
  - service: http_status:404
EOF

# Run tunnel
cloudflared tunnel run opencode-server
```

### Client Setup

**Quick Tunnel**:
```
Connection URL: https://random-name.trycloudflare.com
API Key: (leave blank - Cloudflare handles auth)
```

**Named Tunnel**:
```
Connection URL: https://opencode.yourdomain.com
API Key: (leave blank - Cloudflare handles auth)
```

### Connection Details
- **URL Format**: `https://[tunnel-name].trycloudflare.com` or custom domain
- **SSL**: Automatic (Cloudflare certificate)
- **Authentication**: Managed by Cloudflare (no client-side credentials needed)

### Cloudflare Tunnel Security Notes
- Tunnel connection authenticated via Cloudflare credentials stored on server
- Client connects through Cloudflare's network (no direct exposure)
- Cloudflare terminates SSL and proxies requests to localhost
- No API key needed in client (Cloudflare handles authentication)

---

## Method 3: Reverse Proxy with API Key Authentication

### When to Use
- ✅ Self-hosted production deployment
- ✅ Custom domain with your SSL certificate
- ✅ Full control over security and routing
- ✅ Can add rate limiting, WAF, etc.
- ❌ Requires SSL certificate management
- ❌ More complex setup

### Security
- **Transport**: HTTPS (required - client will reject HTTP)
- **Authentication**: HMAC-signed requests with API key
- **Encryption**: TLS 1.2+ with your certificate

### Server Setup

#### Step 1: Generate API Key
```bash
# Generate secure API key
openssl rand -hex 32
# Output: a1b2c3d4e5f6... (save this!)
```

#### Step 2: Configure Reverse Proxy

**Nginx Configuration**:
```nginx
server {
    listen 443 ssl http2;
    server_name opencode.yourdomain.com;

    # SSL certificate
    ssl_certificate /etc/ssl/certs/yourdomain.com.crt;
    ssl_certificate_key /etc/ssl/private/yourdomain.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;

    location / {
        # Verify HMAC signature (requires lua-nginx-module)
        access_by_lua_block {
            local auth = ngx.req.get_headers()["Authorization"]
            if not auth or not verify_hmac(auth, ngx.var.request_body) then
                ngx.exit(ngx.HTTP_UNAUTHORIZED)
            end
        }

        # Proxy to OpenCode server
        proxy_pass http://127.0.0.1:4096;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Caddy Configuration** (Simpler):
```caddy
opencode.yourdomain.com {
    # Caddy automatically provisions SSL certificate

    # API key validation (requires custom plugin or middleware)
    @authenticated {
        header Authorization *
    }

    reverse_proxy @authenticated localhost:4096 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
    }

    respond @not_authenticated "Unauthorized" 401
}
```

#### Step 3: Start OpenCode Server
```bash
# OpenCode server runs on localhost (not exposed)
opencode serve --port 4096 (default)
```

### Client Setup
```
Connection URL: https://opencode.yourdomain.com
API Key: a1b2c3d4e5f6... (your generated key)
```

### Connection Details
- **URL Format**: `https://opencode.yourdomain.com`
- **SSL**: Required (client enforces HTTPS)
- **Authentication**: HMAC-SHA256 request signing

### HMAC Request Signing

The client signs each request using HMAC-SHA256:

```typescript
// Client-side signing (handled automatically by OpenCode Nexus)
const timestamp = Date.now();
const nonce = generateRandomNonce();
const message = `${method}:${path}:${timestamp}:${nonce}`;
const signature = hmacSHA256(apiKey, message);
const authHeader = `HMAC ${timestamp}:${nonce}:${signature}`;
```

**Authorization Header Format**:
```
Authorization: HMAC <timestamp>:<nonce>:<signature>
```

**Server Validation** (pseudocode):
```javascript
function verifyHMAC(authHeader, requestBody) {
    const [timestamp, nonce, clientSignature] = parseAuthHeader(authHeader);

    // Prevent replay attacks (5-minute window)
    if (Date.now() - timestamp > 300000) {
        return false;
    }

    // Reconstruct message and verify signature
    const message = `${method}:${path}:${timestamp}:${nonce}`;
    const expectedSignature = hmacSHA256(apiKey, message);

    return timingSafeEqual(clientSignature, expectedSignature);
}
```

---

## Security Best Practices

### For All Connection Methods

1. **Certificate Validation**
   - Client validates SSL certificates for HTTPS connections
   - Rejects self-signed certificates by default
   - Use certificate pinning for known servers (optional)

2. **Connection Testing**
   - Client tests connection before saving
   - Health check endpoint: `GET /health`
   - Verify server responds with valid JSON

3. **Secure Storage**
   - API keys encrypted in device keychain/keystore
   - iOS: Keychain Services
   - Android: Android Keystore
   - Desktop: OS credential manager

### For Remote Connections (Cloudflare/Proxy)

4. **HTTPS Only**
   - Client rejects HTTP for remote URLs
   - Minimum TLS 1.2
   - Strong cipher suites only

5. **Rate Limiting**
   - Implement server-side rate limiting
   - Client respects 429 responses with exponential backoff

6. **Access Control**
   - Cloudflare: Use Access policies
   - Reverse proxy: Whitelist IP ranges if possible
   - Monitor access logs for suspicious activity

---

## Connection Configuration in OpenCode Nexus

### Server Profile Structure
```typescript
interface ServerConnection {
    id: string;                    // Unique identifier
    name: string;                  // User-friendly name
    url: string;                   // Connection URL
    method: 'localhost' | 'tunnel' | 'proxy';
    apiKey?: string;               // Optional (for proxy method)
    lastConnected?: string;        // ISO timestamp
    status: 'connected' | 'disconnected' | 'error';
}
```

### Example Configurations

**Localhost**:
```json
{
    "id": "local-dev",
    "name": "Local Development",
    "url": "http://localhost:4096",
    "method": "localhost",
    "status": "connected"
}
```

**Cloudflare Tunnel**:
```json
{
    "id": "cf-tunnel",
    "name": "Remote via Cloudflare",
    "url": "https://my-tunnel.trycloudflare.com",
    "method": "tunnel",
    "status": "connected"
}
```

**Reverse Proxy**:
```json
{
    "id": "prod-proxy",
    "name": "Production Server",
    "url": "https://opencode.mydomain.com",
    "method": "proxy",
    "apiKey": "a1b2c3d4e5f6...",
    "status": "connected"
}
```

---

## Troubleshooting

### Cannot Connect to Localhost

**Problem**: `Connection refused` on localhost
**Solution**:
1. Verify OpenCode server is running: `curl http://localhost:4096/health`
2. Check port is correct (default: 8080)
3. Ensure no firewall blocking localhost connections

### Cloudflare Tunnel Not Working

**Problem**: `502 Bad Gateway` or tunnel URL unreachable
**Solution**:
1. Verify cloudflared process is running
2. Check OpenCode server is accessible: `curl http://localhost:4096/health`
3. Restart tunnel: `cloudflared tunnel --url http://localhost:4096`

### Reverse Proxy Authentication Failed

**Problem**: `401 Unauthorized` with API key
**Solution**:
1. Verify API key matches server configuration
2. Check proxy logs for HMAC validation errors
3. Ensure client clock is synchronized (HMAC uses timestamps)
4. Test direct connection: `curl -H "Authorization: HMAC ..." https://...`

### SSL Certificate Errors

**Problem**: `SSL certificate verification failed`
**Solution**:
1. Ensure reverse proxy has valid SSL certificate
2. Certificate must be from trusted CA (not self-signed)
3. Verify domain matches certificate CN/SAN
4. Check certificate expiration date

---

## Appendix: OpenCode Server Commands

### Basic Server Start
```bash
opencode serve --port 4096 (default)
```

### Server with Logging
```bash
opencode serve --port 4096 (default) --log-level debug
```

### Check Server Health
```bash
curl http://localhost:4096/health
```

### Expected Response
```json
{
    "status": "ok",
    "version": "1.0.0",
    "timestamp": "2025-11-12T12:00:00Z"
}
```

---

## Additional Resources

- **OpenCode Documentation**: https://docs.opencode.ai
- **Cloudflare Tunnel Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **Nginx SSL Configuration**: https://ssl-config.mozilla.org/
- **HMAC Authentication**: https://en.wikipedia.org/wiki/HMAC

---

**Status**: ✅ Ready for Implementation
**Next Steps**: Use this guide to build connection UI in OpenCode Nexus client
