import Constants from 'expo-constants';
import React, { createContext, useCallback, useContext, useMemo, useState } from 'react';

import {
  BridgeResult,
  callBridge,
  bridgeHealth,
  Capability,
  DNSProfile,
  HistoryRecord,
  normalizeCapabilities,
  normalizeHistory,
  normalizeProfiles,
  normalizeSuites,
  TestSuite,
} from '@/src/api/dnspilot';

type DNSPilotContextValue = {
  bridgeUrl: string;
  setBridgeUrl: (value: string) => void;
  health: { ok: boolean; dbPath?: string; repoRoot?: string } | null;
  profiles: DNSProfile[];
  suites: TestSuite[];
  capabilities: Capability[];
  history: HistoryRecord[];
  loading: boolean;
  error: string | null;
  refreshAll: () => Promise<void>;
  runAction: <T = unknown>(action: string, payload?: Record<string, unknown>) => Promise<BridgeResult<T>>;
};

const DNSPilotContext = createContext<DNSPilotContextValue | null>(null);

const defaultBridgeUrl =
  process.env.EXPO_PUBLIC_DNSPILOT_BRIDGE_URL ??
  (Constants.expoConfig?.extra?.dnspilotBridgeUrl as string | undefined) ??
  'http://localhost:8787';

export function DNSPilotProvider({ children }: { children: React.ReactNode }) {
  const [bridgeUrl, setBridgeUrl] = useState(defaultBridgeUrl);
  const [health, setHealth] = useState<DNSPilotContextValue['health']>(null);
  const [profiles, setProfiles] = useState<DNSProfile[]>([]);
  const [suites, setSuites] = useState<TestSuite[]>([]);
  const [capabilities, setCapabilities] = useState<Capability[]>([]);
  const [history, setHistory] = useState<HistoryRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const runAction = useCallback<DNSPilotContextValue['runAction']>(
    async (action, payload = {}) => {
      setError(null);
      try {
        return await callBridge(bridgeUrl, action, payload);
      } catch (caught) {
        const message = caught instanceof Error ? caught.message : String(caught);
        setError(message);
        throw caught;
      }
    },
    [bridgeUrl]
  );

  const refreshAll = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const nextHealth = await bridgeHealth(bridgeUrl);
      const [catalogResult, capabilitiesResult, profilesResult, suitesResult, historyResult] =
        await Promise.all([
          callBridge(bridgeUrl, 'catalog'),
          callBridge(bridgeUrl, 'capabilities'),
          callBridge(bridgeUrl, 'profileList'),
          callBridge(bridgeUrl, 'suiteList'),
          callBridge(bridgeUrl, 'historyList'),
        ]);
      setHealth(nextHealth);
      setProfiles(normalizeProfiles(profilesResult.data).length > 0 ? normalizeProfiles(profilesResult.data) : normalizeProfiles(catalogResult.data));
      setSuites(normalizeSuites(suitesResult.data).length > 0 ? normalizeSuites(suitesResult.data) : normalizeSuites(catalogResult.data));
      setCapabilities(normalizeCapabilities(capabilitiesResult.data));
      setHistory(normalizeHistory(historyResult.data));
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : String(caught);
      setError(message);
      throw caught;
    } finally {
      setLoading(false);
    }
  }, [bridgeUrl]);

  const value = useMemo(
    () => ({
      bridgeUrl,
      setBridgeUrl,
      health,
      profiles,
      suites,
      capabilities,
      history,
      loading,
      error,
      refreshAll,
      runAction,
    }),
    [bridgeUrl, health, profiles, suites, capabilities, history, loading, error, refreshAll, runAction]
  );

  return <DNSPilotContext.Provider value={value}>{children}</DNSPilotContext.Provider>;
}

export function useDNSPilot() {
  const context = useContext(DNSPilotContext);
  if (!context) {
    throw new Error('useDNSPilot must be used inside DNSPilotProvider');
  }
  return context;
}
