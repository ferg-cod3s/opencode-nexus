// Chat page JavaScript - separate file for E2E test compatibility
import { invoke, listen } from './utils/tauri-api.js';
import { mount } from 'svelte';
import ChatInterface from './components/ChatInterface.svelte';
import SessionGrid from './components/SessionGrid.svelte';
import type { ChatSession } from './types/chat';
import { chatStore } from './stores/chat';
import { get } from 'svelte/store';

// Components
// eslint-disable-next-line @typescript-eslint/no-unused-vars
let sessionGridComponent: any = null;
let chatInterfaceComponent: any = null;

// DOM elements
const chatRoot = document.getElementById('chat-root')!;
let sessionsSidebar: HTMLElement;
let chatMain: HTMLElement;

async function initializeChat() {
  console.log('🔍 Chat page: Starting initialization...');

  try {
    chatStore.state.setLoading(true);

    // Load user info
    const userInfo = await invoke<[string, string, string | null] | null>('get_user_info');
    console.log('🔍 Chat page: User info loaded:', userInfo);

    if (userInfo) {
      const usernameDisplay = document.getElementById('username-display');
      if (usernameDisplay) {
        usernameDisplay.textContent = userInfo[0];
      }
    }

    // Load sessions using store action
    await chatStore.actions.loadSessions(loadSessions);

    console.log('🔍 Chat page: Sessions loaded, count:', get(chatStore.sessions).length);

    // Auto-create a session if none exist
    const sessions = get(chatStore.sessions);
    if (sessions.length === 0) {
      console.log('🆕 No sessions found, creating default session...');
      await chatStore.actions.createSession(async (title) => {
        const sessionTitle = title || `Chat ${new Date().toLocaleDateString()}`;
        const session = await invoke<ChatSession>('create_chat_session', { title: sessionTitle });
        console.log('✅ Created default session:', session);
        return session;
      });
    }

    // Mount components
    mountComponents();

    // Listen for chat events
    await listen('chat-event', (event: any) => {
      console.log('📨 Chat event received:', event);
      chatStore.actions.handleChatEvent(event.payload);
    });

    chatStore.state.setConnected(true);
    console.log('✅ Chat page: Initialization complete');
  } catch (e) {
    console.error('❌ Failed to initialize chat:', e);
    chatStore.state.setError(`Failed to initialize: ${e}`);
    showError(`Failed to initialize: ${e}`);
  } finally {
    chatStore.state.setLoading(false);
  }
}

async function loadSessions(): Promise<ChatSession[]> {
  try {
    const loadedSessions = await invoke<ChatSession[]>('get_chat_sessions');
    console.log('📋 Loaded sessions from backend:', loadedSessions);
    return loadedSessions;
  } catch (e) {
    console.error('Failed to load chat sessions:', e);
    throw e;
  }
}

function mountComponents() {
  // Clear loading state
  chatRoot.innerHTML = '';

  // Create layout structure
  const appLayout = document.createElement('div');
  appLayout.className = 'app-layout';

  // Sessions sidebar
  sessionsSidebar = document.createElement('aside');
  sessionsSidebar.className = 'sessions-sidebar';
  sessionsSidebar.setAttribute('aria-label', 'Chat Sessions');

  // Chat main area
  chatMain = document.createElement('main');
  chatMain.className = 'chat-main';
  chatMain.setAttribute('role', 'main');
  chatMain.setAttribute('aria-label', 'Chat Interface');

  appLayout.appendChild(sessionsSidebar);
  appLayout.appendChild(chatMain);
  chatRoot.appendChild(appLayout);

  // Mount components once - they will subscribe to stores internally
  renderSessionGrid();
  renderChatInterface();

  // Subscribe to store changes - only remount when necessary
  let lastSessions = get(chatStore.sessions);
  let lastActiveSessionId = get(chatStore.activeSession)?.id;

  chatStore.sessions.subscribe((sessions) => {
    if (sessions.length !== lastSessions.length) {
      lastSessions = sessions;
      renderSessionGrid();
    }
  });

  chatStore.activeSession.subscribe((session) => {
    const currentSessionId = session?.id;
    if (currentSessionId !== lastActiveSessionId) {
      lastActiveSessionId = currentSessionId;
      console.log('📌 Active session changed to:', currentSessionId);
      // ChatInterface subscribes to store, so no need to remount
    }
  });
}

function renderSessionGrid() {
  if (!sessionsSidebar) return;
  
  sessionsSidebar.innerHTML = '';
  sessionGridComponent = mount(SessionGrid, {
    target: sessionsSidebar,
    props: {
      sessions: get(chatStore.sessions),
      activeSessionId: get(chatStore.activeSession)?.id || null,
      loading: get(chatStore.state).loading,
      onCreateSession: async () => {
        await chatStore.actions.createSession(async (title) => {
          const sessionTitle = title || `Chat ${new Date().toLocaleDateString()}`;
          const session = await invoke<ChatSession>('create_chat_session', { title: sessionTitle });
          console.log('✅ Created new session:', session);
          return session;
        });
      },
      onSelectSession: (session: ChatSession) => {
        chatStore.activeSession.setSession(session);
      },
      onDeleteSession: async (sessionId: string) => {
        await chatStore.actions.deleteSession(sessionId, async (id) => {
          await invoke<void>('delete_chat_session', { session_id: id });
        });
      }
    }
  });
}

function renderChatInterface() {
  if (!chatMain) return;
  
  if (!chatInterfaceComponent) {
    // Mount once - component will subscribe to stores internally
    console.log('🆕 Mounting chat interface (subscribes to store)');
    chatInterfaceComponent = mount(ChatInterface, {
      target: chatMain,
      props: {
        // Don't pass session - component will get from store
        onSendMessage: async (content: string) => {
          console.log('📤 Sending message:', content);
          await chatStore.actions.sendMessage(content, async (sessionId, msg) => {
            await invoke<void>('send_chat_message', {
              session_id: sessionId,
              content: msg
            });
          });
        },
        onClose: () => {
          window.location.href = '/dashboard';
        }
      }
    });
  }
}

function showError(errorMessage: string) {
  const errorDiv = document.createElement('div');
  errorDiv.className = 'error-banner';
  errorDiv.innerHTML = `
    <span class="error-icon">⚠️</span>
    <span class="error-message">${errorMessage}</span>
    <button class="error-dismiss" onclick="this.parentElement.remove()">×</button>
  `;

  chatRoot.insertBefore(errorDiv, chatRoot.firstChild);
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeChat);
} else {
  initializeChat();
}
