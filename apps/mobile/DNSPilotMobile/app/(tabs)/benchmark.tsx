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
import { buildApplyPlanRequest, type ApplyPlanRequest } from '@/src/view-models/benchmark-guidance';
import { buildBenchmarkPlan, suggestedSuites } from '@/src/view-models/benchmark-plan';
import {
  buildBenchmarkDiagnostics,
  type BenchmarkDiagnostics,
  type BenchmarkStepStatus,
  type ResolverDiagnostic,
} from '@/src/view-models/benchmark-diagnostics';
import { buildSettingsGuidance, type SettingsGuidance } from '@/src/view-models/settings-guidance';

type Mode = 'compare' | 'pathCompare' | 'benchmark' | 'pathEstimate' | 'systemBenchmark';
type IpFamily = 'both' | 'ipv4-only' | 'ipv6-only';
type MobilePlatform = 'ios' | 'android-play';

const modeOptions: { label: string; value: Mode }[] = [
  { label: 'DNS Compare', value: 'compare' },
  { label: 'Path Compare', value: 'pathCompare' },
  { label: 'Single DNS', value: 'benchmark' },
  { label: 'Single Path', value: 'pathEstimate' },
  { label: 'System DNS', value: 'systemBenchmark' },
];

const familyOptions: { label: string; value: IpFamily }[] = [
  { label: 'A + AAAA', value: 'both' },
  { label: 'A only', value: 'ipv4-only' },
  { label: 'AAAA only', value: 'ipv6-only' },
];

const platformOptions: { label: string; value: MobilePlatform }[] = [
  { label: 'iOS', value: 'ios' },
  { label: 'Android', value: 'android-play' },
];

