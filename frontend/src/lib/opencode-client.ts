/*
 * MIT License
 *
 * Copyright (c) 2025 OpenCode Nexus Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { createOpencodeClient, type OpencodeClient } from '@opencode-ai/sdk/client';
import { invoke } from '../utils/tauri-api';

export type { OpencodeClient };

export interface ServerConnection {
  name: string;
  hostname: string;
  port: number;
  secure: boolean;
  lastConnected?: string;
}

/**
 * OpencodeClientManager - Manages real SDK client lifecycle and connection
 * Provides a singleton interface for connecting to OpenCode servers using official SDK
 */
export class OpencodeClientManager {
  private client: OpencodeClient | null = null;
  private currentConnection: ServerConnection | null = null;
  private connecting = false;

  /**
   * Connect to an OpenCode server using real SDK
   */
  async connect(connection: ServerConnection): Promise<void> {
    if (this.connecting) {
      console.warn('⚠️ [SDK] Connection already in progress');
      return;
    }

    if (this.client && this.currentConnection?.hostname === connection.hostname) {
      console.log('✅ [SDK] Already connected to this server');
      return;
    }

    this.connecting = true;
    try {
      const protocol = connection.secure ? 'https' : 'http';
      const baseUrl = `${protocol}://${connection.hostname}:${connection.port}`;

      console.log(`🔗 [SDK] Connecting to server: ${baseUrl}`);

      // Use REAL SDK client
      this.client = createOpencodeClient({ 
        baseUrl
        // Note: logLevel not supported in current SDK version
      });
      this.currentConnection = {
        ...connection,
        lastConnected: new Date().toISOString()
      };

      // Persist connection to Tauri backend for storage
      try {
        await invoke('save_connection', { connection: this.currentConnection });
        console.log('💾 [SDK] Connection saved to persistent storage');
      } catch (error) {
        console.warn('⚠️ [SDK] Failed to persist connection:', error);
      }

      console.log('✅ [SDK] Successfully connected to server');
    } finally {
      this.connecting = false;
    }
  }

  /**
   * Disconnect from current server
   */
  async disconnect(): Promise<void> {
    console.log('🔌 [SDK] Disconnecting from server');
    this.client = null;
    this.currentConnection = null;
  }

  /**
   * Get current SDK client instance
   */
  getClient(): OpencodeClient {
    if (!this.client) {
      throw new Error('Not connected to a server. Call connect() first.');
    }
    return this.client;
  }

  /**
   * Check if currently connected
   */
  isConnected(): boolean {
    return this.client !== null && !this.connecting;
  }

  /**
   * Get current connection details
   */
  getCurrentConnection(): ServerConnection | null {
    return this.currentConnection;
  }

  /**
   * Get all saved connections from persistent storage
   */
  async getSavedConnections(): Promise<ServerConnection[]> {
    try {
      const connections = await invoke<ServerConnection[]>('get_saved_connections');
      return connections || [];
    } catch (error) {
      console.warn('⚠️ [SDK] Failed to load saved connections:', error);
      return [];
    }
  }

  /**
   * Get last used connection from persistent storage
   */
  async getLastUsedConnection(): Promise<ServerConnection | null> {
    try {
      const connection = await invoke<ServerConnection | null>('get_last_used_connection');
      return connection || null;
    } catch (error) {
      console.warn('⚠️ [SDK] Failed to load last used connection:', error);
      return null;
    }
  }

  /**
   * Initialize from persistent storage (auto-reconnect if possible)
   */
  async initializeFromStorage(): Promise<boolean> {
    try {
      const lastConnection = await this.getLastUsedConnection();
      if (lastConnection) {
        console.log(`🔄 [SDK] Found saved connection: ${lastConnection.hostname}:${lastConnection.port}`);
        await this.connect(lastConnection);
        return true;
      }
      return false;
    } catch (error) {
      console.warn('⚠️ [SDK] Failed to initialize from storage:', error);
      return false;
    }
  }
}

// Export singleton instance
export const opcodeClient = new OpencodeClientManager();
