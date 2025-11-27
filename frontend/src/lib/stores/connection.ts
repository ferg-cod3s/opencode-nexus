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

import { writable, derived } from 'svelte/store';
import type { ServerConnection } from '../opencode-client';

export interface ConnectionState {
  isConnected: boolean;
  isConnecting: boolean;
  currentServer: ServerConnection | null;
  savedServers: ServerConnection[];
  error: string | null;
  lastError?: Date;
}

const initialState: ConnectionState = {
  isConnected: false,
  isConnecting: false,
  currentServer: null,
  savedServers: [],
  error: null
};

/**
 * Connection state store for managing OpenCode server connections
 */
function createConnectionStore() {
  const { subscribe, set, update } = writable<ConnectionState>(initialState);

  return {
    subscribe,

    // Set the entire state
    setState: (state: ConnectionState) => set(state),

    // Mark as connecting
    setConnecting: (connecting: boolean) => {
      update(state => ({ ...state, isConnecting: connecting }));
    },

    // Update successful connection
    setConnected: (server: ServerConnection) => {
      update(state => ({
        ...state,
        isConnected: true,
        isConnecting: false,
        currentServer: server,
        error: null
      }));
    },

    // Mark as disconnected
    setDisconnected: () => {
      update(state => ({
        ...state,
        isConnected: false,
        isConnecting: false,
        currentServer: null
      }));
    },

    // Set error state
    setError: (error: string) => {
      update(state => ({
        ...state,
        error,
        lastError: new Date(),
        isConnecting: false
      }));
    },

    // Clear error
    clearError: () => {
      update(state => ({
        ...state,
        error: null
      }));
    },

    // Update saved servers list
    setSavedServers: (servers: ServerConnection[]) => {
      update(state => ({
        ...state,
        savedServers: servers
      }));
    },

    // Add a saved server
    addSavedServer: (server: ServerConnection) => {
      update(state => ({
        ...state,
        savedServers: state.savedServers.some(s => s.name === server.name)
          ? state.savedServers.map(s => s.name === server.name ? server : s)
          : [...state.savedServers, server]
      }));
    },

    // Reset to initial state
    reset: () => set(initialState)
  };
}

export const connectionState = createConnectionStore();

// Derived store for connection status string
export const connectionStatus = derived(
  connectionState,
  $state => {
    if ($state.isConnecting) return 'Connecting...';
    if ($state.error) return `Error: ${$state.error}`;
    if ($state.isConnected && $state.currentServer) {
      return `Connected to ${$state.currentServer.hostname}:${$state.currentServer.port}`;
    }
    return 'Disconnected';
  }
);

// Derived store for connection health
export const connectionHealth = derived(
  connectionState,
  $state => ({
    isHealthy: $state.isConnected && !$state.error,
    canRetry: !$state.isConnecting,
    hasError: $state.error !== null
  })
);
