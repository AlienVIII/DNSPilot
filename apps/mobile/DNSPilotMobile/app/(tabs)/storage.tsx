import React, { useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { compactJson, isCustomProfile, isCustomSuite } from '@/src/api/dnspilot';
import {
  AdaptiveColumns,
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
import { translateKnownError } from '@/src/view-models/localization';
import { buildProfileForm, buildSuiteForm } from '@/src/view-models/storage-forms';

type Protocol = 'plain' | 'doh' | 'dot';
type Filtering = 'none' | 'malware' | 'family' | 'ads' | 'security';

export default function StorageScreen() {
  const { profiles, suites, history, error, refreshAll, runAction, locale, t } = useDNSPilot();
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
  const profileForm = useMemo(
    () =>
      buildProfileForm({
        profileId,
        profileName,
        protocol,
        ipv4,
        ipv6,
        dohUrl,
        dotHostname,
        filtering,
        profileTags,
      }),
    [dohUrl, dotHostname, filtering, ipv4, ipv6, profileId, profileName, profileTags, protocol]
  );
  const suiteForm = useMemo(
    () =>
      buildSuiteForm({
        suiteId,
        suiteName,
        suiteDomains,
        suiteTags,
      }),
    [suiteDomains, suiteId, suiteName, suiteTags]
  );
  const profileErrors = profileForm.errors.map((item) => translateKnownError(locale, item)).join('\n');
  const suiteErrors = suiteForm.errors.map((item) => translateKnownError(locale, item)).join('\n');
  const protocolOptions = useMemo(
    () => [
      { label: t('storage.protocol.plain'), value: 'plain' as const },
      { label: t('storage.protocol.doh'), value: 'doh' as const },
      { label: t('storage.protocol.dot'), value: 'dot' as const },
    ],
    [t]
  );
  const filteringOptions = useMemo(
    () => [
      { label: t('storage.filtering.none'), value: 'none' as const },
      { label: t('storage.filtering.malware'), value: 'malware' as const },
      { label: t('storage.filtering.family'), value: 'family' as const },
      { label: t('storage.filtering.ads'), value: 'ads' as const },
      { label: t('storage.filtering.security'), value: 'security' as const },
    ],
    [t]
  );

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

  return (
    <Screen>
      <Section title={t('storage.title')} subtitle={t('storage.subtitle')}>
        <Row>
          <Metric label={t('storage.metric.customProfiles')} value={customProfiles.length} tone="blue" />
          <Metric label={t('storage.metric.customSuites')} value={customSuites.length} tone="green" />
          <Metric label={t('overview.metric.history')} value={history.length} tone="amber" />
        </Row>
        <Button label={t('storage.refresh')} onPress={() => refreshAll().catch(() => undefined)} variant="secondary" />
        <ErrorBanner message={error} />
      </Section>

      <AdaptiveColumns>
        <Section title={t('storage.profile.title')} subtitle={t('storage.profile.subtitle')}>
          <Row>
            <TextField label={t('storage.profile.id')} value={profileId} onChangeText={setProfileId} placeholder="office-dns" />
            <TextField label={t('storage.profile.name')} value={profileName} onChangeText={setProfileName} placeholder="Office DNS" />
          </Row>
          <Segmented options={protocolOptions} value={protocol} onChange={setProtocol} />
          {protocol === 'plain' ? (
            <Row>
              <TextField label={t('storage.profile.ipv4')} value={ipv4} onChangeText={setIpv4} multiline placeholder="1.1.1.1" />
              <TextField label={t('storage.profile.ipv6')} value={ipv6} onChangeText={setIpv6} multiline placeholder="2606:4700:4700::1111" />
            </Row>
          ) : null}
          {protocol === 'doh' ? <TextField label={t('storage.profile.doh')} value={dohUrl} onChangeText={setDohUrl} placeholder="https://dns.example/dns-query" /> : null}
          {protocol === 'dot' ? <TextField label={t('storage.profile.dot')} value={dotHostname} onChangeText={setDotHostname} placeholder="dns.example.com" /> : null}
          <Segmented options={filteringOptions} value={filtering} onChange={setFiltering} />
          <TextField label={t('storage.profile.tags')} value={profileTags} onChangeText={setProfileTags} placeholder="custom, office" />
          <ErrorBanner message={profileErrors} />
          <Row>
            <Button label={t('common.add')} onPress={() => execute('profileAdd', profileForm.payload)} loading={working} disabled={!profileForm.canSubmit} />
            <Button label={t('common.update')} onPress={() => execute('profileUpdate', profileForm.payload)} variant="secondary" loading={working} disabled={!profileForm.canSubmit} />
            <Button label={t('common.delete')} onPress={() => execute('profileDelete', { id: profileForm.payload.id })} variant="danger" loading={working} disabled={!profileForm.canDelete} />
          </Row>
          <Row>
            {customProfiles.map((profile) => (
              <Pill key={profile.id} label={profile.name} onPress={() => fillProfile(profile.id)} tone="amber" />
            ))}
          </Row>
        </Section>

        <Section title={t('storage.suite.title')} subtitle={t('storage.suite.subtitle')}>
          <Row>
            <TextField label={t('storage.suite.id')} value={suiteId} onChangeText={setSuiteId} placeholder="work-stack" />
            <TextField label={t('storage.suite.name')} value={suiteName} onChangeText={setSuiteName} placeholder="Work Stack" />
          </Row>
          <TextField label={t('storage.suite.domains')} value={suiteDomains} onChangeText={setSuiteDomains} multiline placeholder="github.com&#10;registry.npmjs.org" />
          <TextField label={t('storage.suite.tags')} value={suiteTags} onChangeText={setSuiteTags} placeholder="custom, work" />
          <ErrorBanner message={suiteErrors} />
          <Row>
            <Button label={t('storage.suite.add')} onPress={() => execute('suiteAdd', suiteForm.payload)} loading={working} disabled={!suiteForm.canSubmit} />
            <Button label={t('storage.suite.update')} onPress={() => execute('suiteUpdate', suiteForm.payload)} variant="secondary" loading={working} disabled={!suiteForm.canSubmit} />
            <Button label={t('storage.suite.delete')} onPress={() => execute('suiteDelete', { id: suiteForm.payload.id })} variant="danger" loading={working} disabled={!suiteForm.canDelete} />
          </Row>
          <Row>
            {customSuites.map((suite) => (
              <Pill key={suite.id} label={suite.name} onPress={() => fillSuite(suite.id)} tone="green" />
            ))}
          </Row>
        </Section>
      </AdaptiveColumns>

      <Section title={t('storage.history.title')} subtitle={t('storage.history.subtitle')}>
        <Row>
          <Button label={t('storage.history.clear')} onPress={() => execute('historyClear', {})} variant="danger" loading={working} />
        </Row>
        {history.length === 0 ? <EmptyState text={t('storage.history.empty')} /> : null}
        {history.map((record) => (
          <View key={record.id} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
            <Text selectable style={{ color: palette.text, fontSize: 15, fontWeight: '800' }}>
              {record.id}
            </Text>
            <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
              {t('storage.history.record', {
                scope: record.scope ?? t('common.unknown'),
                mode: record.mode ?? t('common.unknown'),
                recommendation: record.recommendation_profile_id ?? t('common.none'),
              })}
            </Text>
            <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
              {(record.domains ?? []).join(', ')}
            </Text>
            <Button label={t('storage.history.delete')} onPress={() => execute('historyDelete', { id: record.id })} variant="danger" loading={working} />
          </View>
        ))}
      </Section>

      <Section title={t('storage.lastResult.title')}>
        {lastResult ? <CodeBlock text={compactJson(lastResult, 2600)} /> : <EmptyState text={t('storage.lastResult.empty')} />}
      </Section>
    </Screen>
  );
}
