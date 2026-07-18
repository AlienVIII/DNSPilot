export type SystemAccessStatus = 'ready' | 'unknown' | 'needs-action' | 'os-gated' | 'unsupported';

export type SystemAccessAction =
  | {
      id: string;
      kind: 'open-settings';
      target: 'ios-app-settings' | 'android-app-settings' | 'android-network-settings' | 'android-private-dns';
      label: string;
    }
  | {
      id: string;
      kind: 'retest-system-dns';
      label: string;
    };

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
  actions: SystemAccessAction[];
};

export function buildSystemAccessPrompt(input: {
  platform: string;
  bridgeStatus?: 'success' | 'failed' | 'unknown';
  nativeRuntime?: boolean;
  locale?: string;
}): SystemAccessPrompt;
