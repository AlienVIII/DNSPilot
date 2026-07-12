import AsyncStorage from '@react-native-async-storage/async-storage';
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
import { DNSPilotRuntime } from '@/modules/dnspilot-runtime/src/DNSPilotRuntimeModule';
import {
  deserializeAppPreferences,
  serializeAppPreferences,
  type AppPreferences,
} from '@/src/view-models/app-preferences';
import { actionTransport } from '@/src/view-models/action-transport';
import { createNativeJobStore } from '@/src/view-models/native-job-store';
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
const appPreferencesStorageKey = 'dnspilot-mobile.preferences.v1';
const defaultAppPreferences: AppPreferences = {
  bridgeUrl: defaultBridgeUrl,
  languagePreference: 'system',
};

function readDeviceLocales() {
  return Localization.getLocales().map((locale) => ({
    languageCode: locale.languageCode,
    languageTag: locale.languageTag,
  }));
}

export function DNSPilotProvider({ children }: { children: React.ReactNode }) {
  const [bridgeUrl, setBridgeUrl] = useState(defaultBridgeUrl);
  const [languagePreference, setLanguagePreference] = useState<LanguagePreference>('system');
  const [preferencesLoaded, setPreferencesLoaded] = useState(false);
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
    let active = true;
    AsyncStorage.getItem(appPreferencesStorageKey)
      .then((raw) => {
        if (!active) return;
        const preferences = deserializeAppPreferences(raw, defaultAppPreferences);
        setBridgeUrl(preferences.bridgeUrl);
        setLanguagePreference(preferences.languagePreference);
      })
      .catch(() => undefined)
      .finally(() => {
        if (active) {
          setPreferencesLoaded(true);
        }
      });
    return () => {
      active = false;
    };
  }, []);

  React.useEffect(() => {
    if (!preferencesLoaded) {
      return;
    }
    AsyncStorage.setItem(
      appPreferencesStorageKey,
      serializeAppPreferences({
        bridgeUrl,
        languagePreference,
      }, defaultAppPreferences)
    ).catch(() => undefined);
  }, [bridgeUrl, languagePreference, preferencesLoaded]);

  React.useEffect(() => {
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        setDeviceLocales(readDeviceLocales());
      }
    });
    return () => subscription.remove();
  }, []);

  const runAction = useCallback(
    async <T,>(action: string, payload: Record<string, unknown> = {}): Promise<BridgeResult<T>> => {
      setError(null);
      try {
        if (actionTransport({ action, nativeAvailable: DNSPilotRuntime.isAvailable() }) === 'native') {
          const result = await DNSPilotRuntime.runAction<BridgeResult<T>>(action, payload);
          if (!result.ok) {
            throw new Error((result as { error?: string }).error ?? `Native runtime failed: ${action}`);
          }
          return result;
        }
        return await callBridge<T>(bridgeUrl, action, payload);
      } catch (caught) {
        const message = caught instanceof Error ? caught.message : String(caught);
        setError(message);
        throw caught;
      }
    },
    [bridgeUrl]
  );

  const nativeRunActionRef = React.useRef(runAction);
  nativeRunActionRef.current = runAction;
  const nativeJobStoreRef = React.useRef<ReturnType<typeof createNativeJobStore> | null>(null);
  if (!nativeJobStoreRef.current) {
    nativeJobStoreRef.current = createNativeJobStore({
      run: (action, payload) => nativeRunActionRef.current(action, payload),
    });
  }

  const startJob = useCallback<DNSPilotContextValue['startJob']>(
    async (action, payload = {}) => {
      setError(null);
      try {
        if (actionTransport({ action, nativeAvailable: DNSPilotRuntime.isAvailable() }) === 'native') {
          return nativeJobStoreRef.current!.start(action, payload);
        }
        return await startBridgeJob(bridgeUrl, action, payload);
      } catch (caught) {
        const message = caught instanceof Error ? caught.message : String(caught);
        setError(message);
        throw caught;
      }
    },
    [bridgeUrl]
  );

  const getJob = useCallback(
    async <T,>(id: string): Promise<BridgeJob<T>> => {
      try {
        const nativeJob = nativeJobStoreRef.current?.get<T>(id);
        if (nativeJob) {
          return nativeJob;
        }
        return await getBridgeJob<T>(bridgeUrl, id);
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
      const nativeAvailable = DNSPilotRuntime.isAvailable();
      const nextHealth = nativeAvailable
        ? { ok: true, dbPath: 'Native application storage' }
        : await bridgeHealth(bridgeUrl);
      const [catalogResult, capabilitiesResult, profilesResult, suitesResult, historyResult] =
        await Promise.all([
          runAction('catalog'),
          runAction('capabilities'),
          runAction('profileList'),
          runAction('suiteList'),
          runAction('historyList'),
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
  }, [bridgeUrl, runAction]);

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
