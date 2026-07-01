export type SystemAccessStatus = 'ready' | 'unknown' | 'needs-action' | 'os-gated' | 'unsupported';

export type SystemAccessPrompt = {
  shouldPrompt: boolean;
  title: string;
  summary: string;
  checks: {
    id: string;
    label: string;
    status: SystemAccessStatus;
    detail: string;
  }[];
  actions: {
    id: string;
    kind: 'open-settings';
    target: 'ios-app-settings' | 'android-app-settings' | 'android-network-settings' | 'android-private-dns';
    label: string;
  }[];
};

export function buildSystemAccessPrompt(input: {
  platform: string;
  bridgeStatus?: 'success' | 'failed' | 'unknown';
  locale?: string;
}): SystemAccessPrompt;
