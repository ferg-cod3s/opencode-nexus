// Chat page JavaScript - separate file for E2E test compatibility
import { invoke, listen } from './utils/tauri-api.js';
import { mount } from 'svelte';
import ChatInterface from './components/ChatInterface.svelte';
import SessionGrid from './components/SessionGrid.svelte';
import type { ChatSession, ChatMessage } from './types/chat';

// Chat event types
enum MessageRole {
  User = 'user',
  Assistant = 'assistant'
}

interface ChatEvent {
  SessionCreated?: { session: ChatSession };
  MessageReceived?: { session_id: string; message: ChatMessage };
  MessageChunk?: { session_id: string; chunk: string };
  Error?: { message: string };
}

// State
let sessions: ChatSession[] = [];
let currentSession: ChatSession | null = null;
let loading = true;
let error = '';

// Components
let sessionGridComponent: any = null;
let chatInterfaceComponent: any = null;

// DOM elements
const chatRoot = document.getElementById('chat-root')!;

async function initializeChat() {
  console.log('🔍 Chat page: Starting initialization...');

  try {
    // Load user info
    const userInfo = await invoke<[string, string, string | null] | null>('get_user_info');
    console.log('🔍 Chat page: User info loaded:', userInfo);

    if (userInfo) {
      const usernameDisplay = document.getElementById('username-display');
      if (usernameDisplay) {
        usernameDisplay.textContent = userInfo[0];
      }
    }

    // Load sessions
    await loadSessions();

    // Setup event listeners
    await setupEventListeners();

    // Start message streaming for real-time AI responses
    await startMessageStreaming();

    loading = false;

    // Mount components
    mountComponents();

    // Hide loading state only on success
    chatRoot.classList.add("loaded");

    console.log('🔍 Chat page: Initialization complete');

  } catch (e) {
    console.error('❌ Chat page: Failed to initialize chat:', e);
    error = `Failed to initialize chat: ${e}`;
    showError(error);
    loading = false; // Only set loading to false on error
  }
}

async function loadSessions() {
  try {
    sessions = await invoke<ChatSession[]>('get_chat_sessions') || [];
    console.log(`Loaded ${sessions.length} chat sessions`);

    // If no sessions exist, create a default one
    if (sessions.length === 0) {
      await createNewSession();
    } else {
      // Load the most recent session
      currentSession = sessions[0];
      await loadSessionHistory(currentSession.id);
    }
  } catch (e) {
    console.error('Failed to load sessions:', e);
    throw new Error(`Failed to load sessions: ${e}`);
  }
}

async function createNewSession(title?: string) {
  try {
    const newSession = await invoke<ChatSession>('create_chat_session', {
      title: title || `Chat ${new Date().toLocaleDateString()}`
    });

    sessions = [newSession, ...sessions];
    currentSession = newSession;

    console.log('Created new session:', newSession.id);
    updateComponents();

    return newSession;
  } catch (e) {
    console.error('Failed to create session:', e);
    throw new Error(`Failed to create session: ${e}`);
  }
}

async function loadSessionHistory(sessionId: string) {
  try {
    if (!currentSession) return;

    const messages = await invoke<ChatMessage[]>('get_chat_session_history', { session_id: sessionId });
    if (messages) {
      currentSession.messages = messages || [];
      updateComponents();
    }
  } catch (e) {
    console.error('Failed to load session history:', e);
    // Don't throw here - we can work with empty messages
    if (currentSession) {
      currentSession.messages = [];
    }
  }
}

async function setupEventListeners() {
  try {
    // Listen for chat events from backend
    const unlistenChat = await listen('chat-event', (event) => {
      const chatEvent = event.payload as ChatEvent;
      handleChatEvent(chatEvent);
    });

    // Store cleanup
    (window as any).__unlistenChat = unlistenChat;

    console.log('Chat event listeners set up successfully');
  } catch (e) {
    console.error('Failed to setup event listeners:', e);
    // Don't throw - chat can work without real-time events
  }
}

async function startMessageStreaming() {
  try {
    await invoke<void>('start_message_stream');
    console.log('Message streaming started');
  } catch (e) {
    console.error('Failed to start message streaming:', e);
    // Don't throw - chat can work without streaming
  }
}

