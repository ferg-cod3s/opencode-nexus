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

import { opcodeClient, type ServerConnection } from './opencode-client';

import { handleError } from './error-handler';
import { withRetry } from './retry-handler';

/**
 * SDK-based chat API - Uses @opencode-ai/sdk instead of Tauri backend
 * Provides type-safe functions for all chat operations
 */

export interface CreateSessionParams {
  title?: string;
}

export interface SendMessageParams {
  sessionId: string;
  content: string;
}

export interface PromptPart {
  type: 'text' | 'file';
  text?: string;
  file?: {
    path: string;
    mimeType?: string;
  };
}

/**
 * Initialize connection to a server with retry logic
 */
export async function initializeConnection(connection: ServerConnection): Promise<void> {
  console.log(`🔗 [SDK API] Initializing connection to ${connection.hostname}:${connection.port}`);

  try {
    await withRetry(
      () => opcodeClient.connect(connection),
      { maxRetries: 2, initialDelayMs: 500 },
      `Connection to ${connection.hostname}:${connection.port}`
    );
    console.log('✅ [SDK API] Connected successfully');
  } catch (error) {
    const appError = handleError(error, 'SDK Connection Error');
    console.error('❌ [SDK API] Failed to initialize connection:', appError);
    throw appError;
  }
}

/**
 * Load all sessions from the server with retry for transient failures
 */
export async function loadSessions() {
  console.log('📥 [SDK API] Loading sessions');

  try {
    const sessions = await withRetry(
      async () => {
        const client = opcodeClient.getClient();
        return await client.session.list();
      },
      { maxRetries: 2, initialDelayMs: 500 },
      'Load sessions'
    );
    console.log(`📥 [SDK API] Loaded ${sessions.data?.length || 0} sessions`);
    return sessions.data || [];
  } catch (error) {
    const appError = handleError(error, 'Load Sessions Error');
    console.error('❌ [SDK API] Failed to load sessions:', appError);
    throw appError;
  }
}

/**
 * Create a new session with retry for transient failures
 */
export async function createSession(params?: CreateSessionParams) {
  console.log('✨ [SDK API] Creating session:', params?.title);

  try {
    const session = await withRetry(
      async () => {
        const client = opcodeClient.getClient();
        return await client.session.create({
          body: {
            title: params?.title || `Chat ${new Date().toLocaleDateString()}`
          }
        });
      },
      { maxRetries: 2, initialDelayMs: 500 },
      'Create session'
    );
    console.log('✨ [SDK API] Created session:', session.data?.id);
    return session.data;
  } catch (error) {
    const appError = handleError(error, 'Create Session Error');
    console.error('❌ [SDK API] Failed to create session:', appError);
    throw appError;
  }
}

/**
 * Send a message to a session with streaming and retry support
 */
export async function sendMessage(params: SendMessageParams) {
  console.log('📤 [SDK API] Sending message to session:', params.sessionId);

  try {
        const response = await withRetry(
          async () => {
            const client = opcodeClient.getClient();
            return await client.session.prompt({
              path: { id: params.sessionId },
              body: { 
                parts: [{
                  type: 'text',
                  text: params.content
                }]
              }
            });
          },
          { maxRetries: 2, initialDelayMs: 500 },
          'Send message'
        );
    console.log('📤 [SDK API] Message sent successfully');
    return response;
  } catch (error) {
    const appError = handleError(error, 'Send Message Error');
    console.error('❌ [SDK API] Failed to send message:', appError);
    throw appError;
  }
}

/**
 * Get session history (all messages in a session) with retry
 */
export async function getSessionHistory(sessionId: string) {
  console.log('📖 [SDK API] Loading history for session:', sessionId);

  try {
    const session = await withRetry(
      async () => {
        const client = opcodeClient.getClient();
        return await client.session.get({ path: { id: sessionId } });
      },
      { maxRetries: 2, initialDelayMs: 500 },
      'Get session'
    );
    console.log(`📖 [SDK API] Loaded session: ${session.data?.id || 'unknown'}`);
    const messagesResponse = await withRetry(
      async () => {
        const client = opcodeClient.getClient();
        return await client.session.messages({ path: { id: sessionId } });
      },
      { maxRetries: 2, initialDelayMs: 500 },
      'Get session messages'
    );
    return messagesResponse.data || [];
  } catch (error) {
    const appError = handleError(error, 'Load Session History Error');
    console.error('❌ [SDK API] Failed to load session history:', appError);
    throw appError;
  }
}

