export type SettingsGuidance = {
  mode: 'guide' | 'protect';
  title: string;
  canMutateSystemDns: boolean;
  steps: string[];
  claims: string[];
  actions: (
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
      }
  )[];
  notes: string[];
};

export function buildSettingsGuidance(input: {
  platform: string;
  applyPlan?: unknown;
  locale?: string;
}): SettingsGuidance;
