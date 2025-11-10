# Authentication Setup Guide
**Project:** OpenCode Nexus - Mobile Client
**Version:** 1.0.0
**Last Updated:** 2025-11-10
**Status:** Production Ready

## Overview

OpenCode Nexus supports multiple authentication methods for securing connections to OpenCode servers. Since OpenCode servers don't include built-in client authentication, you must configure an external authentication layer.

**Supported Authentication Methods:**
1. **No Authentication** - Local development only (unsecured)
2. **Cloudflare Access Service Tokens** - For Cloudflare Tunnel deployments
3. **API Key Authentication** - For reverse proxy setups
4. **Custom Header Authentication** - For enterprise SSO and custom systems

## Architecture

```
OpenCode Nexus Client
        ↓
[Authentication Layer]  ← You configure this
        ↓
OpenCode Server (opencode serve)
```

The authentication layer intercepts requests and validates credentials before forwarding to your OpenCode server.

---

## Method 1: No Authentication (Development Only)

### Use Case
- Local development and testing
- Trusted private networks
- Quick prototyping

### ⚠️ Security Warning
**DO NOT use in production or expose to the internet.** Anyone who can reach your server can access it.

### Setup

1. **Start OpenCode Server**
   ```bash
   opencode serve --port 4096
   ```

2. **Connect from OpenCode Nexus**
   - Host: `localhost` or `127.0.0.1`
   - Port: `4096`
   - Secure: `false` (HTTP only)
   - Authentication: `None`

### When to Use
- ✅ Local development on your machine
- ✅ Testing new features quickly
- ❌ Production deployments
- ❌ Remote access over internet
- ❌ Multi-user environments

---

## Method 2: Cloudflare Access Service Tokens

### Use Case
- Exposing OpenCode servers over the internet securely
- Device-based authentication without user passwords
- Zero Trust Network Access (ZTNA) architecture
- Automatic DDoS protection and rate limiting

### Architecture
```
OpenCode Nexus Client
    ↓ (with CF-Access-Client-Id header)
Cloudflare Tunnel
    ↓ (validates service token)
Cloudflare Access Policy
    ↓ (allows/denies)
OpenCode Server (localhost:4096)
```

### Prerequisites
- Cloudflare account (free tier works)
- Domain name managed by Cloudflare
- `cloudflared` CLI installed

### Setup Steps

#### 1. Install Cloudflare Tunnel

**macOS:**
```bash
brew install cloudflare/cloudflare/cloudflared
```

**Linux:**
```bash
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

**Windows:**
Download from: https://github.com/cloudflare/cloudflared/releases

#### 2. Authenticate with Cloudflare
```bash
cloudflared tunnel login
```
This opens a browser to authorize `cloudflared` with your Cloudflare account.

#### 3. Create Tunnel
```bash
cloudflared tunnel create opencode-tunnel
```
Save the Tunnel ID shown in output (e.g., `abc123...`).

#### 4. Configure Tunnel
Create `~/.cloudflared/config.yml`:
```yaml
tunnel: abc123-your-tunnel-id
credentials-file: /home/user/.cloudflared/abc123-your-tunnel-id.json

ingress:
  - hostname: opencode.yourdomain.com
    service: http://localhost:4096
  - service: http_status:404
```

#### 5. Create DNS Record
```bash
cloudflared tunnel route dns opencode-tunnel opencode.yourdomain.com
```

#### 6. Configure Cloudflare Access Policy

**Via Cloudflare Dashboard:**
1. Go to **Zero Trust** → **Access** → **Applications**
2. Click **Add an application** → **Self-hosted**
3. Configure:
   - **Application name:** OpenCode Server
   - **Session duration:** 24 hours
   - **Application domain:** `opencode.yourdomain.com`
4. **Add a policy:**
   - **Policy name:** OpenCode Nexus Clients
   - **Action:** Service Auth
   - **Include:** Service Token

#### 7. Generate Service Token

**Via Cloudflare Dashboard:**
1. Go to **Zero Trust** → **Access** → **Service Auth**
2. Click **Create Service Token**
3. **Name:** `opencode-nexus-client`
4. **Duration:** Choose based on your needs (e.g., 1 year)
5. Copy the **Client ID** and **Client Secret** immediately (can't view secret again)

**Example values:**
- Client ID: `abc123def456...`
- Client Secret: `xyz789uvw012...`

#### 8. Start Tunnel
```bash
cloudflared tunnel run opencode-tunnel
```

Or run as service:
```bash
cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

