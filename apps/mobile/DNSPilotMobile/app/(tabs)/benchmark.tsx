import * as Clipboard from 'expo-clipboard';
import React, { useEffect, useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { BridgeJob, BridgeResult, compactJson, DNSProfile, profileServers } from '@/src/api/dnspilot';
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
import { compactList } from '@/src/utils/forms';
import { openNativeSettings } from '@/src/utils/native-settings';
import { buildApplyPlanRequest, type ApplyPlanRequest } from '@/src/view-models/benchmark-guidance';
import { buildBenchmarkPlan, suggestedSuites } from '@/src/view-models/benchmark-plan';
import {
  buildBenchmarkDiagnostics,
  type BenchmarkDiagnostics,
  type BenchmarkStepStatus,
  type ResolverDiagnostic,
} from '@/src/view-models/benchmark-diagnostics';
import { translateKnownError, type Translator } from '@/src/view-models/localization';
import { buildSettingsGuidance, guidanceActionStatus, type SettingsGuidance } from '@/src/view-models/settings-guidance';

type Mode = 'compare' | 'pathCompare' | 'benchmark' | 'pathEstimate' | 'systemBenchmark';
type IpFamily = 'both' | 'ipv4-only' | 'ipv6-only';
type MobilePlatform = 'ios' | 'android-play';

export default function BenchmarkScreen() {
  const { profiles, suites, error, refreshAll, runAction, startJob, getJob, locale, t } = useDNSPilot();
  const [mode, setMode] = useState<Mode>('pathCompare');
  const [benchmarkPlatform, setBenchmarkPlatform] = useState<MobilePlatform>('ios');
  const [guidancePlatform, setGuidancePlatform] = useState<MobilePlatform>('ios');
  const [selectedProfiles, setSelectedProfiles] = useState<string[]>([]);
  const [suiteId, setSuiteId] = useState<string>('');
  const [domains, setDomains] = useState('github.com\nexpo.dev\nmicrosoft.com');
  const [attempts, setAttempts] = useState('1');
  const [ipFamily, setIpFamily] = useState<IpFamily>('both');
  const [timeoutMs, setTimeoutMs] = useState('800');
  const [connectTimeoutMs, setConnectTimeoutMs] = useState('1000');
  const [maxTargets, setMaxTargets] = useState('4');
  const [tlsEnabled, setTlsEnabled] = useState(false);
  const [saveHistory, setSaveHistory] = useState(true);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<BridgeResult | null>(null);
  const [diagnostics, setDiagnostics] = useState<BenchmarkDiagnostics | null>(null);
  const [guidance, setGuidance] = useState<SettingsGuidance | null>(null);
  const [guidancePayload, setGuidancePayload] = useState<BridgeResult | null>(null);
  const [guidanceWorking, setGuidanceWorking] = useState(false);
  const [copyStatus, setCopyStatus] = useState<string | null>(null);
  const [settingsActionStatus, setSettingsActionStatus] = useState<string | null>(null);
  const [settingsActionWorking, setSettingsActionWorking] = useState(false);
  const [vpnActive, setVpnActive] = useState(false);
  const [mdmProfileActive, setMdmProfileActive] = useState(false);
  const [corporateDnsDetected, setCorporateDnsDetected] = useState(false);
  const [captivePortalDetected, setCaptivePortalDetected] = useState(false);

  const plainProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'plain'), [profiles]);
  const modeOptions = useMemo(
    () => [
      { label: t('benchmark.mode.compare'), value: 'compare' as const },
      { label: t('benchmark.mode.pathCompare'), value: 'pathCompare' as const },
      { label: t('benchmark.mode.benchmark'), value: 'benchmark' as const },
      { label: t('benchmark.mode.pathEstimate'), value: 'pathEstimate' as const },
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
  const platformOptions = useMemo(
    () => [
      { label: t('platform.ios'), value: 'ios' as const },
      { label: t('platform.android'), value: 'android-play' as const },
    ],
    [t]
  );
  const protectedEnvironment = useMemo(
    () => ({
      vpnActive,
      mdmProfileActive,
      corporateDnsDetected,
      captivePortalDetected,
    }),
    [captivePortalDetected, corporateDnsDetected, mdmProfileActive, vpnActive]
  );
  const applyPlanRequest = useMemo(
    () =>
      buildApplyPlanRequest({
        platform: guidancePlatform,
        result,
        profiles,
        environment: protectedEnvironment,
      }),
    [guidancePlatform, profiles, protectedEnvironment, result]
  );
  const benchmarkPlan = useMemo(
    () =>
      buildBenchmarkPlan({
        mode,
        selectedProfiles,
        suites,
        suiteId,
        domains,
        attempts,
        ipFamily,
        timeoutMs,
        connectTimeoutMs,
        maxTargets,
        tlsEnabled,
        benchmarkPlatform,
        saveHistory,
      }),
    [attempts, benchmarkPlatform, connectTimeoutMs, domains, ipFamily, maxTargets, mode, saveHistory, selectedProfiles, suiteId, suites, timeoutMs, tlsEnabled]
  );
  const systemRetestPlan = useMemo(
    () =>
      buildBenchmarkPlan({
        mode: 'systemBenchmark',
        selectedProfiles: [],
        suites,
        suiteId,
        domains,
        attempts,
        ipFamily,
        timeoutMs,
        connectTimeoutMs,
        maxTargets,
        tlsEnabled: false,
        benchmarkPlatform: guidancePlatform,
        saveHistory: false,
      }),
    [attempts, connectTimeoutMs, domains, guidancePlatform, ipFamily, maxTargets, suiteId, suites, timeoutMs]
  );
  const suiteSuggestions = useMemo(() => suggestedSuites(suites), [suites]);

  useEffect(() => {
    if (plainProfiles.length > 0 && selectedProfiles.length === 0) {
      const preferred = ['cloudflare', 'google-public-dns', 'quad9'].filter((id) => plainProfiles.some((profile) => profile.id === id));
      setSelectedProfiles(preferred.length > 0 ? preferred : plainProfiles.slice(0, 3).map((profile) => profile.id));
    }
  }, [plainProfiles, selectedProfiles.length]);

  useEffect(() => {
    setGuidance(null);
    setGuidancePayload(null);
    setSettingsActionStatus(null);
  }, [captivePortalDetected, corporateDnsDetected, guidancePlatform, mdmProfileActive, result, vpnActive]);

  function toggleProfile(profile: DNSProfile) {
    setSelectedProfiles((current) =>
      current.includes(profile.id) ? current.filter((id) => id !== profile.id) : [...current, profile.id]
    );
  }

  async function runBenchmark() {
    const startedAtMs = Date.now();
    const runMode = mode;
    setRunning(true);
    setResult(null);
    setGuidance(null);
    setGuidancePayload(null);
    setCopyStatus(null);
    setDiagnostics(buildBenchmarkDiagnostics({ mode: runMode, startedAtMs }));
    try {
      let job = await startJob(runMode, benchmarkPlan.payload);
      setDiagnostics(diagnosticsForJob(runMode, job, startedAtMs));
      while (job.status === 'running') {
        await sleep(500);
        job = await getJob(job.id);
        setDiagnostics(diagnosticsForJob(runMode, job, startedAtMs));
      }
      if (job.status === 'failed') {
        throw new Error(job.error?.message ?? 'Bridge benchmark job failed.');
      }
      const next = job.result;
      if (!next) {
        throw new Error('Bridge benchmark job finished without a result payload.');
      }
      setResult(next);
      setDiagnostics(buildBenchmarkDiagnostics({ mode: runMode, result: next, startedAtMs, endedAtMs: Date.now() }));
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
    setCopyStatus(t('benchmark.reportCopied'));
  }

  async function loadGuidedPlan() {
    if (!applyPlanRequest) return;
    setGuidanceWorking(true);
    try {
      const payload = applyPlanPayload(applyPlanRequest);
      const next = await runAction('applyPlan', payload);
      setGuidancePayload(next);
      setGuidance(buildSettingsGuidance({ platform: guidancePlatform, applyPlan: next.data, locale }));
    } finally {
      setGuidanceWorking(false);
    }
  }

  async function runGuidanceAction(action: SettingsGuidance['actions'][number]) {
    if (settingsActionWorking) {
      return;
    }
    setSettingsActionWorking(true);
    setSettingsActionStatus(guidanceActionStatus({ actionKind: action.kind, phase: 'running', locale }));
    try {
      if (action.kind === 'prepare-os-apply') {
        await Clipboard.setStringAsync(action.value);
        await openNativeSettings(action.target);
      } else if (action.kind === 'copy') {
        await Clipboard.setStringAsync(action.value);
      } else if (action.kind === 'open-settings') {
        await openNativeSettings(action.target);
      } else {
        const next = await runAction('systemBenchmark', systemRetestPlan.payload);
        setGuidancePayload(next);
      }
      setSettingsActionStatus(guidanceActionStatus({ actionKind: action.kind, phase: 'success', locale }));
    } catch {
      setSettingsActionStatus(guidanceActionStatus({ actionKind: action.kind, phase: 'failed', locale }));
    } finally {
      setSettingsActionWorking(false);
    }
  }

  const resultData = result?.data as Record<string, unknown> | undefined;
  const summary = resultData?.summary ?? resultData?.metrics ?? resultData;
  const recommendation = resultData?.recommendation;
  const benchmarkErrors = benchmarkPlan.errors.map((item) => translateKnownError(locale, item)).join('\n');

  return (
    <Screen>
      <Section title={t('benchmark.run.title')} subtitle={t('benchmark.run.subtitle')}>
        <Segmented options={modeOptions} value={mode} onChange={setMode} />
        {mode === 'systemBenchmark' ? <Segmented options={platformOptions} value={benchmarkPlatform} onChange={setBenchmarkPlatform} /> : null}
        <Segmented options={familyOptions} value={ipFamily} onChange={setIpFamily} />
        <View style={{ backgroundColor: palette.blueSoft, borderColor: '#bfdbfe', borderRadius: 8, borderWidth: 1, gap: 4, padding: 10 }}>
          <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
            {t('benchmark.help.family')}
          </Text>
        </View>
        <Row>
          <Metric label={t('benchmark.metric.selected')} value={mode === 'systemBenchmark' ? t('common.system') : selectedProfiles.length} tone="blue" />
          <Metric label={t('benchmark.metric.domains')} value={benchmarkPlan.domainCount} tone="green" />
          <Metric label={t('benchmark.metric.platform')} value={mode === 'systemBenchmark' ? benchmarkPlatform : t('common.direct')} tone="amber" />
          <Metric label={t('benchmark.metric.history')} value={benchmarkPlan.historyEnabled ? t('common.enabled') : t('common.disabled')} tone={benchmarkPlan.historyEnabled ? 'amber' : 'neutral'} />
        </Row>
        <TextField label={t('benchmark.domains')} value={domains} onChangeText={setDomains} multiline placeholder="github.com&#10;expo.dev" />
        <Row>
          <TextField label={t('benchmark.attempts')} value={attempts} onChangeText={setAttempts} keyboardType="numeric" />
          <TextField label={t('benchmark.dnsTimeout')} value={timeoutMs} onChangeText={setTimeoutMs} keyboardType="numeric" />
        </Row>
        {(mode === 'pathCompare' || mode === 'pathEstimate') ? (
          <>
            <Row>
              <TextField label={t('benchmark.tcpTimeout')} value={connectTimeoutMs} onChangeText={setConnectTimeoutMs} keyboardType="numeric" />
              <TextField label={t('benchmark.maxTargets')} value={maxTargets} onChangeText={setMaxTargets} keyboardType="numeric" />
            </Row>
            <ToggleRow label={t('benchmark.tlsTiming')} value={tlsEnabled} onValueChange={setTlsEnabled} subtitle={t('benchmark.tlsTimingHelp')} />
          </>
        ) : null}
        <ToggleRow label={t('benchmark.saveHistory')} value={saveHistory} onValueChange={setSaveHistory} subtitle={t('benchmark.saveHistoryHelp')} />
        <ErrorBanner message={benchmarkErrors} />
        <Button label={t('benchmark.runButton')} onPress={runBenchmark} loading={running} disabled={!benchmarkPlan.canRun} />
        <ErrorBanner message={error} />
      </Section>

      {mode !== 'systemBenchmark' ? (
        <Section title={t('benchmark.profiles.title')} subtitle={t('benchmark.profiles.subtitle')}>
          {plainProfiles.length === 0 ? <EmptyState text={t('benchmark.profiles.empty')} /> : null}
          <Row>
            {plainProfiles.map((profile) => (
              <Pill
                key={profile.id}
                label={`${profile.name} (${compactList(profileServers(profile).slice(0, 1))})`}
                selected={selectedProfiles.includes(profile.id)}
                onPress={() => toggleProfile(profile)}
                tone={profile.tags?.includes('custom') ? 'amber' : 'neutral'}
              />
            ))}
          </Row>
        </Section>
      ) : null}

      <Section
        title={t('benchmark.process.title')}
        subtitle={diagnostics ? t('benchmark.process.subtitleReady', { status: t(`status.${diagnostics.status}`), reason: diagnostics.reason }) : t('benchmark.process.subtitleEmpty')}>
        {diagnostics ? (
          <>
            <Row>
              <Metric label={t('benchmark.metric.status')} value={t(`status.${diagnostics.status}`)} tone={statusTone(diagnostics.status)} />
              <Metric
                label={t('benchmark.metric.failedStep')}
                value={diagnostics.failedStepId ? t(`benchmark.step.${diagnostics.failedStepId}`) : t('benchmark.failedStepNone')}
                tone={diagnostics.failedStepId ? 'red' : 'green'}
              />
              <Metric label={t('benchmark.metric.elapsed')} value={formatMs(diagnostics.elapsedMs)} tone="blue" />
            </Row>
            <View style={{ gap: 8 }}>
              {diagnostics.steps.map((step) => (
                <View key={step.id} style={{ alignItems: 'center', backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, flexDirection: 'row', gap: 10, justifyContent: 'space-between', padding: 12 }}>
                  <Text selectable style={{ color: palette.text, flex: 1, fontSize: 14, fontWeight: '800' }}>
                    {t(`benchmark.step.${step.id}`)}
                  </Text>
                  <StatusPill status={step.status} t={t} />
                </View>
              ))}
            </View>
            {diagnostics.resolvers.length > 0 ? (
              <View style={{ gap: 8 }}>
                {diagnostics.resolvers.map((resolver) => (
                  <ResolverRow key={`${resolver.profileId}-${resolver.resolver ?? ''}`} resolver={resolver} t={t} />
                ))}
              </View>
            ) : null}
            <Row>
              <Button label={t('benchmark.copyReport')} onPress={copyReport} variant="secondary" />
              {copyStatus ? <Pill label={copyStatus} tone="green" /> : null}
            </Row>
            <CodeBlock text={diagnostics.report} />
            {diagnostics.debugLog ? <CodeBlock text={diagnostics.debugLog} /> : null}
          </>
        ) : (
          <EmptyState text={t('benchmark.noDiagnostics')} />
        )}
      </Section>

      <Section title={t('benchmark.suites.title')} subtitle={t('benchmark.suites.subtitle')}>
        <Row>
          <Pill label={t('benchmark.noSuite')} selected={!suiteId} onPress={() => setSuiteId('')} />
          {suiteSuggestions.defaultSuiteId ? (
            <Pill label={t('common.default')} selected={suiteId === suiteSuggestions.defaultSuiteId} onPress={() => setSuiteId(suiteSuggestions.defaultSuiteId ?? '')} tone="blue" />
          ) : null}
          {suiteSuggestions.vietnamSuiteId ? (
            <Pill label={t('common.vietnam')} selected={suiteId === suiteSuggestions.vietnamSuiteId} onPress={() => setSuiteId(suiteSuggestions.vietnamSuiteId ?? '')} tone="amber" />
          ) : null}
          {suites.map((suite) => (
            <Pill key={suite.id} label={suite.name} selected={suiteId === suite.id} onPress={() => setSuiteId(suite.id)} tone="green" />
          ))}
        </Row>
        {benchmarkPlan.selectedSuite ? (
          <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>
            {t('benchmark.suiteAdds', {
              count: benchmarkPlan.selectedSuite.domains.length,
              domains: compactList(benchmarkPlan.selectedSuite.domains),
            })}
          </Text>
        ) : null}
      </Section>

      <Section title={t('benchmark.result.title')} subtitle={result ? t('benchmark.result.subtitleReady', { args: result.args.join(' ') }) : t('benchmark.result.subtitleEmpty')}>
        {result ? (
          <>
            <Row>
              <Metric label={t('benchmark.metric.progressEvents')} value={result.progress?.length ?? 0} tone="blue" />
              <Metric label={t('benchmark.metric.action')} value={result.action} tone="green" />
            </Row>
            {recommendation ? (
              <View style={{ backgroundColor: palette.greenSoft, borderColor: '#bbf7d0', borderRadius: 8, borderWidth: 1, padding: 12 }}>
                <Text selectable style={{ color: palette.green, fontSize: 14, fontWeight: '800' }}>
                  {t('benchmark.recommendation')}
                </Text>
                <CodeBlock text={compactJson(recommendation, 1800)} />
              </View>
            ) : null}
            <CodeBlock text={compactJson(summary, 3200)} />
          </>
        ) : (
          <EmptyState text={t('benchmark.noResult')} />
        )}
      </Section>

      <Section title={t('benchmark.guided.title')} subtitle={t('benchmark.guided.subtitle')}>
        {result ? (
          <>
            <Segmented options={platformOptions} value={guidancePlatform} onChange={setGuidancePlatform} />
            <Row>
              <ToggleRow label={t('benchmark.toggle.vpn')} value={vpnActive} onValueChange={setVpnActive} />
              <ToggleRow label={t('benchmark.toggle.mdm')} value={mdmProfileActive} onValueChange={setMdmProfileActive} />
            </Row>
            <Row>
              <ToggleRow label={t('benchmark.toggle.corporateDns')} value={corporateDnsDetected} onValueChange={setCorporateDnsDetected} />
              <ToggleRow label={t('benchmark.toggle.captivePortal')} value={captivePortalDetected} onValueChange={setCaptivePortalDetected} />
            </Row>
            {applyPlanRequest ? (
              <>
                <Row>
                  <Metric label={t('benchmark.metric.recommended')} value={applyPlanRequest.profileName} tone="green" />
                  <Metric label={t('benchmark.metric.health')} value={applyPlanRequest.gateHealth} tone={applyPlanRequest.gateHealth === 'healthy' ? 'green' : 'amber'} />
                  <Metric label={t('benchmark.metric.confidence')} value={applyPlanRequest.confidence} tone="blue" />
                </Row>
                <Button label={t('benchmark.loadGuidedPlan')} onPress={loadGuidedPlan} loading={guidanceWorking} variant="secondary" />
              </>
            ) : (
              <EmptyState text={t('benchmark.noGuidedPlan')} />
            )}
            {guidance ? (
              <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 10, padding: 12 }}>
                <View style={{ alignItems: 'center', flexDirection: 'row', gap: 8, justifyContent: 'space-between' }}>
                  <Text selectable style={{ color: palette.text, flex: 1, fontSize: 16, fontWeight: '800' }}>
                    {guidance.title}
                  </Text>
                  <Pill label={guidance.mode} tone={guidance.mode === 'protect' ? 'red' : 'blue'} />
                </View>
                <Row>
                  <Metric label={t('policy.metric.mutatesDns')} value={guidance.canMutateSystemDns ? t('common.yes') : t('common.no')} tone={guidance.canMutateSystemDns ? 'red' : 'green'} />
                  <Metric label={t('policy.metric.steps')} value={guidance.steps.length} tone="amber" />
                </Row>
                <View style={{ gap: 8 }}>
                  {guidance.steps.map((step, index) => (
                    <View key={`${index}-${step}`} style={{ backgroundColor: palette.background, borderColor: palette.border, borderRadius: 8, borderWidth: 1, padding: 10 }}>
                      <Text selectable style={{ color: palette.text, fontSize: 13, lineHeight: 18 }}>
                        {index + 1}. {step}
                      </Text>
                    </View>
                  ))}
                </View>
                <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>
                  {guidance.claims.join(' ')}
                </Text>
                {guidance.actions.length > 0 ? (
                  <Row>
                    {guidance.actions.map((action) => (
                      <Button
                        key={action.id}
                        label={action.label}
                        onPress={() => runGuidanceAction(action)}
                        variant="secondary"
                        disabled={settingsActionWorking}
                        loading={settingsActionWorking && action.kind === 'retest-system-dns'}
                      />
                    ))}
                    {settingsActionStatus ? <Pill label={settingsActionStatus} tone={settingsActionStatus === t('settings.action.failed') ? 'red' : 'green'} /> : null}
                  </Row>
                ) : null}
                {guidancePayload ? <CodeBlock text={compactJson(guidancePayload.data, 2200)} /> : null}
              </View>
            ) : null}
          </>
        ) : (
          <EmptyState text={t('benchmark.result.subtitleEmpty')} />
        )}
      </Section>
    </Screen>
  );
}

