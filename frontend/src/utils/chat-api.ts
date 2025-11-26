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
 * Chat API - Bridge between chat store and Tauri backend commands
 * Provides functions that can be passed to chatActions methods
 */

import { invoke, listen } from './tauri-api';
import type { ChatSession, ChatMessage, ChatEvent, ModelConfig } from '../types/chat';

/**
 * Load all chat sessions from the backend
 */
export const loadChatSessions = async (): Promise<ChatSession[]> => {
  console.log('📥 [CHAT API] Loading chat sessions from backend');
  try {
    const sessions = await invoke<any[]>('get_chat_sessions');
    console.log('📥 [CHAT API] Loaded sessions:', sessions.length);
    return sessions;
  } catch (error) {
    console.error('❌ [CHAT API] Failed to load chat sessions:', error);
    throw error;
  }
};

/**
 * Create a new chat session
 */
export const createChatSession = async (title?: string): Promise<ChatSession> => {
  console.log('✨ [CHAT API] Creating chat session:', title);
  try {
    const session = await invoke<ChatSession>('create_chat_session', {
      title: title || `Chat ${new Date().toLocaleDateString()}`
    });
    console.log('✨ [CHAT API] Created session:', session.id);
    return session;
  } catch (error) {
    console.error('❌ [CHAT API] Failed to create chat session:', error);
    throw error;
  }
};

/**
 * Load message history for a specific session
 */
export const loadSessionHistory = async (sessionId: string): Promise<ChatMessage[]> => {
  console.log('📖 [CHAT API] Loading history for session:', sessionId);
  try {
    const messages = await invoke<ChatMessage[]>('get_chat_session_history', {
      session_id: sessionId
    });
    console.log('📖 [CHAT API] Loaded messages:', messages.length);
    return messages;
  } catch (error) {
    console.error('❌ [CHAT API] Failed to load session history:', error);
    throw error;
  }
};

/**
 * Send a message to a chat session with optional model configuration
 * The backend will emit 'chat-event' events for streaming responses
 */
export const sendChatMessage = async (
  sessionId: string,
  content: string,
  model?: ModelConfig
): Promise<void> => {
  console.log('📤 [CHAT API] Sending message to session:', sessionId);
  try {
    await invoke<void>('send_chat_message', {
      session_id: sessionId,
      content,
      model
    });
    console.log('📤 [CHAT API] Message sent successfully');
  } catch (error) {
    console.error('❌ [CHAT API] Failed to send chat message:', error);
    throw error;
  }
};

/**
 * Delete a chat session
 */
export const deleteChatSession = async (sessionId: string): Promise<void> => {
  console.log('🗑️ [CHAT API] Deleting session:', sessionId);
  try {
    await invoke<void>('delete_chat_session', {
      session_id: sessionId
    });
    console.log('🗑️ [CHAT API] Session deleted successfully');
  } catch (error) {
    console.error('❌ [CHAT API] Failed to delete session:', error);
    throw error;
  }
};

/**
 * Start listening to real-time chat events from the backend
 * Events include: MessageChunk, MessageReceived, SessionCreated, Error
 */
export const startChatEventListener = async (
  handler: (event: ChatEvent) => Promise<void>
): Promise<() => void> => {
  console.log('🔊 [CHAT API] Starting chat event listener');

  try {
    // First, start the message stream on the backend
    await invoke<void>('start_message_stream');
    console.log('🔊 [CHAT API] Message stream started');

    // Then listen to events
    const unsubscribe = await listen('chat-event', async (event: any) => {
      console.log('📨 [CHAT API] Received chat event:', event.payload);
      try {
        await handler(event.payload);
      } catch (error) {
        console.error('❌ [CHAT API] Error handling chat event:', error);
      }
    });

    console.log('🔊 [CHAT API] Event listener attached');
    return unsubscribe;
  } catch (error) {
    console.error('❌ [CHAT API] Failed to start chat event listener:', error);
    throw error;
  }
};

/**
 * Get available models from the OpenCode server
 */
export const getAvailableModels = async (): Promise<Array<[string, string]>> => {
  console.log('📋 [CHAT API] Fetching available models');
  try {
    const models = await invoke<Array<[string, string]>>('get_available_models');
    console.log('📋 [CHAT API] Available models:', models.length);
    return models;
  } catch (error) {
    console.error('❌ [CHAT API] Failed to get available models:', error);
    throw error;
  }
};

/**
 * Initialize chat system - load initial data and set up event listeners
 */
export const initializeChat = async (
  onChatEvent: (event: ChatEvent) => Promise<void>
): Promise<() => void> => {
  console.log('🚀 [CHAT API] Initializing chat system');

  try {
    // Start listening to events first
    const unsubscribe = await startChatEventListener(onChatEvent);

    console.log('🚀 [CHAT API] Chat system initialized');
    return unsubscribe;
  } catch (error) {
    console.error('❌ [CHAT API] Failed to initialize chat system:', error);
    throw error;
  }
};

/**
 * Connection event types that the backend emits
 */
export type ConnectionEventType = 'Connected' | 'Disconnected' | 'Error' | 'HealthCheck';

export interface ConnectionEventPayload {
  event_type: ConnectionEventType;
  message: string;
}

