export type DNSProtocol = 'plain' | 'doh' | 'dot';
export type PlatformId =
  | 'ios'
  | 'android-play'
  | 'macos-store'
  | 'windows-store'
  | 'linux-flatpak'
  | 'linux-snap'
  | 'linux-native-power'
  | 'macos-power'
  | 'windows-power';

export type DNSProfile = {
  id: string;
  name: string;
  description?: string;
  ipv4_servers?: string[];
  ipv6_servers?: string[];
  protocol: DNSProtocol;
  doh_url?: string | null;
  dot_hostname?: string | null;
  tags?: string[];
  use_case?: string;
  filtering_type?: string;
  security_notes?: string[];
};

export type TestSuite = {
  id: string;
  name: string;
  description?: string;
  domains: string[];
  tags?: string[];
};

export type Capability = {
  platform: PlatformId;
  can_benchmark: boolean;
  apply: string;
  flush: string;
  store_safe: boolean;
  notes: string[];
};

export type HistoryRecord = {
  id: string;
  started_at?: string;
  scope?: string;
  mode?: string;
  domains?: string[];
  resolver_profile_ids?: string[];
  recommendation_profile_id?: string | null;
  notes?: string[];
};

export type BridgeResult<T = unknown> = {
  ok: boolean;
  action: string;
  args: string[];
  data: T;
  progress?: unknown[];
};

export type BridgeJobStatus = 'running' | 'success' | 'failed' | 'cancelled';

export type BridgeJob<T = unknown> = {
  id: string;
  action: string;
  status: BridgeJobStatus;
  started_at: string;
  ended_at?: string | null;
  progress: unknown[];
  result?: BridgeResult<T> | null;
  error?: { message?: string; details?: unknown } | null;
};

type BridgeErrorBody = {
  error?: string;
  details?: unknown;
};

type BridgeJobBody<T = unknown> = {
  ok: boolean;
  job?: BridgeJob<T>;
  error?: string;
  details?: unknown;
};

export async function bridgeHealth(baseUrl: string) {
  const response = await fetch(`${trimBaseUrl(baseUrl)}/health`);
  if (!response.ok) {
    throw new Error(`Bridge health failed: ${response.status}`);
  }
  return response.json() as Promise<{ ok: boolean; dbPath: string; repoRoot: string }>;
}

export async function callBridge<T = unknown>(
  baseUrl: string,
  action: string,
  payload: Record<string, unknown> = {}
): Promise<BridgeResult<T>> {
  const response = await fetch(`${trimBaseUrl(baseUrl)}/api/cli`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ action, payload }),
  });
  const body = (await response.json()) as BridgeResult<T> | BridgeErrorBody;
  if (!response.ok || !('ok' in body) || !body.ok) {
    const message = 'error' in body && body.error ? body.error : `Bridge command failed: ${action}`;
    throw new Error(message);
  }
  return body;
}

export async function startBridgeJob<T = unknown>(
  baseUrl: string,
  action: string,
  payload: Record<string, unknown> = {}
): Promise<BridgeJob<T>> {
  const response = await fetch(`${trimBaseUrl(baseUrl)}/api/jobs`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ action, payload }),
  });
  const body = (await response.json()) as BridgeJobBody<T>;
  if (!response.ok || !body.ok || !body.job) {
    throw new Error(body.error ?? `Bridge job failed to start: ${action}`);
  }
  return body.job;
}

export async function getBridgeJob<T = unknown>(baseUrl: string, id: string): Promise<BridgeJob<T>> {
  const response = await fetch(`${trimBaseUrl(baseUrl)}/api/jobs/${encodeURIComponent(id)}`);
  const body = (await response.json()) as BridgeJobBody<T>;
  if (!response.ok || !body.ok || !body.job) {
    throw new Error(body.error ?? `Bridge job not found: ${id}`);
  }
  return body.job;
}

export async function cancelBridgeJob<T = unknown>(baseUrl: string, id: string): Promise<BridgeJob<T>> {
  const response = await fetch(`${trimBaseUrl(baseUrl)}/api/jobs/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
  const body = (await response.json()) as BridgeJobBody<T>;
  if (!response.ok || !body.ok || !body.job) {
    throw new Error(body.error ?? `Bridge job could not be cancelled: ${id}`);
  }
  return body.job;
}

export function normalizeProfiles(data: unknown): DNSProfile[] {
  const payload = data as { profiles?: DNSProfile[] };
  return Array.isArray(payload?.profiles) ? payload.profiles : [];
}

export function normalizeSuites(data: unknown): TestSuite[] {
  const payload = data as { testSuites?: TestSuite[]; test_suites?: TestSuite[] };
  if (Array.isArray(payload?.testSuites)) {
    return payload.testSuites;
  }
  if (Array.isArray(payload?.test_suites)) {
    return payload.test_suites;
  }
  return [];
}

export function normalizeCapabilities(data: unknown): Capability[] {
  const payload = data as { capabilities?: Capability[] };
  return Array.isArray(payload?.capabilities) ? payload.capabilities : [];
}

export function normalizeHistory(data: unknown): HistoryRecord[] {
  const payload = data as { benchmark_history?: HistoryRecord[] };
  return Array.isArray(payload?.benchmark_history) ? payload.benchmark_history : [];
}

export function profileServers(profile: DNSProfile) {
  return [...(profile.ipv4_servers ?? []), ...(profile.ipv6_servers ?? [])];
}

export function isCustomProfile(profile: DNSProfile) {
  return profile.use_case === 'custom' || profile.tags?.includes('custom');
}

export function isCustomSuite(suite: TestSuite) {
  return suite.description === 'Custom domain test suite.' || suite.tags?.includes('custom');
}

export function compactJson(value: unknown, maxLength = 6000) {
  const text = JSON.stringify(value, null, 2);
  if (text.length <= maxLength) {
    return text;
  }
  return `${text.slice(0, maxLength)}\n... truncated ...`;
}

function trimBaseUrl(baseUrl: string) {
  return baseUrl.trim().replace(/\/+$/, '');
}
