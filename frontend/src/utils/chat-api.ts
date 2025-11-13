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
import type { ChatSession, ChatMessage, ChatEvent } from '../types/chat';

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
 * Send a message to a chat session
 * The backend will emit 'chat-event' events for streaming responses
 */
export const sendChatMessage = async (sessionId: string, content: string): Promise<void> => {
  console.log('📤 [CHAT API] Sending message to session:', sessionId);
  try {
    await invoke<void>('send_chat_message', {
      session_id: sessionId,
      content
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
    await invoke<void>('delete_session', {
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
