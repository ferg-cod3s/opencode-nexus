/**
 * Tauri API wrapper that provides fallbacks for browser/E2E test environments
 * In actual Tauri app: Uses real Tauri API
 * In browser/tests: Uses mocked API for testing
 */

import type { OnboardingState } from '../types/onboarding';

// Check if we're running in a Tauri environment
export const isTauriEnvironment = (): boolean => {
  return typeof window !== 'undefined' && '__TAURI__' in window;
};

// Import Tauri APIs (only available in Tauri environment)
let tauriInvoke: ((cmd: string, args?: any) => Promise<any>) | null = null;
let tauriListen: ((event: string, handler: (event: any) => void) => Promise<() => void>) | undefined = undefined;
let tauriEmit: ((event: string, payload?: any) => Promise<void>) | undefined = undefined;

// Load Tauri APIs if in Tauri environment
if (isTauriEnvironment()) {
  try {
    // Use require-style dynamic import for Tauri APIs
    const win = window as any;
    if (win.__TAURI_INTERNALS__) {
      tauriInvoke = win.__TAURI_INTERNALS__.invoke;
    }
  } catch (error) {
    console.warn('[TAURI API] Failed to load Tauri invoke API:', error);
  }
}

// Mock data for testing
const MOCK_TEST_USER = {
  username: 'testuser',
  password: 'SecurePass123!'
};

// Mock storage for chat sessions and messages (persists in localStorage for E2E tests)
const getMockChatStorage = (): Map<string, any> => {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('mockChatStorage');
    return stored ? new Map<string, any>(JSON.parse(stored)) : new Map<string, any>();
  }
  return new Map<string, any>();
};

const setMockChatStorage = (storage: Map<string, any>) => {
  if (typeof window !== 'undefined') {
    localStorage.setItem('mockChatStorage', JSON.stringify(Array.from(storage.entries())));
  }
};

// Mock storage for authentication state (persists in localStorage for E2E tests)
const getMockAuthStorage = () => {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('mockAuthStorage');
    if (stored) {
      const parsed = JSON.parse(stored);
      return {
        ...parsed,
        lockedUntil: parsed.lockedUntil ? new Date(parsed.lockedUntil) : null
      };
    }
  }
  return {
    failedAttempts: 0,
    lockedUntil: null as Date | null,
    lockoutDuration: 30 * 60 * 1000 // 30 minutes in milliseconds
  };
};

const setMockAuthStorage = (storage: any) => {
  if (typeof window !== 'undefined') {
    localStorage.setItem('mockAuthStorage', JSON.stringify(storage));
  }
};