function handleChatEvent(event: ChatEvent) {
  console.log('Received chat event:', event);

  if (event.SessionCreated) {
    const newSession = event.SessionCreated.session;
    sessions = [newSession, ...sessions.filter(s => s.id !== newSession.id)];
    updateComponents();
  } else if (event.MessageReceived) {
    const { session_id, message } = event.MessageReceived;
    if (currentSession && currentSession.id === session_id) {
      currentSession.messages = [...currentSession.messages, message];
      updateComponents();
    }
  } else if (event.MessageChunk) {
    const { session_id, chunk } = event.MessageChunk;
    if (currentSession && currentSession.id === session_id) {
      handleStreamingChunk(chunk);
    }
  } else if (event.Error) {
    error = event.Error.message;
    showError(error);
  }
}

function handleStreamingChunk(chunk: string) {
  if (!currentSession) return;

  const messages = currentSession.messages;
  const lastMessage = messages[messages.length - 1];

  if (lastMessage && lastMessage.role === "assistant") {
    // Append to existing assistant message
    lastMessage.content += chunk;
  } else {
    // Create new streaming message
    const streamingMessage: ChatMessage = {
      id: `streaming-${Date.now()}`,
      role: MessageRole.Assistant,
      content: chunk,
      timestamp: new Date().toISOString()
    };
    currentSession.messages = [...messages, streamingMessage];
  }

  updateComponents();
}

function mountComponents() {
  // Clear loading state
  chatRoot.innerHTML = '';

  // Create layout structure
  const appLayout = document.createElement('div');
  appLayout.className = 'app-layout';

  // Sessions sidebar
  const sessionsSidebar = document.createElement('aside');
  sessionsSidebar.className = 'sessions-sidebar';
  sessionsSidebar.setAttribute('aria-label', 'Chat Sessions');

  // Chat main area
  const chatMain = document.createElement('main');
  chatMain.className = 'chat-main';
  chatMain.setAttribute('role', 'main');
  chatMain.setAttribute('aria-label', 'Chat Interface');

  appLayout.appendChild(sessionsSidebar);
  appLayout.appendChild(chatMain);
  chatRoot.appendChild(appLayout);

  // Mount SessionGrid using Svelte 5 mount API
  sessionGridComponent = mount(SessionGrid, {
    target: sessionsSidebar,
    props: {
      sessions,
      activeSessionId: currentSession?.id || null,
      loading
    }
  });

  // Mount ChatInterface using Svelte 5 mount API
  if (currentSession) {
    chatInterfaceComponent = mount(ChatInterface, {
      target: chatMain,
      props: {
        session: currentSession,
        loading
      }
    });
  }
}

function updateComponents() {
  if (sessionGridComponent) {
    sessionGridComponent.sessions = sessions;
    sessionGridComponent.activeSessionId = currentSession?.id || null;
    sessionGridComponent.loading = loading;
  }

  if (chatInterfaceComponent && currentSession) {
    chatInterfaceComponent.session = currentSession;
    chatInterfaceComponent.loading = loading;
  }
}

async function handleSendMessage(event: CustomEvent<{ content: string }>) {
  if (!currentSession) return;

  try {
    loading = true;

    const userMessage: ChatMessage = {
      id: `temp-${Date.now()}`,
      role: MessageRole.User,
      content: event.detail.content,
      timestamp: new Date().toISOString()
    };

    // Add user message immediately
    currentSession.messages = [...currentSession.messages, userMessage];
    updateComponents();

    // Send to backend
    await invoke<void>('send_chat_message', {
      session_id: currentSession.id,
      content: event.detail.content
    });

    // Response will come via event stream

  } catch (e) {
    console.error('Failed to send message:', e);
    error = `Failed to send message: ${e}`;
    showError(error);
  } finally {
    loading = false;
    updateComponents();
  }
}

function handleSelectSession(event: CustomEvent<{ session: ChatSession }>) {
  const session = event.detail.session;
  currentSession = session;
  loadSessionHistory(session.id);
}

function handleDeleteSession(event: CustomEvent<{ sessionId: string }>) {
  const sessionId = event.detail.sessionId;
  sessions = sessions.filter(s => s.id !== sessionId);

  if (currentSession && currentSession.id === sessionId) {
    currentSession = sessions[0] || null;
    if (currentSession) {
      loadSessionHistory(currentSession.id);
    }
  }

  updateComponents();
}

function handleCloseChat() {
  // Navigate back to dashboard
  window.location.href = '/dashboard';
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

// Event listeners
document.addEventListener('sendMessage', handleSendMessage as EventListener);
document.addEventListener('selectSession', handleSelectSession as EventListener);
document.addEventListener('deleteSession', handleDeleteSession as EventListener);
document.addEventListener('closeChat', handleCloseChat as EventListener);

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  // Cleanup handled by Svelte components automatically
});

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeChat);
} else {
  initializeChat();
}