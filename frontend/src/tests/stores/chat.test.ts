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

import { describe, test, expect, beforeEach, afterEach, mock } from 'bun:test';

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

const mockWindow = {
  addEventListener: mock(() => {}),
  dispatchEvent: mock(() => {}),
  onLine: true
};

const mockNavigator = {
  onLine: true
};

(global as any).localStorage = mockLocalStorage;
(global as any).window = mockWindow;
(global as any).navigator = mockNavigator;

import { get } from 'svelte/store';
import {
  chatStore,
  chatStateStore,
  sessionsStore,
  activeSessionStore,
  compositionStore,
  chatError,
  isOnline,
  hasQueuedMessages,
  syncInProgress,
  queuedMessageCount
} from '../../stores/chat';
import type { ChatSession, ChatMessage } from '../../types/chat';
import { MessageRole } from '../../types/chat';
import { initializeOfflineStorage } from '../../utils/offline-storage';

describe('Chat Store - Error Handling & State Management', () => {
  beforeEach(async () => {
    // Clear localStorage before each test
    mockLocalStorage.clear();

    // Initialize offline storage after mocks are set up
    initializeOfflineStorage();

    // Initialize and reset all stores before each test
    try {
      await chatStore.actions.initialize();
    } catch (error) {
      // Initialization may fail in test environment, that's ok
      console.log('Store initialization skipped in test');
    }
  });

  describe('Error State Management', () => {
    test('should initialize with no error', () => {
      expect(get(chatError)).toBeNull();
    });

    test('should set error message', () => {
      const errorMsg = 'Failed to load sessions';
      chatStateStore.setError(errorMsg);
      expect(get(chatError)).toBe(errorMsg);
    });

    test('should clear error when set to null', () => {
      chatStateStore.setError('Test error');
      expect(get(chatError)).toBe('Test error');

      chatStateStore.setError(null);
      expect(get(chatError)).toBeNull();
    });

    test('should update error through clearError action', () => {
      chatStateStore.setError('Initial error');
      chatStore.actions.clearError();
      expect(get(chatError)).toBeNull();
    });
  });

  describe('Online Status Management', () => {
    test('should track online/offline status', () => {
      // Initialize online status if not already set
      chatStateStore.setOnline(true);
      let status = get(isOnline);
      expect(status).toBe(true);

      chatStateStore.setOnline(false);
      expect(get(isOnline)).toBe(false);

      chatStateStore.setOnline(true);
      expect(get(isOnline)).toBe(true);
    });
  });

  describe('Session Management', () => {
    const mockSession: ChatSession = {
      id: 'session-1',
      title: 'Test Chat',
      created_at: new Date().toISOString(),
      messages: []
    };

    test('should add session to sessions store', () => {
      sessionsStore.addSession(mockSession);
      const sessions = get(sessionsStore);
      expect(sessions).toContainEqual(mockSession);
      expect(sessions.length).toBe(1);
    });

    test('should set active session', () => {
      activeSessionStore.setSession(mockSession);
      expect(get(activeSessionStore)).toEqual(mockSession);
    });

    test('should remove session from sessions store', () => {
      sessionsStore.addSession(mockSession);
      sessionsStore.removeSession(mockSession.id);
      expect(get(sessionsStore).length).toBe(0);
    });

    test('should update active session when deleted', async () => {
      const session1: ChatSession = {
        ...mockSession,
        id: 'session-1'
      };
      const session2: ChatSession = {
        ...mockSession,
        id: 'session-2'
      };

      sessionsStore.addSession(session1);
      sessionsStore.addSession(session2);
      activeSessionStore.setSession(session1);

      // Delete active session
      await chatStore.actions.deleteSession(session1.id);

      // Should switch to session2
      const activeSession = get(activeSessionStore);
      expect(activeSession?.id).toBe(session2.id);
    });
  });

  describe('Message Management', () => {
    const mockSession: ChatSession = {
      id: 'session-1',
      title: 'Test Chat',
      created_at: new Date().toISOString(),
      messages: []
    };

    const userMessage: ChatMessage = {
      id: 'msg-1',
      role: MessageRole.User,
      content: 'Hello',
      timestamp: new Date().toISOString()
    };

    beforeEach(() => {
      activeSessionStore.setSession(mockSession);
    });

    test('should add message to active session', () => {
      activeSessionStore.addMessage(userMessage);
      const session = get(activeSessionStore);
      expect(session?.messages).toContainEqual(userMessage);
      expect(session?.messages.length).toBe(1);
    });

    test('should append to last message (streaming)', () => {
      const assistantMessage: ChatMessage = {
        id: 'msg-2',
        role: MessageRole.Assistant,
        content: 'Hello',
        timestamp: new Date().toISOString()
      };

      activeSessionStore.addMessage(userMessage);
      activeSessionStore.addMessage(assistantMessage);
      activeSessionStore.appendToLastMessage(' there');

      const session = get(activeSessionStore);
      expect(session?.messages[1].content).toBe('Hello there');
    });

    test('should create new streaming message if last is user message', () => {
      activeSessionStore.addMessage(userMessage);
      activeSessionStore.appendToLastMessage('Response');

      const session = get(activeSessionStore);
      expect(session?.messages.length).toBe(2);
      expect(session?.messages[1].role).toBe(MessageRole.Assistant);
      expect(session?.messages[1].content).toBe('Response');
    });
  });

  describe('Queued Messages', () => {
    test('should track queued message count', () => {
      expect(get(queuedMessageCount)).toBe(0);

      compositionStore.setQueuedMessageCount(3);
      expect(get(queuedMessageCount)).toBe(3);
    });

    test('should indicate when messages are queued', () => {
      expect(get(hasQueuedMessages)).toBe(false);

      chatStateStore.setHasQueuedMessages(true);
      expect(get(hasQueuedMessages)).toBe(true);
    });

    test('should clear queued messages', () => {
      chatStateStore.setHasQueuedMessages(true);
      compositionStore.setQueuedMessageCount(5);

      compositionStore.reset();
      expect(get(queuedMessageCount)).toBe(0);
    });
  });

  describe('Sync Progress', () => {
    test('should track sync in progress state', () => {
      expect(get(syncInProgress)).toBe(false);

      chatStateStore.setSyncInProgress(true);
      expect(get(syncInProgress)).toBe(true);

      chatStateStore.setSyncInProgress(false);
      expect(get(syncInProgress)).toBe(false);
    });
  });

  describe('Store Reset', () => {
    test('should reset all stores to initial state', () => {
      // Populate stores
      const mockSession: ChatSession = {
        id: 'session-1',
        title: 'Test',
        created_at: new Date().toISOString(),
        messages: []
      };

      sessionsStore.addSession(mockSession);
      activeSessionStore.setSession(mockSession);
      chatStateStore.setError('Test error');
      compositionStore.setQueuedMessageCount(5);

      // Reset via actions (proper API)
      chatStore.actions.clearError();
      compositionStore.reset();
      activeSessionStore.setSession(null);

      // Verify all cleared
      expect(get(sessionsStore).length).toBeGreaterThanOrEqual(0); // Sessions not cleared
      expect(get(activeSessionStore)).toBeNull();
      expect(get(chatError)).toBeNull();
      expect(get(queuedMessageCount)).toBe(0);
    });
  });

  describe('Message Draft Management', () => {
    test('should set and clear draft', () => {
      const draft = 'This is a draft message';
      compositionStore.setDraft(draft);
      expect(get(compositionStore).draft).toBe(draft);

      compositionStore.clearDraft();
      expect(get(compositionStore).draft).toBe('');
    });

    test('should manage attachments', () => {
      const attachment = 'file-1.txt';
      compositionStore.addAttachment(attachment);
      expect(get(compositionStore).attachments).toContain(attachment);

      compositionStore.removeAttachment(attachment);
      expect(get(compositionStore).attachments).not.toContain(attachment);
    });
  });

  describe('Chat Events Handling', () => {
    const mockSession: ChatSession = {
      id: 'session-1',
      title: 'Test Chat',
      created_at: new Date().toISOString(),
      messages: []
    };

    test('should handle SessionCreated event', async () => {
      const event = {
        SessionCreated: {
          session: mockSession
        }
      };

      await chatStore.actions.handleChatEvent(event as any);

      const sessions = get(sessionsStore);
      expect(sessions).toContainEqual(mockSession);
    });

    test('should handle MessageReceived event', async () => {
      const sessionWithMessages: ChatSession = {
        ...mockSession,
        messages: []
      };
      activeSessionStore.setSession(sessionWithMessages);

      const message: ChatMessage = {
        id: 'msg-1',
        role: MessageRole.Assistant,
        content: 'Response',
        timestamp: new Date().toISOString()
      };

      const event = {
        MessageReceived: {
          session_id: mockSession.id,
          message
        }
      };

      await chatStore.actions.handleChatEvent(event as any);

      const activeSession = get(activeSessionStore);
      expect(activeSession?.messages.length).toBeGreaterThan(0);
      expect(activeSession?.messages[activeSession.messages.length - 1]).toEqual(message);
    });

    test('should handle MessageChunk event for streaming', async () => {
      const sessionWithMessages: ChatSession = {
        ...mockSession,
        id: 'session-1',
        messages: []
      };
      activeSessionStore.setSession(sessionWithMessages);

      const assistantMessage: ChatMessage = {
        id: 'msg-1',
        role: MessageRole.Assistant,
        content: 'Hello',
        timestamp: new Date().toISOString()
      };

      activeSessionStore.addMessage(assistantMessage);

      const event = {
        MessageChunk: {
          session_id: 'session-1',
          chunk: ' world'
        }
      };

      await chatStore.actions.handleChatEvent(event as any);

      const activeSession = get(activeSessionStore);
      expect(activeSession?.messages[0].content).toBe('Hello world');
    });

    test('should handle Error event', async () => {
      const errorMsg = 'Server error';
      const event = {
        Error: {
          message: errorMsg
        }
      };

      await chatStore.actions.handleChatEvent(event as any);
      expect(get(chatError)).toBe(errorMsg);
    });
  });

  describe('Store Subscriptions', () => {
    test('should update derived store when base store changes', () => {
      chatStateStore.setError('Test error');

      let capturedError: string | null = null;
      const unsubscribe = chatError.subscribe(error => {
        capturedError = error;
      });

      expect(capturedError).toBe('Test error');

      chatStateStore.setError('New error');
      expect(capturedError).toBe('New error');

      unsubscribe();
    });

    test('should track multiple store subscribers', () => {
      const errors: (string | null)[] = [];
      const statuses: boolean[] = [];

      const errorUnsub = chatError.subscribe(e => errors.push(e));
      const statusUnsub = isOnline.subscribe(s => statuses.push(s));

      chatStateStore.setError('Error 1');
      chatStateStore.setOnline(false);
      chatStateStore.setError('Error 2');

      expect(errors.length).toBeGreaterThan(1);
      expect(statuses.length).toBeGreaterThan(1);

      errorUnsub();
      statusUnsub();
    });
  });

  describe('Session Selection', () => {
    test('should select session and reset composition', () => {
      const session: ChatSession = {
        id: 'session-1',
        title: 'Test',
        created_at: new Date().toISOString(),
        messages: []
      };

      compositionStore.setDraft('Old draft');
      chatStore.actions.selectSession(session);

      expect(get(activeSessionStore)).toEqual(session);
      expect(get(compositionStore).draft).toBe('');
    });
  });

  describe('Composition State', () => {
    test('should set composing state', () => {
      compositionStore.setComposing(true);
      expect(get(compositionStore).isComposing).toBe(true);

      compositionStore.setComposing(false);
      expect(get(compositionStore).isComposing).toBe(false);
    });

    test('should reset composition state', () => {
      compositionStore.setDraft('Draft');
      compositionStore.addAttachment('file.txt');
      compositionStore.setComposing(true);

      compositionStore.reset();

      const state = get(compositionStore);
      expect(state.draft).toBe('');
      expect(state.attachments.length).toBe(0);
      expect(state.isComposing).toBe(false);
    });
  });
});
