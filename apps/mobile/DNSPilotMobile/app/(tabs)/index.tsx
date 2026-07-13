import * as Clipboard from 'expo-clipboard';
import Constants from 'expo-constants';
import React, { useEffect, useMemo, useState } from 'react';
import { Platform, Text, View } from 'react-native';

import { BridgeJob, BridgeResult, DNSProfile } from '@/src/api/dnspilot';
import { DNSSettings, type DNSSettingsStatus } from '@/modules/dns-settings/src/DNSSettingsModule';
import {
  Button,
  CodeBlock,
  EmptyState,
  ErrorBanner,
  Metric,
  Pill,
  Row,
  Screen,
  Section,
  Segmented,
  TextField,
  ToggleRow,
  palette,
} from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { openNativeSettings } from '@/src/utils/native-settings';
import { buildBenchmarkDiagnostics, type BenchmarkDiagnostics, type BenchmarkStepStatus, type ResolverDiagnostic } from '@/src/view-models/benchmark-diagnostics';
import { buildApplyPlanRequest } from '@/src/view-models/benchmark-guidance';
import { buildBenchmarkPlan, type BenchmarkMode } from '@/src/view-models/benchmark-plan';
import { buildConsumerResult } from '@/src/view-models/consumer-result';
import { buildQuickCheck, quickCheckPresets } from '@/src/view-models/consumer-check';
import { buildIosDnsSettingsRequest } from '@/src/view-models/native-dns-settings';
import { buildSettingsGuidance, guidanceActionStatus, type SettingsGuidance } from '@/src/view-models/settings-guidance';

type Mode = Extract<BenchmarkMode, 'compare' | 'pathCompare' | 'systemBenchmark'>;
type IpFamily = 'both' | 'ipv4-only' | 'ipv6-only';
type MobilePlatform = 'ios' | 'android-play';

const platform: MobilePlatform = Platform.OS === 'android' ? 'android-play' : 'ios';
const iosDnsSettingsEnabled = Constants.expoConfig?.extra?.iosDnsSettingsEnabled === true;

