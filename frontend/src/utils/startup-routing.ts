export type RuntimeEnvironment = 'tauri' | 'browser' | 'test';

export type StartupRoutingContext = {
  environment: RuntimeEnvironment;
  httpBackendUrl?: string;
  hasSavedConnections: boolean;
};

export type StartupRoute = '/connect' | '/chat' | 'stay';

export const determineStartupRoute = (context: StartupRoutingContext): StartupRoute => {
  const { environment, httpBackendUrl, hasSavedConnections } = context;

  if (environment === 'browser') {
    if (httpBackendUrl) {
      return '/chat';
    }
    // In browser without backend, redirect to connect (for testing/development)
    return '/connect';
  }

  if (environment === 'tauri' || environment === 'test') {
    return hasSavedConnections ? '/chat' : '/connect';
  }

  return 'stay';
};

export const applyStartupRoute = (
  route: StartupRoute,
  currentPath: string,
  navigate: (target: string) => void
): void => {
  if (currentPath !== '/') {
    return;
  }

  if (route === 'stay') {
    return;
  }

  navigate(route);
};
