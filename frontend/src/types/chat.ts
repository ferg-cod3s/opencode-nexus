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
  type: 'session_created' | 'message_received' | 'message_chunk' | 'error';
  session_id?: string;
  session?: ChatSession;
  message?: ChatMessage;
  chunk?: string;
  error?: string;
}