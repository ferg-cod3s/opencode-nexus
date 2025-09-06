export interface ChatSession {
  id: string;
  title?: string;
  created_at: string;
  messages: ChatMessage[];
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