function applyPlanPayload(request: ApplyPlanRequest) {
  return {
    platform: request.platform,
    profileId: request.profileId,
    testedResolver: request.testedResolver,
    confidence: request.confidence,
    gateHealth: request.gateHealth,
    environment: request.environment,
  };
}

function diagnosticsForJob(mode: Mode, job: BridgeJob, startedAtMs: number) {
  if (job.status === 'failed') {
    return buildBenchmarkDiagnostics({
      mode,
      error: new Error(job.error?.message ?? 'Bridge benchmark job failed.'),
      startedAtMs,
      endedAtMs: Date.now(),
    });
  }
  return buildBenchmarkDiagnostics({
    mode,
    result:
      job.result ??
      ({
        ok: true,
        action: job.action,
        args: [],
        data: {},
        progress: job.progress,
      } satisfies BridgeResult),
    startedAtMs,
    endedAtMs: Date.now(),
  });
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function StatusPill({ status, t }: { status: BenchmarkStepStatus; t: Translator }) {
  return <Pill label={t(`status.${status}`)} tone={statusTone(status)} />;
}

function ResolverRow({ resolver, t }: { resolver: ResolverDiagnostic; t: Translator }) {
  return (
    <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 6, padding: 12 }}>
      <View style={{ alignItems: 'center', flexDirection: 'row', gap: 8, justifyContent: 'space-between' }}>
        <Text selectable style={{ color: palette.text, flex: 1, fontSize: 14, fontWeight: '800' }}>
          {resolver.profileId}
        </Text>
        <Pill label={t(`status.${resolver.status}`)} tone={statusTone(resolver.status)} />
      </View>
      <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>
        {resolver.resolver ?? 'resolver unknown'} | elapsed {formatMs(resolver.elapsedMs)} | failure {formatRate(resolver.failureRate)} | timeout {formatRate(resolver.timeoutRate)}
      </Text>
      <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
        {resolver.diagnosis}
      </Text>
    </View>
  );
}

function statusTone(status: string) {
  if (status === 'success') return 'green';
  if (status === 'running' || status === 'degraded') return 'amber';
  if (status === 'failed') return 'red';
  return 'neutral';
}

function formatMs(value?: number) {
  return value === undefined ? 'n/a' : `${Math.round(value)}ms`;
}

function formatRate(value?: number) {
  return value === undefined ? 'n/a' : `${Math.round(value * 100)}%`;
}
