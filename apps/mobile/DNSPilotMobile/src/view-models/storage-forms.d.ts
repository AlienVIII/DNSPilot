import type { DNSProtocol } from '@/src/api/dnspilot';

export type StorageForm<TPayload> = {
  payload: TPayload;
  errors: string[];
  canSubmit: boolean;
  canDelete: boolean;
};

export type ProfileFormPayload = {
  id: string;
  name: string;
  protocol: DNSProtocol;
  ipv4Servers: string[];
  ipv6Servers: string[];
  dohUrl?: string;
  dotHostname?: string;
  filtering: 'none' | 'malware' | 'family' | 'ads' | 'security';
  tags: string[];
};

export type SuiteFormPayload = {
  id: string;
  name: string;
  domains: string[];
  tags: string[];
};

export function buildProfileForm(input: {
  profileId?: string;
  profileName?: string;
  protocol?: DNSProtocol;
  ipv4?: string;
  ipv6?: string;
  dohUrl?: string;
  dotHostname?: string;
  filtering?: ProfileFormPayload['filtering'];
  profileTags?: string;
}): StorageForm<ProfileFormPayload>;

export function buildSuiteForm(input: {
  suiteId?: string;
  suiteName?: string;
  suiteDomains?: string;
  suiteTags?: string;
}): StorageForm<SuiteFormPayload>;
