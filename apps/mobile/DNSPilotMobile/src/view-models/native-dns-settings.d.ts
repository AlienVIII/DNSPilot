import type { DNSProfile } from '@/src/api/dnspilot';

export type IosDnsSettingsRequest = {
  description: string;
  protocol: 'doh';
  serverAddresses: string[];
  dohUrl: string;
} | {
  description: string;
  protocol: 'dot';
  serverAddresses: string[];
  dotHostname: string;
};

export type IosDnsSettingsPlan = {
  canInstall: boolean;
  request: IosDnsSettingsRequest | null;
  reason: 'encrypted-protocol-required' | 'bootstrap-address-required' | 'valid-doh-url-required' | 'valid-dot-hostname-required' | null;
};

export function buildIosDnsSettingsRequest(profile: DNSProfile | null | undefined): IosDnsSettingsPlan;
