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
 * Advanced Message Synchronization Manager for OpenCode Nexus
 * Provides comprehensive sync functionality with automatic triggering,
 * progress tracking, error handling, and user feedback.
 */

import type { ChatMessage } from '../types/chat';
import { OfflineStorage, ConnectionMonitor, MessageStatus, type OfflineMessage } from '../utils/offline-storage';
import { chatActions, chatStateStore, compositionStore } from '../stores/chat';

// Sync configuration
interface SyncConfig {
  maxRetries: number;
  retryDelay: number;
  batchSize: number;
  rateLimitDelay: number;
  maxConcurrentBatches: number;
  syncTimeout: number;
  enableAutoSync: boolean;
  conflictResolution: 'server-wins' | 'client-wins' | 'manual';
}

// Sync progress and status
export interface SyncProgress {
  totalMessages: number;
  processedMessages: number;
  sentMessages: number;
  failedMessages: number;
  currentBatch: number;
  totalBatches: number;
  estimatedTimeRemaining: number;
  currentOperation: string;
  startTime: number;
}

export interface SyncResult {
  success: boolean;
  sent: number;
  failed: number;
  conflicts: number;
  duration: number;
  errors: SyncError[];
  sessionUpdates: string[];
}

export interface SyncError {
  messageId: string;
  sessionId: string;
  error: string;
  timestamp: string;
  retryCount: number;
}

// Sync event types
export enum SyncEventType {
  STARTED = 'sync_started',
  PROGRESS = 'sync_progress',
  BATCH_COMPLETE = 'batch_complete',
  MESSAGE_SENT = 'message_sent',
  MESSAGE_FAILED = 'message_failed',
  CONFLICT_DETECTED = 'conflict_detected',
  COMPLETED = 'sync_completed',
  FAILED = 'sync_failed',
  CANCELLED = 'sync_cancelled'
}

export interface SyncEvent {
  type: SyncEventType;
  data: any;
  timestamp: string;
}

// Conflict resolution
interface MessageConflict {
  localMessage: OfflineMessage;
  serverMessage: ChatMessage;
  resolution: 'local' | 'server' | 'merge' | 'manual';
}

// Sync manager class
export class MessageSyncManager {
  private static instance: MessageSyncManager;
  private config: SyncConfig;
  private isSyncing = false;
  private abortController: AbortController | null = null;
  private eventListeners: ((event: SyncEvent) => void)[] = [];
  private syncHistory: SyncResult[] = [];
  private retryTimeouts: Map<string, ReturnType<typeof setTimeout>> = new Map();

  private constructor() {
    this.config = {
      maxRetries: 3,
      retryDelay: 1000,
      batchSize: 5,
      rateLimitDelay: 200,
      maxConcurrentBatches: 1,
      syncTimeout: 30000,
      enableAutoSync: true,
      conflictResolution: 'server-wins'
    };

    this.initializeAutoSync();
  }

  static getInstance(): MessageSyncManager {
    if (!MessageSyncManager.instance) {
      MessageSyncManager.instance = new MessageSyncManager();
    }
    return MessageSyncManager.instance;
  }

  // Configuration management
  updateConfig(newConfig: Partial<SyncConfig>): void {
    this.config = { ...this.config, ...newConfig };
  }

  getConfig(): SyncConfig {
    return { ...this.config };
  }

  // Event system
  addEventListener(callback: (event: SyncEvent) => void): () => void {
    this.eventListeners.push(callback);
    return () => {
      const index = this.eventListeners.indexOf(callback);
      if (index > -1) {
        this.eventListeners.splice(index, 1);
      }
    };
  }

  private emitEvent(type: SyncEventType, data: any): void {
    const event: SyncEvent = {
      type,
      data,
      timestamp: new Date().toISOString()
    };

    this.eventListeners.forEach(callback => {
      try {
        callback(event);
      } catch (error) {
        console.error('Error in sync event listener:', error);
      }
    });
  }