export default function CheckDnsScreen() {
  const { profiles, suites, error, refreshAll, runAction, startJob, getJob, locale, t } = useDNSPilot();
  const [presetID, setPresetID] = useState('general');
  const [advanced, setAdvanced] = useState(false);
  const [mode, setMode] = useState<Mode>('compare');
  const [ipFamily, setIpFamily] = useState<IpFamily>('both');
  const [selectedProfiles, setSelectedProfiles] = useState<string[]>([]);
  const [domains, setDomains] = useState('');
  const [attempts, setAttempts] = useState('2');
  const [timeoutMs, setTimeoutMs] = useState('800');
  const [connectTimeoutMs, setConnectTimeoutMs] = useState('1000');
  const [maxTargets, setMaxTargets] = useState('4');
  const [tlsEnabled, setTlsEnabled] = useState(false);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<BridgeResult | null>(null);
  const [diagnostics, setDiagnostics] = useState<BenchmarkDiagnostics | null>(null);
  const [copyStatus, setCopyStatus] = useState<string | null>(null);
  const [guidance, setGuidance] = useState<SettingsGuidance | null>(null);
  const [settingsStatus, setSettingsStatus] = useState<string | null>(null);
  const [settingsWorking, setSettingsWorking] = useState(false);
  const [iosDnsStatus, setIosDnsStatus] = useState<DNSSettingsStatus | null>(null);

  const plainProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'plain'), [profiles]);
  const presets = useMemo(() => quickCheckPresets(suites), [suites]);
  const quickDefaults = useMemo(
    () => buildQuickCheck({ profiles, suites, platform, presetID }),
    [presetID, profiles, suites]
  );
  const benchmarkPlan = useMemo(
    () =>
      buildBenchmarkPlan({
        mode: advanced ? mode : quickDefaults.mode,
        selectedProfiles: advanced ? selectedProfiles : quickDefaults.selectedProfiles,
        suites,
        suiteId: advanced ? quickDefaults.suiteId : quickDefaults.suiteId,
        domains,
        attempts,
        ipFamily,
        timeoutMs,
        connectTimeoutMs,
        maxTargets,
        tlsEnabled: advanced && tlsEnabled,
        benchmarkPlatform: platform,
        saveHistory: true,
      }),
    [advanced, attempts, connectTimeoutMs, domains, ipFamily, maxTargets, mode, quickDefaults, selectedProfiles, suites, timeoutMs, tlsEnabled]
  );
  const presentation = useMemo(
    () => buildConsumerResult({ result, profiles, platform, iosDnsSettingsAvailable: iosDnsSettingsEnabled && Boolean(iosDnsStatus?.available) }),
    [iosDnsStatus?.available, profiles, result]
  );
  const selectedRecommendation = profiles.find((profile) => profile.id === presentation.recommendation.profileId);
  const iosDnsPlan = useMemo(() => buildIosDnsSettingsRequest(selectedRecommendation), [selectedRecommendation]);
  const modeOptions = useMemo(
    () => [
      { label: t('benchmark.mode.compare'), value: 'compare' as const },
      { label: t('benchmark.mode.pathCompare'), value: 'pathCompare' as const },
      { label: t('benchmark.mode.systemBenchmark'), value: 'systemBenchmark' as const },
    ],
    [t]
  );
  const familyOptions = useMemo(
    () => [
      { label: t('benchmark.family.both'), value: 'both' as const },
      { label: t('benchmark.family.ipv4Only'), value: 'ipv4-only' as const },
      { label: t('benchmark.family.ipv6Only'), value: 'ipv6-only' as const },
    ],
    [t]
  );

  useEffect(() => {
    refreshAll().catch(() => undefined);
  }, [refreshAll]);

  useEffect(() => {
    if (!presets.some((preset) => preset.id === presetID)) {
      setPresetID(presets[0]?.id ?? 'general');
    }
  }, [presetID, presets]);

  useEffect(() => {
    if (!advanced || selectedProfiles.length === 0) {
      setSelectedProfiles(quickDefaults.selectedProfiles);
    }
  }, [advanced, quickDefaults.selectedProfiles, selectedProfiles.length]);

  useEffect(() => {
    if (Platform.OS !== 'ios' || !iosDnsSettingsEnabled) return;
    DNSSettings.getStatus().then(setIosDnsStatus).catch(() => undefined);
  }, []);

  function toggleProfile(profile: DNSProfile) {
    setSelectedProfiles((current) =>
      current.includes(profile.id) ? current.filter((id) => id !== profile.id) : [...current, profile.id]
    );
  }

  async function runBenchmark() {
    if (!benchmarkPlan.canRun || running) return;
    const startedAtMs = Date.now();
    const runMode = advanced ? mode : quickDefaults.mode;
    setRunning(true);
    setResult(null);
    setGuidance(null);
    setSettingsStatus(null);
    setCopyStatus(null);
    setDiagnostics(buildBenchmarkDiagnostics({ mode: runMode, startedAtMs }));
    try {
      let job = await startJob(runMode, benchmarkPlan.payload);
      setDiagnostics(diagnosticsForJob(runMode, job, startedAtMs, t('benchmark.error.failed')));
      while (job.status === 'running') {
        await sleep(500);
        job = await getJob(job.id);
        setDiagnostics(diagnosticsForJob(runMode, job, startedAtMs, t('benchmark.error.failed')));
      }
      if (job.status === 'failed') throw new Error(job.error?.message ?? t('benchmark.error.failed'));
      if (!job.result) throw new Error(t('benchmark.error.noResult'));
      setResult(job.result);
      setDiagnostics(buildBenchmarkDiagnostics({ mode: runMode, result: job.result, startedAtMs, endedAtMs: Date.now() }));
      await refreshAll();
    } catch (caught) {
      setDiagnostics(buildBenchmarkDiagnostics({ mode: runMode, error: caught, startedAtMs, endedAtMs: Date.now() }));
    } finally {
      setRunning(false);
    }
  }

  async function copyReport() {
    if (!diagnostics) return;
    await Clipboard.setStringAsync(diagnostics.report);
    setCopyStatus(t('check.reportCopied'));
  }

  async function startSetup() {
    if (!result || !presentation.primaryAction || settingsWorking) return;
    setSettingsWorking(true);
    setSettingsStatus(null);
    try {
      if (presentation.primaryAction.kind === 'install-ios-dns-settings') {
        if (!iosDnsPlan.request) throw new Error(iosDnsPlan.reason ?? 'DNS Settings is unavailable.');
        setIosDnsStatus(await DNSSettings.install(iosDnsPlan.request));
        setSettingsStatus(t('policy.nativeDns.enableHelp'));
        return;
      }
      const request = buildApplyPlanRequest({ platform, result, profiles, environment: {} });
      if (!request) return;
      const applyPlan = await runAction('applyPlan', {
        platform: request.platform,
        profileId: request.profileId,
        testedResolver: request.testedResolver,
        confidence: request.confidence,
        gateHealth: request.gateHealth,
        environment: request.environment,
      });
      setGuidance(buildSettingsGuidance({ platform, applyPlan: applyPlan.data, locale }));
    } catch (caught) {
      setSettingsStatus(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setSettingsWorking(false);
    }
  }

  async function runGuidanceAction(action: SettingsGuidance['actions'][number]) {
    if (settingsWorking) return;
    setSettingsWorking(true);
    setSettingsStatus(guidanceActionStatus({ actionKind: action.kind, phase: 'running', locale }));
    try {
      if (action.kind === 'prepare-os-apply') {
        await Clipboard.setStringAsync(action.value);
        await openNativeSettings(action.target);
      } else if (action.kind === 'copy') {
        await Clipboard.setStringAsync(action.value);
      } else if (action.kind === 'open-settings') {
        await openNativeSettings(action.target);
      } else {
        await runAction('systemBenchmark', {
          platform,
          domains: benchmarkPlan.payload.domains.length > 0 ? benchmarkPlan.payload.domains : ['cloudflare.com', 'google.com'],
          attempts: 1,
          ipFamily: benchmarkPlan.payload.ipFamily,
          timeoutMs: 800,
        });
        setSettingsStatus(t('check.systemResult'));
      }
      setSettingsStatus((current) => current ?? guidanceActionStatus({ actionKind: action.kind, phase: 'success', locale }));
    } catch {
      setSettingsStatus(guidanceActionStatus({ actionKind: action.kind, phase: 'failed', locale }));
    } finally {
      setSettingsWorking(false);
    }
  }

  return (
    <Screen>
      <Section title={t('check.title')} subtitle={t('check.subtitle')}>
        <Section title={t('check.targets')}>
          {presets.length === 0 ? <EmptyState text={t('check.noTargets')} /> : null}
          <Row>
            {presets.map((preset) => (
              <Pill key={preset.id} label={preset.name} selected={presetID === preset.id} onPress={() => setPresetID(preset.id)} tone={preset.tags.includes('gaming') ? 'amber' : 'blue'} />
            ))}
          </Row>
        </Section>
        <Row>
          <Button label={t('check.runQuick')} onPress={runBenchmark} loading={running} disabled={!benchmarkPlan.canRun} />
          <Button label={advanced ? t('check.hideAdvanced') : t('check.advanced')} onPress={() => setAdvanced((current) => !current)} variant="secondary" />
        </Row>
        <ErrorBanner message={benchmarkPlan.errors[0]} />
        <ErrorBanner message={error} />
      </Section>

      {advanced ? (
        <Section title={t('check.advanced')} subtitle={t('benchmark.help.family')}>
          <Segmented options={modeOptions} value={mode} onChange={setMode} />
          <Segmented options={familyOptions} value={ipFamily} onChange={setIpFamily} />
          {mode !== 'systemBenchmark' ? (
            <>
              <Text selectable style={{ color: palette.text, fontSize: 15, fontWeight: '800' }}>{t('check.selectResolvers')}</Text>
              {plainProfiles.length === 0 ? <EmptyState text={t('check.noResolvers')} /> : null}
              <Row>
                {plainProfiles.map((profile) => (
                  <Pill key={profile.id} label={profile.name} selected={selectedProfiles.includes(profile.id)} onPress={() => toggleProfile(profile)} tone={profile.tags?.includes('custom') ? 'amber' : 'neutral'} />
                ))}
              </Row>
            </>
          ) : null}
          <TextField label={t('benchmark.domains')} value={domains} onChangeText={setDomains} multiline placeholder="example.com" />
          <Row>
            <TextField label={t('benchmark.attempts')} value={attempts} onChangeText={setAttempts} keyboardType="numeric" />
            <TextField label={t('benchmark.dnsTimeout')} value={timeoutMs} onChangeText={setTimeoutMs} keyboardType="numeric" />
          </Row>
          {mode === 'pathCompare' ? (
            <>
              <Row>
                <TextField label={t('benchmark.tcpTimeout')} value={connectTimeoutMs} onChangeText={setConnectTimeoutMs} keyboardType="numeric" />
                <TextField label={t('benchmark.maxTargets')} value={maxTargets} onChangeText={setMaxTargets} keyboardType="numeric" />
              </Row>
              <ToggleRow label={t('benchmark.tlsTiming')} value={tlsEnabled} onValueChange={setTlsEnabled} subtitle={t('benchmark.tlsTimingHelp')} />
            </>
          ) : null}
        </Section>
      ) : null}

      <ProcessSection diagnostics={diagnostics} copyStatus={copyStatus} onCopyReport={copyReport} t={t} />

      <Section title={t('benchmark.result.title')} subtitle={result ? t('benchmark.result.subtitleReady', { args: result.action }) : t('check.result.noResult')}>
        {!result ? <EmptyState text={t('check.result.noResult')} /> : null}
        {result ? (
          <View style={cardStyle}>
            <Row>
              <Metric label={t('benchmark.metric.health')} value={presentation.health} tone={presentation.health === 'healthy' ? 'green' : presentation.health === 'failed' ? 'red' : 'amber'} />
              <Metric label={t('benchmark.metric.confidence')} value={presentation.confidence} tone={presentation.confidence === 'high' ? 'green' : 'amber'} />
              <Metric label={t('benchmark.metric.elapsed')} value={formatMs(diagnostics?.elapsedMs)} tone="blue" />
            </Row>
            <ResultLine label={t('check.result.fastest')} value={presentation.fastestObserved ? `${presentation.fastestObserved.profileName} · ${presentation.fastestObserved.medianDnsLatencyMs} ms` : t('common.none')} />
            <ResultLine
              label={t('check.result.balanced')}
              value={
                presentation.recommendation.kind === 'keep-current'
                  ? t('check.result.keepCurrent')
                  : presentation.recommendation.kind === 'recommended'
                    ? presentation.recommendation.profileName ?? t('check.result.none')
                    : presentation.recommendation.kind === 'best-measured'
                      ? `${t('check.result.bestMeasured')}: ${presentation.recommendation.profileName ?? t('common.none')}`
                      : t('check.result.none')
              }
            />
            {presentation.notes.map((note) => (
              <Text key={note} selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>{note}</Text>
            ))}
            {presentation.primaryAction ? (
              <Button label={presentation.primaryAction.kind === 'install-ios-dns-settings' ? t('check.installIos') : t('check.setup')} onPress={startSetup} loading={settingsWorking} />
            ) : null}
            {settingsStatus ? <ErrorBanner message={settingsStatus} /> : null}
          </View>
        ) : null}
      </Section>

      {guidance ? (
        <Section title={guidance.title} subtitle={guidance.claims.join(' ')}>
          <View style={cardStyle}>
            {guidance.steps.map((step, index) => <Text key={`${index}-${step}`} selectable style={{ color: palette.text, fontSize: 14, lineHeight: 20 }}>{index + 1}. {step}</Text>)}
            <Row>
              {guidance.actions.map((action) => (
                <Button key={action.id} label={action.label} onPress={() => runGuidanceAction(action)} variant="secondary" loading={settingsWorking && action.kind === 'retest-system-dns'} disabled={settingsWorking} />
              ))}
            </Row>
          </View>
        </Section>
      ) : null}
    </Screen>
  );
}

