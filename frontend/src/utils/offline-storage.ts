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

/**
 * Offline conversation caching utility for OpenCode Nexus
 * Provides local storage integration with proper serialization, quota management,
 * and automatic sync when connection is restored.
 */

import type { ChatSession, ChatMessage } from '../types/chat';
import { MessageRole } from '../types/chat';

// Storage keys
const STORAGE_KEYS = {
  SESSIONS: 'opencode_nexus_chat_sessions',
  QUEUED_MESSAGES: 'opencode_nexus_queued_messages',
  CONNECTION_STATUS: 'opencode_nexus_connection_status',
  STORAGE_METADATA: 'opencode_nexus_storage_metadata'
} as const;

// Storage limits
const STORAGE_LIMITS = {
  MAX_TOTAL_SIZE: 50 * 1024 * 1024, // 50MB total
  MAX_SESSION_SIZE: 5 * 1024 * 1024, // 5MB per session
  MAX_MESSAGE_SIZE: 1024 * 1024, // 1MB per message
  MAX_SESSIONS: 100, // Maximum number of sessions
  CLEANUP_THRESHOLD: 0.8 // Clean up when 80% full
} as const;

// Message status for offline functionality
export enum MessageStatus {
  SENT = 'sent',
  QUEUED = 'queued',
  SENDING = 'sending',
  FAILED = 'failed'
}

// Extended message type with offline status
export interface OfflineMessage extends ChatMessage {
  status: MessageStatus;
  queuedAt?: string;
  retryCount?: number;
  sessionId: string;
}

// Storage metadata
interface StorageMetadata {
  version: string;
  lastSync: string;
  totalSize: number;
  sessionCount: number;
  messageCount: number;
  lastCleanup: string;
}

// Connection status
export interface ConnectionStatus {
  isOnline: boolean;
  lastOnline: string;
  lastOffline: string;
}

// Compression utilities
class CompressionUtils {
  static async compress(data: string): Promise<string> {
    // Simple LZ-string style compression for large messages
    if (data.length < 1000) return data; // Don't compress small data

    try {
      // Use browser's built-in compression if available
      if (typeof CompressionStream !== 'undefined') {
        const stream = new CompressionStream('gzip');
        const writer = stream.writable.getWriter();
        const reader = stream.readable.getReader();

        writer.write(new TextEncoder().encode(data));
        writer.close();

        const chunks: Uint8Array[] = [];
        let done = false;
        while (!done) {
          const { value, done: readerDone } = await reader.read();
          done = readerDone;
          if (value) chunks.push(value);
        }

        const compressed = new Uint8Array(chunks.reduce((acc, chunk) => acc + chunk.length, 0));
        let offset = 0;
        for (const chunk of chunks) {
          compressed.set(chunk, offset);
          offset += chunk.length;
        }

        return btoa(String.fromCharCode(...compressed));
      }
    } catch (error) {
      console.warn('Compression failed, using uncompressed data:', error);
    }

    return data;
  }

  static async decompress(data: string): Promise<string> {
    if (!data.startsWith('data:') && data.length < 1000) return data;

    try {
      // Use browser's built-in decompression if available
      if (typeof DecompressionStream !== 'undefined') {
        const compressed = Uint8Array.from(atob(data), c => c.charCodeAt(0));
        const stream = new DecompressionStream('gzip');
        const writer = stream.writable.getWriter();
        const reader = stream.readable.getReader();

        writer.write(compressed);
        writer.close();

        const chunks: Uint8Array[] = [];
        let done = false;
        while (!done) {
          const { value, done: readerDone } = await reader.read();
          done = readerDone;
          if (value) chunks.push(value);
        }

        const decompressed = new Uint8Array(chunks.reduce((acc, chunk) => acc + chunk.length, 0));
        let offset = 0;
        for (const chunk of chunks) {
          decompressed.set(chunk, offset);
          offset += chunk.length;
        }

        return new TextDecoder().decode(decompressed);
      }
    } catch (error) {
      console.warn('Decompression failed, returning original data:', error);
    }

    return data;
  }
}

