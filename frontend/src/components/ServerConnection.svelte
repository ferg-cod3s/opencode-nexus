<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  export let loading = false;
  export let error: string | null = null;

  type AuthType = 'none' | 'cloudflare' | 'apikey' | 'custom';

  interface AuthCredentials {
    type: AuthType;
    cloudflareClientId?: string;
    cloudflareClientSecret?: string;
    apiKey?: string;
    customHeaderName?: string;
    customHeaderValue?: string;
  }

  const dispatch = createEventDispatcher<{
    connect: {
      hostname: string;
      port: number;
      https: boolean;
      authType: AuthType;
      authCredentials: AuthCredentials;
    };
  }>();

  // Form state
  let hostname = '';
  let port = 3000;
  let https = true;
  let authType: AuthType = 'none';

  // Authentication credentials
  let cloudflareClientId = '';
  let cloudflareClientSecret = '';
  let apiKey = '';
  let customHeaderName = '';
  let customHeaderValue = '';

  // Validation state
  let hostnameError: string | null = null;
  let portError: string | null = null;
  let authError: string | null = null;

  // Connection history (NOTE: Never store credentials in history for security!)
  let connectionHistory: Array<{
    hostname: string;
    port: number;
    https: boolean;
    authType: AuthType;
    lastUsed: string;
  }> = [];
  let showHistory = false;

  // Load connection history from localStorage on mount
  $: if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('opencode-connection-history');
    if (stored) {
      try {
        connectionHistory = JSON.parse(stored);
      } catch (e) {
        console.warn('Failed to parse connection history:', e);
        connectionHistory = [];
      }
    }
  }

  // Save connection history to localStorage
  function saveConnectionHistory() {
    if (typeof window !== 'undefined') {
      localStorage.setItem('opencode-connection-history', JSON.stringify(connectionHistory));
    }
  }

  // Validate hostname
  function validateHostname(value: string): string | null {
    if (!value.trim()) {
      return 'Hostname or IP address is required';
    }

    // Basic hostname/IP validation
    const hostnameRegex = /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/;
    const ipRegex = /^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$/;

    if (!hostnameRegex.test(value) && !ipRegex.test(value)) {
      return 'Please enter a valid hostname or IP address';
    }

    return null;
  }

  // Validate port
  function validatePort(value: number): string | null {
    if (isNaN(value) || value < 1 || value > 65535) {
      return 'Port must be between 1 and 65535';
    }
    return null;
  }

  // Validate authentication credentials
  function validateAuth(): string | null {
    if (authType === 'cloudflare') {
      if (!cloudflareClientId.trim() || !cloudflareClientSecret.trim()) {
        return 'Both Client ID and Client Secret are required for Cloudflare Access';
      }
    } else if (authType === 'apikey') {
      if (!apiKey.trim()) {
        return 'API Key is required';
      }
    } else if (authType === 'custom') {
      if (!customHeaderName.trim() || !customHeaderValue.trim()) {
        return 'Both header name and value are required for custom authentication';
      }
    }
    return null;
  }

  // Handle hostname input
  function handleHostnameInput(event: Event) {
    const target = event.target as HTMLInputElement;
    hostname = target.value;
    hostnameError = validateHostname(hostname);
  }

  // Handle port input
  function handlePortInput(event: Event) {
    const target = event.target as HTMLInputElement;
    const value = parseInt(target.value, 10);
    port = isNaN(value) ? 3000 : value;
    portError = validatePort(port);
  }

  // Handle HTTPS toggle
  function handleHttpsToggle() {
    https = !https;
  }

  // Select from history
  function selectFromHistory(item: typeof connectionHistory[0]) {
    hostname = item.hostname;
    port = item.port;
    https = item.https;
    authType = item.authType;
    hostnameError = null;
    portError = null;
    authError = null;
    showHistory = false;

    // Clear credentials for security (user must re-enter)
    cloudflareClientId = '';
    cloudflareClientSecret = '';
    apiKey = '';
    customHeaderName = '';
    customHeaderValue = '';

    // Update last used timestamp
    item.lastUsed = new Date().toISOString();
    saveConnectionHistory();
  }

  // Remove from history
  function removeFromHistory(index: number) {
    connectionHistory.splice(index, 1);
    connectionHistory = connectionHistory; // Trigger reactivity
    saveConnectionHistory();
  }

  // Handle form submission
  function handleConnect() {
    // Validate all fields
    hostnameError = validateHostname(hostname);
    portError = validatePort(port);
    authError = validateAuth();

    if (hostnameError || portError || authError) {
      return;
    }

    // Build auth credentials object
    const authCredentials: AuthCredentials = {
      type: authType,
    };

    if (authType === 'cloudflare') {
      authCredentials.cloudflareClientId = cloudflareClientId;
      authCredentials.cloudflareClientSecret = cloudflareClientSecret;
    } else if (authType === 'apikey') {
      authCredentials.apiKey = apiKey;
    } else if (authType === 'custom') {
      authCredentials.customHeaderName = customHeaderName;
      authCredentials.customHeaderValue = customHeaderValue;
    }

    // Add to connection history (without credentials!)
    const existingIndex = connectionHistory.findIndex(
      item =>
        item.hostname === hostname &&
        item.port === port &&
        item.https === https &&
        item.authType === authType
    );

    if (existingIndex >= 0) {
      // Update existing entry
      connectionHistory[existingIndex].lastUsed = new Date().toISOString();
    } else {
      // Add new entry (NOTE: Never save credentials to history!)
      connectionHistory.unshift({
        hostname,
        port,
        https,
        authType,
        lastUsed: new Date().toISOString(),
      });

      // Keep only last 10 entries
      if (connectionHistory.length > 10) {
        connectionHistory = connectionHistory.slice(0, 10);
      }
    }

    saveConnectionHistory();

    // Dispatch connect event with authentication
    dispatch('connect', { hostname, port, https, authType, authCredentials });
  }

  // Handle keyboard navigation
  function handleKeydown(event: KeyboardEvent) {
    if (
      event.key === 'Enter' &&
      !loading &&
      !hostnameError &&
      !portError &&
      !authError &&
      hostname.trim()
    ) {
      handleConnect();
    }
  }

  // Clear error when user starts typing
  $: if (hostname && hostnameError) {
    hostnameError = null;
  }

  $: if (port && portError) {
    portError = null;
  }

  // Clear auth error when auth type or credentials change
  $: if (authType || cloudflareClientId || cloudflareClientSecret || apiKey || customHeaderName || customHeaderValue) {
    authError = null;
  }

  // Get auth type display name
  function getAuthTypeName(type: AuthType): string {
    const names = {
      none: 'None',
      cloudflare: 'Cloudflare Access',
      apikey: 'API Key',
      custom: 'Custom Header'
    };
    return names[type];
  }
