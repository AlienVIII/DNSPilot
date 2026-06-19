import * as Clipboard from 'expo-clipboard';
import React, { useEffect, useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { BridgeResult, compactJson, DNSProfile, profileServers } from '@/src/api/dnspilot';
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
import { compactList, lines } from '@/src/utils/forms';
import {
  buildBenchmarkDiagnostics,
  type BenchmarkDiagnostics,
  type BenchmarkStepStatus,
  type ResolverDiagnostic,
} from '@/src/view-models/benchmark-diagnostics';

type Mode = 'compare' | 'pathCompare' | 'benchmark' | 'pathEstimate' | 'systemBenchmark';
type IpFamily = 'both' | 'ipv4-only' | 'ipv6-only';

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

export default function BenchmarkScreen() {
  const { profiles, suites, error, refreshAll, runAction } = useDNSPilot();
  const [mode, setMode] = useState<Mode>('pathCompare');
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
  const [copyStatus, setCopyStatus] = useState<string | null>(null);

  const plainProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'plain'), [profiles]);

  useEffect(() => {
    if (plainProfiles.length > 0 && selectedProfiles.length === 0) {
      const preferred = ['cloudflare', 'google-public-dns', 'quad9'].filter((id) => plainProfiles.some((profile) => profile.id === id));
      setSelectedProfiles(preferred.length > 0 ? preferred : plainProfiles.slice(0, 3).map((profile) => profile.id));
    }
  }, [plainProfiles, selectedProfiles.length]);

  function toggleProfile(profile: DNSProfile) {
    setSelectedProfiles((current) =>
      current.includes(profile.id) ? current.filter((id) => id !== profile.id) : [...current, profile.id]
    );
  }

  async function runBenchmark() {
    const startedAtMs = Date.now();
    setRunning(true);
    setResult(null);
    setCopyStatus(null);
    setDiagnostics(buildBenchmarkDiagnostics({ mode, startedAtMs }));
    try {
      const payload = {
        profileIds: selectedProfiles,
        profileId: selectedProfiles[0] ?? 'cloudflare',
        suiteId: suiteId || undefined,
        domains: lines(domains),
        attempts: Number(attempts),
        ipFamily,
        timeoutMs: Number(timeoutMs),
        dnsTimeoutMs: Number(timeoutMs),
        connectTimeoutMs: Number(connectTimeoutMs),
        maxConnectTargetsPerDomain: Number(maxTargets),
        tlsHandshakeTimeoutMs: tlsEnabled ? Number(connectTimeoutMs) : undefined,
        platform: 'ios',
        saveHistory,
      };
      const next = await runAction(mode, payload);
      setResult(next);
      setDiagnostics(buildBenchmarkDiagnostics({ mode, result: next, startedAtMs, endedAtMs: Date.now() }));
      await refreshAll();
    } catch (caught) {
      setDiagnostics(buildBenchmarkDiagnostics({ mode, error: caught, startedAtMs, endedAtMs: Date.now() }));
    } finally {
      setRunning(false);
    }
  }

  async function copyReport() {
    if (!diagnostics) return;
    await Clipboard.setStringAsync(diagnostics.report);
    setCopyStatus('Report copied.');
  }

  const resultData = result?.data as Record<string, unknown> | undefined;
  const summary = resultData?.summary ?? resultData?.metrics ?? resultData;
  const recommendation = resultData?.recommendation;

  return (
    <Screen>
      <Section title="Run" subtitle="Foreground only. Long worst-case plans will hold the app on this screen until CLI returns.">
        <Segmented options={modeOptions} value={mode} onChange={setMode} />
        <Segmented options={familyOptions} value={ipFamily} onChange={setIpFamily} />
        <Row>
          <Metric label="Selected" value={mode === 'systemBenchmark' ? 'system' : selectedProfiles.length} tone="blue" />
          <Metric label="Domains" value={lines(domains).length + (suiteId ? 1 : 0)} tone="green" />
          <Metric label="History" value={saveHistory ? 'on' : 'off'} tone={saveHistory ? 'amber' : 'neutral'} />
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
        <Button label="Run benchmark" onPress={runBenchmark} loading={running} disabled={selectedProfiles.length === 0 && mode !== 'systemBenchmark'} />
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
          {suites.map((suite) => (
            <Pill key={suite.id} label={suite.name} selected={suiteId === suite.id} onPress={() => setSuiteId(suite.id)} tone="green" />
          ))}
        </Row>
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
    </Screen>
  );
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