  // Auto-sync initialization
  private initializeAutoSync(): void {
    if (!this.config.enableAutoSync) return;

    // Listen for connection changes
    ConnectionMonitor.addListener(async (isOnline) => {
      if (isOnline && !this.isSyncing) {
        // Check if there are queued messages
        const queuedMessages = await OfflineStorage.getQueuedMessages();
        if (queuedMessages.length > 0) {
          console.log(`Auto-sync triggered: ${queuedMessages.length} queued messages`);
          this.startSync();
        }
      }
    });

    // Periodic sync check (every 30 seconds when online)
    setInterval(async () => {
      if (ConnectionMonitor.getIsOnline() && !this.isSyncing && this.config.enableAutoSync) {
        const queuedMessages = await OfflineStorage.getQueuedMessages();
        if (queuedMessages.length > 0) {
          this.startSync();
        }
      }
    }, 30000);
  }

  // Main sync method
  async startSync(messageSender?: (sessionId: string, content: string) => Promise<void>): Promise<SyncResult> {
    if (this.isSyncing) {
      throw new Error('Sync already in progress');
    }

    this.isSyncing = true;
    this.abortController = new AbortController();
    const startTime = Date.now();

    chatStateStore.setSyncInProgress(true);

    try {
      this.emitEvent(SyncEventType.STARTED, { startTime });

      const result = await this.performSync(messageSender);

      this.syncHistory.unshift(result);
      // Keep only last 10 sync results
      if (this.syncHistory.length > 10) {
        this.syncHistory = this.syncHistory.slice(0, 10);
      }

      this.emitEvent(SyncEventType.COMPLETED, result);
      return result;

    } catch (error) {
      const errorResult: SyncResult = {
        success: false,
        sent: 0,
        failed: 0,
        conflicts: 0,
        duration: Date.now() - startTime,
        errors: [{
          messageId: '',
          sessionId: '',
          error: error instanceof Error ? error.message : 'Unknown sync error',
          timestamp: new Date().toISOString(),
          retryCount: 0
        }],
        sessionUpdates: []
      };

      this.emitEvent(SyncEventType.FAILED, errorResult);
      throw error;

    } finally {
      this.isSyncing = false;
      this.abortController = null;
      chatStateStore.setSyncInProgress(false);
    }
  }

  // Cancel ongoing sync
  cancelSync(): void {
    if (this.abortController) {
      this.abortController.abort();
      this.emitEvent(SyncEventType.CANCELLED, {});
    }
  }

  // Check if sync is in progress
  isCurrentlySyncing(): boolean {
    return this.isSyncing;
  }

  // Get sync history
  getSyncHistory(): SyncResult[] {
    return [...this.syncHistory];
  }

  // Get last sync result
  getLastSyncResult(): SyncResult | null {
    return this.syncHistory[0] || null;
  }

