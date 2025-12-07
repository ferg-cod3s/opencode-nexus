import { describe, test, expect } from 'bun:test';
import { applyStartupRoute, determineStartupRoute, StartupRoute } from '../../utils/startup-routing';

describe('determineStartupRoute', () => {
  test('routes to connect in browser without backend URL', () => {
    const route = determineStartupRoute({
      environment: 'browser',
      httpBackendUrl: undefined,
      hasSavedConnections: false
    });

    expect(route).toBe('/connect');
  });

  test('routes to chat in browser when HTTP backend is configured', () => {
    const route = determineStartupRoute({
      environment: 'browser',
      httpBackendUrl: 'https://backend.example.com',
      hasSavedConnections: false
    });

    expect(route).toBe('/chat');
  });

  test('routes to connect in tauri when there are no saved connections', () => {
    const route = determineStartupRoute({
      environment: 'tauri',
      httpBackendUrl: undefined,
      hasSavedConnections: false
    });

    expect(route).toBe('/connect');
  });

  test('routes to chat in tauri when there are saved connections', () => {
    const route = determineStartupRoute({
      environment: 'tauri',
      httpBackendUrl: undefined,
      hasSavedConnections: true,
      isConnected: true
    });

    expect(route).toBe('/chat');
  });

  test('routes to connect in test environment when there are no saved connections', () => {
    const route = determineStartupRoute({
      environment: 'test',
      httpBackendUrl: undefined,
      hasSavedConnections: false
    });

    expect(route).toBe('/connect');
  });

  test('routes to chat in test environment when there are saved connections', () => {
    const route = determineStartupRoute({
      environment: 'test',
      httpBackendUrl: undefined,
      hasSavedConnections: true,
      isConnected: true
    });

    expect(route).toBe('/chat');
  });
});

describe('applyStartupRoute', () => {
  const setup = (initialPath: string) => {
    const navigatedTo: string[] = [];
    const navigate = (target: string) => {
      navigatedTo.push(target);
    };

    const apply = (route: StartupRoute) => {
      applyStartupRoute(route, initialPath, navigate);
    };

    return { navigatedTo, apply };
  };

  test('does nothing when not on root path', () => {
    const { navigatedTo, apply } = setup('/chat');

    apply('/connect');

    expect(navigatedTo).toHaveLength(0);
  });

  test('does nothing for stay route', () => {
    const { navigatedTo, apply } = setup('/');

    apply('stay');

    expect(navigatedTo).toHaveLength(0);
  });

  test('navigates to connect when route is /connect and on root path', () => {
    const { navigatedTo, apply } = setup('/');

    apply('/connect');

    expect(navigatedTo).toEqual(['/connect']);
  });

  test('navigates to chat when route is /chat and on root path', () => {
    const { navigatedTo, apply } = setup('/');

    apply('/chat');

    expect(navigatedTo).toEqual(['/chat']);
  });
});