function ProcessSection({ diagnostics, copyStatus, onCopyReport, t }: { diagnostics: BenchmarkDiagnostics | null; copyStatus: string | null; onCopyReport: () => void; t: (key: string, params?: Record<string, string | number>) => string }) {
  const [detailsVisible, setDetailsVisible] = useState(false);
  return (
    <Section title={t('benchmark.process.title')} subtitle={diagnostics ? t('benchmark.process.subtitleReady', { status: t(`status.${diagnostics.status}`), reason: diagnostics.reason }) : t('benchmark.process.subtitleEmpty')}>
      {!diagnostics ? <EmptyState text={t('benchmark.noDiagnostics')} /> : null}
      {diagnostics ? (
        <View style={cardStyle}>
          <Row>
            <Metric label={t('benchmark.metric.status')} value={t(`status.${diagnostics.status}`)} tone={statusTone(diagnostics.status)} />
            <Metric label={t('benchmark.metric.failedStep')} value={diagnostics.failedStepId ? t(`benchmark.step.${diagnostics.failedStepId}`) : t('benchmark.failedStepNone')} tone={diagnostics.failedStepId ? 'red' : 'green'} />
            <Metric label={t('benchmark.metric.elapsed')} value={formatMs(diagnostics.elapsedMs)} tone="blue" />
          </Row>
          {diagnostics.steps.map((step) => <StepRow key={step.id} id={step.id} status={step.status} t={t} />)}
          {diagnostics.resolvers.map((resolver) => <ResolverRow key={`${resolver.profileId}-${resolver.resolver ?? ''}`} resolver={resolver} t={t} />)}
          <Row>
            <Button label={detailsVisible ? t('check.result.hideDetails') : t('check.result.details')} onPress={() => setDetailsVisible((current) => !current)} variant="secondary" />
            <Button label={t('check.copyReport')} onPress={onCopyReport} variant="secondary" />
            {copyStatus ? <Pill label={copyStatus} tone="green" /> : null}
          </Row>
          {detailsVisible ? <><CodeBlock text={diagnostics.report} /><CodeBlock text={diagnostics.debugLog} /></> : null}
        </View>
      ) : null}
    </Section>
  );
}