  // Private sync implementation
  private async performSync(messageSender?: (sessionId: string, content: string) => Promise<void>): Promise<SyncResult> {
    const startTime = Date.now();
    let sent = 0;
    let failed = 0;
    let conflicts = 0;
    const errors: SyncError[] = [];
    const sessionUpdates: string[] = [];

    // Get all queued messages
    const queuedMessages = await OfflineStorage.getQueuedMessages();
    if (queuedMessages.length === 0) {
      return {
        success: true,
        sent: 0,
        failed: 0,
        conflicts: 0,
        duration: Date.now() - startTime,
        errors: [],
        sessionUpdates: []
      };
    }

    // Sort messages by timestamp for proper ordering
    const sortedMessages = queuedMessages.sort((a, b) =>
      new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
    );

    // Group messages by session
    const messagesBySession = new Map<string, OfflineMessage[]>();
    for (const message of sortedMessages) {
      if (!messagesBySession.has(message.sessionId)) {
        messagesBySession.set(message.sessionId, []);
      }
      messagesBySession.get(message.sessionId)!.push(message);
    }

    // Process messages in batches
    const totalMessages = sortedMessages.length;
    const totalBatches = Math.ceil(totalMessages / this.config.batchSize);
    let processedMessages = 0;

    this.emitEvent(SyncEventType.PROGRESS, {
      totalMessages,
      processedMessages: 0,
      sentMessages: 0,
      failedMessages: 0,
      currentBatch: 0,
      totalBatches,
      estimatedTimeRemaining: 0,
      currentOperation: 'Preparing sync...',
      startTime
    } as SyncProgress);

    for (let batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      if (this.abortController?.signal.aborted) {
        throw new Error('Sync cancelled');
      }

      const batchStart = batchIndex * this.config.batchSize;
      const batchEnd = Math.min(batchStart + this.config.batchSize, totalMessages);
      const batchMessages = sortedMessages.slice(batchStart, batchEnd);

      const batchResult = await this.processBatch(batchMessages, messageSender);

      sent += batchResult.sent;
      failed += batchResult.failed;
      conflicts += batchResult.conflicts;
      errors.push(...batchResult.errors);
      sessionUpdates.push(...batchResult.sessionUpdates);

      processedMessages += batchMessages.length;

      // Update progress
      const elapsed = Date.now() - startTime;
      const rate = processedMessages / elapsed;
      const remaining = totalMessages - processedMessages;
      const estimatedTimeRemaining = remaining / rate;

      this.emitEvent(SyncEventType.PROGRESS, {
        totalMessages,
        processedMessages,
        sentMessages: sent,
        failedMessages: failed,
        currentBatch: batchIndex + 1,
        totalBatches,
        estimatedTimeRemaining,
        currentOperation: `Processing batch ${batchIndex + 1}/${totalBatches}`,
        startTime
      } as SyncProgress);

      this.emitEvent(SyncEventType.BATCH_COMPLETE, {
        batchIndex: batchIndex + 1,
        totalBatches,
        batchResult
      });

      // Rate limiting between batches
      if (batchIndex < totalBatches - 1) {
        await this.delay(this.config.rateLimitDelay);
      }
    }

    // Update UI state
    const allQueued = await OfflineStorage.getQueuedMessages();
    const queuedCount = allQueued.length;
    compositionStore.setQueuedMessageCount(queuedCount);
    chatStateStore.setHasQueuedMessages(queuedCount > 0);

    return {
      success: failed === 0,
      sent,
      failed,
      conflicts,
      duration: Date.now() - startTime,
      errors,
      sessionUpdates
    };
  }

