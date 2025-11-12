export interface ChatSession {
  id: string;
  title?: string;
  created_at: string;
  messages: ChatMessage[];
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