function ResultLine({ label, value }: { label: string; value: string }) {
  return (
    <View style={{ gap: 2 }}>
      <Text selectable style={{ color: palette.muted, fontSize: 12 }}>{label}</Text>
      <Text selectable style={{ color: palette.text, fontSize: 16, fontWeight: '800' }}>{value}</Text>
    </View>
  );
}

function StepRow({ id, status, t }: { id: string; status: BenchmarkStepStatus; t: (key: string) => string }) {
  return (
    <View style={rowStyle}>
      <Text selectable style={{ color: palette.text, flex: 1, fontSize: 14, fontWeight: '700' }}>{t(`benchmark.step.${id}`)}</Text>
      <Pill label={t(`status.${status}`)} tone={statusTone(status)} />
    </View>
  );
}

function ResolverRow({ resolver, t }: { resolver: ResolverDiagnostic; t: (key: string) => string }) {
  return (
    <View style={rowStyle}>
      <View style={{ flex: 1, gap: 2 }}>
        <Text selectable style={{ color: palette.text, fontSize: 14, fontWeight: '700' }}>{resolver.profileId}</Text>
        <Text selectable style={{ color: palette.muted, fontSize: 12 }}>{resolver.resolver ?? t('common.unknown')} · {resolver.diagnosis}</Text>
      </View>
      <Pill label={resolver.status} tone={statusTone(resolver.status)} />
    </View>
  );
}

function diagnosticsForJob(mode: Mode, job: BridgeJob, startedAtMs: number, failureMessage: string) {
  if (job.status === 'failed') return buildBenchmarkDiagnostics({ mode, error: new Error(job.error?.message ?? failureMessage), startedAtMs, endedAtMs: Date.now() });
  return buildBenchmarkDiagnostics({ mode, result: job.result ?? { ok: true, action: job.action, args: [], data: {}, progress: job.progress }, startedAtMs, endedAtMs: Date.now() });
}

function statusTone(status: string): 'neutral' | 'blue' | 'green' | 'amber' | 'red' {
  if (status === 'success') return 'green';
  if (status === 'failed') return 'red';
  if (status === 'degraded' || status === 'running') return 'amber';
  return 'neutral';
}

function formatMs(value?: number) {
  return value === undefined ? '-' : `${Math.round(value)} ms`;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const cardStyle = { backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 10, padding: 12 } as const;
const rowStyle = { alignItems: 'center', backgroundColor: palette.background, borderColor: palette.border, borderRadius: 8, borderWidth: 1, flexDirection: 'row', gap: 10, padding: 10 } as const;