/**
 * Delete a session
 */
export async function deleteSession(sessionId: string) {
  console.log('🗑️ [SDK API] Deleting session:', sessionId);

  try {
    const client = opcodeClient.getClient();
    await client.session.delete({ path: { id: sessionId } });
    console.log('🗑️ [SDK API] Session deleted successfully');
  } catch (error) {
    const appError = handleError(error, 'Delete Session Error');
    console.error('❌ [SDK API] Failed to delete session:', appError);
    throw appError;
  }
}

/**
 * Subscribe to real-time events from the server (SSE) with error handling
 * Returns an async iterator for streaming events
 */
export async function subscribeToEvents(onEvent: (event: any) => Promise<void>) {
  console.log('🔊 [SDK API] Subscribing to server events');

  try {
    const client = opcodeClient.getClient();
    const eventStream = await client.event.subscribe();

    // Start listening to events in the background
    (async () => {
      try {
        for await (const event of eventStream.stream || []) {
          console.log('📨 [SDK API] Received event:', event.type);
          try {
            await onEvent(event);
          } catch (error) {
            console.error('❌ [SDK API] Error handling event:', error);
            handleError(error, 'Event Handler Error');
          }
        }
      } catch (error) {
        console.error('❌ [SDK API] Error in event stream:', error);
        handleError(error, 'Event Stream Error');
      }
    })();

    console.log('✅ [SDK API] Event subscription active');
  } catch (error) {
    const appError = handleError(error, 'Subscribe to Events Error');
    console.error('❌ [SDK API] Failed to subscribe to events:', appError);
    throw appError;
  }
}

/**
 * Get available models from the server with retry
 */
export async function getAvailableModels() {
  console.log('📋 [SDK API] Fetching available models');

  try {
    const providersConfig = await withRetry(
      async () => {
        const client = opcodeClient.getClient();
        return await client.config.providers();
      },
      { maxRetries: 2, initialDelayMs: 500 },
      'Fetch available providers'
    );
    const models = providersConfig.data?.providers || [];
    console.log(`📋 [SDK API] Available models: ${models.length} providers`);
    return models;
  } catch (error) {
    const appError = handleError(error, 'Get Available Models Error');
    console.error('❌ [SDK API] Failed to get available models:', appError);
    throw appError;
  }
}

/**
 * Get saved connections from persistent storage
 */
export async function getSavedConnections(): Promise<ServerConnection[]> {
  console.log('📚 [SDK API] Loading saved connections');

  try {
    const connections = await opcodeClient.getSavedConnections();
    console.log(`📚 [SDK API] Loaded ${connections.length} saved connections`);
    return connections;
  } catch (error) {
    console.warn('⚠️ [SDK API] Failed to load saved connections:', error);
    handleError(error, 'Load Saved Connections Warning');
    return [];
  }
}

/**
 * Get last used connection from persistent storage
 */
export async function getLastUsedConnection(): Promise<ServerConnection | null> {
  console.log('🔄 [SDK API] Loading last used connection');

  try {
    const connection = await opcodeClient.getLastUsedConnection();
    if (connection) {
      console.log(`🔄 [SDK API] Last connection: ${connection.hostname}:${connection.port}`);
    } else {
      console.log('🔄 [SDK API] No previous connection found');
    }
    return connection;
  } catch (error) {
    console.warn('⚠️ [SDK API] Failed to load last used connection:', error);
    handleError(error, 'Load Last Connection Warning');
    return null;
  }
}

/**
 * Check if currently connected
 */
export function isConnected(): boolean {
  return opcodeClient.isConnected();
}

/**
 * Get current connection details
 */
export function getCurrentConnection(): ServerConnection | null {
  return opcodeClient.getCurrentConnection();
}

/**
 * Disconnect from the current server
 */
export async function disconnect(): Promise<void> {
  console.log('🔌 [SDK API] Disconnecting from server');

  try {
    await opcodeClient.disconnect();
    console.log('✅ [SDK API] Disconnected successfully');
  } catch (error) {
    const appError = handleError(error, 'Disconnect Error');
    console.error('❌ [SDK API] Failed to disconnect:', appError);
    throw appError;
  }
}
