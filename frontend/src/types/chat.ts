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

export interface ChatSession {
  id: string;
  title?: string;
  created_at: string;
  messages: ChatMessage[];
}

// Model configuration for selecting provider and model
export interface ModelConfig {
  provider_id: string;
  model_id: string;
}

// Lightweight metadata for mobile-optimized session list
// Full messages fetched from server on-demand
export interface SessionMetadata {
  id: string;
  title?: string;
  created_at: string;
  updated_at?: string;
  message_count: number;
}

export interface ChatMessage {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: string;
}

export enum MessageRole {
  User = "user",
  Assistant = "assistant"
}

export interface ChatEvent {
  SessionCreated?: { session: ChatSession };
  MessageReceived?: { session_id: string; message: ChatMessage };
  MessageChunk?: { session_id: string; chunk: string };
  Error?: { message: string };
}