// Storage quota management
class StorageManager {
  private static async getStorageSize(): Promise<number> {
    try {
      const keys = Object.values(STORAGE_KEYS);
      let totalSize = 0;

      for (const key of keys) {
        const data = localStorage.getItem(key);
        if (data) {
          totalSize += data.length * 2; // UTF-16 characters = 2 bytes each
        }
      }

      return totalSize;
    } catch (error) {
      console.error('Failed to calculate storage size:', error);
      return 0;
    }
  }

  static async isStorageFull(): Promise<boolean> {
    const size = await this.getStorageSize();
    return size >= STORAGE_LIMITS.MAX_TOTAL_SIZE;
  }

  static async getStorageUsage(): Promise<{ used: number; available: number; percentage: number }> {
    const used = await this.getStorageSize();
    const available = STORAGE_LIMITS.MAX_TOTAL_SIZE - used;
    const percentage = (used / STORAGE_LIMITS.MAX_TOTAL_SIZE) * 100;

    return { used, available, percentage };
  }

  static async cleanupOldSessions(): Promise<void> {
    try {
      const sessions = await OfflineStorage.getStoredSessions();
      const metadata = await OfflineStorage.getStorageMetadata();

      // Sort sessions by last activity (most recent first)
      const sortedSessions = sessions.sort((a, b) => {
        const aLastMessage = a.messages[a.messages.length - 1];
        const bLastMessage = b.messages[b.messages.length - 1];

        const aTime = aLastMessage ? new Date(aLastMessage.timestamp).getTime() : new Date(a.created_at).getTime();
        const bTime = bLastMessage ? new Date(bLastMessage.timestamp).getTime() : new Date(b.created_at).getTime();

        return bTime - aTime;
      });

      // Keep only the most recent sessions
      const sessionsToKeep = sortedSessions.slice(0, STORAGE_LIMITS.MAX_SESSIONS);
      const sessionsToRemove = sortedSessions.slice(STORAGE_LIMITS.MAX_SESSIONS);

      // Remove old sessions
      for (const session of sessionsToRemove) {
        await OfflineStorage.removeSession(session.id);
      }

      // Update metadata
      metadata.lastCleanup = new Date().toISOString();
      metadata.sessionCount = sessionsToKeep.length;
      await OfflineStorage.updateStorageMetadata(metadata);

      console.log(`Cleaned up ${sessionsToRemove.length} old sessions`);
    } catch (error) {
      console.error('Failed to cleanup old sessions:', error);
    }
  }

  static async enforceStorageLimits(): Promise<void> {
    const usage = await this.getStorageUsage();

    if (usage.percentage >= STORAGE_LIMITS.CLEANUP_THRESHOLD * 100) {
      console.log(`Storage usage at ${usage.percentage.toFixed(1)}%, running cleanup`);
      await this.cleanupOldSessions();
    }
  }
}

// Main offline storage class
export class OfflineStorage {
  private static readonly VERSION = '1.0.0';

  // Check if localStorage is available (browser environment)
  private static isLocalStorageAvailable(): boolean {
    return typeof localStorage !== 'undefined';
  }

  // Session storage methods
  static async storeSession(session: ChatSession): Promise<void> {
    if (!this.isLocalStorageAvailable()) {
      console.warn('localStorage not available, skipping session storage');
      return;
    }
    try {
      await StorageManager.enforceStorageLimits();

      const sessions = await this.getStoredSessions();
      const existingIndex = sessions.findIndex(s => s.id === session.id);

      if (existingIndex >= 0) {
        sessions[existingIndex] = session;
      } else {
        sessions.push(session);
      }

      // Compress large sessions
      const serialized = JSON.stringify(sessions);
      const compressed = await CompressionUtils.compress(serialized);

      localStorage.setItem(STORAGE_KEYS.SESSIONS, compressed);
      await this.updateStorageMetadata();
    } catch (error) {
      console.error('Failed to store session:', error);
      throw new Error('Failed to store conversation data');
    }
  }

