import React, { useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { compactJson, isCustomProfile, isCustomSuite } from '@/src/api/dnspilot';
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
  palette,
} from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { lines, safeId } from '@/src/utils/forms';

type Protocol = 'plain' | 'doh' | 'dot';
type Filtering = 'none' | 'malware' | 'family' | 'ads' | 'security';

const protocolOptions: { label: string; value: Protocol }[] = [
  { label: 'Plain', value: 'plain' },
  { label: 'DoH', value: 'doh' },
  { label: 'DoT', value: 'dot' },
];

const filteringOptions: { label: string; value: Filtering }[] = [
  { label: 'None', value: 'none' },
  { label: 'Malware', value: 'malware' },
  { label: 'Family', value: 'family' },
  { label: 'Ads', value: 'ads' },
  { label: 'Security', value: 'security' },
];

export default function StorageScreen() {
  const { profiles, suites, history, error, refreshAll, runAction } = useDNSPilot();
  const [profileId, setProfileId] = useState('');
  const [profileName, setProfileName] = useState('');
  const [protocol, setProtocol] = useState<Protocol>('plain');
  const [ipv4, setIpv4] = useState('9.9.9.9');
  const [ipv6, setIpv6] = useState('');
  const [dohUrl, setDohUrl] = useState('');
  const [dotHostname, setDotHostname] = useState('');
  const [filtering, setFiltering] = useState<Filtering>('none');
  const [profileTags, setProfileTags] = useState('custom');
  const [suiteId, setSuiteId] = useState('');
  const [suiteName, setSuiteName] = useState('');
  const [suiteDomains, setSuiteDomains] = useState('github.com\nexpo.dev');
  const [suiteTags, setSuiteTags] = useState('custom');
  const [working, setWorking] = useState(false);
  const [lastResult, setLastResult] = useState<unknown>(null);

  const customProfiles = useMemo(() => profiles.filter(isCustomProfile), [profiles]);
  const customSuites = useMemo(() => suites.filter(isCustomSuite), [suites]);

  function fillProfile(id: string) {
    const profile = customProfiles.find((item) => item.id === id);
    if (!profile) return;
    setProfileId(profile.id);
    setProfileName(profile.name);
    setProtocol(profile.protocol);
    setIpv4((profile.ipv4_servers ?? []).join('\n'));
    setIpv6((profile.ipv6_servers ?? []).join('\n'));
    setDohUrl(profile.doh_url ?? '');
    setDotHostname(profile.dot_hostname ?? '');
    setFiltering((profile.filtering_type as Filtering | undefined) ?? 'none');
    setProfileTags((profile.tags ?? ['custom']).join(', '));
  }

  function fillSuite(id: string) {
    const suite = customSuites.find((item) => item.id === id);
    if (!suite) return;
    setSuiteId(suite.id);
    setSuiteName(suite.name);
    setSuiteDomains(suite.domains.join('\n'));
    setSuiteTags((suite.tags ?? ['custom']).join(', '));
  }

  async function execute(action: string, payload: Record<string, unknown>) {
    setWorking(true);
    try {
      const result = await runAction(action, payload);
      setLastResult(result.data);
      await refreshAll();
    } finally {
      setWorking(false);
    }
  }

  const profilePayload = {
    id: profileId || safeId(profileName),
    name: profileName,
    protocol,
    ipv4Servers: lines(ipv4),
    ipv6Servers: lines(ipv6),
    dohUrl: dohUrl || undefined,
    dotHostname: dotHostname || undefined,
    filtering,
    tags: lines(profileTags),
  };

  const suitePayload = {
    id: suiteId || safeId(suiteName),
    name: suiteName,
    domains: lines(suiteDomains),
    tags: lines(suiteTags),
  };

  return (
    <Screen>
      <Section title="Storage" subtitle="SQLite-backed custom DNS profiles, domain suites, and benchmark history.">
        <Row>
          <Metric label="Custom profiles" value={customProfiles.length} tone="blue" />
          <Metric label="Custom suites" value={customSuites.length} tone="green" />
          <Metric label="History" value={history.length} tone="amber" />
        </Row>
        <Button label="Refresh storage" onPress={() => refreshAll().catch(() => undefined)} variant="secondary" />
        <ErrorBanner message={error} />
      </Section>

      <Section title="Custom DNS Profile" subtitle="Plain profiles can be benchmarked. DoH/DoT profiles are saved for catalog/apply guidance.">
        <Row>
          <TextField label="ID" value={profileId} onChangeText={setProfileId} placeholder="office-dns" />
          <TextField label="Name" value={profileName} onChangeText={setProfileName} placeholder="Office DNS" />
        </Row>
        <Segmented options={protocolOptions} value={protocol} onChange={setProtocol} />
        {protocol === 'plain' ? (
          <Row>
            <TextField label="IPv4 servers" value={ipv4} onChangeText={setIpv4} multiline placeholder="1.1.1.1" />
            <TextField label="IPv6 servers" value={ipv6} onChangeText={setIpv6} multiline placeholder="2606:4700:4700::1111" />
          </Row>
        ) : null}
        {protocol === 'doh' ? <TextField label="DoH URL" value={dohUrl} onChangeText={setDohUrl} placeholder="https://dns.example/dns-query" /> : null}
        {protocol === 'dot' ? <TextField label="DoT hostname" value={dotHostname} onChangeText={setDotHostname} placeholder="dns.example.com" /> : null}
        <Segmented options={filteringOptions} value={filtering} onChange={setFiltering} />
        <TextField label="Tags" value={profileTags} onChangeText={setProfileTags} placeholder="custom, office" />
        <Row>
          <Button label="Add" onPress={() => execute('profileAdd', profilePayload)} loading={working} />
          <Button label="Update" onPress={() => execute('profileUpdate', profilePayload)} variant="secondary" loading={working} />
          <Button label="Delete" onPress={() => execute('profileDelete', { id: profilePayload.id })} variant="danger" loading={working} />
        </Row>
        <Row>
          {customProfiles.map((profile) => (
            <Pill key={profile.id} label={profile.name} onPress={() => fillProfile(profile.id)} tone="amber" />
          ))}
        </Row>
      </Section>

      <Section title="Custom Domain Suite" subtitle="Suites plug into benchmark, compare, path-estimate, and path-compare.">
        <Row>
          <TextField label="ID" value={suiteId} onChangeText={setSuiteId} placeholder="work-stack" />
          <TextField label="Name" value={suiteName} onChangeText={setSuiteName} placeholder="Work Stack" />
        </Row>
        <TextField label="Domains" value={suiteDomains} onChangeText={setSuiteDomains} multiline placeholder="github.com&#10;registry.npmjs.org" />
        <TextField label="Tags" value={suiteTags} onChangeText={setSuiteTags} placeholder="custom, work" />
        <Row>
          <Button label="Add suite" onPress={() => execute('suiteAdd', suitePayload)} loading={working} />
          <Button label="Update suite" onPress={() => execute('suiteUpdate', suitePayload)} variant="secondary" loading={working} />
          <Button label="Delete suite" onPress={() => execute('suiteDelete', { id: suitePayload.id })} variant="danger" loading={working} />
        </Row>
        <Row>
          {customSuites.map((suite) => (
            <Pill key={suite.id} label={suite.name} onPress={() => fillSuite(suite.id)} tone="green" />
          ))}
        </Row>
      </Section>

      <Section title="History" subtitle="Saved by benchmark commands with Save history enabled.">
        <Row>
          <Button label="Clear history" onPress={() => execute('historyClear', {})} variant="danger" loading={working} />
        </Row>
        {history.length === 0 ? <EmptyState text="No saved benchmark history." /> : null}
        {history.map((record) => (
          <View key={record.id} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
            <Text selectable style={{ color: palette.text, fontSize: 15, fontWeight: '800' }}>
              {record.id}
            </Text>
            <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
              {record.scope} | {record.mode} | recommended {record.recommendation_profile_id ?? 'none'}
            </Text>
            <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
              {(record.domains ?? []).join(', ')}
            </Text>
            <Button label="Delete record" onPress={() => execute('historyDelete', { id: record.id })} variant="danger" loading={working} />
          </View>
        ))}
      </Section>

      <Section title="Last CLI Result">
        {lastResult ? <CodeBlock text={compactJson(lastResult, 2600)} /> : <EmptyState text="No storage action result yet." />}
      </Section>
    </Screen>
  );
}