// Mock API responses for E2E tests
const mockApi = {
  // Authentication APIs
  authenticate_user: async (args: { username: string; password: string }): Promise<boolean> => {
    console.log(`[MOCK API] authenticate_user called with:`, args);

    const authStorage = getMockAuthStorage();

    // Check if account is locked
    if (authStorage.lockedUntil && new Date() < authStorage.lockedUntil) {
      console.log(`[MOCK API] Account is locked until:`, authStorage.lockedUntil);
      throw new Error('Account is temporarily locked due to too many failed attempts');
    }

    // Simulate authentication delay
    await new Promise(resolve => setTimeout(resolve, 100));

    const isValid = args.username === MOCK_TEST_USER.username && args.password === MOCK_TEST_USER.password;
    console.log(`[MOCK API] Authentication result:`, isValid);

    if (!isValid) {
      authStorage.failedAttempts++;
      console.log(`[MOCK API] Failed attempts:`, authStorage.failedAttempts);

      // Lock account after 5 failed attempts
      if (authStorage.failedAttempts >= 5) {
        authStorage.lockedUntil = new Date(Date.now() + authStorage.lockoutDuration);
        console.log(`[MOCK API] Account locked until:`, authStorage.lockedUntil);
        setMockAuthStorage(authStorage);
        throw new Error('Account locked due to too many failed attempts');
      }
      setMockAuthStorage(authStorage);
    } else {
      // Reset failed attempts on successful login
      authStorage.failedAttempts = 0;
      authStorage.lockedUntil = null;
      setMockAuthStorage(authStorage);
    }

    return isValid;
  },

  is_auth_configured: async (): Promise<boolean> => {
    console.log(`[MOCK API] is_auth_configured called`);
    return true;
  },

  create_owner_account: async (args: { username: string; password: string }): Promise<void> => {
    console.log(`[MOCK API] create_owner_account called with:`, args);
    return;
  },

  get_user_info: async (): Promise<[string, string, string | null] | null> => {
    console.log(`[MOCK API] get_user_info called`);
    return [MOCK_TEST_USER.username, '2024-01-01 12:00:00 UTC', '2024-01-01 13:00:00 UTC'];
  },

  // Onboarding APIs
  complete_onboarding: async (args: { opencode_server_path?: string }): Promise<void> => {
    console.log(`[MOCK API] complete_onboarding called with:`, args);
    localStorage.setItem('mockOnboardingComplete', 'true');
    return;
  },

  setup_opencode_server: async (): Promise<void> => {
    console.log(`[MOCK API] setup_opencode_server called`);
    return;
  },

  create_owner_account: async (args: { username: string; password: string }): Promise<void> => {
    console.log(`[MOCK API] create_owner_account called with username:`, args.username);
    return;
  },

   get_onboarding_state: async (): Promise<OnboardingState> => {
     console.log(`[MOCK API] get_onboarding_state called`);
     
     // Check if we should simulate incomplete onboarding (for onboarding tests)
     // If we're on the onboarding page, assume onboarding is NOT complete
     const isOnboardingPage = typeof window !== 'undefined' && window.location.pathname === '/onboarding';
     const isCompleted = !isOnboardingPage && (
       typeof window !== 'undefined' && localStorage.getItem('mockOnboardingComplete') === 'true'
     );
     
     return {
       config: isCompleted ? {
         is_completed: true,
         opencode_server_path: '/fake/test/path/opencode',
         owner_account_created: true,
         owner_username: 'testuser',
         created_at: new Date().toISOString(),
         updated_at: new Date().toISOString()
       } : null,
       system_requirements: {
         os_compatible: true,
         memory_sufficient: true,
         disk_space_sufficient: true,
         network_available: true,
         required_permissions: true
       },
       opencode_detected: true,
       opencode_path: '/fake/test/path/opencode'
     };
   },

  // Server Management APIs
  get_server_info: async (): Promise<any> => {
    console.log(`[MOCK API] get_server_info called`);
    return {
      status: 'Running',
      pid: 12345,
      port: 4096,
      host: '127.0.0.1',
      started_at: '2024-01-01T12:00:00Z',
      last_error: null,
      version: '1.0.0',
      binary_path: '/fake/test/path/opencode'
    };
  },

  get_server_metrics: async (): Promise<any> => {
    console.log(`[MOCK API] get_server_metrics called`);
    return {
      cpu_usage: 15.5,
      memory_usage: 268435456, // 256MB in bytes
      uptime: { secs: 3600, nanos: 0 }, // 1 hour
      request_count: 150,
      error_count: 2
    };
  },

  start_opencode_server: async (): Promise<void> => {
    console.log(`[MOCK API] start_opencode_server called`);
    return;
  },

  stop_opencode_server: async (): Promise<void> => {
    console.log(`[MOCK API] stop_opencode_server called`);
    return;
  },

  restart_opencode_server: async (): Promise<void> => {
    console.log(`[MOCK API] restart_opencode_server called`);
    return;
  },

  // Session Management APIs
  get_active_sessions: async (): Promise<any[]> => {
    console.log(`[MOCK API] get_active_sessions called`);
    return [
      {
        session_id: 'mock-session-1',
        created_at: '2024-01-01T12:00:00Z',
        last_activity: '2024-01-01T13:00:00Z',
        status: 'Active',
        client_info: 'Mock Client'
      }
    ];
  },

  get_session_stats: async (): Promise<any> => {
    console.log(`[MOCK API] get_session_stats called`);
    return {
      total_sessions: 5,
      active_sessions: 1,
      total_messages: 42,
      avg_session_duration: { secs: 1800, nanos: 0 } // 30 minutes
    };
  },

  // Chat APIs
  get_chat_sessions: async (): Promise<any[]> => {
    console.log(`[MOCK API] get_chat_sessions called`);

    const chatStorage = getMockChatStorage();

    // Return stored sessions or create a default one
    const sessions = Array.from(chatStorage.values()).filter((session: any) => session.type === 'session');
    if (sessions.length === 0) {
      // Create a default session
      const defaultSession = {
        id: 'mock-chat-1',
        title: 'Chat Session',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 0,
        messages: [],
        type: 'session'
      };
      chatStorage.set('mock-chat-1', defaultSession);
      setMockChatStorage(chatStorage);
      return [defaultSession];
    }

    return sessions;
  },

  create_chat_session: async (args: { title?: string }): Promise<any> => {
    console.log(`[MOCK API] create_chat_session called with:`, args);
    const chatStorage = getMockChatStorage();
    const sessionId = `mock-chat-${Date.now()}`;
    const session = {
      id: sessionId,
      title: args.title || 'New Chat',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      message_count: 0,
      messages: [],
      type: 'session'
    };
    chatStorage.set(sessionId, session);
    setMockChatStorage(chatStorage);
    return session;
  },

  get_chat_session_history: async (args: { session_id: string }): Promise<any[]> => {
    console.log(`[MOCK API] get_chat_session_history called with:`, args);
    const chatStorage = getMockChatStorage();
    const session = chatStorage.get(args.session_id);
    return session ? session.messages : [];
  },

  send_chat_message: async (args: { session_id: string; content: string }): Promise<void> => {
    console.log(`[MOCK API] send_chat_message called with:`, args);

    const chatStorage = getMockChatStorage();

    // Get or create session
    let session = chatStorage.get(args.session_id);
    if (!session) {
      session = {
        id: args.session_id,
        title: 'Chat Session',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 0,
        messages: [],
        type: 'session'
      };
      chatStorage.set(args.session_id, session);
    }

    // Add user message to session
    const userMessage = {
      id: `user-msg-${Date.now()}`,
      role: 'user',
      content: args.content,
      timestamp: new Date().toISOString()
    };
    session.messages.push(userMessage);
    session.message_count = session.messages.length;
    session.updated_at = new Date().toISOString();

    // Save updated session
    chatStorage.set(args.session_id, session);
    setMockChatStorage(chatStorage);

    // Simulate AI response
    const fullResponse = `I received your message: "${args.content}". This is a mock AI response that acknowledges what you said. In a real implementation, this would be generated by an AI model.`;

    const chunkSize = 50;
    const chunks: string[] = [];
    for (let i = 0; i < fullResponse.length; i += chunkSize) {
      chunks.push(fullResponse.slice(i, i + chunkSize));
    }

    // Emit chunks at short intervals
    chunks.forEach((chunk, index) => {
      setTimeout(() => {
        emit('chat-event', {
          MessageChunk: { session_id: args.session_id, chunk }
        });
      }, 100 * index);
    });

    // Emit final received message after all chunks
    const finalMessage = {
      id: `assistant-msg-${Date.now()}`,
      role: 'assistant',
      content: fullResponse,
      timestamp: new Date().toISOString()
    };

    setTimeout(() => {
      // Reload storage and update session
      const updatedChatStorage = getMockChatStorage();
      const updatedSession = updatedChatStorage.get(args.session_id);
      if (updatedSession) {
        updatedSession.messages.push(finalMessage);
        updatedSession.message_count = updatedSession.messages.length;
        setMockChatStorage(updatedChatStorage);
      }

      emit('chat-event', {
        MessageReceived: { session_id: args.session_id, message: finalMessage }
      });
    }, 100 * chunks.length + 50);
  },

  start_message_stream: async (): Promise<void> => {
    console.log(`[MOCK API] start_message_stream called`);
    return;
  },

  is_authenticated: async (): Promise<boolean> => {
    console.log(`[MOCK API] is_authenticated called`);
    return true;
  },

  is_account_locked: async (): Promise<{ locked: boolean; unlockTime?: string }> => {
    console.log(`[MOCK API] is_account_locked called`);
    const authStorage = getMockAuthStorage();
    const locked = authStorage.lockedUntil && new Date() < authStorage.lockedUntil;
    return {
      locked,
      unlockTime: locked ? authStorage.lockedUntil!.toISOString() : undefined
    };
  },

  get_application_logs: async (): Promise<string[]> => {
    console.log(`[MOCK API] get_application_logs called`);
    return [
      '[2024-01-01 12:00:00 UTC] 🔍 Index page: Starting initialization...',
      '[2024-01-01 12:00:01 UTC] 🔐 [AUTH] Checking authentication status...',
      '[2024-01-01 12:00:02 UTC] 👤 [USER] Getting user information...',
      '[2024-01-01 12:00:03 UTC] 🚀 [ONBOARDING] Getting onboarding state...'
    ];
  }
};