  static async getStoredSessions(): Promise<ChatSession[]> {
    if (!this.isLocalStorageAvailable()) {
      return [];
    }
    try {
      const compressed = localStorage.getItem(STORAGE_KEYS.SESSIONS);
      if (!compressed) return [];

      const decompressed = await CompressionUtils.decompress(compressed);
      const sessions = JSON.parse(decompressed);

      return Array.isArray(sessions) ? sessions : [];
    } catch (error) {
      console.error('Failed to retrieve stored sessions:', error);
      return [];
    }
  }

  static async getStoredSession(sessionId: string): Promise<ChatSession | null> {
    const sessions = await this.getStoredSessions();
    return sessions.find(s => s.id === sessionId) || null;
  }

  static async removeSession(sessionId: string): Promise<void> {
    try {
      const sessions = await this.getStoredSessions();
      const filtered = sessions.filter(s => s.id !== sessionId);

      const serialized = JSON.stringify(filtered);
      const compressed = await CompressionUtils.compress(serialized);

      localStorage.setItem(STORAGE_KEYS.SESSIONS, compressed);
      await this.updateStorageMetadata();
    } catch (error) {
      console.error('Failed to remove session:', error);
      throw new Error('Failed to remove conversation');
    }
  }

  static async clearAllSessions(): Promise<void> {
    try {
      localStorage.removeItem(STORAGE_KEYS.SESSIONS);
      await this.updateStorageMetadata();
    } catch (error) {
      console.error('Failed to clear sessions:', error);
    }
  }

