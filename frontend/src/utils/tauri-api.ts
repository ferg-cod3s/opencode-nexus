/**
 * Tauri API wrapper that provides fallbacks for browser/E2E test environments
 * In actual Tauri app: Uses real Tauri API
 * In browser/tests: Uses mocked API for testing
 */

// Check if we're running in a Tauri environment
export const isTauriEnvironment = (): boolean => {
  return typeof window !== 'undefined' && '__TAURI__' in window;
};

// Mock data for testing
const MOCK_TEST_USER = {
  username: 'testuser',
  password: 'SecurePass123!'
};

// Mock API responses for E2E tests
const mockApi = {
  // Authentication APIs
  authenticate_user: async (args: { username: string; password: string }): Promise<boolean> => {
    console.log(`[MOCK API] authenticate_user called with:`, args);
    return args.username === MOCK_TEST_USER.username && args.password === MOCK_TEST_USER.password;
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
    return;
  },
  
  get_onboarding_state: async (): Promise<any> => {
    console.log(`[MOCK API] get_onboarding_state called`);
    return {
      config: {
        is_completed: true,
        opencode_server_path: '/fake/test/path/opencode',
        owner_account_created: true,
        owner_username: MOCK_TEST_USER.username,
        created_at: '2024-01-01T12:00:00Z',
        updated_at: '2024-01-01T12:00:00Z'
      },
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
      status: 'Stopped',
      pid: null,
      port: 4096,
      host: '127.0.0.1',
      started_at: null,
      last_error: null,
      version: null,
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
    return [
      {
        id: 'mock-chat-1',
        title: 'Mock Chat Session',
        created_at: '2024-01-01T12:00:00Z',
        updated_at: '2024-01-01T13:00:00Z',
        message_count: 5
      }
    ];
  },

  create_chat_session: async (args: { title?: string }): Promise<any> => {
    console.log(`[MOCK API] create_chat_session called with:`, args);
    return {
      id: 'mock-chat-new',
      title: args.title || 'New Mock Chat',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      message_count: 0
    };
  },

  get_chat_session_history: async (args: { session_id: string }): Promise<any[]> => {
    console.log(`[MOCK API] get_chat_session_history called with:`, args);
    return [
      {
        id: 'msg-1',
        role: 'user',
        content: 'Hello, this is a mock message!',
        timestamp: '2024-01-01T12:00:00Z'
      },
      {
        id: 'msg-2',
        role: 'assistant',
        content: 'Hello! This is a mock response from the assistant.',
        timestamp: '2024-01-01T12:01:00Z'
      }
    ];
  },

  send_chat_message: async (args: { session_id: string; content: string }): Promise<any> => {
    console.log(`[MOCK API] send_chat_message called with:`, args);
    return {
      id: 'msg-response',
      role: 'assistant',
      content: `Mock response to: "${args.content}"`,
      timestamp: new Date().toISOString()
    };
  },

  start_message_stream: async (): Promise<void> => {
    console.log(`[MOCK API] start_message_stream called`);
    return;
  },

  is_authenticated: async (): Promise<boolean> => {
    console.log(`[MOCK API] is_authenticated called`);
    return true;
  }
};

/**
 * Invoke a Tauri command with automatic fallback to mock API in browser environments
 */
export const invoke = async <T = any>(command: string, args?: Record<string, any>): Promise<T> => {
  console.log(`[API] Invoking command: ${command}`, args);

  if (isTauriEnvironment()) {
    try {
      // Use real Tauri API
      const { invoke } = await import('@tauri-apps/api/core');
      const result = await invoke<T>(command, args);
      console.log(`[TAURI API] ${command} result:`, result);
      return result;
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
  if (isTauriEnvironment()) {
    try {
      // Use real Tauri event API
      const { listen } = await import('@tauri-apps/api/event');
      return await listen(event, handler);
    } catch (error) {
      console.error(`[TAURI EVENT] Failed to listen to ${event}:`, error);
      throw error;
    }
  } else {
    // Mock event listener for browser/test environments
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
  }
};

/**
 * Mock implementation for emitting events (mainly for testing)
 */
export const emit = async (event: string, payload?: any): Promise<void> => {
  if (isTauriEnvironment()) {
    try {
      const { emit } = await import('@tauri-apps/api/event');
      await emit(event, payload);
    } catch (error) {
      console.error(`[TAURI EVENT] Failed to emit ${event}:`, error);
      throw error;
    }
  } else {
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
    (window.location.port === '1420' || window.location.port === '4173')
  );
  
  return {
    isTauri,
    canAuthenticate: isTauri || isTest,
    environment: isTauri ? 'tauri' : (isTest ? 'test' : 'browser')
  };
};