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

import type { ChatMessage, ChatSession } from './chat';

/**
 * Onboarding state for new user setup
 */
export interface OnboardingState {
  completed: boolean;
  current_step?: string;
  config?: OnboardingConfig | null;
  system_requirements?: SystemRequirements;
  opencode_detected?: boolean;
  opencode_path?: string;
}

export interface OnboardingConfig {
  is_completed: boolean;
  owner_account_created: boolean;
  owner_username?: string;
  created_at: string;
  updated_at: string;
}

export interface SystemRequirements {
  os_compatible: boolean;
  memory_sufficient: boolean;
  disk_space_sufficient: boolean;
  network_available: boolean;
  required_permissions: boolean;
}

/**
 * Server information from the backend
 */
export interface ServerInfo {
  status: string;
  pid?: number;
  port: number;
  host: string;
  started_at?: string;
  last_error?: string | null;
  version?: string;
  binary_path?: string;
}

/**
 * Server performance metrics
 */
export interface ServerMetrics {
  cpu_usage: number;
  memory_usage: number;
  uptime: Duration;
  request_count: number;
  error_count: number;
}

export interface Duration {
  secs: number;
  nanos: number;
}

/**
 * Active session information
 */
export interface ActiveSession {
  session_id: string;
  created_at: string;
  last_activity: string;
  status: string;
  client_info?: string;
}

/**
 * Session statistics
 */
export interface SessionStats {
  total_sessions: number;
  active_sessions: number;
  total_messages: number;
  avg_session_duration?: Duration;
}

/**
 * Mock chat session with messages for storage
 */
export interface MockChatSession extends ChatSession {
  updated_at: string;
  message_count: number;
  type: 'session';
}

/**
 * Authentication storage state
 */
export interface AuthStorage {
  failedAttempts: number;
  lockedUntil: Date | null;
  lockoutDuration: number;
}

/**
 * Account lock status
 */
export interface AccountLockStatus {
  locked: boolean;
  unlockTime?: string;
}

/**
 * Connection information
 */
export interface ConnectionInfo {
  name: string;
  hostname: string;
  port: number;
  secure: boolean;
  last_connected: string;
}

/**
 * Tauri event payload wrapper
 */
export interface TauriEvent<T> {
  payload: T;
}

/**
 * Generic event listener type
 */
export type EventListener<T = unknown> = (event: TauriEvent<T>) => void;

/**
 * Mock API function type
 */
export type MockApiFunction<TArgs = void, TResult = void> = (args: TArgs) => Promise<TResult>;

/**
 * Command arguments for various API calls
 */
export interface AuthenticateArgs {
  username: string;
  password: string;
}

export interface CreateChatSessionArgs {
  title?: string;
}

export interface ChatSessionHistoryArgs {
  session_id: string;
}

export interface SendChatMessageArgs {
  session_id: string;
  content: string;
}

export interface ConnectToServerArgs {
  serverUrl: string;
  apiKey?: string;
  method: string;
  name: string;
}

export interface TestConnectionArgs {
  serverUrl: string;
  apiKey?: string;
}

/**
 * User info tuple [username, created_at, last_login]
 */
export type UserInfo = [string, string, string | null];

/**
 * Environment check result
 */
export interface EnvironmentCheck {
  isTauri: boolean;
  canAuthenticate: boolean;
  environment: 'tauri' | 'browser' | 'test';
  httpBackendUrl?: string;
}

/**
 * Vite import.meta.env type augmentation
 */
export interface ImportMetaEnv {
  VITE_CHAT_BACKEND_URL?: string;
}

/**
 * Window augmentation for runtime config
 */
export interface WindowWithConfig extends Window {
  VITE_CHAT_BACKEND_URL?: string;
  __TAURI__?: unknown;
}

/**
 * Generic message for chat events
 */
export interface ChatEventMessage {
  id: string;
  role: string;
  content: string;
  timestamp: string;
}
