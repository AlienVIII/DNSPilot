import type { BenchmarkPlatform } from './benchmark-plan';

type Profile = { id: string; protocol: string };
type Suite = { id: string; name: string; domains: string[]; tags?: string[] };

export type QuickCheck = {
  mode: 'compare';
  selectedProfiles: string[];
  suiteId?: string;
  domains: string;
  attempts: string;
  ipFamily: 'both';
  timeoutMs: string;
  connectTimeoutMs: string;
  maxTargets: string;
  tlsEnabled: false;
  benchmarkPlatform: BenchmarkPlatform;
  saveHistory: true;
};

export type QuickCheckPreset = { id: string; suiteId: string; name: string; tags: string[] };

export function buildQuickCheck(input?: {
  profiles?: Profile[];
  suites?: Suite[];
  platform?: BenchmarkPlatform;
  presetID?: string;
}): QuickCheck;

export function quickCheckPresets(suites?: Suite[]): QuickCheckPreset[];

export function buildCheckEntryState(input?: { nativeRuntime?: boolean }): {
  showsSystemAccessSheet: false;
  showsBridgeConfiguration: boolean;
};
