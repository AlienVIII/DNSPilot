import type { BridgeResult, DNSProfile, PlatformId } from '@/src/api/dnspilot';

export type ApplyPlanRequest = {
  platform: PlatformId;
  profileId: string;
  profileName: string;
  testedResolver: string;
  confidence: 'high' | 'medium' | 'low' | 'inconclusive';
  gateHealth: 'healthy' | 'degraded' | 'failed' | 'inconclusive';
  environment: {
    vpnActive: boolean;
    mdmProfileActive: boolean;
    corporateDnsDetected: boolean;
    captivePortalDetected: boolean;
  };
};

export function buildApplyPlanRequest(input: {
  platform: PlatformId;
  result?: BridgeResult | null;
  profiles?: DNSProfile[];
  environment?: Partial<ApplyPlanRequest['environment']>;
}): ApplyPlanRequest | null;