#### 9. Start OpenCode Server
```bash
opencode serve --port 4096
```

#### 10. Connect from OpenCode Nexus

**Connection Settings:**
- **Host:** `opencode.yourdomain.com`
- **Port:** `443` (HTTPS)
- **Secure:** `true`
- **Authentication:** `Cloudflare Access`
- **Client ID:** `abc123def456...` (from step 7)
- **Client Secret:** `xyz789uvw012...` (from step 7)

### Security Benefits
✅ Device-based authentication (no user passwords)
✅ Automatic DDoS protection
✅ Rate limiting and bot protection
✅ Zero Trust Network Access
✅ Audit logging in Cloudflare dashboard
✅ Free tier available

### Troubleshooting

**401/403 Errors:**
- Verify Client ID and Client Secret are correct
- Check Access policy allows Service Auth
- Ensure tunnel is running (`cloudflared tunnel list`)

**Connection Timeout:**
- Verify DNS record points to tunnel
- Check tunnel is routing to correct local port
- Confirm OpenCode server is running on localhost:4096

**View Logs:**
```bash
cloudflared tunnel info opencode-tunnel
journalctl -u cloudflared -f
```

### Additional Resources
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Service Tokens Guide](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/)
- [Access Policies Guide](https://developers.cloudflare.com/cloudflare-one/policies/access/)

---

## Method 3: API Key Authentication

### Use Case
- Custom reverse proxy deployments (nginx, Caddy, Traefik)
- Simple authentication without complex infrastructure
- Self-hosted environments with full control
- API gateway integrations

### Architecture
```
OpenCode Nexus Client
    ↓ (with X-API-Key header)
Reverse Proxy (nginx/Caddy)
    ↓ (validates API key)
OpenCode Server (localhost:4096)
```

### Setup with nginx

#### 1. Install nginx
```bash
# Ubuntu/Debian
sudo apt install nginx

# macOS
brew install nginx

# RHEL/CentOS
sudo yum install nginx
```

#### 2. Generate API Key
```bash
# Generate secure random API key
openssl rand -hex 32
# Example output: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...
```

Save this key securely - you'll configure it in nginx and OpenCode Nexus.

#### 3. Configure nginx

Create `/etc/nginx/sites-available/opencode`:
```nginx
# Map to validate API key
map $http_x_api_key $api_key_valid {
    default 0;
    "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6..." 1;  # Your API key from step 2
}

server {
    listen 443 ssl http2;
    server_name opencode.yourdomain.com;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/opencode.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/opencode.yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # API key validation
    if ($api_key_valid = 0) {
        return 401 "Unauthorized: Invalid API Key";
    }

    # Proxy to OpenCode server
    location / {
        proxy_pass http://127.0.0.1:4096;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # SSE/WebSocket support
        proxy_set_header Connection '';
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;

        # Timeouts for long-running requests
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Logging
    access_log /var/log/nginx/opencode_access.log;
    error_log /var/log/nginx/opencode_error.log;
}
```

#### 4. Enable SSL with Let's Encrypt
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d opencode.yourdomain.com
```

#### 5. Enable and Restart nginx
```bash
sudo ln -s /etc/nginx/sites-available/opencode /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

#### 6. Start OpenCode Server
```bash
opencode serve --port 4096
```

#### 7. Connect from OpenCode Nexus

**Connection Settings:**
- **Host:** `opencode.yourdomain.com`
- **Port:** `443` (HTTPS)
- **Secure:** `true`
- **Authentication:** `API Key`
- **API Key:** `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...` (from step 2)

### Setup with Caddy

#### 1. Install Caddy
```bash
# Ubuntu/Debian
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# macOS
brew install caddy
```

#### 2. Generate API Key
```bash
openssl rand -hex 32
```

#### 3. Configure Caddy

Create `/etc/caddy/Caddyfile`:
```caddy
opencode.yourdomain.com {
    # Automatic HTTPS with Let's Encrypt

    # API key validation
    @unauthorized {
        not header X-API-Key "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6..."
    }

    respond @unauthorized "Unauthorized: Invalid API Key" 401

    # Proxy to OpenCode server
    reverse_proxy localhost:4096 {
        # Preserve headers
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}

        # SSE/streaming support
        flush_interval -1
    }

    # Logging
    log {
        output file /var/log/caddy/opencode.log
    }
}
```

#### 4. Start Caddy
```bash
sudo systemctl enable caddy
sudo systemctl start caddy
```

Caddy automatically obtains SSL certificates from Let's Encrypt!

### Security Best Practices

**API Key Management:**
- ✅ Use cryptographically secure random keys (min 32 bytes)
- ✅ Store keys in secure key management systems
- ✅ Rotate keys regularly (every 90 days recommended)
- ✅ Use different keys for each client/environment
- ✅ Monitor access logs for unauthorized attempts
- ❌ Never commit API keys to version control
- ❌ Don't share keys between environments

**Key Rotation:**
```nginx
# Support multiple keys during rotation
map $http_x_api_key $api_key_valid {
    default 0;
    "new-key-123..."  1;  # New key
    "old-key-456..."  1;  # Old key (remove after migration)
}
```

### Troubleshooting

**401 Unauthorized:**
- Verify API key matches exactly (no spaces, correct capitalization)
- Check nginx/Caddy config for typos in key
- Confirm X-API-Key header is being sent
- Check nginx error logs: `sudo tail -f /var/log/nginx/opencode_error.log`

**Connection Issues:**
- Verify DNS points to proxy server IP
- Check SSL certificate is valid
- Ensure OpenCode server is running on localhost:4096
- Test proxy directly: `curl -H "X-API-Key: your-key" https://opencode.yourdomain.com/session`

---

## Method 4: Custom Header Authentication

### Use Case
- Enterprise SSO integration
- OAuth2 bearer token authentication
- Custom authentication systems
- API gateway integrations

### Setup

The custom header method allows you to specify any HTTP header name and value for authentication. This is useful when integrating with existing enterprise authentication systems.

#### Common Use Cases

**1. OAuth2 Bearer Tokens**
```
Header Name: Authorization
Header Value: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**2. Custom API Headers**
```
Header Name: X-Custom-Auth-Token
Header Value: your-custom-token-here
```

**3. JWT Tokens**
```
Header Name: X-JWT-Token
Header Value: your-jwt-token
```

#### Configuration

You'll configure your authentication gateway (Kong, AWS API Gateway, etc.) to validate the custom header, then forward valid requests to your OpenCode server.

**Example with nginx:**
```nginx
map $http_x_custom_auth_token $auth_valid {
    default 0;
    "your-custom-token" 1;
}

server {
    listen 443 ssl;
    server_name opencode.yourdomain.com;

    if ($auth_valid = 0) {
        return 401;
    }

    location / {
        proxy_pass http://localhost:4096;
    }
}
```

**Connect from OpenCode Nexus:**
- **Authentication:** `Custom Header`
- **Header Name:** `X-Custom-Auth-Token`
- **Header Value:** `your-custom-token`

---

## Security Recommendations

### General Best Practices

1. **Always Use HTTPS in Production**
   - Obtain SSL certificates from Let's Encrypt (free)
   - Enable HTTPS for all server connections
   - Use TLS 1.2 or higher

2. **Credential Storage**
   - OpenCode Nexus encrypts credentials at rest
   - iOS: Stored in Keychain with biometric protection
   - Android: Stored in KeyStore with encryption
   - Never store credentials in plaintext

3. **Network Security**
   - Use firewall to restrict access to OpenCode server port
   - Only allow connections from reverse proxy/tunnel
   - Monitor access logs for suspicious activity

4. **Authentication Method Selection**

| Method | Security | Complexity | Cost | Best For |
|--------|----------|------------|------|----------|
| None | ❌ Unsecured | ✅ Simple | Free | Development only |
| Cloudflare Access | ✅✅✅ High | ✅✅ Medium | Free tier available | Internet exposure |
| API Key | ✅✅ Medium | ✅✅ Medium | Free (self-hosted) | Self-hosted production |
| Custom Header | ✅✅✅ High | ✅✅✅ Complex | Varies | Enterprise SSO |

### Compliance Considerations

**GDPR/Privacy:**
- OpenCode Nexus stores minimal user data
- Conversations cached locally only
- No data sent to third parties
- Users can delete all local data

**Security Certifications:**
- SOC 2 (Cloudflare Access provides this)
- ISO 27001 (available with enterprise proxies)

---

## Testing Your Setup

### 1. Test Server Connectivity
```bash
# Replace with your setup
curl https://opencode.yourdomain.com/session
```

**Expected Response:**
- 401 Unauthorized (authentication required)
- 403 Forbidden (authentication failed)

### 2. Test with Authentication

**Cloudflare Access:**
```bash
curl -H "CF-Access-Client-Id: your-id" \
     -H "CF-Access-Client-Secret: your-secret" \
     https://opencode.yourdomain.com/session
```

**API Key:**
```bash
curl -H "X-API-Key: your-api-key" \
     https://opencode.yourdomain.com/session
```

**Expected Response:**
- 200 OK with session data

### 3. Test from OpenCode Nexus

1. Open OpenCode Nexus
2. Tap **Connect to Server**
3. Enter connection details
4. Select authentication method
5. Enter credentials
6. Tap **Test Connection**
7. Should see: ✅ "Connected successfully"

### Common Test Errors

**Connection Timeout:**
- DNS not resolving
- Server not running
- Firewall blocking connection

**401 Unauthorized:**
- Credentials incorrect
- Authentication not configured
- Wrong authentication method selected

**403 Forbidden:**
- Credentials correct but access denied
- Access policy blocking connection
- IP allowlist blocking connection

---

## Migration Guide

### From No Auth → Cloudflare Access

1. Set up Cloudflare Tunnel following Method 2
2. Generate service token
3. Update connection in OpenCode Nexus:
   - Change authentication from "None" to "Cloudflare Access"
   - Enter Client ID and Secret
4. Test connection
5. Delete old unsecured connection

### From No Auth → API Key

1. Set up nginx/Caddy following Method 3
2. Generate API key
3. Update connection in OpenCode Nexus:
   - Change host to your domain
   - Change port to 443
   - Enable secure (HTTPS)
   - Change authentication to "API Key"
   - Enter API key
4. Test connection
5. Stop exposing OpenCode server directly

### Rotating Credentials

**Cloudflare Service Tokens:**
1. Generate new service token in Cloudflare dashboard
2. Update OpenCode Nexus with new credentials
3. Test connection
4. Revoke old service token

**API Keys:**
1. Generate new API key
2. Add to nginx/Caddy config alongside old key
3. Update OpenCode Nexus with new key
4. Test connection
5. Remove old key from nginx/Caddy after 24 hours

---

## Support and Resources

### Documentation
- [OpenCode Nexus Security Guide](./SECURITY.md)
- [OpenCode Nexus Architecture](./ARCHITECTURE.md)
- [OpenCode Server Documentation](https://github.com/opencode/docs)

### External Resources
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [nginx Documentation](https://nginx.org/en/docs/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Let's Encrypt](https://letsencrypt.org/)

### Need Help?
- GitHub Issues: [opencode-nexus/issues](https://github.com/ferg-cod3s/opencode-nexus/issues)
- Security Issues: Use GitHub Security Advisories

---

**Last Updated:** 2025-11-10
**Authentication Implementation:** v1.0.0
**Tested With:** OpenCode Server 1.x, Cloudflare Tunnel 2024.x, nginx 1.24+, Caddy 2.7+
