export type ActionTransport = 'native' | 'bridge';

export function actionTransport(input?: { action?: string; nativeAvailable?: boolean }): ActionTransport;