/**
 * Invoke a Tauri command with automatic fallback to mock API in browser environments
 */
export const invoke = async <T = any>(command: string, args?: Record<string, any>): Promise<T> => {
  console.log(`[API] Invoking command: ${command}`, args);
  console.log(`[API] Environment check:`, checkEnvironment());

  if (isTauriEnvironment() && tauriInvoke) {
    try {
      // Use real Tauri API
      const result = await tauriInvoke(command, args);
      console.log(`[TAURI API] ${command} result:`, result);
      return result as T;
    } catch (error) {
      console.error(`[TAURI API] Command ${command} failed:`, error);
      throw error;
    }
  } else {
    // Use mock API for browser/E2E testing
    console.log(`[MOCK API] Using mock implementation for ${command}`);

    if (command in mockApi) {
      try {
        const result = await (mockApi as any)[command](args);
        console.log(`[MOCK API] ${command} result:`, result);
        return result;
      } catch (error) {
        console.error(`[MOCK API] Command ${command} failed:`, error);
        throw error;
      }
    } else {
      console.warn(`[MOCK API] No mock implementation for command: ${command}`);
      throw new Error(`Mock API: Command '${command}' not implemented`);
    }
  }
};

// Mock event system for browser/test environments
const mockEventListeners = new Map<string, Function[]>();

