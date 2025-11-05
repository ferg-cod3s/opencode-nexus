<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { onMount } from 'svelte';

  // Connection status types (mirroring Rust backend)
  export enum ConnectionStatus {
    Disconnected = 'disconnected',
    Connecting = 'connecting',
    Connected = 'connected',
    Error = 'error'
  }

  export interface ServerInfo {
    name: string;
    hostname: string;
    port: number;
    secure: boolean;
    version?: string;
    status: ConnectionStatus;
    last_connected?: string;
    last_error?: string;
  }

  export interface ConnectionMetrics {
    latency?: number; // in milliseconds
    response_time?: number; // in milliseconds
    quality: 'good' | 'poor' | 'offline';
    last_ping?: number; // timestamp
  }

  export interface ConnectionEvent {
    timestamp: Date;
    event_type: 'connected' | 'disconnected' | 'error' | 'health_check';
    message: string;
  }

  // Component props
  export let serverInfo: ServerInfo | null = null;
  export let metrics: ConnectionMetrics | null = null;
  export let connectionHistory: ConnectionEvent[] = [];
  export let showHistory = false;
  export let compact = false; // Compact mode for smaller displays

  const dispatch = createEventDispatcher<{
    reconnect: { hostname: string; port: number; secure: boolean };
    disconnect: void;
    toggleHistory: void;
  }>();

  // Reactive status computation
  $: status = serverInfo?.status || ConnectionStatus.Disconnected;
  $: isConnected = status === ConnectionStatus.Connected;
  $: isConnecting = status === ConnectionStatus.Connecting;
  $: hasError = status === ConnectionStatus.Error;

  // Status display helpers
  $: statusText = getStatusText(status);
  $: statusColor = getStatusColor(status);
  $: statusIcon = getStatusIcon(status);

  // Quality indicators
  $: qualityText = getQualityText(metrics?.quality || 'offline');
  $: qualityColor = getQualityColor(metrics?.quality || 'offline');

  // Connection URL
  $: connectionUrl = serverInfo ? `${serverInfo.secure ? 'https' : 'http'}://${serverInfo.hostname}:${serverInfo.port}` : null;

  // Latency display
  $: latencyDisplay = metrics?.latency ? `${Math.round(metrics.latency)}ms` : '--';

  function getStatusText(status: ConnectionStatus): string {
    switch (status) {
      case ConnectionStatus.Connected:
        return 'Connected';
      case ConnectionStatus.Connecting:
        return 'Connecting...';
      case ConnectionStatus.Disconnected:
        return 'Disconnected';
      case ConnectionStatus.Error:
        return 'Connection Error';
      default:
        return 'Unknown';
    }
  }

  function getStatusColor(status: ConnectionStatus): string {
    switch (status) {
      case ConnectionStatus.Connected:
        return 'hsl(120, 50%, 50%)'; // Green
      case ConnectionStatus.Connecting:
        return 'hsl(45, 100%, 50%)'; // Yellow/Orange
      case ConnectionStatus.Disconnected:
        return 'hsl(220, 20%, 60%)'; // Gray
      case ConnectionStatus.Error:
        return 'hsl(0, 80%, 50%)'; // Red
      default:
        return 'hsl(220, 20%, 60%)';
    }
  }

  function getStatusIcon(status: ConnectionStatus): string {
    switch (status) {
      case ConnectionStatus.Connected:
        return '🟢';
      case ConnectionStatus.Connecting:
        return '🟡';
      case ConnectionStatus.Disconnected:
        return '⚪';
      case ConnectionStatus.Error:
        return '🔴';
      default:
        return '⚪';
    }
  }

  function getQualityText(quality: 'good' | 'poor' | 'offline'): string {
    switch (quality) {
      case 'good':
        return 'Good';
      case 'poor':
        return 'Poor';
      case 'offline':
        return 'Offline';
      default:
        return 'Unknown';
    }
  }

  function getQualityColor(quality: 'good' | 'poor' | 'offline'): string {
    switch (quality) {
      case 'good':
        return 'hsl(120, 50%, 50%)'; // Green
      case 'poor':
        return 'hsl(45, 100%, 50%)'; // Yellow
      case 'offline':
        return 'hsl(0, 80%, 50%)'; // Red
      default:
        return 'hsl(220, 20%, 60%)';
    }
  }

  function handleReconnect() {
    if (serverInfo) {
      dispatch('reconnect', {
        hostname: serverInfo.hostname,
        port: serverInfo.port,
        secure: serverInfo.secure
      });
    }
  }

  function handleDisconnect() {
    dispatch('disconnect');
  }

  function toggleHistory() {
    showHistory = !showHistory;
    dispatch('toggleHistory');
  }

  function formatTimestamp(timestamp: Date): string {
    return timestamp.toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  }

  function getEventIcon(eventType: string): string {
    switch (eventType) {
      case 'connected':
        return '🔗';
      case 'disconnected':
        return '🔌';
      case 'error':
        return '❌';
      case 'health_check':
        return '💚';
      default:
        return '📝';
    }
  }

  // Announce status changes to screen readers
  $: if (serverInfo?.status) {
    announceStatusChange(serverInfo.status);
  }

  function announceStatusChange(status: ConnectionStatus) {
    const announcement = `Connection status: ${getStatusText(status)}`;
    const liveRegion = document.createElement('div');
    liveRegion.setAttribute('aria-live', 'assertive');
    liveRegion.setAttribute('aria-atomic', 'true');
    liveRegion.style.position = 'absolute';
    liveRegion.style.left = '-10000px';
    liveRegion.style.width = '1px';
    liveRegion.style.height = '1px';
    liveRegion.style.overflow = 'hidden';
    liveRegion.textContent = announcement;
    document.body.appendChild(liveRegion);
    setTimeout(() => document.body.removeChild(liveRegion), 1000);
  }
