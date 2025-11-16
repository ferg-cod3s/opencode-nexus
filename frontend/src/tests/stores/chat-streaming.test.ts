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

import { describe, test, expect, beforeEach } from 'bun:test';

// Mock browser APIs BEFORE importing anything that uses them
const mockLocalStorage = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => { store[key] = value.toString(); },
    removeItem: (key: string) => { delete store[key]; },
    clear: () => { store = {}; },
    key: (index: number) => Object.keys(store)[index] || null,
    get length() { return Object.keys(store).length; }
  };
})();

globalThis.localStorage = mockLocalStorage as any;
globalThis.window = globalThis as any;
globalThis.self = globalThis as any;

import { activeSessionStore, chatStore } from '../../stores/chat';
import { get } from 'svelte/store';
import type { ChatSession, ChatMessage } from '../../types/chat';
import { MessageRole } from '../../types/chat';

describe('Chat Streaming - No Duplicate Messages (Priority 1 Fix)', () => {
  let testSession: ChatSession;

  beforeEach(() => {
    // Reset localStorage
    mockLocalStorage.clear();

    // Reset store before each test
    chatStore.actions.reset();

    // Create test session
    testSession = {
      id: 'test-session-123',
      title: 'Test Chat',
      messages: [],
      created_at: new Date().toISOString()
    };
  });

  test('should create only one streaming message when receiving multiple chunks', () => {
    // Set up the session
    activeSessionStore.setSession(testSession);

    // Add a user message first
    const userMessage: ChatMessage = {
      id: 'user-msg-1',
      role: MessageRole.User,
      content: 'Hello, AI!',
      timestamp: new Date().toISOString()
    };
    activeSessionStore.addMessage(userMessage);

    let currentSession = get(activeSessionStore);
    expect(currentSession?.messages.length).toBe(1);

    // Simulate receiving multiple message chunks (THIS WAS THE BUG)
    // Before fix: would create 5 new messages (one per chunk)
    // After fix: should reuse the same streaming message for all chunks
    activeSessionStore.appendToLastMessage('This ');
    activeSessionStore.appendToLastMessage('is ');
    activeSessionStore.appendToLastMessage('a ');
    activeSessionStore.appendToLastMessage('streaming ');
    activeSessionStore.appendToLastMessage('response.');

    currentSession = get(activeSessionStore);

    // Should have 2 messages: 1 user + 1 assistant (not 7!)
    expect(currentSession?.messages.length).toBe(2);

    // Verify the assistant message is properly accumulated
    const assistantMessage = currentSession?.messages[1];
    expect(assistantMessage?.role).toBe(MessageRole.Assistant);
    expect(assistantMessage?.content).toBe('This is a streaming response.');
  });

  test('should handle chunks for consecutive messages correctly', () => {
    activeSessionStore.setSession(testSession);

    // User message 1
    activeSessionStore.addMessage({
      id: 'user-msg-1',
      role: MessageRole.User,
      content: 'First question',
      timestamp: new Date().toISOString()
    });

    // AI response 1 (streaming chunks)
    activeSessionStore.appendToLastMessage('First ');
    activeSessionStore.appendToLastMessage('response.');

    let session = get(activeSessionStore);
    expect(session?.messages.length).toBe(2);
    expect(session?.messages[1].content).toBe('First response.');

    // Clear streaming ID (simulates MessageReceived event)
    activeSessionStore.clearStreamingMessageId();

    // User message 2
    activeSessionStore.addMessage({
      id: 'user-msg-2',
      role: MessageRole.User,
      content: 'Second question',
      timestamp: new Date().toISOString()
    });

    // AI response 2 (streaming chunks) - should create a NEW streaming message ID
    activeSessionStore.appendToLastMessage('Second ');
    activeSessionStore.appendToLastMessage('response.');

    session = get(activeSessionStore);
    expect(session?.messages.length).toBe(4);
    expect(session?.messages[2].role).toBe(MessageRole.User);
    expect(session?.messages[3].role).toBe(MessageRole.Assistant);
    expect(session?.messages[3].content).toBe('Second response.');
  });

  test('should generate unique message IDs for each streaming message', () => {
    activeSessionStore.setSession(testSession);

    // Add a user message
    activeSessionStore.addMessage({
      id: 'user-msg-1',
      role: MessageRole.User,
      content: 'Question 1',
      timestamp: new Date().toISOString()
    });

    // First streaming message
    activeSessionStore.appendToLastMessage('Response 1');
    let session = get(activeSessionStore);
    const firstStreamingId = session?.messages[1].id;

    // Clear streaming ID (simulating MessageReceived)
    activeSessionStore.clearStreamingMessageId();

    // Add another user message
    activeSessionStore.addMessage({
      id: 'user-msg-2',
      role: MessageRole.User,
      content: 'Question 2',
      timestamp: new Date().toISOString()
    });

    // Second streaming message
    activeSessionStore.appendToLastMessage('Response 2');
    session = get(activeSessionStore);
    const secondStreamingId = session?.messages[3].id;

    // IDs should be different
    expect(firstStreamingId).not.toBe(secondStreamingId);
    expect(firstStreamingId).toBeDefined();
    expect(secondStreamingId).toBeDefined();
  });

  test('should clear streaming state when switching sessions', () => {
    activeSessionStore.setSession(testSession);
    activeSessionStore.addMessage({
      id: 'user-msg-1',
      role: MessageRole.User,
      content: 'Hello',
      timestamp: new Date().toISOString()
    });
    activeSessionStore.appendToLastMessage('Response start');

    let session = get(activeSessionStore);
    expect(session?.messages.length).toBe(2);

    // Switch to a new session
    const newSession: ChatSession = {
      id: 'new-session',
      title: 'New Session',
      messages: [],
      created_at: new Date().toISOString()
    };
    activeSessionStore.setSession(newSession);

    // Add a message in the new session - should create a NEW streaming message
    activeSessionStore.appendToLastMessage('New response');

    session = get(activeSessionStore);
    expect(session?.messages.length).toBe(1);
    expect(session?.messages[0].content).toBe('New response');
  });

  test('should handle rapid chunk sequences without creating duplicates', () => {
    activeSessionStore.setSession(testSession);

    // Add user message
    activeSessionStore.addMessage({
      id: 'user-msg',
      role: MessageRole.User,
      content: 'Test',
      timestamp: new Date().toISOString()
    });

    // Simulate rapid chunks (what the bug was causing)
    const chunks = [
      'Building', ' ', 'a', ' ', 'response', ' ', 'with', ' ', 'many', ' ', 'chunks', '.'
    ];

    for (const chunk of chunks) {
      activeSessionStore.appendToLastMessage(chunk);
    }

    const session = get(activeSessionStore);

    // Should have exactly 2 messages (1 user + 1 AI)
    expect(session?.messages.length).toBe(2);

    // AI message should contain all chunks concatenated
    const aiMessage = session?.messages[1];
    expect(aiMessage?.content).toBe('Building a response with many chunks.');

    // There should only be ONE assistant message, not 12
    const assistantMessages = session?.messages.filter(m => m.role === MessageRole.Assistant);
    expect(assistantMessages?.length).toBe(1);
  });
});
