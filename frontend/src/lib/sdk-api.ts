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
import type { Client } from '@opencode-ai/sdk';

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
 * Initialize connection to a server
 */
export async function initializeConnection(connection: ServerConnection): Promise<void> {
  console.log(`🔗 [SDK API] Initializing connection to ${connection.hostname}:${connection.port}`);
  try {
    await opcodeClient.connect(connection);
    console.log('✅ [SDK API] Connected successfully');
  } catch (error) {
    console.error('❌ [SDK API] Failed to initialize connection:', error);
    throw error;
  }
}

/**
 * Load all sessions from the server
 */
export async function loadSessions() {
  console.log('📥 [SDK API] Loading sessions');
  try {
    const client = opcodeClient.getClient();
    const sessions = await client.session.list();
    console.log(`📥 [SDK API] Loaded ${sessions.length} sessions`);
    return sessions;
  } catch (error) {
    console.error('❌ [SDK API] Failed to load sessions:', error);
    throw error;
  }
}

/**
 * Create a new session
 */
export async function createSession(params?: CreateSessionParams) {
  console.log('✨ [SDK API] Creating session:', params?.title);
  try {
    const client = opcodeClient.getClient();
    const session = await client.session.create({
      title: params?.title || `Chat ${new Date().toLocaleDateString()}`
    });
    console.log('✨ [SDK API] Created session:', session.id);
    return session;
  } catch (error) {
    console.error('❌ [SDK API] Failed to create session:', error);
    throw error;
  }
}

/**
 * Send a message to a session with streaming support
 */
export async function sendMessage(params: SendMessageParams) {
  console.log('📤 [SDK API] Sending message to session:', params.sessionId);
  try {
    const client = opcodeClient.getClient();

    // Send the message
    const response = await client.session.prompt(params.sessionId, {
      parts: [{ type: 'text', text: params.content }]
    });

    console.log('📤 [SDK API] Message sent successfully');
    return response;
  } catch (error) {
    console.error('❌ [SDK API] Failed to send message:', error);
    throw error;
  }
}

/**
 * Get session history (all messages in a session)
 */
export async function getSessionHistory(sessionId: string) {
  console.log('📖 [SDK API] Loading history for session:', sessionId);
  try {
    const client = opcodeClient.getClient();
    const session = await client.session.get(sessionId);
    console.log(`📖 [SDK API] Loaded ${session.messages?.length || 0} messages`);
    return session.messages || [];
  } catch (error) {
    console.error('❌ [SDK API] Failed to load session history:', error);
    throw error;
  }
}

/**
 * Delete a session
 */
export async function deleteSession(sessionId: string) {
  console.log('🗑️ [SDK API] Deleting session:', sessionId);
  try {
    const client = opcodeClient.getClient();
    await client.session.delete(sessionId);
    console.log('🗑️ [SDK API] Session deleted successfully');
  } catch (error) {
    console.error('❌ [SDK API] Failed to delete session:', error);
    throw error;
  }
}

/**
 * Subscribe to real-time events from the server (SSE)
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
        for await (const event of eventStream) {
          console.log('📨 [SDK API] Received event:', event.type);
          await onEvent(event);
        }
      } catch (error) {
        console.error('❌ [SDK API] Error in event stream:', error);
      }
    })();

    console.log('✅ [SDK API] Event subscription active');
  } catch (error) {
    console.error('❌ [SDK API] Failed to subscribe to events:', error);
    throw error;
  }
}

/**
 * Get available models from the server
 */
export async function getAvailableModels() {
  console.log('📋 [SDK API] Fetching available models');
  try {
    const client = opcodeClient.getClient();
    const config = await client.config.get();
    const models = config.providers || [];
    console.log(`📋 [SDK API] Available models: ${models.length} providers`);
    return models;
  } catch (error) {
    console.error('❌ [SDK API] Failed to get available models:', error);
    throw error;
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
    console.error('❌ [SDK API] Failed to load saved connections:', error);
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
    console.error('❌ [SDK API] Failed to disconnect:', error);
    throw error;
  }
}
