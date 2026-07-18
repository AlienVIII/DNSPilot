export type NativeDnsStatusPresentation = {
  availabilityKey: string;
  installedKey: string;
  enabledKey: string;
  tone: 'green' | 'amber' | 'red';
};

export function buildNativeDnsStatus(status?: {
  available?: boolean;
  installed?: boolean;
  enabled?: boolean;
} | null): NativeDnsStatusPresentation;
