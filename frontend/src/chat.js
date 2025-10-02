// Chat interface initialization for E2E tests
// This file properly mounts the Svelte ChatInterface component

console.log('🔍 Chat.js: Initializing chat system for E2E tests...');

// Import and mount the actual ChatInterface component
import ChatInterface from './components/ChatInterface.svelte';
import { activeSessionStore, chatStateStore, chatActions } from './stores/chat';
import { get } from 'svelte/store';

async function initializeChatForTests() {
  try {
    console.log('🔍 Chat.js: Starting initialization...');

    // Display username from sessionStorage
    const username = sessionStorage.getItem('username') || 'User';
    const usernameDisplay = document.getElementById('username-display');
    if (usernameDisplay) {
      usernameDisplay.textContent = username;
    }

    // Set up logout functionality
    const logoutButton = document.getElementById('logout-button');
    if (logoutButton) {
      logoutButton.addEventListener('click', async () => {
        sessionStorage.clear();
        window.location.href = '/login';
      });
    }

    // Import Tauri API
    const { invoke } = await import('./utils/tauri-api.js');

    // Initialize chat stores
    await chatActions.initialize();

    // Load existing sessions
    try {
      const sessions = await invoke('get_chat_sessions');
      console.log('🔍 Chat.js: Loaded sessions:', sessions);
      
      if (sessions && sessions.length > 0) {
        // Set sessions in store
        sessions.forEach(session => {
          activeSessionStore.setSession(session);
        });
        // Set first session as active
        activeSessionStore.setSession(sessions[0]);
      } else {
        // Create a default test session
        console.log('🔍 Chat.js: No sessions found, creating default session...');
        const defaultSession = {
          id: `test-session-${Date.now()}`,
          title: 'Test Session',
          messages: [],
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        activeSessionStore.setSession(defaultSession);
      }
    } catch (error) {
      console.warn('🔍 Chat.js: Failed to load sessions, creating default:', error);
      // Create default session for testing
      const defaultSession = {
        id: `test-session-${Date.now()}`,
        title: 'Test Session',
        messages: [],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };
      activeSessionStore.setSession(defaultSession);
    }

    // Remove loading state
    const chatRoot = document.getElementById('chat-root');
    if (chatRoot) {
      const loadingState = document.getElementById('loading-state');
      if (loadingState) {
        loadingState.remove();
      }

      // Mount the real ChatInterface component
      console.log('🔍 Chat.js: Mounting ChatInterface component...');
      const chatInterface = new ChatInterface({
        target: chatRoot,
        props: {
          onSendMessage: async (content) => {
            console.log('🔍 Chat.js: Sending message:', content);
            const activeSession = get(activeSessionStore);
            
            if (!activeSession) {
              console.error('🔍 Chat.js: No active session');
              return;
            }

            try {
              await invoke('send_chat_message', { 
                session_id: activeSession.id, 
                content 
              });
              console.log('🔍 Chat.js: Message sent successfully');
            } catch (error) {
              console.error('🔍 Chat.js: Failed to send message:', error);
              chatStateStore.setError(`Failed to send message: ${error}`);
            }
          },
          onClose: () => {
            console.log('🔍 Chat.js: Chat closed');
          }
        }
      });

      console.log('🔍 Chat.js: ChatInterface mounted successfully');
    } else {
      console.error('🔍 Chat.js: Could not find #chat-root element');
    }

  } catch (error) {
    console.error('🔍 Chat.js: Initialization failed:', error);
    
    // Show error state
    const chatRoot = document.getElementById('chat-root');
    if (chatRoot) {
      chatRoot.innerHTML = `
        <div class="error-state" data-testid="chat-error">
          <h2>Chat Unavailable</h2>
          <p>Failed to initialize: ${error.message || error}</p>
          <button onclick="window.location.reload()">Retry</button>
        </div>
      `;
    }
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeChatForTests);
} else {
  initializeChatForTests();
}
