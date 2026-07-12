import type { BridgeJob, BridgeResult } from '@/src/api/dnspilot';

export function createNativeJobStore(input: {
  run: <T = unknown>(action: string, payload?: Record<string, unknown>) => Promise<BridgeResult<T>>;
  now?: () => string;
}): {
  start<T = unknown>(action: string, payload?: Record<string, unknown>): BridgeJob<T>;
  get<T = unknown>(id: string): BridgeJob<T> | undefined;
};
