export type BenchmarkStepStatus = 'idle' | 'running' | 'success' | 'failed';
export type BenchmarkRunStatus = 'running' | 'success' | 'failed';

export type BenchmarkStep = {
  id: 'prepare' | 'dns' | 'connect' | 'tls' | 'save';
  label: string;
  status: BenchmarkStepStatus;
};

export type ResolverDiagnostic = {
  profileId: string;
  resolver?: string;
  status: 'running' | 'success' | 'degraded' | 'failed';
  elapsedMs?: number;
  failureRate?: number;
  timeoutRate?: number;
  diagnosis: string;
};

export type BenchmarkDiagnostics = {
  status: BenchmarkRunStatus;
  elapsedMs?: number;
  failedStepId?: BenchmarkStep['id'];
  reason: string;
  debugLog: string;
  steps: BenchmarkStep[];
  resolvers: ResolverDiagnostic[];
  report: string;
};

export function buildBenchmarkDiagnostics(input: {
  mode: string;
  result?: unknown;
  error?: unknown;
  startedAtMs?: number;
  endedAtMs?: number;
}): BenchmarkDiagnostics;
