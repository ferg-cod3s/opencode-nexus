# Cloudflare Proxy Configuration for OpenCode Nexus
# This file explains how to configure Cloudflare to work with your reverse proxy setup

## Architecture Overview

```
Mobile App → Cloudflare → Your Server (Caddy + OpenCode)
```

## Current Setup

- **Domain**: opencode.fergify.work
- **Cloudflare Proxy**: Currently pointing to your server
- **Local Development**: Caddy with self-signed certificates

## Configuration Options

### Option 1: Cloudflare as Primary Proxy (Recommended for Production)

1. **DNS Settings in Cloudflare Dashboard**:
   ```
   Type: A
   Name: opencode
   IPv4 address: YOUR_SERVER_IP
   Proxy status: Proxied (orange cloud)
   TTL: Auto
   ```

2. **SSL/TLS Settings**:
   ```
   Overview: Full (strict)
   Edge Certificates: Always Use HTTPS
   HSTS: Enable
   Minimum TLS Version: 1.2
   ```

3. **Network Settings**:
   ```
   WebSockets: On
   HTTP/3 (with QUIC): On
   0-RTT Connection Resumption: On
   ```

4. **Security Settings**:
   ```
   SSL/TLS → Origin Server: Create custom origin certificate
   Bypass: Cloudflare Origin CA certificate
   ```

### Option 2: Cloudflare Tunnel (Recommended for Development)

1. **Install cloudflared**:
   ```bash
   # macOS
   brew install cloudflared
   
   # Linux
   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i cloudflared-linux-amd64.deb
   ```

2. **Authenticate cloudflared**:
   ```bash
   cloudflared tunnel login
   ```

3. **Create a tunnel**:
   ```bash
   cloudflared tunnel create opencode-nexus
   ```

4. **Configure the tunnel** (create `~/.cloudflared/config.yml`):
   ```yaml
   tunnel: opencode-nexus
   credentials-file: /home/user/.cloudflared/opencode-nexus.json
   
   ingress:
     - hostname: opencode.fergify.work
       service: http://localhost:3000
     - service: http_status:404
   ```

5. **Create DNS record**:
   ```bash
   cloudflared tunnel route dns opencode-nexus opencode.fergify.work
   ```

6. **Run the tunnel**:
   ```bash
   cloudflared tunnel run opencode-nexus
   ```

### Option 3: Hybrid Setup (Development + Production)

Use Cloudflare Tunnel for development and direct proxy for production.

## Mobile App Configuration

### For Local Development (with Caddy)
```json
{
  "serverUrl": "https://localhost:3000",
  "connectionMethod": "proxy",
  "apiKey": "your-api-key",
  "sslVerification": false // For self-signed certs
}
```

### For Production (with Cloudflare)
```json
{
  "serverUrl": "https://opencode.fergify.work",
  "connectionMethod": "proxy", 
  "apiKey": "your-api-key",
  "sslVerification": true
}
```

### For Cloudflare Tunnel
```json
{
  "serverUrl": "https://opencode.fergify.work",
  "connectionMethod": "tunnel",
  "apiKey": "your-api-key",
  "sslVerification": true
}
```

## Headers Configuration

### Required Headers for Mobile App

Add these headers in your Caddyfile or server configuration:

```nginx
# For Cloudflare proxy compatibility
X-Forwarded-Proto: https
X-Forwarded-Host: opencode.fergify.work
X-Forwarded-For: {remote}

# CORS for mobile app
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key

# Security headers
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
```

## API Key Handling

### Cloudflare API Shield (Optional)

For additional security, you can use Cloudflare API Shield:

1. **Create API Token** in Cloudflare dashboard
2. **Configure API Shield** with your token schema
3. **Update mobile app** to include Cloudflare token

### HMAC Signature Verification

Your app already supports HMAC signing for proxy connections:

```typescript
// In your mobile app configuration
{
  "connectionMethod": "proxy",
  "hmacEnabled": true,
  "hmacSecret": "your-hmac-secret"
}
```

## Testing the Setup

### 1. Test Local Development
```bash
# Start Caddy
./setup-caddy.sh

# Test connection
curl -k -H "X-API-Key: your-api-key" https://localhost:3000/session
```

### 2. Test Cloudflare Tunnel
```bash
# Start tunnel
cloudflared tunnel run opencode-nexus

# Test connection
curl -H "X-API-Key: your-api-key" https://opencode.fergify.work/session
```

### 3. Test Production Setup
```bash
# Test through Cloudflare proxy
curl -H "X-API-Key: your-api-key" https://opencode.fergify.work/session
```

## Troubleshooting

### Common Issues

1. **SSL Certificate Errors**:
   - For local dev: Use `-k` flag with curl or disable SSL verification in app
   - For production: Ensure Cloudflare SSL is set to "Full (strict)"

2. **CORS Errors**:
   - Check that CORS headers are properly configured
   - Ensure preflight OPTIONS requests are handled

3. **API Key Issues**:
   - Verify API key is being sent in `X-API-Key` header
   - Check that server is configured to read the header

4. **Connection Timeouts**:
   - Increase timeout values in Cloudflare settings
   - Check that your server is responding quickly enough

### Debug Commands

```bash
# Check DNS resolution
nslookup opencode.fergify.work

# Test SSL certificate
openssl s_client -connect opencode.fergify.work:443

# Check headers
curl -I https://opencode.fergify.work

# Test with API key
curl -v -H "X-API-Key: your-key" https://opencode.fergify.work/session
```

## Security Recommendations

1. **Use API Shield** for production API protection
2. **Enable HSTS** to enforce HTTPS
3. **Rate Limiting** to prevent abuse
4. **Web Application Firewall** rules for additional protection
5. **Regular API key rotation** (every 90 days)
6. **Monitor logs** for unusual activity

## Next Steps

1. Choose your proxy setup (Option 1, 2, or 3)
2. Configure Cloudflare settings
3. Update mobile app configuration
4. Test connection flow
5. Deploy to production