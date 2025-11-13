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

import { writable, derived, get } from 'svelte/store';
import type { ChatSession, ChatMessage, ChatEvent } from '../types/chat';
import { MessageRole } from '../types/chat';
import { OfflineStorage, ConnectionMonitor, MessageStatus, type OfflineMessage } from '../utils/offline-storage';
import { messageSyncManager } from '../utils/message-sync-manager';

// Chat sessions store
function createSessionsStore() {
  const { subscribe, set, update } = writable<ChatSession[]>([]);

  return {
    subscribe,
    setSessions: (sessions: ChatSession[]) => set(sessions),
    addSession: (session: ChatSession) => {
      update(sessions => {
        // Add new session at the beginning, remove if already exists
        const filtered = sessions.filter(s => s.id !== session.id);
        return [session, ...filtered];
      });
    },
    updateSession: (sessionId: string, updates: Partial<ChatSession>) => {
      update(sessions => sessions.map(session => 
        session.id === sessionId 
          ? { ...session, ...updates }
          : session
      ));
    },
    removeSession: (sessionId: string) => {
      update(sessions => sessions.filter(s => s.id !== sessionId));
    },
    clear: () => set([])
  };
}

// Active session store
function createActiveSessionStore() {
  const { subscribe, set, update } = writable<ChatSession | null>(null);

  return {
    subscribe,
    setSession: (session: ChatSession | null) => set(session),
  addMessage: (message: ChatMessage) => {
    update(session => {
      if (!session) return session;
      const newSession = {
        ...session,
        messages: [...session.messages, message]
      };
      console.log('✅ Store: addMessage called, old count:', session.messages.length, 'new count:', newSession.messages.length);
      return newSession;
    });
  },
    updateLastMessage: (updates: Partial<ChatMessage>) => {
      update(session => {
        if (!session || session.messages.length === 0) return session;
        const messages = [...session.messages];
        const lastMessage = messages[messages.length - 1];
        messages[messages.length - 1] = { ...lastMessage, ...updates };
        return {
          ...session,
          messages
        };
      });
    },
    appendToLastMessage: (content: string) => {
      update(session => {
        if (!session || session.messages.length === 0) return session;
        const messages = [...session.messages];
        const lastMessage = messages[messages.length - 1];
        if (lastMessage.role === MessageRole.Assistant) {
          messages[messages.length - 1] = {
            ...lastMessage,
            content: lastMessage.content + content
          };
        } else {
            // Create new streaming message
            messages.push({
              id: `streaming-${Date.now()}`,
              role: MessageRole.Assistant,
              content,
              timestamp: new Date().toISOString()
            });
        }
        return {
          ...session,
          messages
        };
      });
    },
    clear: () => set(null)
  };
}

// Chat loading/error state store
function createChatStateStore() {
  const { subscribe, update } = writable({
    loading: false,
    error: null as string | null,
    connected: false,
    isStreaming: false,
    isOnline: ConnectionMonitor.getIsOnline(),
    hasQueuedMessages: false,
    syncInProgress: false
  });

  return {
    subscribe,
    setLoading: (loading: boolean) => {
      update(state => ({ ...state, loading }));
    },
    setError: (error: string | null) => {
      update(state => ({ ...state, error }));
    },
    setConnected: (connected: boolean) => {
      update(state => ({ ...state, connected }));
    },
    setStreaming: (isStreaming: boolean) => {
      update(state => ({ ...state, isStreaming }));
    },
    setOnline: (isOnline: boolean) => {
      update(state => ({ ...state, isOnline }));
    },
    setHasQueuedMessages: (hasQueuedMessages: boolean) => {
      update(state => ({ ...state, hasQueuedMessages }));
    },
    setSyncInProgress: (syncInProgress: boolean) => {
      update(state => ({ ...state, syncInProgress }));
    },
    reset: () => {
      update(() => ({
        loading: false,
        error: null,
        connected: false,
        isStreaming: false,
        isOnline: ConnectionMonitor.getIsOnline(),
        hasQueuedMessages: false,
        syncInProgress: false
      }));
    }
  };
}

// Message composition store (for drafts, etc.)
function createCompositionStore() {
  const { subscribe, set, update } = writable({
    draft: '',
    attachments: [] as string[],
    isComposing: false,
    queuedMessageCount: 0
  });

  return {
    subscribe,
    setDraft: (draft: string) => {
      update(state => ({ ...state, draft }));
    },
    clearDraft: () => {
      update(state => ({ ...state, draft: '' }));
    },
    addAttachment: (attachment: string) => {
      update(state => ({
        ...state,
        attachments: [...state.attachments, attachment]
      }));
    },
    removeAttachment: (attachment: string) => {
      update(state => ({
        ...state,
        attachments: state.attachments.filter(a => a !== attachment)
      }));
    },
    setComposing: (isComposing: boolean) => {
      update(state => ({ ...state, isComposing }));
    },
    setQueuedMessageCount: (count: number) => {
      update(state => ({ ...state, queuedMessageCount: count }));
    },
    reset: () => {
      set({
        draft: '',
        attachments: [],
        isComposing: false,
        queuedMessageCount: 0
      });
    }
  };
}