export default function BenchmarkScreen() {
  const { profiles, suites, error, refreshAll, runAction, startJob, getJob } = useDNSPilot();
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
  const [vpnActive, setVpnActive] = useState(false);
  const [mdmProfileActive, setMdmProfileActive] = useState(false);
  const [corporateDnsDetected, setCorporateDnsDetected] = useState(false);
  const [captivePortalDetected, setCaptivePortalDetected] = useState(false);

  const plainProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'plain'), [profiles]);
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
    setCopyStatus('Report copied.');
  }

  async function loadGuidedPlan() {
    if (!applyPlanRequest) return;
    setGuidanceWorking(true);
    try {
      const payload = applyPlanPayload(applyPlanRequest);
      const next = await runAction('applyPlan', payload);
      setGuidancePayload(next);
      setGuidance(buildSettingsGuidance({ platform: guidancePlatform, applyPlan: next.data }));
    } finally {
      setGuidanceWorking(false);
    }
  }

  const resultData = result?.data as Record<string, unknown> | undefined;
  const summary = resultData?.summary ?? resultData?.metrics ?? resultData;
  const recommendation = resultData?.recommendation;

  return (
    <Screen>
      <Section title="Run" subtitle="Foreground only. Long worst-case plans will hold the app on this screen until CLI returns.">
        <Segmented options={modeOptions} value={mode} onChange={setMode} />
        {mode === 'systemBenchmark' ? <Segmented options={platformOptions} value={benchmarkPlatform} onChange={setBenchmarkPlatform} /> : null}
        <Segmented options={familyOptions} value={ipFamily} onChange={setIpFamily} />
        <View style={{ backgroundColor: palette.blueSoft, borderColor: '#bfdbfe', borderRadius: 8, borderWidth: 1, gap: 4, padding: 10 }}>
          <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
            A + AAAA tests IPv4 and IPv6 answers. Use A only when IPv6 looks broken on the current network. Use AAAA only to isolate IPv6 resolver behavior.
          </Text>
        </View>
        <Row>
          <Metric label="Selected" value={mode === 'systemBenchmark' ? 'system' : selectedProfiles.length} tone="blue" />
          <Metric label="Domains" value={benchmarkPlan.domainCount} tone="green" />
          <Metric label="Platform" value={mode === 'systemBenchmark' ? benchmarkPlatform : 'direct'} tone="amber" />
          <Metric label="History" value={benchmarkPlan.historyEnabled ? 'on' : 'off'} tone={benchmarkPlan.historyEnabled ? 'amber' : 'neutral'} />
        </Row>
        <TextField label="Domains" value={domains} onChangeText={setDomains} multiline placeholder="github.com&#10;expo.dev" />
        <Row>
          <TextField label="Attempts" value={attempts} onChangeText={setAttempts} keyboardType="numeric" />
          <TextField label="DNS timeout ms" value={timeoutMs} onChangeText={setTimeoutMs} keyboardType="numeric" />
        </Row>
        {(mode === 'pathCompare' || mode === 'pathEstimate') ? (
          <>
            <Row>
              <TextField label="TCP timeout ms" value={connectTimeoutMs} onChangeText={setConnectTimeoutMs} keyboardType="numeric" />
              <TextField label="Max targets/domain" value={maxTargets} onChangeText={setMaxTargets} keyboardType="numeric" />
            </Row>
            <ToggleRow label="TLS/SNI timing" value={tlsEnabled} onValueChange={setTlsEnabled} subtitle="Adds TLS handshake samples where supported." />
          </>
        ) : null}
        <ToggleRow label="Save history" value={saveHistory} onValueChange={setSaveHistory} subtitle="Available for compare/path-compare/benchmark." />
        <ErrorBanner message={benchmarkPlan.errors.join('\n')} />
        <Button label="Run benchmark" onPress={runBenchmark} loading={running} disabled={!benchmarkPlan.canRun} />
        <ErrorBanner message={error} />
      </Section>

      {mode !== 'systemBenchmark' ? (
        <Section title="Profiles" subtitle="Plain DNS profiles only. Custom profiles saved in Storage appear here.">
          {plainProfiles.length === 0 ? <EmptyState text="Refresh Overview or start the bridge to load profiles." /> : null}
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
        title="Process"
        subtitle={diagnostics ? `${diagnostics.status} | ${diagnostics.reason}` : 'Run a benchmark to populate process diagnostics.'}>
        {diagnostics ? (
          <>
            <Row>
              <Metric label="Status" value={diagnostics.status} tone={statusTone(diagnostics.status)} />
              <Metric label="Failed step" value={diagnostics.failedStepId ?? 'none'} tone={diagnostics.failedStepId ? 'red' : 'green'} />
              <Metric label="Elapsed" value={formatMs(diagnostics.elapsedMs)} tone="blue" />
            </Row>
            <View style={{ gap: 8 }}>
              {diagnostics.steps.map((step) => (
                <View key={step.id} style={{ alignItems: 'center', backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, flexDirection: 'row', gap: 10, justifyContent: 'space-between', padding: 12 }}>
                  <Text selectable style={{ color: palette.text, flex: 1, fontSize: 14, fontWeight: '800' }}>
                    {step.label}
                  </Text>
                  <StatusPill status={step.status} />
                </View>
              ))}
            </View>
            {diagnostics.resolvers.length > 0 ? (
              <View style={{ gap: 8 }}>
                {diagnostics.resolvers.map((resolver) => (
                  <ResolverRow key={`${resolver.profileId}-${resolver.resolver ?? ''}`} resolver={resolver} />
                ))}
              </View>
            ) : null}
            <Row>
              <Button label="Copy report" onPress={copyReport} variant="secondary" />
              {copyStatus ? <Pill label={copyStatus} tone="green" /> : null}
            </Row>
            <CodeBlock text={diagnostics.report} />
            {diagnostics.debugLog ? <CodeBlock text={diagnostics.debugLog} /> : null}
          </>
        ) : (
          <EmptyState text="No process diagnostics yet." />
        )}
      </Section>

      <Section title="Suites" subtitle="Optional. Domains above are added to suite domains.">
        <Row>
          <Pill label="No suite" selected={!suiteId} onPress={() => setSuiteId('')} />
          {suiteSuggestions.defaultSuiteId ? (
            <Pill label="Default" selected={suiteId === suiteSuggestions.defaultSuiteId} onPress={() => setSuiteId(suiteSuggestions.defaultSuiteId ?? '')} tone="blue" />
          ) : null}
          {suiteSuggestions.vietnamSuiteId ? (
            <Pill label="Vietnam" selected={suiteId === suiteSuggestions.vietnamSuiteId} onPress={() => setSuiteId(suiteSuggestions.vietnamSuiteId ?? '')} tone="amber" />
          ) : null}
          {suites.map((suite) => (
            <Pill key={suite.id} label={suite.name} selected={suiteId === suite.id} onPress={() => setSuiteId(suite.id)} tone="green" />
          ))}
        </Row>
        {benchmarkPlan.selectedSuite ? (
          <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>
            Selected suite adds {benchmarkPlan.selectedSuite.domains.length} domains: {compactList(benchmarkPlan.selectedSuite.domains)}
          </Text>
        ) : null}
      </Section>

      <Section title="Result" subtitle={result ? `CLI: ${result.args.join(' ')}` : 'Run a benchmark to see parsed JSON.'}>
        {result ? (
          <>
            <Row>
              <Metric label="Progress events" value={result.progress?.length ?? 0} tone="blue" />
              <Metric label="Action" value={result.action} tone="green" />
            </Row>
            {recommendation ? (
              <View style={{ backgroundColor: palette.greenSoft, borderColor: '#bbf7d0', borderRadius: 8, borderWidth: 1, padding: 12 }}>
                <Text selectable style={{ color: palette.green, fontSize: 14, fontWeight: '800' }}>
                  Recommendation
                </Text>
                <CodeBlock text={compactJson(recommendation, 1800)} />
              </View>
            ) : null}
            <CodeBlock text={compactJson(summary, 3200)} />
          </>
        ) : (
          <EmptyState text="No benchmark result yet." />
        )}
      </Section>

      <Section title="Guided DNS Settings" subtitle="Store-safe next step from the benchmark recommendation. No silent system DNS mutation.">
        {result ? (
          <>
            <Segmented options={platformOptions} value={guidancePlatform} onChange={setGuidancePlatform} />
            <Row>
              <ToggleRow label="VPN active" value={vpnActive} onValueChange={setVpnActive} />
              <ToggleRow label="MDM active" value={mdmProfileActive} onValueChange={setMdmProfileActive} />
            </Row>
            <Row>
              <ToggleRow label="Corporate DNS" value={corporateDnsDetected} onValueChange={setCorporateDnsDetected} />
              <ToggleRow label="Captive portal" value={captivePortalDetected} onValueChange={setCaptivePortalDetected} />
            </Row>
            {applyPlanRequest ? (
              <>
                <Row>
                  <Metric label="Recommended" value={applyPlanRequest.profileName} tone="green" />
                  <Metric label="Health" value={applyPlanRequest.gateHealth} tone={applyPlanRequest.gateHealth === 'healthy' ? 'green' : 'amber'} />
                  <Metric label="Confidence" value={applyPlanRequest.confidence} tone="blue" />
                </Row>
                <Button label="Load guided settings plan" onPress={loadGuidedPlan} loading={guidanceWorking} variant="secondary" />
              </>
            ) : (
              <EmptyState text="No guided settings plan is available because the benchmark did not return a recommendation." />
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
                  <Metric label="Mutates DNS" value={guidance.canMutateSystemDns ? 'yes' : 'no'} tone={guidance.canMutateSystemDns ? 'red' : 'green'} />
                  <Metric label="Steps" value={guidance.steps.length} tone="amber" />
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
                {guidancePayload ? <CodeBlock text={compactJson(guidancePayload.data, 2200)} /> : null}
              </View>
            ) : null}
          </>
        ) : (
          <EmptyState text="Run a benchmark first." />
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

function StatusPill({ status }: { status: BenchmarkStepStatus }) {
  return <Pill label={status} tone={statusTone(status)} />;
}

function ResolverRow({ resolver }: { resolver: ResolverDiagnostic }) {
  return (
    <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 6, padding: 12 }}>
      <View style={{ alignItems: 'center', flexDirection: 'row', gap: 8, justifyContent: 'space-between' }}>
        <Text selectable style={{ color: palette.text, flex: 1, fontSize: 14, fontWeight: '800' }}>
          {resolver.profileId}
        </Text>
        <Pill label={resolver.status} tone={statusTone(resolver.status)} />
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
