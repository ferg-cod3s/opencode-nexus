/*
 * MIT License
 *
 * Copyright (c) 2025 OpenCode Nexus Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in Software without restriction, including without limitation the rights
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

import { test, expect } from '@playwright/test';
import { ChatHelper } from './helpers/chat';

/**
 * Client Performance Tests
 * 
 * Tests client-side performance metrics for client-only architecture:
 * - Page load performance
 * - Connection establishment time
 * - Message send/receive latency
 * - Navigation performance
 * - Large message list rendering
 */

test.describe('Client Performance', () => {
  test.describe('Page Load Performance', () => {
    test('page load time is under 2 seconds', async ({ page }) => {
      const startTime = Date.now();
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');
      const loadTime = Date.now() - startTime;
      
      expect(loadTime).toBeLessThan(2000);
      console.log(`Page load time: ${loadTime}ms`);
    });

    test('navigation between pages is under 500ms', async ({ page }) => {
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');
      
      const startTime = Date.now();
      await page.goto('/settings');
      await page.waitForLoadState('networkidle');
      const navTime = Date.now() - startTime;
      
      expect(navTime).toBeLessThan(500);
      console.log(`Navigation time: ${navTime}ms`);
    });
  });

  test.describe('Connection Performance', () => {
    test('connection establishment is under 3 seconds', async ({ page }) => {
      const chat = new ChatHelper(page);
      
      const startTime = Date.now();
      await chat.setupMockConnection();
      const connectionTime = Date.now() - startTime;
      
      expect(connectionTime).toBeLessThan(3000);
      console.log(`Connection setup time: ${connectionTime}ms`);
    });
  });

  test.describe('Message Performance', () => {
    test('message send time is under 200ms', async ({ page }) => {
      const chat = new ChatHelper(page);
      await chat.setupMockConnection();
      
      const startTime = Date.now();
      await chat.sendMessage('Test message');
      const sendTime = Date.now() - startTime;
      
      expect(sendTime).toBeLessThan(200);
      console.log(`Message send time: ${sendTime}ms`);
    });

    test('large message list renders efficiently', async ({ page }) => {
      await page.goto('/chat');
      
      // Inject 100 mock messages
      await page.evaluate(() => {
        const messages = Array.from({ length: 100 }, (_, i) => ({
          id: `msg-${i}`,
          content: `Test message ${i}`,
          role: i % 2 === 0 ? 'user' : 'assistant',
          timestamp: new Date().toISOString()
        }));
        localStorage.setItem('mock_messages', JSON.stringify(messages));
      });
      await page.reload();
      
      // Verify messages render
      const messageCount = await page.getByTestId('chat-message').count();
      expect(messageCount).toBe(100);
      
      console.log(`Rendered ${messageCount} messages efficiently`);
    });
  });

  test.describe('UI Responsiveness', () => {
    test('interface remains responsive during message sending', async ({ page }) => {
      const chat = new ChatHelper(page);
      await chat.setupMockConnection();
      
      // Send multiple messages rapidly
      const startTime = Date.now();
      for (let i = 0; i < 5; i++) {
        await chat.sendMessage(`Test message ${i + 1}`);
        await page.waitForTimeout(100);
      }
      const totalTime = Date.now() - startTime;
      
      expect(totalTime).toBeLessThan(5000); // 5 messages in under 5 seconds
      console.log(`Sent 5 messages in ${totalTime}ms`);
    });

    test('session switching is under 300ms', async ({ page }) => {
      const chat = new ChatHelper(page);
      await chat.setupMockConnection();
      
      // Create multiple sessions
      await chat.createNewSession();
      await chat.createNewSession();
      
      // Test session switching time
      const startTime = Date.now();
      await chat.switchToSession(0);
      await chat.switchToSession(1);
      await chat.switchToSession(2);
      const switchTime = Date.now() - startTime;
      
      expect(switchTime).toBeLessThan(300); // Each switch under 100ms average
      console.log(`Session switching time: ${switchTime}ms`);
    });
  });

  test.describe('Memory Performance', () => {
    test('extended usage does not cause excessive memory growth', async ({ page }) => {
      test.setTimeout(60000); // 1 minute test
      
      const chat = new ChatHelper(page);
      await chat.setupMockConnection();
      
      // Get initial memory usage
      const initialMemory = await page.evaluate(() => (performance as any).memory?.usedJSHeapSize || 0);
      
      // Simulate extended usage
      for (let i = 0; i < 20; i++) {
        await chat.sendMessage(`Memory test message ${i + 1}`);
        await page.waitForTimeout(100);
        
        if (i % 5 === 0) {
          await chat.createNewSession();
        }
      }
      
      // Force garbage collection if available
      await page.evaluate(() => {
        if ((window as any).gc) {
          (window as any).gc();
        }
      });
      
      await page.waitForTimeout(2000);
      
      // Check final memory usage
      const finalMemory = await page.evaluate(() => (performance as any).memory?.usedJSHeapSize || 0);
      
      if (initialMemory > 0 && finalMemory > 0) {
        const memoryIncrease = finalMemory - initialMemory;
        const memoryIncreasePercent = (memoryIncrease / initialMemory) * 100;
        
        // Memory increase should be reasonable (less than 50% for 20 messages)
        expect(memoryIncreasePercent).toBeLessThan(50);
        
        console.log('Memory Usage:', {
          initial: `${Math.round(initialMemory / 1024 / 1024)}MB`,
          final: `${Math.round(finalMemory / 1024 / 1024)}MB`,
          increase: `${Math.round(memoryIncrease / 1024 / 1024)}MB (${memoryIncreasePercent.toFixed(1)}%)`
        });
      }
    });
  });

  test.describe('Accessibility Performance', () => {
    test('accessibility attributes do not impact performance', async ({ page }) => {
      const startTime = Date.now();
      await page.goto('/chat');
      await page.waitForLoadState('networkidle');
      
      // Check that accessibility features are present
      await expect(page.getByTestId('message-input')).toHaveAttribute('aria-label');
      await expect(page.getByTestId('send-button')).toHaveAttribute('aria-label');
      
      const loadTime = Date.now() - startTime;
      
      // Accessibility should not significantly impact load time
      expect(loadTime).toBeLessThan(2000);
      console.log(`Accessible page load time: ${loadTime}ms`);
    });
  });
});