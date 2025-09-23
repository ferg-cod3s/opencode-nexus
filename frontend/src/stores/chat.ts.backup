import { writable, derived, get } from 'svelte/store';
import type { ChatSession, ChatMessage, ChatEvent } from '../types/chat';
import { MessageRole } from '../types/chat';

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
        return {
          ...session,
          messages: [...session.messages, message]
        };
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
    isStreaming: false
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
    reset: () => {
      update(() => ({
        loading: false,
        error: null,
        connected: false,
        isStreaming: false
      }));
    }
  };
}

// Message composition store (for drafts, etc.)
function createCompositionStore() {
  const { subscribe, set, update } = writable({
    draft: '',
    attachments: [] as string[],
    isComposing: false
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
    reset: () => {
      set({
        draft: '',
        attachments: [],
        isComposing: false
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

  // Load sessions from backend
  loadSessions: async (sessionLoader: () => Promise<ChatSession[]>) => {
    chatStateStore.setLoading(true);
    try {
      const sessions = await sessionLoader();
      sessionsStore.setSessions(sessions);
      
      // Set first session as active if none selected
      const currentSession = get(activeSessionStore);
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
    if (!activeSession) {
      chatStateStore.setError('No active session');
      return;
    }

    // Add user message immediately
    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      role: MessageRole.User,
      content,
      timestamp: new Date().toISOString()
    };

    activeSessionStore.addMessage(userMessage);
    compositionStore.clearDraft();
    
    try {
      chatStateStore.setStreaming(true);
      await messageSender(activeSession.id, content);
      // Response will come via handleChatEvent
    } catch (error) {
      chatStateStore.setError(`Failed to send message: ${error}`);
    } finally {
      chatStateStore.setStreaming(false);
    }
  },

  // Handle chat events from backend
  handleChatEvent: (event: ChatEvent) => {
    if (event.SessionCreated) {
      sessionsStore.addSession(event.SessionCreated.session);
    } else if (event.MessageReceived) {
      const { session_id, message } = event.MessageReceived;
      const activeSession = get(activeSessionStore);
      
      if (activeSession && activeSession.id === session_id) {
        activeSessionStore.addMessage(message);
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
  isConnected
};

// Type exports for external use
export type ChatStore = typeof chatStore;
export type ChatActions = typeof chatActions;