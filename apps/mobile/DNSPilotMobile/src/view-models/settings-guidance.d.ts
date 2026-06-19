export type SettingsGuidance = {
  mode: 'guide' | 'protect';
  title: string;
  canMutateSystemDns: boolean;
  steps: string[];
  claims: string[];
  notes: string[];
};

export function buildSettingsGuidance(input: {
  platform: string;
  applyPlan?: unknown;
}): SettingsGuidance;
