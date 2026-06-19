import type { TestSuite } from '@/src/api/dnspilot';

export type BenchmarkMode = 'compare' | 'pathCompare' | 'benchmark' | 'pathEstimate' | 'systemBenchmark';
export type BenchmarkIpFamily = 'both' | 'ipv4-only' | 'ipv6-only';
export type BenchmarkPlatform = 'ios' | 'android-play';

export type BenchmarkPayload = {
  profileIds: string[];
  profileId: string;
  suiteId?: string;
  domains: string[];
  attempts: number;
  ipFamily: BenchmarkIpFamily;
  timeoutMs: number;
  dnsTimeoutMs: number;
  connectTimeoutMs: number;
  maxConnectTargetsPerDomain: number;
  tlsHandshakeTimeoutMs?: number;
  platform: BenchmarkPlatform;
  saveHistory: boolean;
};

export type BenchmarkPlan = {
  payload: BenchmarkPayload;
  errors: string[];
  canRun: boolean;
  domainCount: number;
  selectedCount: number | 'system';
  selectedSuite?: TestSuite;
  historyEnabled: boolean;
};

export function buildBenchmarkPlan(input: {
  mode?: BenchmarkMode;
  selectedProfiles?: string[];
  suites?: TestSuite[];
  suiteId?: string;
  domains?: string;
  attempts?: string;
  ipFamily?: BenchmarkIpFamily;
  timeoutMs?: string;
  connectTimeoutMs?: string;
  maxTargets?: string;
  tlsEnabled?: boolean;
  benchmarkPlatform?: BenchmarkPlatform;
  saveHistory?: boolean;
}): BenchmarkPlan;

export function suggestedSuites(suites?: TestSuite[]): {
  defaultSuiteId?: string;
  vietnamSuiteId?: string;
};