/**
 * Mock implementation of Tauri's event listening system
 */
export const listen = async (event: string, handler: (event: any) => void): Promise<() => void> => {
  if (isTauriEnvironment() && tauriListen) {
    try {
      // Use real Tauri event API
      return await tauriListen(event, handler);
    } catch (error) {
      console.error(`[TAURI EVENT] Failed to listen to ${event}:`, error);
    }
  }

  // Use mock event system
  console.log(`[MOCK EVENT] Listening to event: ${event}`);

  if (!mockEventListeners.has(event)) {
    mockEventListeners.set(event, []);
  }

  mockEventListeners.get(event)!.push(handler);

  // Return unsubscribe function
  return () => {
    const listeners = mockEventListeners.get(event);
    if (listeners) {
      const index = listeners.indexOf(handler);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    }
  };
};

/**
 * Mock implementation for emitting events (mainly for testing)
 */
export const emit = async (event: string, payload?: any): Promise<void> => {
  if (isTauriEnvironment() && tauriEmit) {
    try {
      await tauriEmit(event, payload);
      return;
    } catch (error) {
      console.error(`[TAURI EVENT] Failed to emit ${event}:`, error);
    }
  }

  console.log(`[MOCK EVENT] Emitting event: ${event}`, payload);
  const listeners = mockEventListeners.get(event);
  if (listeners) {
    listeners.forEach(handler => {
      try {
        handler({ payload });
      } catch (error) {
        console.error(`[MOCK EVENT] Error in event handler for ${event}:`, error);
      }
    });
  }
};

/**
 * Check if the current environment supports Tauri functionality
 */
export const checkEnvironment = (): {
  isTauri: boolean;
  canAuthenticate: boolean;
  environment: 'tauri' | 'browser' | 'test'
} => {
  const isTauri = isTauriEnvironment();

  // Detect test environment
  const isTest = typeof window !== 'undefined' && (
    window.location.hostname === 'localhost' &&
    (window.location.port === '1420' || window.location.port === '1421' || window.location.port === '4173')
  );

  return {
    isTauri,
    canAuthenticate: isTauri || isTest,
    environment: isTauri ? 'tauri' : (isTest ? 'test' : 'browser')
  };
};