</script>

<div class="server-connection" data-testid="server-connection">
  <div class="connection-header">
    <h2 class="connection-title">Connect to OpenCode Server</h2>
    <p class="connection-subtitle">Enter your server details to establish a connection</p>
  </div>

  <form class="connection-form" on:keydown={handleKeydown}>
    <!-- Hostname/IP Input -->
    <div class="form-group">
      <label for="hostname-input" class="form-label">
        Server Address
        <span class="required" aria-label="required">*</span>
      </label>
      <input
        id="hostname-input"
        type="text"
        class="form-input"
        class:error={hostnameError}
        placeholder="example.com or 192.168.1.100"
        value={hostname}
        on:input={handleHostnameInput}
        disabled={loading}
        aria-describedby={hostnameError ? "hostname-error" : "hostname-help"}
        aria-invalid={hostnameError ? "true" : "false"}
        autocomplete="off"
        spellcheck="false"
      />
      {#if hostnameError}
        <div id="hostname-error" class="error-message" role="alert" aria-live="polite">
          {hostnameError}
        </div>
      {:else}
        <div id="hostname-help" class="help-text">
          Enter hostname (e.g., myserver.com) or IP address
        </div>
      {/if}
    </div>

    <!-- Port Input -->
    <div class="form-group">
      <label for="port-input" class="form-label">
        Port
        <span class="required" aria-label="required">*</span>
      </label>
      <input
        id="port-input"
        type="number"
        class="form-input"
        class:error={portError}
        placeholder="3000"
        min="1"
        max="65535"
        value={port}
        on:input={handlePortInput}
        disabled={loading}
        aria-describedby={portError ? "port-error" : "port-help"}
        aria-invalid={portError ? "true" : "false"}
      />
      {#if portError}
        <div id="port-error" class="error-message" role="alert" aria-live="polite">
          {portError}
        </div>
      {:else}
        <div id="port-help" class="help-text">
          Default OpenCode port is 3000
        </div>
      {/if}
    </div>

    <!-- HTTPS Toggle -->
    <div class="form-group">
      <label class="checkbox-label">
        <input
          type="checkbox"
          class="checkbox-input"
          bind:checked={https}
          on:change={handleHttpsToggle}
          disabled={loading}
          aria-describedby="https-help"
        />
        <span class="checkbox-mark" aria-hidden="true"></span>
        <span class="checkbox-text">Use HTTPS (secure connection)</span>
      </label>
      <div id="https-help" class="help-text">
        Recommended for production servers
      </div>
    </div>

    <!-- Authentication Method -->
    <div class="form-group">
      <label for="auth-type-select" class="form-label">
        Authentication Method
      </label>
      <select
        id="auth-type-select"
        class="form-select"
        bind:value={authType}
        disabled={loading}
        aria-describedby="auth-help"
      >
        <option value="none">None (Development Only)</option>
        <option value="cloudflare">Cloudflare Access Service Token</option>
        <option value="apikey">API Key</option>
        <option value="custom">Custom Header</option>
      </select>
      <div id="auth-help" class="help-text">
        {#if authType === 'none'}
          ⚠️ Unsecured - Only for local development
        {:else if authType === 'cloudflare'}
          For Cloudflare Tunnel deployments with Access policies
        {:else if authType === 'apikey'}
          For reverse proxy setups (nginx, Caddy, Traefik)
        {:else if authType === 'custom'}
          For enterprise SSO and custom authentication systems
        {/if}
        <a href="https://github.com/ferg-cod3s/opencode-nexus/blob/main/docs/client/AUTH_SETUP.md" target="_blank" rel="noopener noreferrer" class="auth-docs-link">
          Setup Guide →
        </a>
      </div>
    </div>

    <!-- Cloudflare Access Credentials -->
    {#if authType === 'cloudflare'}
      <div class="form-group auth-credentials">
        <label for="cf-client-id" class="form-label">
          Client ID
          <span class="required" aria-label="required">*</span>
        </label>
        <input
          id="cf-client-id"
          type="text"
          class="form-input"
          placeholder="abc123def456..."
          bind:value={cloudflareClientId}
          disabled={loading}
          autocomplete="off"
          spellcheck="false"
        />
        <div class="help-text">
          From Cloudflare Zero Trust → Access → Service Auth
        </div>
      </div>

      <div class="form-group auth-credentials">
        <label for="cf-client-secret" class="form-label">
          Client Secret
          <span class="required" aria-label="required">*</span>
        </label>
        <input
          id="cf-client-secret"
          type="password"
          class="form-input"
          placeholder="xyz789uvw012..."
          bind:value={cloudflareClientSecret}
          disabled={loading}
          autocomplete="off"
          spellcheck="false"
        />
        <div class="help-text">
          🔒 Stored securely - never saved in connection history
        </div>
      </div>
    {/if}

    <!-- API Key Credentials -->
    {#if authType === 'apikey'}
      <div class="form-group auth-credentials">
        <label for="api-key" class="form-label">
          API Key
          <span class="required" aria-label="required">*</span>
        </label>
        <input
          id="api-key"
          type="password"
          class="form-input"
          placeholder="Enter your API key"
          bind:value={apiKey}
          disabled={loading}
          autocomplete="off"
          spellcheck="false"
        />
        <div class="help-text">
          🔒 Stored securely - configured in your reverse proxy
        </div>
      </div>
    {/if}

    <!-- Custom Header Credentials -->
    {#if authType === 'custom'}
      <div class="form-group auth-credentials">
        <label for="custom-header-name" class="form-label">
          Header Name
          <span class="required" aria-label="required">*</span>
        </label>
        <input
          id="custom-header-name"
          type="text"
          class="form-input"
          placeholder="X-Custom-Auth-Token"
          bind:value={customHeaderName}
          disabled={loading}
          autocomplete="off"
          spellcheck="false"
        />
        <div class="help-text">
          E.g., "Authorization", "X-API-Key", "X-Custom-Auth"
        </div>
      </div>

      <div class="form-group auth-credentials">
        <label for="custom-header-value" class="form-label">
          Header Value
          <span class="required" aria-label="required">*</span>
        </label>
        <input
          id="custom-header-value"
          type="password"
          class="form-input"
          placeholder="Bearer token or custom value"
          bind:value={customHeaderValue}
          disabled={loading}
          autocomplete="off"
          spellcheck="false"
        />
        <div class="help-text">
          🔒 Stored securely - never saved in connection history
        </div>
      </div>
    {/if}

    <!-- Authentication Error -->
    {#if authError}
      <div class="auth-error" role="alert" aria-live="polite">
        <span class="error-icon" aria-hidden="true">⚠️</span>
        <span class="error-text">{authError}</span>
      </div>
    {/if}

    <!-- Connection History -->
    {#if connectionHistory.length > 0}
      <div class="form-group">
        <button
          type="button"
          class="history-toggle"
          on:click={() => showHistory = !showHistory}
          aria-expanded={showHistory}
          aria-controls="connection-history"
          disabled={loading}
        >
          <span class="history-icon" aria-hidden="true">📋</span>
          {showHistory ? 'Hide' : 'Show'} Recent Connections ({connectionHistory.length})
        </button>

        {#if showHistory}
          <div id="connection-history" class="history-list" role="listbox">
            {#each connectionHistory as item, index (item.hostname + item.port + item.https)}
              <div class="history-item" role="option">
                <button
                  type="button"
                  class="history-select"
                  on:click={() => selectFromHistory(item)}
                  disabled={loading}
                  aria-label="Select {item.hostname}:{item.port} ({item.https ? 'HTTPS' : 'HTTP'}) with {getAuthTypeName(item.authType)}"
                >
                  <div class="history-info">
                    <span class="history-address">
                      {item.https ? '🔒' : '🌐'} {item.hostname}:{item.port}
                    </span>
                    <span class="history-auth">
                      {#if item.authType !== 'none'}
                        🔐 {getAuthTypeName(item.authType)}
                      {:else}
                        ⚠️ No Auth
                      {/if}
                    </span>
                  </div>
                  <span class="history-date">
                    {new Date(item.lastUsed).toLocaleDateString()}
                  </span>
                </button>
                <button
                  type="button"
                  class="history-remove"
                  on:click={() => removeFromHistory(index)}
                  disabled={loading}
                  aria-label="Remove {item.hostname}:{item.port} from history"
                >
                  <span aria-hidden="true">×</span>
                </button>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    <!-- Error Display -->
    {#if error}
      <div class="global-error" role="alert" aria-live="assertive">
        <span class="error-icon" aria-hidden="true">⚠️</span>
        <span class="error-text">{error}</span>
      </div>
    {/if}

    <!-- Connect Button -->
    <button
      type="button"
      class="connect-btn"
      disabled={loading || !hostname.trim() || !!hostnameError || !!portError}
      on:click={handleConnect}
      aria-describedby="connect-help"
    >
      {#if loading}
        <div class="loading-spinner" aria-hidden="true"></div>
        <span>Connecting...</span>
      {:else}
        <span>Connect to Server</span>
      {/if}
    </button>

    <div id="connect-help" class="sr-only">
      Press Enter or click to connect to the OpenCode server
    </div>
  </form>
</div>

<style>
  .server-connection {
    max-width: 480px;
    margin: 0 auto;
    padding: 2rem;
    background: hsl(0, 0%, 100%);
    border-radius: 16px;
    box-shadow: 0 8px 32px hsla(220, 20%, 20%, 0.12);
  }

  .connection-header {
    text-align: center;
    margin-bottom: 2rem;
  }

  .connection-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: hsl(220, 20%, 20%);
    margin: 0 0 0.5rem 0;
  }

  .connection-subtitle {
    font-size: 0.875rem;
    color: hsl(220, 10%, 60%);
    margin: 0;
  }

  .connection-form {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .form-label {
    font-size: 0.875rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .required {
    color: hsl(0, 80%, 50%);
    font-weight: 700;
  }

  .form-input {
    padding: 0.875rem 1rem;
    border: 2px solid hsl(220, 20%, 90%);
    border-radius: 12px;
    font-size: 1rem;
    font-family: inherit;
    background: hsl(0, 0%, 100%);
    transition: all 0.2s ease;
    outline: none;
  }

  .form-input:focus {
    border-color: hsl(220, 90%, 60%);
    box-shadow: 0 0 0 3px hsla(220, 90%, 60%, 0.1);
  }

  .form-input.error {
    border-color: hsl(0, 80%, 50%);
    box-shadow: 0 0 0 3px hsla(0, 80%, 50%, 0.1);
  }

  .form-input:disabled {
    background: hsl(220, 20%, 96%);
    cursor: not-allowed;
    opacity: 0.7;
  }

  .form-select {
    padding: 0.875rem 1rem;
    border: 2px solid hsl(220, 20%, 90%);
    border-radius: 12px;
    font-size: 1rem;
    font-family: inherit;
    background: hsl(0, 0%, 100%);
    transition: all 0.2s ease;
    outline: none;
    cursor: pointer;
  }

  .form-select:focus {
    border-color: hsl(220, 90%, 60%);
    box-shadow: 0 0 0 3px hsla(220, 90%, 60%, 0.1);
  }

  .form-select:disabled {
    background: hsl(220, 20%, 96%);
    cursor: not-allowed;
    opacity: 0.7;
  }

  .auth-credentials {
    padding-left: 1rem;
    border-left: 3px solid hsl(220, 90%, 60%);
    margin-top: 1rem;
  }

  .auth-error {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 1rem;
    background: hsl(40, 100%, 96%);
    border: 1px solid hsl(40, 100%, 80%);
    border-radius: 8px;
    color: hsl(40, 80%, 30%);
  }

  .auth-docs-link {
    color: hsl(220, 90%, 60%);
    text-decoration: none;
    font-weight: 600;
    margin-left: 0.5rem;
    white-space: nowrap;
  }

  .auth-docs-link:hover {
    text-decoration: underline;
  }

  .auth-docs-link:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
    border-radius: 4px;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    cursor: pointer;
    font-size: 0.875rem;
    color: hsl(220, 20%, 20%);
    padding: 0.5rem;
    border-radius: 8px;
    transition: background-color 0.2s ease;
  }

  .checkbox-label:hover {
    background: hsl(220, 20%, 96%);
  }

  .checkbox-input {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
  }

  .checkbox-mark {
    width: 20px;
    height: 20px;
    border: 2px solid hsl(220, 20%, 90%);
    border-radius: 4px;
    background: hsl(0, 0%, 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  .checkbox-input:checked + .checkbox-mark {
    background: hsl(220, 90%, 60%);
    border-color: hsl(220, 90%, 60%);
  }

  .checkbox-input:checked + .checkbox-mark::after {
    content: '✓';
    color: white;
    font-size: 12px;
    font-weight: bold;
  }

  .checkbox-input:focus + .checkbox-mark {
    box-shadow: 0 0 0 3px hsla(220, 90%, 60%, 0.2);
  }

  .checkbox-text {
    flex: 1;
  }

  .help-text {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
    margin-top: 0.25rem;
  }

  .error-message {
    font-size: 0.75rem;
    color: hsl(0, 80%, 50%);
    margin-top: 0.25rem;
    font-weight: 500;
  }

  .history-toggle {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: hsl(220, 20%, 96%);
    border: 1px solid hsl(220, 20%, 90%);
    border-radius: 8px;
    font-size: 0.875rem;
    color: hsl(220, 20%, 20%);
    cursor: pointer;
    transition: all 0.2s ease;
    width: fit-content;
  }

  .history-toggle:hover:not(:disabled) {
    background: hsl(220, 20%, 92%);
    border-color: hsl(220, 30%, 80%);
  }

  .history-toggle:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .history-toggle:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .history-icon {
    font-size: 1rem;
  }

  .history-list {
    margin-top: 1rem;
    border: 1px solid hsl(220, 20%, 90%);
    border-radius: 8px;
    overflow: hidden;
  }

  .history-item {
    display: flex;
    align-items: center;
    border-bottom: 1px solid hsl(220, 20%, 95%);
  }

  .history-item:last-child {
    border-bottom: none;
  }

  .history-select {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.875rem 1rem;
    background: none;
    border: none;
    text-align: left;
    cursor: pointer;
    transition: background-color 0.2s ease;
    font-family: inherit;
  }

  .history-select:hover:not(:disabled) {
    background: hsl(220, 20%, 96%);
  }

  .history-select:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: -2px;
  }

  .history-select:disabled {
    cursor: not-allowed;
    opacity: 0.6;
  }

  .history-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    flex: 1;
  }

  .history-address {
    font-size: 0.875rem;
    color: hsl(220, 20%, 20%);
    font-weight: 500;
  }

  .history-auth {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
    font-weight: 400;
  }

  .history-date {
    font-size: 0.75rem;
    color: hsl(220, 10%, 60%);
  }

  .history-remove {
    padding: 0.875rem 1rem;
    background: none;
    border: none;
    color: hsl(220, 10%, 60%);
    cursor: pointer;
    font-size: 1.25rem;
    transition: all 0.2s ease;
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .history-remove:hover:not(:disabled) {
    background: hsl(0, 80%, 96%);
    color: hsl(0, 80%, 50%);
  }

  .history-remove:focus {
    outline: 2px solid hsl(0, 80%, 50%);
    outline-offset: -2px;
  }

  .global-error {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 1rem;
    background: hsl(0, 80%, 96%);
    border: 1px solid hsl(0, 80%, 90%);
    border-radius: 8px;
    color: hsl(0, 80%, 40%);
  }

  .error-icon {
    font-size: 1.25rem;
    flex-shrink: 0;
  }

  .error-text {
    font-size: 0.875rem;
    font-weight: 500;
  }

  .connect-btn {
    width: 100%;
    padding: 1rem 2rem;
    background: hsl(220, 90%, 60%);
    border: none;
    border-radius: 12px;
    color: white;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    transition: all 0.2s ease;
    min-height: 56px;
  }

  .connect-btn:hover:not(:disabled) {
    background: hsl(220, 80%, 50%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px hsla(220, 90%, 60%, 0.3);
  }

  .connect-btn:active:not(:disabled) {
    transform: translateY(0);
  }

  .connect-btn:disabled {
    background: hsl(220, 20%, 80%);
    cursor: not-allowed;
    transform: none;
    box-shadow: none;
  }

  .connect-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .loading-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid transparent;
    border-top: 2px solid currentColor;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    .server-connection {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .form-input {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .form-input:focus {
      border-color: hsl(0, 0%, 0%);
      box-shadow: 0 0 0 3px hsla(0, 0%, 0%, 0.3);
    }

    .form-input.error {
      border-color: hsl(0, 0%, 0%);
    }

    .checkbox-mark {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .connect-btn {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .connect-btn:focus {
      outline: 3px solid hsl(0, 0%, 0%);
    }

    .history-toggle {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .global-error {
      border: 2px solid hsl(0, 0%, 0%);
      background: hsl(0, 0%, 100%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .connect-btn {
      transition: none;
    }

    .connect-btn:hover:not(:disabled) {
      transform: none;
    }

    .connect-btn:active:not(:disabled) {
      transform: none;
    }

    .form-input {
      transition: none;
    }

    .checkbox-label {
      transition: none;
    }

    .history-toggle {
      transition: none;
    }

    .history-select {
      transition: none;
    }

    .history-remove {
      transition: none;
    }

    .loading-spinner {
      animation: none;
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .server-connection {
      margin: 0;
      padding: 1.5rem;
      border-radius: 0;
      box-shadow: none;
      min-height: 100vh;
    }

    .connection-header {
      margin-bottom: 1.5rem;
    }

    .connection-title {
      font-size: 1.25rem;
    }

    .connection-form {
      gap: 1.25rem;
    }

    .form-input {
      font-size: 16px; /* Prevent zoom on iOS */
      padding: 1rem;
      min-height: 44px;
    }

    .checkbox-label {
      padding: 0.75rem;
      min-height: 44px;
    }

    .history-toggle {
      padding: 1rem;
      min-height: 44px;
      width: 100%;
    }

    .history-select {
      padding: 1rem;
      min-height: 44px;
    }

    .history-remove {
      width: 44px;
      height: 44px;
      font-size: 1.125rem;
    }

    .connect-btn {
      padding: 1.25rem 2rem;
      font-size: 1.125rem;
      min-height: 56px;
    }

    .global-error {
      padding: 1rem;
    }
  }

  /* Focus management for keyboard navigation */
  .form-input:focus,
  .checkbox-input:focus + .checkbox-mark,
  .history-toggle:focus,
  .history-select:focus,
  .history-remove:focus,
  .connect-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  /* Ensure minimum touch targets */
  .checkbox-label,
  .history-toggle,
  .history-select,
  .history-remove,
  .connect-btn {
    min-height: 44px;
  }
</style></content>
<parameter name="filePath">frontend/src/components/ServerConnection.svelte