import Constants from 'expo-constants';
import * as Localization from 'expo-localization';
import React, { createContext, useCallback, useContext, useMemo, useState } from 'react';
import { AppState } from 'react-native';

import {
  BridgeJob,
  BridgeResult,
  callBridge,
  bridgeHealth,
  Capability,
  DNSProfile,
  getBridgeJob,
  HistoryRecord,
  normalizeCapabilities,
  normalizeHistory,
  normalizeProfiles,
  normalizeSuites,
  startBridgeJob,
  TestSuite,
} from '@/src/api/dnspilot';
import {
  createTranslator,
  languageOptions,
  resolveLocale,
  type LanguagePreference,
  type SupportedLocale,
  type Translator,
} from '@/src/view-models/localization';

type DNSPilotContextValue = {
  bridgeUrl: string;
  setBridgeUrl: (value: string) => void;
  locale: SupportedLocale;
  languagePreference: LanguagePreference;
  setLanguagePreference: (value: LanguagePreference) => void;
  languageOptions: typeof languageOptions;
  t: Translator;
  health: { ok: boolean; dbPath?: string; repoRoot?: string } | null;
  profiles: DNSProfile[];
  suites: TestSuite[];
  capabilities: Capability[];
  history: HistoryRecord[];
  loading: boolean;
  error: string | null;
  refreshAll: () => Promise<void>;
  runAction: <T = unknown>(action: string, payload?: Record<string, unknown>) => Promise<BridgeResult<T>>;
  startJob: <T = unknown>(action: string, payload?: Record<string, unknown>) => Promise<BridgeJob<T>>;
  getJob: <T = unknown>(id: string) => Promise<BridgeJob<T>>;
};

const DNSPilotContext = createContext<DNSPilotContextValue | null>(null);

const defaultBridgeUrl =
  process.env.EXPO_PUBLIC_DNSPILOT_BRIDGE_URL ??
  (Constants.expoConfig?.extra?.dnspilotBridgeUrl as string | undefined) ??
  'http://localhost:8787';

function readDeviceLocales() {
  return Localization.getLocales().map((locale) => ({
    languageCode: locale.languageCode,
    languageTag: locale.languageTag,
  }));
}

export function DNSPilotProvider({ children }: { children: React.ReactNode }) {
  const [bridgeUrl, setBridgeUrl] = useState(defaultBridgeUrl);
  const [languagePreference, setLanguagePreference] = useState<LanguagePreference>('system');
  const [deviceLocales, setDeviceLocales] = useState(readDeviceLocales);
  const [health, setHealth] = useState<DNSPilotContextValue['health']>(null);
  const [profiles, setProfiles] = useState<DNSProfile[]>([]);
  const [suites, setSuites] = useState<TestSuite[]>([]);
  const [capabilities, setCapabilities] = useState<Capability[]>([]);
  const [history, setHistory] = useState<HistoryRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const locale = useMemo(() => resolveLocale({ preference: languagePreference, deviceLocales }), [deviceLocales, languagePreference]);
  const t = useMemo(() => createTranslator(locale), [locale]);

  React.useEffect(() => {
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        setDeviceLocales(readDeviceLocales());
      }
    });
    return () => subscription.remove();
  }, []);

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

  const startJob = useCallback<DNSPilotContextValue['startJob']>(
    async (action, payload = {}) => {
      setError(null);
      try {
        return await startBridgeJob(bridgeUrl, action, payload);
      } catch (caught) {
        const message = caught instanceof Error ? caught.message : String(caught);
        setError(message);
        throw caught;
      }
    },
    [bridgeUrl]
  );

  const getJob = useCallback<DNSPilotContextValue['getJob']>(
    async (id) => {
      try {
        return await getBridgeJob(bridgeUrl, id);
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
      locale,
      languagePreference,
      setLanguagePreference,
      languageOptions,
      t,
      health,
      profiles,
      suites,
      capabilities,
      history,
      loading,
      error,
      refreshAll,
      runAction,
      startJob,
      getJob,
    }),
    [
      bridgeUrl,
      locale,
      languagePreference,
      t,
      health,
      profiles,
      suites,
      capabilities,
      history,
      loading,
      error,
      refreshAll,
      runAction,
      startJob,
      getJob,
    ]
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