/**
 * Subscribe to real-time connection events from the backend
 * Events include: Connected, Disconnected, Error, HealthCheck
 * 
 * @param onConnected - Callback when successfully connected to server
 * @param onDisconnected - Callback when disconnected from server
 * @param onError - Callback when connection error occurs
 * @param onHealthCheck - Optional callback for health check events
 * @returns Unsubscribe function to stop listening to events
 */
export const subscribeToConnectionEvents = async (
  onConnected: (message: string) => void,
  onDisconnected: (message: string) => void,
  onError: (message: string) => void,
  onHealthCheck?: (message: string) => void
): Promise<() => void> => {
  console.log('🔗 [CONNECTION API] Subscribing to connection events');

  try {
    // Listen to connection_event from the backend
    const unsubscribe = await listen('connection_event', async (event: any) => {
      const payload = event.payload as ConnectionEventPayload;
      console.log('📡 [CONNECTION API] Received connection event:', payload.event_type, payload.message);

      switch (payload.event_type) {
        case 'Connected':
          console.log('✅ [CONNECTION API] Connected:', payload.message);
          onConnected(payload.message);
          break;

        case 'Disconnected':
          console.log('⚠️ [CONNECTION API] Disconnected:', payload.message);
          onDisconnected(payload.message);
          break;

        case 'Error':
          console.log('❌ [CONNECTION API] Connection error:', payload.message);
          onError(payload.message);
          break;

        case 'HealthCheck':
          console.log('💓 [CONNECTION API] Health check:', payload.message);
          if (onHealthCheck) onHealthCheck(payload.message);
          break;

        default:
          console.warn('⚠️ [CONNECTION API] Unknown connection event type:', payload.event_type);
      }
    });

    console.log('🔗 [CONNECTION API] Successfully subscribed to connection events');
    return unsubscribe;
  } catch (error) {
    console.error('❌ [CONNECTION API] Failed to subscribe to connection events:', error);
    throw error;
  }
};

/**
 * Reconnection configuration
 */
export interface ReconnectionConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
}

/**
 * Default reconnection configuration
 * - 5 retry attempts
 * - Start with 1 second delay
 * - Max delay of 32 seconds (exponential backoff caps out)
 */
export const DEFAULT_RECONNECTION_CONFIG: ReconnectionConfig = {
  maxRetries: 5,
  baseDelayMs: 1000,
  maxDelayMs: 32000
};

/**
 * Attempt to reconnect to the server with exponential backoff
 * 
 * @param config - Reconnection configuration
 * @returns Promise resolving to true if reconnection succeeded, false if max retries exhausted
 */
export const reconnectWithBackoff = async (
  config: ReconnectionConfig = DEFAULT_RECONNECTION_CONFIG
): Promise<boolean> => {
  console.log('🔄 [RECONNECTION] Starting reconnection attempt...');

  const { maxRetries, baseDelayMs, maxDelayMs } = config;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    // Calculate exponential backoff delay: 1s, 2s, 4s, 8s, 16s, etc.
    const delayMs = Math.min(baseDelayMs * Math.pow(2, attempt - 1), maxDelayMs);

    console.log(
      `🔄 [RECONNECTION] Attempt ${attempt}/${maxRetries} in ${delayMs}ms`
    );

    // Wait before attempting reconnection
    await new Promise((resolve) => setTimeout(resolve, delayMs));

    try {
      // Check if we can get saved connections
      const connections = await invoke<any[]>('get_saved_connections');

      if (Array.isArray(connections) && connections.length > 0) {
        // Try to connect to the last used connection
        const lastConnection = connections[0];
        console.log(
          `🔄 [RECONNECTION] Attempting to connect to: ${lastConnection.hostname}:${lastConnection.port}`
        );

        try {
          // Test the connection
          const testResult = await invoke<boolean>('test_server_connection', {
            serverUrl: `${lastConnection.secure ? 'https' : 'http'}://${lastConnection.hostname}:${lastConnection.port}`
          });

          if (testResult) {
            console.log('✅ [RECONNECTION] Successfully reconnected to server');
            return true;
          }
        } catch (testError) {
          console.warn(
            `⚠️ [RECONNECTION] Connection test failed on attempt ${attempt}:`,
            testError
          );
        }
      }
    } catch (error) {
      console.warn(
        `⚠️ [RECONNECTION] Reconnection attempt ${attempt} failed:`,
        error
      );
    }

    // Continue to next attempt if this one failed
    if (attempt < maxRetries) {
      console.log(
        `ℹ️ [RECONNECTION] Retrying... (${maxRetries - attempt} attempts remaining)`
      );
    }
  }

  console.log(
    `❌ [RECONNECTION] Failed to reconnect after ${maxRetries} attempts`
  );
  return false;
};

/**
 * Chat API exports for use with chatActions
 * These functions have signatures compatible with chatActions callbacks
 */
export const chatApiCallbacks = {
  // Compatible with chatActions.loadSessions(sessionLoader)
  sessionLoader: loadChatSessions,

  // Compatible with chatActions.createSession(sessionCreator)
  sessionCreator: createChatSession,

  // Compatible with chatActions.sendMessage(..., messageSender)
  messageSender: sendChatMessage,

  // Compatible with chatActions.deleteSession(..., sessionDeleter)
  sessionDeleter: deleteChatSession
};
