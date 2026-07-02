export type SettingsGuidance = {
  mode: 'guide' | 'protect';
  title: string;
  canMutateSystemDns: boolean;
  steps: string[];
  claims: string[];
  actions: (
    | {
        id: 'prepare-os-apply';
        kind: 'prepare-os-apply';
        label: string;
        value: string;
        target: 'ios-app-settings' | 'android-network-settings' | 'android-private-dns';
      }
    | {
        id: 'copy-dns-servers';
        kind: 'copy';
        label: string;
        value: string;
      }
    | {
        id: 'open-settings';
        kind: 'open-settings';
        label: string;
        target: 'ios-app-settings' | 'android-network-settings' | 'android-private-dns';
      }
    | {
        id: 'retest-system-dns';
        kind: 'retest-system-dns';
        label: string;
      }
  )[];
  notes: string[];
};

export function buildSettingsGuidance(input: {
  platform: string;
  applyPlan?: unknown;
  locale?: string;
}): SettingsGuidance;

export function guidanceActionStatus(input: {
  actionKind: SettingsGuidance['actions'][number]['kind'];
  phase: 'running' | 'success' | 'failed';
  locale?: string;
}): string;