</script>

<div class="connection-status" class:compact data-testid="connection-status">
  <!-- Status Header -->
  <div class="status-header" role="status" aria-live="polite" aria-label="Connection status">
    <div class="status-indicator">
      <span class="status-dot" style="background-color: {statusColor}" aria-hidden="true"></span>
      <span class="status-icon" aria-hidden="true">{statusIcon}</span>
      <span class="status-text">{statusText}</span>
    </div>

    {#if isConnected && metrics}
      <div class="quality-indicator" aria-label="Connection quality: {qualityText}">
        <span class="quality-dot" style="background-color: {qualityColor}" aria-hidden="true"></span>
        <span class="quality-text" style="color: {qualityColor}">{qualityText}</span>
        <span class="latency-text" aria-label="Latency: {latencyDisplay}">({latencyDisplay})</span>
      </div>
    {/if}
  </div>

  <!-- Server Information -->
  {#if serverInfo}
    <div class="server-info" aria-labelledby="server-info-heading">
      <h3 id="server-info-heading" class="sr-only">Server Information</h3>

      <div class="info-row">
        <span class="info-label">Server:</span>
        <span class="info-value">{serverInfo.name}</span>
      </div>

      <div class="info-row">
        <span class="info-label">Address:</span>
        <span class="info-value">
          {serverInfo.hostname}:{serverInfo.port}
          {#if serverInfo.secure}
            <span class="secure-icon" aria-label="Secure connection" title="HTTPS">🔒</span>
          {/if}
        </span>
      </div>

      {#if serverInfo.version}
        <div class="info-row">
          <span class="info-label">Version:</span>
          <span class="info-value">{serverInfo.version}</span>
        </div>
      {/if}

      {#if serverInfo.last_connected}
        <div class="info-row">
          <span class="info-label">Last Connected:</span>
          <span class="info-value">
            {new Date(serverInfo.last_connected).toLocaleString()}
          </span>
        </div>
      {/if}
    </div>
  {/if}

  <!-- Error Display -->
  {#if hasError && serverInfo?.last_error}
    <div class="error-display" role="alert" aria-live="assertive">
      <span class="error-icon" aria-hidden="true">⚠️</span>
      <span class="error-text">{serverInfo.last_error}</span>
    </div>
  {/if}

  <!-- Action Buttons -->
  <div class="action-buttons">
    {#if isConnected}
      <button
        type="button"
        class="action-btn disconnect-btn"
        on:click={handleDisconnect}
        aria-label="Disconnect from server"
      >
        <span aria-hidden="true">🔌</span>
        Disconnect
      </button>
    {:else if !isConnecting}
      <button
        type="button"
        class="action-btn reconnect-btn"
        on:click={handleReconnect}
        disabled={!serverInfo}
        aria-label="Reconnect to server"
      >
        <span aria-hidden="true">🔗</span>
        Reconnect
      </button>
    {/if}

    {#if connectionHistory.length > 0}
      <button
        type="button"
        class="action-btn history-btn"
        on:click={toggleHistory}
        aria-expanded={showHistory}
        aria-controls="connection-history"
        aria-label="{showHistory ? 'Hide' : 'Show'} connection history ({connectionHistory.length} events)"
      >
        <span aria-hidden="true">📋</span>
        {showHistory ? 'Hide' : 'Show'} History ({connectionHistory.length})
      </button>
    {/if}
  </div>

  <!-- Connection History -->
  {#if showHistory && connectionHistory.length > 0}
    <div id="connection-history" class="history-container" role="region" aria-labelledby="history-heading">
      <h3 id="history-heading" class="history-title">Connection History</h3>

      <div class="history-list" role="list">
        {#each connectionHistory.slice(0, 10) as event (event.timestamp.getTime())}
          <div class="history-item" role="listitem">
            <span class="history-time" aria-hidden="true">
              {formatTimestamp(event.timestamp)}
            </span>
            <span class="history-icon" aria-hidden="true">
              {getEventIcon(event.event_type)}
            </span>
            <span class="history-message">
              {event.message}
            </span>
            <span class="sr-only">
              {event.event_type} event at {formatTimestamp(event.timestamp)}: {event.message}
            </span>
          </div>
        {/each}
      </div>

      {#if connectionHistory.length > 10}
        <div class="history-more" aria-label="And {connectionHistory.length - 10} more events">
          ... and {connectionHistory.length - 10} more events
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .connection-status {
    background: hsl(0, 0%, 100%);
    border-radius: 16px;
    box-shadow: 0 8px 32px hsla(220, 20%, 20%, 0.12);
    padding: 1.5rem;
    max-width: 480px;
    margin: 0 auto;
  }

  .connection-status.compact {
    padding: 1rem;
    max-width: 320px;
  }

  .status-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 1rem;
    flex-wrap: wrap;
    gap: 0.75rem;
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .status-dot {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .status-icon {
    font-size: 1rem;
  }

  .status-text {
    font-size: 1rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
  }

  .quality-indicator {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    font-size: 0.875rem;
  }

  .quality-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .quality-text {
    font-weight: 500;
  }

  .latency-text {
    color: hsl(220, 20%, 60%);
    font-size: 0.75rem;
  }

  .server-info {
    background: hsl(220, 20%, 98%);
    border-radius: 12px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .connection-status.compact .server-info {
    padding: 0.75rem;
  }

  .info-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.375rem 0;
    border-bottom: 1px solid hsl(220, 20%, 95%);
  }

  .info-row:last-child {
    border-bottom: none;
  }

  .info-label {
    font-size: 0.875rem;
    font-weight: 600;
    color: hsl(220, 20%, 40%);
    min-width: 100px;
  }

  .info-value {
    font-size: 0.875rem;
    color: hsl(220, 20%, 20%);
    text-align: right;
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.25rem;
  }

  .secure-icon {
    font-size: 0.75rem;
  }

  .error-display {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 1rem;
    background: hsl(0, 80%, 96%);
    border: 1px solid hsl(0, 80%, 90%);
    border-radius: 8px;
    margin-bottom: 1rem;
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

  .action-buttons {
    display: flex;
    gap: 0.75rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
  }

  .action-btn {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 12px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    transition: all 0.2s ease;
    min-height: 44px;
    flex: 1;
    justify-content: center;
  }

  .reconnect-btn {
    background: hsl(220, 90%, 60%);
    color: white;
  }

  .reconnect-btn:hover:not(:disabled) {
    background: hsl(220, 80%, 50%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px hsla(220, 90%, 60%, 0.3);
  }

  .disconnect-btn {
    background: hsl(0, 80%, 50%);
    color: white;
  }

  .disconnect-btn:hover:not(:disabled) {
    background: hsl(0, 70%, 40%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px hsla(0, 80%, 50%, 0.3);
  }

  .history-btn {
    background: hsl(220, 20%, 96%);
    color: hsl(220, 20%, 40%);
    border: 1px solid hsl(220, 20%, 90%);
  }

  .history-btn:hover:not(:disabled) {
    background: hsl(220, 20%, 92%);
    border-color: hsl(220, 30%, 80%);
  }

  .action-btn:disabled {
    background: hsl(220, 20%, 80%);
    cursor: not-allowed;
    transform: none;
    box-shadow: none;
  }

  .action-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  .history-container {
    border: 1px solid hsl(220, 20%, 90%);
    border-radius: 8px;
    overflow: hidden;
  }

  .history-title {
    font-size: 1rem;
    font-weight: 600;
    color: hsl(220, 20%, 20%);
    margin: 0;
    padding: 1rem;
    background: hsl(220, 20%, 96%);
    border-bottom: 1px solid hsl(220, 20%, 90%);
  }

  .history-list {
    max-height: 200px;
    overflow-y: auto;
  }

  .history-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    border-bottom: 1px solid hsl(220, 20%, 95%);
    font-size: 0.875rem;
  }

  .history-item:last-child {
    border-bottom: none;
  }

  .history-time {
    min-width: 70px;
    font-family: monospace;
    font-size: 0.75rem;
    color: hsl(220, 20%, 60%);
  }

  .history-icon {
    font-size: 0.875rem;
    flex-shrink: 0;
  }

  .history-message {
    flex: 1;
    color: hsl(220, 20%, 40%);
  }

  .history-more {
    padding: 0.75rem 1rem;
    background: hsl(220, 20%, 96%);
    font-size: 0.75rem;
    color: hsl(220, 20%, 60%);
    text-align: center;
    border-top: 1px solid hsl(220, 20%, 95%);
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
    .connection-status {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .server-info {
      border: 2px solid hsl(0, 0%, 0%);
      background: hsl(0, 0%, 100%);
    }

    .error-display {
      border: 2px solid hsl(0, 0%, 0%);
      background: hsl(0, 0%, 100%);
    }

    .action-btn {
      border: 2px solid hsl(0, 0%, 0%);
    }

    .action-btn:focus {
      outline: 3px solid hsl(0, 0%, 0%);
    }

    .history-container {
      border: 2px solid hsl(0, 0%, 0%);
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    .action-btn {
      transition: none;
    }

    .action-btn:hover:not(:disabled) {
      transform: none;
    }
  }

  /* Mobile responsiveness */
  @media (max-width: 768px) {
    .connection-status {
      margin: 0;
      padding: 1rem;
      border-radius: 0;
      box-shadow: none;
      min-height: auto;
    }

    .connection-status.compact {
      padding: 0.75rem;
    }

    .status-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }

    .quality-indicator {
      align-self: flex-end;
    }

    .info-row {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.25rem;
    }

    .info-label {
      min-width: auto;
    }

    .info-value {
      text-align: left;
      justify-content: flex-start;
    }

    .action-buttons {
      flex-direction: column;
    }

    .action-btn {
      width: 100%;
      padding: 1rem;
      font-size: 1rem;
      min-height: 48px;
    }

    .history-item {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.375rem;
      padding: 1rem;
    }

    .history-time {
      min-width: auto;
      align-self: flex-end;
    }
  }

  /* Focus management for keyboard navigation */
  .action-btn:focus,
  .history-btn:focus {
    outline: 2px solid hsl(220, 90%, 60%);
    outline-offset: 2px;
  }

  /* Ensure minimum touch targets */
  .action-btn,
  .history-btn {
    min-height: 44px;
  }

  @media (max-width: 768px) {
    .action-btn,
    .history-btn {
      min-height: 48px;
    }
  }
</style></content>
<parameter name="filePath">frontend/src/components/ConnectionStatus.svelte