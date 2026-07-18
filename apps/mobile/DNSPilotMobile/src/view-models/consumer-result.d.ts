import type { DNSProfile } from '@/src/api/dnspilot';

export type ConsumerRecommendationKind = 'recommended' | 'best-measured' | 'keep-current' | 'none';
export type ConsumerPrimaryAction =
  | { kind: 'guide-settings'; profileId: string }
  | { kind: 'install-ios-dns-settings'; profileId: string }
  | null;

export type ConsumerResult = {
  scope: string;
  health: string;
  confidence: 'high' | 'medium' | 'low' | 'inconclusive';
  fastestObserved: {
    profileId: string;
    profileName: string;
    medianDnsLatencyMs: number;
    failureRate: number;
  } | null;
  recommendation: { kind: ConsumerRecommendationKind; profileId: string | null; profileName: string | null };
  keepCurrentDNS: boolean;
  notes: string[];
  primaryAction: ConsumerPrimaryAction;
};

export function buildConsumerResult(input?: {
  result?: unknown;
  profiles?: DNSProfile[];
  platform?: 'ios' | 'android-play';
  iosDnsSettingsAvailable?: boolean;
}): ConsumerResult;