  // Queued messages methods
  static async queueMessage(sessionId: string, content: string): Promise<OfflineMessage> {
    try {
      await StorageManager.enforceStorageLimits();

      const queuedMessages = await this.getQueuedMessages();
      const message: OfflineMessage = {
        id: `queued-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        role: MessageRole.User,
        content,
        timestamp: new Date().toISOString(),
        status: MessageStatus.QUEUED,
        queuedAt: new Date().toISOString(),
        retryCount: 0,
        sessionId
      };

      queuedMessages.push(message);

      const serialized = JSON.stringify(queuedMessages);
      const compressed = await CompressionUtils.compress(serialized);

      localStorage.setItem(STORAGE_KEYS.QUEUED_MESSAGES, compressed);
      await this.updateStorageMetadata();

      return message;
    } catch (error) {
      console.error('Failed to queue message:', error);
      throw new Error('Failed to queue message for offline sending');
    }
  }

  static async getQueuedMessages(): Promise<OfflineMessage[]> {
    try {
      const compressed = localStorage.getItem(STORAGE_KEYS.QUEUED_MESSAGES);
      if (!compressed) return [];

      const decompressed = await CompressionUtils.decompress(compressed);
      const messages = JSON.parse(decompressed);

      return Array.isArray(messages) ? messages : [];
    } catch (error) {
      console.error('Failed to retrieve queued messages:', error);
      return [];
    }
  }

  static async getQueuedMessagesForSession(sessionId: string): Promise<OfflineMessage[]> {
    const allQueued = await this.getQueuedMessages();
    return allQueued.filter(msg => msg.sessionId === sessionId);
  }

  static async updateQueuedMessage(messageId: string, updates: Partial<OfflineMessage>): Promise<void> {
    try {
      const queuedMessages = await this.getQueuedMessages();
      const index = queuedMessages.findIndex(msg => msg.id === messageId);

      if (index >= 0) {
        queuedMessages[index] = { ...queuedMessages[index], ...updates };

        const serialized = JSON.stringify(queuedMessages);
        const compressed = await CompressionUtils.compress(serialized);

        localStorage.setItem(STORAGE_KEYS.QUEUED_MESSAGES, compressed);
      }
    } catch (error) {
      console.error('Failed to update queued message:', error);
    }
  }

  static async removeQueuedMessage(messageId: string): Promise<void> {
    try {
      const queuedMessages = await this.getQueuedMessages();
      const filtered = queuedMessages.filter(msg => msg.id !== messageId);

      const serialized = JSON.stringify(filtered);
      const compressed = await CompressionUtils.compress(serialized);

      localStorage.setItem(STORAGE_KEYS.QUEUED_MESSAGES, compressed);
      await this.updateStorageMetadata();
    } catch (error) {
      console.error('Failed to remove queued message:', error);
    }
  }

  static async clearQueuedMessages(): Promise<void> {
    try {
      localStorage.removeItem(STORAGE_KEYS.QUEUED_MESSAGES);
      await this.updateStorageMetadata();
    } catch (error) {
      console.error('Failed to clear queued messages:', error);
    }
  }

  // Connection status methods
  static async setConnectionStatus(isOnline: boolean): Promise<void> {
    if (!this.isLocalStorageAvailable()) {
      return;
    }
    try {
      const status: ConnectionStatus = {
        isOnline,
        lastOnline: isOnline ? new Date().toISOString() : '',
        lastOffline: !isOnline ? new Date().toISOString() : ''
      };

      // Preserve last online/offline times
      const existing = await this.getConnectionStatus();
      if (existing) {
        status.lastOnline = isOnline ? new Date().toISOString() : existing.lastOnline;
        status.lastOffline = !isOnline ? new Date().toISOString() : existing.lastOffline;
      }

      localStorage.setItem(STORAGE_KEYS.CONNECTION_STATUS, JSON.stringify(status));
    } catch (error) {
      console.error('Failed to set connection status:', error);
    }
  }

  static async getConnectionStatus(): Promise<ConnectionStatus | null> {
    if (!this.isLocalStorageAvailable()) {
      return null;
    }
    try {
      const data = localStorage.getItem(STORAGE_KEYS.CONNECTION_STATUS);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      console.error('Failed to get connection status:', error);
      return null;
    }
  }

  // Storage metadata methods
  static async getStorageMetadata(): Promise<StorageMetadata> {
    if (!this.isLocalStorageAvailable()) {
      // Return default metadata when localStorage is not available
      return {
        version: this.VERSION,
        lastSync: new Date().toISOString(),
        totalSize: 0,
        sessionCount: 0,
        messageCount: 0,
        lastCleanup: new Date().toISOString()
      };
    }
    try {
      const data = localStorage.getItem(STORAGE_KEYS.STORAGE_METADATA);
      if (data) {
        return JSON.parse(data);
      }
    } catch (error) {
      console.error('Failed to get storage metadata:', error);
    }

    // Return default metadata
    return {
      version: this.VERSION,
      lastSync: new Date().toISOString(),
      totalSize: 0,
      sessionCount: 0,
      messageCount: 0,
      lastCleanup: new Date().toISOString()
    };
  }

  static async updateStorageMetadata(metadata?: Partial<StorageMetadata>): Promise<void> {
    if (!this.isLocalStorageAvailable()) {
      return;
    }
    try {
      const current = await this.getStorageMetadata();
      const updated = { ...current, ...metadata };

      // Recalculate actual stats
      const sessions = await this.getStoredSessions();
      const queuedMessages = await this.getQueuedMessages();

      updated.sessionCount = sessions.length;
      updated.messageCount = sessions.reduce((total, session) => total + session.messages.length, 0) + queuedMessages.length;
      updated.lastSync = new Date().toISOString();

      localStorage.setItem(STORAGE_KEYS.STORAGE_METADATA, JSON.stringify(updated));
    } catch (error) {
      console.error('Failed to update storage metadata:', error);
    }
  }

  // Sync methods
  static async syncQueuedMessages(
    sendMessageFn: (sessionId: string, content: string) => Promise<void>
  ): Promise<{ sent: number; failed: number }> {
    const queuedMessages = await this.getQueuedMessages();
    let sent = 0;
    let failed = 0;

    for (const message of queuedMessages) {
      if (message.status === MessageStatus.QUEUED) {
        try {
          await this.updateQueuedMessage(message.id, { status: MessageStatus.SENDING });
          await sendMessageFn(message.sessionId, message.content);
          await this.removeQueuedMessage(message.id);
          sent++;
        } catch (error) {
          console.error('Failed to send queued message:', error);
          const retryCount = (message.retryCount || 0) + 1;

          if (retryCount >= 3) {
            await this.updateQueuedMessage(message.id, {
              status: MessageStatus.FAILED,
              retryCount
            });
          } else {
            await this.updateQueuedMessage(message.id, {
              status: MessageStatus.QUEUED,
              retryCount
            });
          }
          failed++;
        }
      }
    }

    return { sent, failed };
  }

  // Utility methods
  static async getStorageStats(): Promise<{
    sessions: number;
    messages: number;
    queuedMessages: number;
    storageUsage: { used: number; available: number; percentage: number };
  }> {
    const sessions = await this.getStoredSessions();
    const queuedMessages = await this.getQueuedMessages();
    const storageUsage = await StorageManager.getStorageUsage();

    const totalMessages = sessions.reduce((total, session) => total + session.messages.length, 0);

    return {
      sessions: sessions.length,
      messages: totalMessages,
      queuedMessages: queuedMessages.length,
      storageUsage
    };
  }

  static async clearAllData(): Promise<void> {
    try {
      Object.values(STORAGE_KEYS).forEach(key => {
        localStorage.removeItem(key);
      });
    } catch (error) {
      console.error('Failed to clear all offline data:', error);
    }
  }

  // Migration method for future versions
  static async migrateStorage(): Promise<void> {
    const metadata = await this.getStorageMetadata();

    if (metadata.version !== this.VERSION) {
      console.log(`Migrating storage from ${metadata.version} to ${this.VERSION}`);

      // Future migration logic would go here
      // For now, just update the version
      metadata.version = this.VERSION;
      await this.updateStorageMetadata(metadata);
    }
  }
}

// Connection monitoring utility
export class ConnectionMonitor {
  private static isOnline: boolean = typeof navigator !== 'undefined' ? navigator.onLine : true;
  private static listeners: ((isOnline: boolean) => void)[] = [];

  static init(): void {
    // Set initial status from navigator if available
    if (typeof navigator !== 'undefined') {
      this.isOnline = navigator.onLine;
    }
    OfflineStorage.setConnectionStatus(this.isOnline);

    // Listen for online/offline events (only in browser environment)
    if (typeof window !== 'undefined') {
      window.addEventListener('online', () => {
        this.isOnline = true;
        this.notifyListeners(true);
        OfflineStorage.setConnectionStatus(true);
      });

      window.addEventListener('offline', () => {
        this.isOnline = false;
        this.notifyListeners(false);
        OfflineStorage.setConnectionStatus(false);
      });
    }
  }

  static getIsOnline(): boolean {
    return this.isOnline;
  }

  static addListener(callback: (isOnline: boolean) => void): () => void {
    this.listeners.push(callback);

    // Return unsubscribe function
    return () => {
      const index = this.listeners.indexOf(callback);
      if (index > -1) {
        this.listeners.splice(index, 1);
      }
    };
  }

  private static notifyListeners(isOnline: boolean): void {
    this.listeners.forEach(callback => {
      try {
        callback(isOnline);
      } catch (error) {
        console.error('Error in connection listener:', error);
      }
    });
  }
}

// Initialize storage when explicitly called (client-side only)
export function initializeOfflineStorage(): void {
  if (typeof window !== 'undefined') {
    OfflineStorage.migrateStorage().catch(error => {
      console.error('Failed to migrate offline storage:', error);
    });

    ConnectionMonitor.init();
  }
}