  // Process a batch of messages
  private async processBatch(
    messages: OfflineMessage[],
    messageSender?: (sessionId: string, content: string) => Promise<void>
  ): Promise<{
    sent: number;
    failed: number;
    conflicts: number;
    errors: SyncError[];
    sessionUpdates: string[];
  }> {
    let sent = 0;
    let failed = 0;
    let conflicts = 0;
    const errors: SyncError[] = [];
    const sessionUpdates: string[] = [];

    // Process messages sequentially to maintain order
    for (const message of messages) {
      if (this.abortController?.signal.aborted) break;

      try {
        // Update message status to sending
        await OfflineStorage.updateQueuedMessage(message.id, { status: MessageStatus.SENDING });

        this.emitEvent(SyncEventType.MESSAGE_SENT, {
          messageId: message.id,
          sessionId: message.sessionId,
          status: 'sending'
        });

        // Check for conflicts before sending
        const conflict = await this.checkForConflicts(message);
        if (conflict) {
          conflicts++;
          this.emitEvent(SyncEventType.CONFLICT_DETECTED, {
            messageId: message.id,
            sessionId: message.sessionId,
            conflict
          });

          const resolution = await this.resolveConflict(conflict);
          if (resolution === 'skip') {
            await OfflineStorage.removeQueuedMessage(message.id);
            continue;
          }
        }

        // Send message
        if (messageSender) {
          await messageSender(message.sessionId, message.content);
        } else {
          // Use default chat action
          await chatActions.sendMessage(message.content, async (sessionId, content) => {
            // This will be replaced by the actual message sender
            console.log(`Sending message to session ${sessionId}: ${content}`);
          });
        }

        // Mark as sent and remove from queue
        await OfflineStorage.removeQueuedMessage(message.id);
        sent++;

        this.emitEvent(SyncEventType.MESSAGE_SENT, {
          messageId: message.id,
          sessionId: message.sessionId,
          status: 'sent'
        });

        // Update session in cache
        if (!sessionUpdates.includes(message.sessionId)) {
          sessionUpdates.push(message.sessionId);
        }

      } catch (error) {
        failed++;

        const syncError: SyncError = {
          messageId: message.id,
          sessionId: message.sessionId,
          error: error instanceof Error ? error.message : 'Unknown error',
          timestamp: new Date().toISOString(),
          retryCount: message.retryCount || 0
        };

        errors.push(syncError);

        this.emitEvent(SyncEventType.MESSAGE_FAILED, syncError);

        // Handle retry logic
        const currentRetryCount = message.retryCount || 0;
        const retryCount = currentRetryCount + 1;
        if (retryCount < this.config.maxRetries) {
          // Schedule retry
          const retryDelay = this.config.retryDelay * Math.pow(2, retryCount - 1);
          await OfflineStorage.updateQueuedMessage(message.id, {
            status: MessageStatus.QUEUED,
            retryCount
          });

          this.scheduleRetry(message.id, retryDelay);
        } else {
          // Mark as failed
          await OfflineStorage.updateQueuedMessage(message.id, {
            status: MessageStatus.FAILED,
            retryCount
          });
        }
      }
    }

    return { sent, failed, conflicts, errors, sessionUpdates };
  }

  // Check for message conflicts
  private async checkForConflicts(message: OfflineMessage): Promise<MessageConflict | null> {
    try {
      // Get current session state
      const session = await OfflineStorage.getStoredSession(message.sessionId);
      if (!session) return null;

      // Check if a similar message already exists in the session
      const existingMessage = session.messages.find(m =>
        m.content === message.content &&
        Math.abs(new Date(m.timestamp).getTime() - new Date(message.timestamp).getTime()) < 5000 // Within 5 seconds
      );

      if (existingMessage) {
        return {
          localMessage: message,
          serverMessage: existingMessage,
          resolution: 'manual' // Default to manual resolution
        };
      }

      return null;
    } catch (error) {
      console.warn('Error checking for conflicts:', error);
      return null;
    }
  }

  // Resolve message conflicts
  private async resolveConflict(_conflict: MessageConflict): Promise<'local' | 'server' | 'merge' | 'skip'> {
    switch (this.config.conflictResolution) {
      case 'server-wins':
        return 'skip'; // Don't send local message
      case 'client-wins':
        return 'local'; // Send local message anyway
      case 'manual':
      default:
        // For now, default to server-wins for automatic resolution
        // In a full implementation, this would show a UI dialog
        return 'skip';
    }
  }

  // Schedule retry for failed message
  private scheduleRetry(messageId: string, delay: number): void {
    const timeout = setTimeout(async () => {
      this.retryTimeouts.delete(messageId);

      // Check if message still exists and needs retry
      const queuedMessages = await OfflineStorage.getQueuedMessages();
      const message = queuedMessages.find(m => m.id === messageId);

      if (message && message.status === MessageStatus.QUEUED && (message.retryCount || 0) < this.config.maxRetries) {
        // Trigger sync for this specific message
        this.startSync();
      }
    }, delay);

    this.retryTimeouts.set(messageId, timeout);
  }

  // Utility method for delays
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // Cleanup method
  cleanup(): void {
    // Clear all retry timeouts
    for (const timeout of this.retryTimeouts.values()) {
      clearTimeout(timeout);
    }
    this.retryTimeouts.clear();

    // Cancel any ongoing sync
    if (this.abortController) {
      this.abortController.abort();
    }
  }
}

// Export singleton instance
export const messageSyncManager = MessageSyncManager.getInstance();