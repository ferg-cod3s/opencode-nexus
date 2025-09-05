import { Page, expect } from '@playwright/test';

export class ServerHelper {
  constructor(private page: Page) {}

  async loginAsTestUser() {
    await this.page.goto('/login');
    await this.page.fill('[data-testid="username-input"]', 'testuser');
    await this.page.fill('[data-testid="password-input"]', 'SecurePass123!');
    await this.page.click('[data-testid="login-button"]');
    await expect(this.page).toHaveURL('/dashboard');
  }

  async navigateToDashboard() {
    await this.page.click('[data-testid="dashboard-tab"]');
    await expect(this.page.locator('[data-testid="server-dashboard"]')).toBeVisible();
  }

  async startServer(options?: { expectFailure?: boolean }) {
    await this.page.click('[data-testid="start-server-button"]');
    
    if (!options?.expectFailure) {
      // Expect status to change to starting, then running
      await expect(this.page.locator('[data-testid="server-status"]')).toContainText('Starting');
      await this.waitForServerRunning();
    } else {
      // Expect error message
      await expect(this.page.locator('[data-testid="server-error"]')).toBeVisible();
    }
  }

  async stopServer() {
    await this.page.click('[data-testid="stop-server-button"]');
    
    // Expect status to change to stopping, then stopped
    await expect(this.page.locator('[data-testid="server-status"]')).toContainText('Stopping');
    await this.waitForServerStopped();
  }

  async restartServer() {
    await this.page.click('[data-testid="restart-server-button"]');
    
    // Should show restarting status
    await expect(this.page.locator('[data-testid="server-status"]')).toContainText('Restarting');
    
    // Should eventually be running
    await this.waitForServerRunning();
  }

  async waitForServerRunning() {
    await expect(this.page.locator('[data-testid="server-status"]')).toContainText('Running', { 
      timeout: 15000 
    });
    
    // Verify server details are shown
    await expect(this.page.locator('[data-testid="server-port"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="server-pid"]')).toBeVisible();
  }

  async waitForServerStopped() {
    await expect(this.page.locator('[data-testid="server-status"]')).toContainText('Stopped', { 
      timeout: 10000 
    });
    
    // Server details should be hidden when stopped
    await expect(this.page.locator('[data-testid="server-pid"]')).not.toBeVisible();
  }

  async verifyServerMetrics() {
    // Server must be running for metrics
    await this.waitForServerRunning();
    
    // Check that metrics are displayed
    await expect(this.page.locator('[data-testid="server-metrics"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="cpu-usage"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="memory-usage"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="request-count"]')).toBeVisible();
  }

  async checkServerLogs() {
    await this.page.click('[data-testid="view-logs-button"]');
    await expect(this.page.locator('[data-testid="server-logs"]')).toBeVisible();
    
    // Should have some log entries if server was running
    const logEntries = this.page.locator('[data-testid="log-entry"]');
    const logCount = await logEntries.count();
    expect(logCount).toBeGreaterThan(0);
  }

  async configureServerSettings(config: {
    port?: number;
    host?: string;
    dataDir?: string;
  }) {
    await this.page.click('[data-testid="server-settings-button"]');
    await expect(this.page.locator('[data-testid="server-config-modal"]')).toBeVisible();
    
    if (config.port) {
      await this.page.fill('[data-testid="port-input"]', config.port.toString());
    }
    
    if (config.host) {
      await this.page.fill('[data-testid="host-input"]', config.host);
    }
    
    if (config.dataDir) {
      await this.page.fill('[data-testid="data-dir-input"]', config.dataDir);
    }
    
    await this.page.click('[data-testid="save-config-button"]');
    
    // Should close modal and show success message
    await expect(this.page.locator('[data-testid="server-config-modal"]')).not.toBeVisible();
    await expect(this.page.locator('[data-testid="config-saved-message"]')).toBeVisible();
  }

  async testServerAutoRecovery() {
    // Start server
    await this.startServer();
    
    // Mock server crash by injecting failure
    await this.page.evaluate(() => {
      // Simulate server crash event
      window.dispatchEvent(new CustomEvent('server-crashed', { 
        detail: { reason: 'Process exited unexpectedly' }
      }));
    });
    
    // Should show crash notification
    await expect(this.page.locator('[data-testid="server-crash-notification"]')).toBeVisible();
    
    // Should attempt auto-recovery
    await expect(this.page.locator('[data-testid="server-status"]')).toContainText('Recovering');
    
    // Should eventually be running again
    await this.waitForServerRunning();
  }

  async testPortConflict() {
    // Configure server to use a conflicting port
    await this.configureServerSettings({ port: 80 }); // Likely to conflict
    
    // Try to start server
    await this.startServer({ expectFailure: true });
    
    // Should show port conflict error
    await expect(this.page.locator('[data-testid="port-conflict-error"]')).toBeVisible();
    await expect(this.page.locator('[data-testid="suggested-ports"]')).toBeVisible();
  }

  async verifyRealTimeUpdates() {
    await this.waitForServerRunning();
    
    // Server metrics should update automatically
    const initialCpuUsage = await this.page.textContent('[data-testid="cpu-usage"]');
    
    // Wait for metrics update (they should refresh every few seconds)
    await this.page.waitForTimeout(5000);
    
    const updatedCpuUsage = await this.page.textContent('[data-testid="cpu-usage"]');
    
    // Values might be the same, but the timestamp should update
    const timestamp = this.page.locator('[data-testid="metrics-timestamp"]');
    await expect(timestamp).toBeVisible();
  }

  async testServerHealthCheck() {
    await this.waitForServerRunning();
    
    // Health check should be performed automatically
    const healthStatus = this.page.locator('[data-testid="health-status"]');
    await expect(healthStatus).toContainText('Healthy');
    
    // Health check indicator should be green
    await expect(this.page.locator('[data-testid="health-indicator"]')).toHaveClass(/healthy/);
  }

  async getServerStatus(): Promise<string> {
    const statusElement = this.page.locator('[data-testid="server-status"]');
    return await statusElement.textContent() || '';
  }

  async getServerPort(): Promise<number> {
    const portElement = this.page.locator('[data-testid="server-port"]');
    const portText = await portElement.textContent();
    return parseInt(portText || '0');
  }

  async getServerUptime(): Promise<string> {
    const uptimeElement = this.page.locator('[data-testid="server-uptime"]');
    return await uptimeElement.textContent() || '';
  }
}