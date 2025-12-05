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

import { test, expect } from '@playwright/test';
import { ChatHelper } from './helpers/chat';

/**
 * @deprecated These tests are for the OLD architecture (server management + local server).
 * After the client pivot, server management features were removed.
 * 
 * TODO: Rewrite performance tests for client-only architecture:
 * - Page load performance
 * - Connection establishment time
 * - Message send/receive latency
 * - Memory usage during chat sessions
 * - Navigation performance
 */

// Skip all performance tests - they test deprecated server management flows
test.describe.skip('Performance Tests (DEPRECATED - Server Management)', () => {
  test.describe('Chat Performance', () => {
    test('chat message response time meets performance targets', async ({ page }) => {
      test.setTimeout(30000);
      
      const chat = new ChatHelper(page);
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Test multiple response times to get average
      const responseTimes: number[] = [];
      const testMessages = [
        'What is 2 + 2?',
        'Hello',
        'Tell me about Python',
        'How do I create a function?'
      ];
      
      for (const message of testMessages) {
        const startTime = Date.now();
        await chat.sendMessage(message);
        await chat.waitForFirstResponseToken();
        const responseTime = Date.now() - startTime;
        
        responseTimes.push(responseTime);
        
        // Individual response should be under 3 seconds
        expect(responseTime).toBeLessThan(3000);
        
        // Wait for complete response before next message
        await chat.waitForResponse();
        
        // Small delay between messages
        await page.waitForTimeout(500);
      }
      
      // Calculate average response time
      const averageResponseTime = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
      
      // Average response time should be under 2 seconds
      expect(averageResponseTime).toBeLessThan(2000);
      
      console.log('Chat Response Times:', {
        individual: responseTimes,
        average: averageResponseTime,
        target: '< 2000ms'
      });
    });

    test('streaming messages display progressively without lag', async ({ page }) => {
      test.setTimeout(45000);
      
      const chat = new ChatHelper(page);
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Send message that should generate long response
      await chat.sendMessage('Write a detailed explanation of React components with multiple code examples');
      
      // Monitor streaming performance
      let tokenCount = 0;
      let streamingStartTime = 0;
      let firstTokenTime = 0;
      
      // Wait for streaming to start
      await expect(page.locator('[data-testid="typing-indicator"]')).toBeVisible();
      streamingStartTime = Date.now();
      
      // Monitor the AI response element for content updates
      const aiMessage = page.locator('[data-testid="ai-message"]').last();
      
      // Wait for first content to appear
      await expect(aiMessage).not.toBeEmpty({ timeout: 5000 });
      firstTokenTime = Date.now();
      
      const firstTokenDelay = firstTokenTime - streamingStartTime;
      expect(firstTokenDelay).toBeLessThan(2000); // First token within 2 seconds
      
      // Monitor streaming completion
      let previousLength = 0;
      let stagnantCount = 0;
      
      while (await page.locator('[data-testid="typing-indicator"]').isVisible()) {
        const currentContent = await aiMessage.textContent() || '';
        const currentLength = currentContent.length;
        
        if (currentLength > previousLength) {
          // Content is growing - streaming is active
          tokenCount++;
          stagnantCount = 0;
          previousLength = currentLength;
        } else {
          // No new content
          stagnantCount++;
          if (stagnantCount > 10) {
            // No progress for too long - might be stuck
            break;
          }
        }
        
        // Small delay between checks
        await page.waitForTimeout(100);
      }
      
      // Verify streaming completed successfully
      await expect(page.locator('[data-testid="typing-indicator"]')).not.toBeVisible();
      
      const finalContent = await aiMessage.textContent() || '';
      expect(finalContent.length).toBeGreaterThan(100); // Should have substantial content
      
      console.log('Streaming Performance:', {
        firstTokenDelay,
        tokenUpdates: tokenCount,
        finalContentLength: finalContent.length
      });
    });

    test('chat interface remains responsive during heavy streaming', async ({ page }) => {
      test.setTimeout(60000);
      
      const chat = new ChatHelper(page);
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Start a long streaming response
      await chat.sendMessage('Generate a comprehensive tutorial on web development covering HTML, CSS, JavaScript, and React with detailed code examples for each section');
      
      // While streaming is happening, test UI responsiveness
      await expect(page.locator('[data-testid="typing-indicator"]')).toBeVisible();
      
      // Test that we can still interact with the interface
      await test.step('UI interactions during streaming', async () => {
        // Should be able to click buttons (though some might be disabled)
        const newSessionButton = page.locator('[data-testid="new-session-button"]');
        if (await newSessionButton.isEnabled()) {
          await newSessionButton.click();
          // Should create new session even while other session is streaming
          await expect(page.locator('[data-testid="chat-messages"]')).toBeEmpty();
        }
        
        // Should be able to navigate between sessions
        const sessions = page.locator('[data-testid="chat-session"]');
        const sessionCount = await sessions.count();
        if (sessionCount > 1) {
          await sessions.first().click();
          // Should switch back to streaming session
          await expect(page.locator('[data-testid="typing-indicator"]')).toBeVisible();
        }
        
        // Should be able to scroll through chat
        const chatContainer = page.locator('[data-testid="chat-messages"]');
        await chatContainer.evaluate(el => el.scrollTop = 0);
        await page.waitForTimeout(100);
        await chatContainer.evaluate(el => el.scrollTop = el.scrollHeight);
        
        // Input field should be responsive (though send might be disabled)
        await page.fill('[data-testid="message-input"]', 'This should be responsive');
        await expect(page.locator('[data-testid="message-input"]')).toHaveValue('This should be responsive');
        await page.fill('[data-testid="message-input"]', '');
      });
      
      // Wait for streaming to complete
      await chat.waitForStreamingResponse();
      
      // Interface should be fully functional again
      await chat.sendMessage('Interface was responsive during streaming');
      await chat.waitForResponse();
    });
  });

  test.describe('Server Management Performance', () => {
    test('server startup time meets targets', async ({ page }) => {
      test.setTimeout(45000);
      
      const server = new ServerHelper(page);
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Test server startup multiple times for consistency
      const startupTimes: number[] = [];
      const testRuns = 3;
      
      for (let i = 0; i < testRuns; i++) {
        // Ensure server is stopped
        const status = await server.getServerStatus();
        if (!status.toLowerCase().includes('stopped')) {
          await server.stopServer();
          await server.waitForServerStopped();
        }
        
        // Time server startup
        const startTime = Date.now();
        await server.startServer();
        await server.waitForServerRunning();
        const startupTime = Date.now() - startTime;
        
        startupTimes.push(startupTime);
        
        // Individual startup should be under 15 seconds
        expect(startupTime).toBeLessThan(15000);
        
        // Small delay between tests
        await page.waitForTimeout(1000);
      }
      
      // Calculate average startup time
      const averageStartupTime = startupTimes.reduce((a, b) => a + b, 0) / startupTimes.length;
      
      // Average startup should be under 10 seconds
      expect(averageStartupTime).toBeLessThan(10000);
      
      console.log('Server Startup Performance:', {
        individual: startupTimes,
        average: averageStartupTime,
        target: '< 10000ms'
      });
    });

    test('real-time metrics update without performance degradation', async ({ page }) => {
      test.setTimeout(60000);
      
      const server = new ServerHelper(page);
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      
      // Start server to get metrics
      await server.startServer();
      await server.waitForServerRunning();
      
      // Monitor metrics updates over time
      const metricsUpdates: number[] = [];
      const monitoringDuration = 30000; // 30 seconds
      const startTime = Date.now();
      
      let previousTimestamp = '';
      let updateCount = 0;
      
      while (Date.now() - startTime < monitoringDuration) {
        // Check if metrics timestamp has updated
        const currentTimestamp = await page.textContent('[data-testid="metrics-timestamp"]') || '';
        
        if (currentTimestamp !== previousTimestamp && currentTimestamp !== '') {
          const updateTime = Date.now();
          metricsUpdates.push(updateTime);
          updateCount++;
          previousTimestamp = currentTimestamp;
          
          // Verify CPU and memory metrics are updating
          const cpuUsage = await page.textContent('[data-testid="cpu-usage"]');
          const memoryUsage = await page.textContent('[data-testid="memory-usage"]');
          
          expect(cpuUsage).toBeTruthy();
          expect(memoryUsage).toBeTruthy();
        }
        
        // Check update frequency (should update every 2-5 seconds)
        await page.waitForTimeout(1000);
      }
      
      // Should have gotten several updates
      expect(updateCount).toBeGreaterThan(3);
      
      // Calculate average update interval
      if (metricsUpdates.length > 1) {
        const intervals = [];
        for (let i = 1; i < metricsUpdates.length; i++) {
          intervals.push(metricsUpdates[i] - metricsUpdates[i - 1]);
        }
        const averageInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
        
        // Updates should be frequent enough (every 2-10 seconds)
        expect(averageInterval).toBeGreaterThan(1000); // At least 1 second apart
        expect(averageInterval).toBeLessThan(10000); // No more than 10 seconds apart
        
        console.log('Metrics Update Performance:', {
          totalUpdates: updateCount,
          averageInterval: averageInterval,
          target: '2-10 seconds'
        });
      }
    });

    test('concurrent server operations maintain performance', async ({ page }) => {
      test.setTimeout(90000);
      
      const server = new ServerHelper(page);
      const chat = new ChatHelper(page);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      await server.startServer();
      await server.waitForServerRunning();
      
      // Start concurrent operations
      await test.step('Run concurrent operations', async () => {
        const operations = [
          // Server metrics refresh
          async () => {
            for (let i = 0; i < 5; i++) {
              await page.click('[data-testid="refresh-metrics-button"]');
              await page.waitForTimeout(2000);
            }
          },
          
          // Log viewing
          async () => {
            await server.checkServerLogs();
            await page.waitForTimeout(1000);
          },
          
          // Chat interactions
          async () => {
            await chat.navigateToChat();
            await chat.sendMessage('Testing concurrent performance');
            await chat.waitForResponse();
          },
          
          // Dashboard navigation
          async () => {
            for (let i = 0; i < 3; i++) {
              await server.navigateToDashboard();
              await chat.navigateToChat();
              await server.navigateToDashboard();
              await page.waitForTimeout(500);
            }
          }
        ];
        
        // Run all operations concurrently
        const startTime = Date.now();
        await Promise.all(operations);
        const totalTime = Date.now() - startTime;
        
        // All concurrent operations should complete within reasonable time
        expect(totalTime).toBeLessThan(30000); // Under 30 seconds
        
        console.log('Concurrent Operations Time:', totalTime + 'ms');
      });
      
      // Verify system is still responsive after concurrent operations
      await test.step('Verify system responsiveness', async () => {
        // Server should still be running
        const status = await server.getServerStatus();
        expect(status.toLowerCase()).toContain('running');
        
        // Chat should still work
        await chat.navigateToChat();
        await chat.sendMessage('System still responsive after concurrent operations');
        await chat.waitForResponse();
        
        // Metrics should still be updating
        await server.navigateToDashboard();
        await server.verifyServerMetrics();
      });
    });
  });

  test.describe('Real-time Features Performance', () => {
    test('SSE connections maintain performance under load', async ({ page }) => {
      test.setTimeout(90000);
      
      const chat = new ChatHelper(page);
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Create multiple chat sessions to test SSE handling
      const sessionCount = 3;
      const sessions = [];
      
      for (let i = 0; i < sessionCount; i++) {
        await chat.createNewSession();
        sessions.push(i);
        
        // Send message in each session
        await chat.sendMessage(`Test message in session ${i + 1}`);
        
        // Don't wait for full response to create load
        await page.waitForTimeout(1000);
      }
      
      // Monitor SSE performance while multiple streams are active
      const eventCount = 0;
      const eventTimes: number[] = [];
      
      // Listen for SSE events (this would be implementation-specific)
      await page.evaluate(() => {
        const originalEventSource = window.EventSource;
        let eventCounter = 0;
        
        // Mock event monitoring
        window.EventSource = function(url: string, options?: any) {
          const es = new originalEventSource(url, options);
          
          es.addEventListener('message', (event) => {
            eventCounter++;
            (window as any).sseEventCount = eventCounter;
            (window as any).lastEventTime = Date.now();
          });
          
          return es;
        };
      });
      
      // Wait for all responses to complete
      for (let i = 0; i < sessionCount; i++) {
        await chat.switchToSession(i);
        await chat.waitForResponse();
      }
      
      // Check SSE performance metrics
      const finalEventCount = await page.evaluate(() => (window as any).sseEventCount || 0);
      const lastEventTime = await page.evaluate(() => (window as any).lastEventTime || 0);
      
      // Should have received events for all sessions
      expect(finalEventCount).toBeGreaterThan(0);
      
      // All sessions should have working messages
      for (let i = 0; i < sessionCount; i++) {
        await chat.switchToSession(i);
        const messageCount = await chat.getMessageCount();
        expect(messageCount).toBeGreaterThanOrEqual(2); // At least user message + AI response
      }
      
      console.log('SSE Performance:', {
        sessions: sessionCount,
        events: finalEventCount,
        eventsPerSession: finalEventCount / sessionCount
      });
    });

    test('real-time updates maintain accuracy under concurrent load', async ({ page }) => {
      test.setTimeout(120000);
      
      const server = new ServerHelper(page);
      const chat = new ChatHelper(page);
      
      await server.loginAsTestUser();
      await server.navigateToDashboard();
      await server.startServer();
      await server.waitForServerRunning();
      
      // Create concurrent real-time activities
      await test.step('Generate concurrent real-time load', async () => {
        // Start server operations in background
        const serverOperations = async () => {
          // Rapidly refresh metrics
          for (let i = 0; i < 10; i++) {
            await page.click('[data-testid="refresh-metrics-button"]');
            await page.waitForTimeout(1000);
          }
        };
        
        // Start chat operations in another tab
        const chatOperations = async () => {
          await chat.navigateToChat();
          
          // Send multiple messages rapidly
          for (let i = 0; i < 3; i++) {
            await chat.sendMessage(`Concurrent load test message ${i + 1}`);
            // Don't wait for full response - create load
            await page.waitForTimeout(2000);
          }
        };
        
        // Run concurrent operations
        await Promise.all([serverOperations(), chatOperations()]);
      });
      
      // Verify real-time accuracy after load
      await test.step('Verify real-time accuracy', async () => {
        // Server metrics should still be accurate
        await server.navigateToDashboard();
        await server.verifyServerMetrics();
        
        const serverStatus = await server.getServerStatus();
        expect(serverStatus.toLowerCase()).toContain('running');
        
        // Chat should still be responsive and accurate
        await chat.navigateToChat();
        
        // Wait for any pending responses
        await page.waitForTimeout(5000);
        
        // Should be able to send new message and get response
        await chat.sendMessage('Testing accuracy after concurrent load');
        await chat.waitForResponse();
        
        // Response should be coherent and timely
        const lastMessage = page.locator('[data-testid="ai-message"]').last();
        const responseContent = await lastMessage.textContent();
        expect(responseContent?.length).toBeGreaterThan(10);
      });
    });
  });

  test.describe('Memory and Resource Performance', () => {
    test('extended usage does not cause memory leaks', async ({ page }) => {
      test.setTimeout(180000); // 3 minutes for memory test
      
      const chat = new ChatHelper(page);
      await chat.loginAndStartServer();
      await chat.navigateToChat();
      
      // Get initial memory usage
      const initialMemory = await page.evaluate(() => (performance as any).memory?.usedJSHeapSize || 0);
      
      // Simulate extended usage
      await test.step('Extended usage simulation', async () => {
        // Send many messages to create memory load
        for (let i = 0; i < 10; i++) {
          await chat.sendMessage(`Memory test message ${i + 1}`);
          await chat.waitForResponse();
          
          // Create and switch sessions
          if (i % 3 === 0) {
            await chat.createNewSession();
          }
          
          // Navigate between sections
          const server = new ServerHelper(page);
          await server.navigateToDashboard();
          await chat.navigateToChat();
          
          await page.waitForTimeout(1000);
        }
      });
      
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
        
        // Memory increase should be reasonable (less than 100% increase)
        expect(memoryIncreasePercent).toBeLessThan(100);
        
        console.log('Memory Usage:', {
          initial: `${Math.round(initialMemory / 1024 / 1024)}MB`,
          final: `${Math.round(finalMemory / 1024 / 1024)}MB`,
          increase: `${Math.round(memoryIncrease / 1024 / 1024)}MB (${memoryIncreasePercent.toFixed(1)}%)`
        });
      }
    });

    test('application startup performance meets targets', async ({ page }) => {
      test.setTimeout(30000);
      
      // Measure cold start time
      const startTime = Date.now();
      
      // Navigate to application
      await page.goto('/');
      
      // Wait for authentication check and redirect
      await page.waitForLoadState('networkidle');
      
      const authCheckTime = Date.now();
      
      // Complete login
      await page.fill('[data-testid="username-input"]', 'testuser');
      await page.fill('[data-testid="password-input"]', 'SecurePass123!');
      await page.click('[data-testid="login-button"]');
      
      // Wait for dashboard to be fully loaded
      await expect(page.locator('[data-testid="dashboard-welcome"]')).toBeVisible();
      
      const dashboardLoadTime = Date.now();
      
      // Start server
      await page.click('[data-testid="start-server-button"]');
      const server = new ServerHelper(page);
      await server.waitForServerRunning();
      
      const serverStartTime = Date.now();
      
      // Navigate to chat
      const chat = new ChatHelper(page);
      await chat.navigateToChat();
      await expect(page.locator('[data-testid="chat-interface"]')).toBeVisible();
      
      const chatReadyTime = Date.now();
      
      // Calculate performance metrics
      const metrics = {
        authCheck: authCheckTime - startTime,
        dashboardLoad: dashboardLoadTime - authCheckTime,
        serverStart: serverStartTime - dashboardLoadTime,
        chatReady: chatReadyTime - serverStartTime,
        total: chatReadyTime - startTime
      };
      
      // Performance targets
      expect(metrics.authCheck).toBeLessThan(2000); // Auth check < 2s
      expect(metrics.dashboardLoad).toBeLessThan(3000); // Dashboard load < 3s  
      expect(metrics.serverStart).toBeLessThan(15000); // Server start < 15s
      expect(metrics.chatReady).toBeLessThan(1000); // Chat ready < 1s
      expect(metrics.total).toBeLessThan(20000); // Total < 20s
      
      console.log('Startup Performance Metrics:', metrics);
    });
  });
});