// Create store instances
export const sessionsStore = createSessionsStore();
export const activeSessionStore = createActiveSessionStore();
export const chatStateStore = createChatStateStore();
export const compositionStore = createCompositionStore();

// Derived stores for convenience
export const activeSessions = derived(
  sessionsStore,
  $sessions => $sessions // All sessions are considered active
);

export const hasActiveSessions = derived(
  activeSessions,
  $activeSessions => $activeSessions.length > 0
);

export const currentSessionMessages = derived(
  activeSessionStore,
  $activeSession => $activeSession?.messages || []
);

export const isLoading = derived(
  chatStateStore,
  $chatState => $chatState.loading
);

export const chatError = derived(
  chatStateStore,
  $chatState => $chatState.error
);

export const isConnected = derived(
  chatStateStore,
  $chatState => $chatState.connected
);

export const isOnline = derived(
  chatStateStore,
  $chatState => $chatState.isOnline
);

export const hasQueuedMessages = derived(
  chatStateStore,
  $chatState => $chatState.hasQueuedMessages
);

export const syncInProgress = derived(
  chatStateStore,
  $chatState => $chatState.syncInProgress
);

export const queuedMessageCount = derived(
  compositionStore,
  $composition => $composition.queuedMessageCount
);

// Chat actions - higher level functions that coordinate multiple stores
export const chatActions = {
  // Initialize chat system
  initialize: async () => {
    chatStateStore.setLoading(true);
    chatStateStore.setError(null);
    
    try {
      // This will be called from components that have access to Tauri API
      chatStateStore.setConnected(true);
      chatStateStore.setLoading(false);
    } catch (error) {
      chatStateStore.setError(`Failed to initialize chat: ${error}`);
      chatStateStore.setLoading(false);
    }
  },

  // Load sessions from backend or cache
  loadSessions: async (sessionLoader?: () => Promise<ChatSession[]>) => {
    chatStateStore.setLoading(true);
    try {
      const isOnline = get(chatStateStore).isOnline;
      let sessions: ChatSession[] = [];

      if (isOnline && sessionLoader) {
        // Online: load from backend and cache
        sessions = await sessionLoader();
        // Store sessions in offline cache
        for (const session of sessions) {
          await OfflineStorage.storeSession(session);
        }
      } else {
        // Offline: load from cache
        sessions = await OfflineStorage.getStoredSessions();
        if (sessions.length === 0) {
          chatStateStore.setError('No cached conversations available. Please connect to load conversations.');
        }
      }

      sessionsStore.setSessions(sessions);

      // Load queued messages for the current session
      const currentSession = get(activeSessionStore);
      if (currentSession) {
        const queuedMessages = await OfflineStorage.getQueuedMessagesForSession(currentSession.id);
        compositionStore.setQueuedMessageCount(queuedMessages.length);
        chatStateStore.setHasQueuedMessages(queuedMessages.length > 0);
      }

      // Set first session as active if none selected
      if (!currentSession && sessions.length > 0) {
        activeSessionStore.setSession(sessions[0]);
      }
    } catch (error) {
      chatStateStore.setError(`Failed to load sessions: ${error}`);
    } finally {
      chatStateStore.setLoading(false);
    }
  },

  // Create new session
  createSession: async (sessionCreator: (title?: string) => Promise<ChatSession>) => {
    chatStateStore.setLoading(true);
    try {
      const title = `Chat ${new Date().toLocaleDateString()}`;
      const newSession = await sessionCreator(title);
      
      sessionsStore.addSession(newSession);
      activeSessionStore.setSession(newSession);
      
      return newSession;
    } catch (error) {
      chatStateStore.setError(`Failed to create session: ${error}`);
      throw error;
    } finally {
      chatStateStore.setLoading(false);
    }
  },

  // Send message
  sendMessage: async (
    content: string,
    messageSender: (sessionId: string, content: string) => Promise<void>
  ) => {
    const activeSession = get(activeSessionStore);
    console.log('📤 chatActions.sendMessage: Starting, activeSession:', activeSession?.id);
    
    if (!activeSession) {
      chatStateStore.setError('No active session');
      return;
    }

    const isOnline = get(chatStateStore).isOnline;

    // Add user message immediately
    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      role: MessageRole.User,
      content,
      timestamp: new Date().toISOString()
    };

    console.log('📤 chatActions.sendMessage: Adding user message to store:', userMessage);
    activeSessionStore.addMessage(userMessage);
    compositionStore.clearDraft();

    if (isOnline) {
      // Online: send immediately
      try {
        chatStateStore.setStreaming(true);
        await messageSender(activeSession.id, content);
        // Store the updated session
        await OfflineStorage.storeSession(activeSession);
        // Response will come via handleChatEvent
      } catch (error) {
        chatStateStore.setError(`Failed to send message: ${error}`);
        // Queue message for retry when connection is restored
        await OfflineStorage.queueMessage(activeSession.id, content);
        chatStateStore.setHasQueuedMessages(true);
        compositionStore.setQueuedMessageCount(
          get(compositionStore).queuedMessageCount + 1
        );
      } finally {
        chatStateStore.setStreaming(false);
      }
    } else {
      // Offline: queue message
      try {
        await OfflineStorage.queueMessage(activeSession.id, content);
        chatStateStore.setHasQueuedMessages(true);
        compositionStore.setQueuedMessageCount(
          get(compositionStore).queuedMessageCount + 1
        );
      } catch (error) {
        chatStateStore.setError(`Failed to queue message: ${error}`);
      }
    }
  },

  // Handle chat events from backend
  handleChatEvent: async (event: ChatEvent) => {
    if (event.SessionCreated) {
      const session = event.SessionCreated.session;
      sessionsStore.addSession(session);
      // Cache the new session
      await OfflineStorage.storeSession(session);
    } else if (event.MessageReceived) {
      const { session_id, message } = event.MessageReceived;
      const activeSession = get(activeSessionStore);

      if (activeSession && activeSession.id === session_id) {
        activeSessionStore.addMessage(message);
        // Update cached session
        const updatedSession = {
          ...activeSession,
          messages: [...activeSession.messages, message]
        };
        await OfflineStorage.storeSession(updatedSession);
      }

      // Update session in sessions store
      sessionsStore.updateSession(session_id, {
        messages: [...(activeSession?.messages || []), message]
      });
    } else if (event.MessageChunk) {
      const { session_id, chunk } = event.MessageChunk;
      const activeSession = get(activeSessionStore);

      if (activeSession && activeSession.id === session_id) {
        activeSessionStore.appendToLastMessage(chunk);
      }
    } else if (event.Error) {
      chatStateStore.setError(event.Error.message);
    }
  },

  // Select session
  selectSession: (session: ChatSession) => {
    activeSessionStore.setSession(session);
    compositionStore.reset();
  },

  // Delete session
  deleteSession: async (sessionId: string, sessionDeleter?: (id: string) => Promise<void>) => {
    try {
      if (sessionDeleter) {
        await sessionDeleter(sessionId);
      }
      
      sessionsStore.removeSession(sessionId);
      
      // If active session was deleted, select another
      const activeSession = get(activeSessionStore);
      if (activeSession?.id === sessionId) {
        const remainingSessions = get(sessionsStore);
        const nextSession = remainingSessions.length > 0 ? remainingSessions[0] : null;
        activeSessionStore.setSession(nextSession);
      }
    } catch (error) {
      chatStateStore.setError(`Failed to delete session: ${error}`);
    }
  },

  // Sync queued messages when connection is restored
  syncQueuedMessages: async (messageSender?: (sessionId: string, content: string) => Promise<void>) => {
    try {
      const result = await messageSyncManager.startSync(messageSender);

      // Update queued message count
      const allQueued = await OfflineStorage.getQueuedMessages();
      const queuedCount = allQueued.length;
      compositionStore.setQueuedMessageCount(queuedCount);
      chatStateStore.setHasQueuedMessages(queuedCount > 0);

      if (result.sent > 0) {
        console.log(`Synced ${result.sent} queued messages`);
      }

      if (result.failed > 0) {
        chatStateStore.setError(`${result.failed} messages failed to sync`);
      }

      return result;
    } catch (error) {
      chatStateStore.setError(`Failed to sync messages: ${error}`);
      return { sent: 0, failed: 0, success: false, conflicts: 0, duration: 0, errors: [], sessionUpdates: [] };
    }
  },

  // Initialize offline functionality
  initializeOffline: () => {
    // Monitor connection status
    ConnectionMonitor.addListener((isOnline) => {
      chatStateStore.setOnline(isOnline);
    });

    // Load cached data on initialization
    chatActions.loadSessions();
  },

  // Get offline storage stats
  getOfflineStats: async () => {
    try {
      return await OfflineStorage.getStorageStats();
    } catch (error) {
      console.error('Failed to get offline stats:', error);
      return null;
    }
  },

  // Clear offline data
  clearOfflineData: async () => {
    try {
      await OfflineStorage.clearAllData();
      chatStateStore.setHasQueuedMessages(false);
      compositionStore.setQueuedMessageCount(0);
      // Reload sessions (will be empty now)
      await chatActions.loadSessions();
    } catch (error) {
      chatStateStore.setError(`Failed to clear offline data: ${error}`);
    }
  },

  // Clear error
  clearError: () => {
    chatStateStore.setError(null);
  },

  // Reset all stores
  reset: () => {
    sessionsStore.clear();
    activeSessionStore.clear();
    chatStateStore.reset();
    compositionStore.reset();
  }
};

// Export chat store bundle for easy importing
export const chatStore = {
  sessions: sessionsStore,
  activeSession: activeSessionStore,
  state: chatStateStore,
  composition: compositionStore,
  actions: chatActions,

  // Derived stores
  activeSessions,
  hasActiveSessions,
  currentSessionMessages,
  isLoading,
  chatError,
  isConnected,
  isOnline,
  hasQueuedMessages,
  syncInProgress,
  queuedMessageCount
};

// Type exports for external use
export type ChatStore = typeof chatStore;
export type ChatActions = typeof chatActions;
