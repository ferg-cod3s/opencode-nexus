# OpenCode Nexus - Mobile Connection Summary

## Quick Setup

### Server Information
- **URL**: https://dev-opencode.fergify.work
- **Method**: tunnel
- **SSL**: Verified (Cloudflare)
- **API Key**: a264b0d3...

### Mobile App Configuration

#### Option 1: Scan QR Code
1. Open mobile camera
2. Scan `mobile-config.png`
3. Tap notification to import

#### Option 2: Manual Entry
1. Open OpenCode Nexus app
2. Go to Settings → Connection
3. Enter:
   - Server URL: `https://dev-opencode.fergify.work`
   - Connection Method: `tunnel`
   - API Key: `a264b0d3074f80240a6d7b6babc670646243f277663d43a577c9da1025320c1c`

#### Option 3: Import Config File
1. Transfer `mobile-config.json` to device
2. Open app → Import Configuration
3. Select the config file

### Testing Connection
1. Open app after configuration
2. Should auto-connect to server
3. Check connection status in app

### Troubleshooting
- **Connection failed**: Check tunnel is running
- **SSL errors**: Ensure SSL verification is enabled
- **API key rejected**: Verify key is correct

### Tunnel Management
- Start tunnel: `./setup-cloudflare-tunnel.sh start`
- Stop tunnel: `./setup-cloudflare-tunnel.sh stop`
- Check status: `./setup-cloudflare-tunnel.sh status`

Generated: Sat Nov 29 07:16:34 PM UTC 2025
