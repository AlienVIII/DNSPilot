import React, { useEffect, useMemo, useState } from 'react';
import Constants from 'expo-constants';
import { Platform, Text, View } from 'react-native';

import { isCustomProfile, isCustomSuite, profileServers } from '@/src/api/dnspilot';
import { DNSSettings, type DNSSettingsStatus } from '@/modules/dns-settings/src/DNSSettingsModule';
import { AdaptiveColumns, Button, EmptyState, ErrorBanner, Metric, Pill, Row, Screen, Section, Segmented, TextField, palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { translateKnownError } from '@/src/view-models/localization';
import { buildIosDnsSettingsRequest } from '@/src/view-models/native-dns-settings';
import { buildNativeDnsStatus } from '@/src/view-models/native-dns-status';
import { buildProfileForm, buildSuiteForm } from '@/src/view-models/storage-forms';

type Protocol = 'plain' | 'doh' | 'dot';
type Filtering = 'none' | 'malware' | 'family' | 'ads' | 'security';
const iosDnsSettingsEnabled = Constants.expoConfig?.extra?.iosDnsSettingsEnabled === true;

export default function ProfilesScreen() {
  const { profiles, suites, error, refreshAll, runAction, locale, t, languageOptions, languagePreference, setLanguagePreference } = useDNSPilot();
  const [query, setQuery] = useState('');
  const [profileId, setProfileId] = useState('');
  const [profileName, setProfileName] = useState('');
  const [protocol, setProtocol] = useState<Protocol>('plain');
  const [ipv4, setIpv4] = useState('');
  const [ipv6, setIpv6] = useState('');
  const [dohUrl, setDohUrl] = useState('');
  const [dotHostname, setDotHostname] = useState('');
  const [filtering, setFiltering] = useState<Filtering>('none');
  const [profileTags, setProfileTags] = useState('custom');
  const [suiteId, setSuiteId] = useState('');
  const [suiteName, setSuiteName] = useState('');
  const [suiteDomains, setSuiteDomains] = useState('');
  const [suiteTags, setSuiteTags] = useState('custom');
  const [working, setWorking] = useState(false);
  const [selectedEncryptedProfileID, setSelectedEncryptedProfileID] = useState('');
  const [nativeDnsStatus, setNativeDnsStatus] = useState<DNSSettingsStatus | null>(null);
  const [nativeDnsWorking, setNativeDnsWorking] = useState(false);

  const customProfiles = useMemo(() => profiles.filter(isCustomProfile), [profiles]);
  const customSuites = useMemo(() => suites.filter(isCustomSuite), [suites]);
  const encryptedProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'doh' || profile.protocol === 'dot'), [profiles]);
  const selectedEncryptedProfile = encryptedProfiles.find((profile) => profile.id === selectedEncryptedProfileID);
  const iosDnsPlan = useMemo(() => buildIosDnsSettingsRequest(selectedEncryptedProfile), [selectedEncryptedProfile]);
  const nativeDnsPresentation = useMemo(() => nativeDnsStatus ? buildNativeDnsStatus(nativeDnsStatus) : null, [nativeDnsStatus]);
  const profileForm = useMemo(
    () => buildProfileForm({ profileId, profileName, protocol, ipv4, ipv6, dohUrl, dotHostname, filtering, profileTags }),
    [dohUrl, dotHostname, filtering, ipv4, ipv6, profileId, profileName, profileTags, protocol]
  );
  const suiteForm = useMemo(
    () => buildSuiteForm({ suiteId, suiteName, suiteDomains, suiteTags }),
    [suiteDomains, suiteId, suiteName, suiteTags]
  );
  const visibleProfiles = useMemo(() => {
    const term = query.trim().toLowerCase();
    return profiles.filter((profile) => !term || [profile.name, profile.id, profile.description, ...(profile.tags ?? [])].some((part) => String(part ?? '').toLowerCase().includes(term)));
  }, [profiles, query]);
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

  useEffect(() => {
    if (!selectedEncryptedProfileID && encryptedProfiles.length > 0) setSelectedEncryptedProfileID(encryptedProfiles[0].id);
  }, [encryptedProfiles, selectedEncryptedProfileID]);

  useEffect(() => {
    if (Platform.OS !== 'ios' || !iosDnsSettingsEnabled) return;
    DNSSettings.getStatus().then(setNativeDnsStatus).catch(() => undefined);
  }, []);

  async function execute(action: string, payload: Record<string, unknown>) {
    setWorking(true);
    try {
      await runAction(action, payload);
      await refreshAll();
    } finally {
      setWorking(false);
    }
  }

  function editProfile(id: string) {
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

  function editSuite(id: string) {
    const suite = customSuites.find((item) => item.id === id);
    if (!suite) return;
    setSuiteId(suite.id);
    setSuiteName(suite.name);
    setSuiteDomains(suite.domains.join('\n'));
    setSuiteTags((suite.tags ?? ['custom']).join(', '));
  }

  async function installDnsSettings() {
    if (!iosDnsPlan.request) return;
    setNativeDnsWorking(true);
    try {
      setNativeDnsStatus(await DNSSettings.install(iosDnsPlan.request));
    } catch (caught) {
      setNativeDnsStatus({ available: false, installed: false, enabled: false, reason: caught instanceof Error ? caught.message : String(caught) });
    } finally {
      setNativeDnsWorking(false);
    }
  }

  async function removeDnsSettings() {
    setNativeDnsWorking(true);
    try {
      setNativeDnsStatus(await DNSSettings.remove());
    } catch (caught) {
      setNativeDnsStatus({ available: false, installed: false, enabled: false, reason: caught instanceof Error ? caught.message : String(caught) });
    } finally {
      setNativeDnsWorking(false);
    }
  }

  async function refreshNativeDnsStatus() {
    setNativeDnsWorking(true);
    try {
      setNativeDnsStatus(await DNSSettings.getStatus());
    } catch (caught) {
      setNativeDnsStatus({ available: false, installed: false, enabled: false, reason: caught instanceof Error ? caught.message : String(caught) });
    } finally {
      setNativeDnsWorking(false);
    }
  }

  return (
    <Screen>
      <Section title={t('tabs.profiles')} subtitle={t('catalog.subtitle')}>
        <TextField label={t('common.search')} value={query} onChangeText={setQuery} placeholder={t('catalog.placeholder')} />
        <Button label={t('catalog.refresh')} onPress={() => refreshAll().catch(() => undefined)} variant="secondary" loading={working} />
        <ErrorBanner message={error} />
      </Section>

      <Section title={t('catalog.profiles.title')} subtitle={t('catalog.profiles.subtitle', { count: visibleProfiles.length })}>
        {visibleProfiles.length === 0 ? <EmptyState text={t('catalog.profiles.empty')} /> : null}
        {visibleProfiles.map((profile) => (
          <View key={profile.id} style={cardStyle}>
            <Row>
              <Text selectable style={{ color: palette.text, flex: 1, fontSize: 16, fontWeight: '800' }}>{profile.name}</Text>
              <Pill label={profile.protocol.toUpperCase()} tone={profile.protocol === 'plain' ? 'blue' : 'amber'} />
            </Row>
            {profile.description ? <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>{profile.description}</Text> : null}
            <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>{profileServers(profile).join(', ') || profile.doh_url || profile.dot_hostname || t('common.none')}</Text>
          </View>
        ))}
      </Section>

      <AdaptiveColumns>
        <Section title={t('storage.profile.title')} subtitle={t('storage.profile.subtitle')}>
          <Row>
            <TextField label={t('storage.profile.id')} value={profileId} onChangeText={setProfileId} placeholder="office-dns" />
            <TextField label={t('storage.profile.name')} value={profileName} onChangeText={setProfileName} placeholder="Office DNS" />
          </Row>
          <Segmented options={protocolOptions} value={protocol} onChange={setProtocol} />
          {protocol === 'plain' ? <Row><TextField label={t('storage.profile.ipv4')} value={ipv4} onChangeText={setIpv4} multiline placeholder="1.1.1.1" /><TextField label={t('storage.profile.ipv6')} value={ipv6} onChangeText={setIpv6} multiline placeholder="2606:4700:4700::1111" /></Row> : null}
          {protocol === 'doh' ? <TextField label={t('storage.profile.doh')} value={dohUrl} onChangeText={setDohUrl} placeholder="https://dns.example/dns-query" /> : null}
          {protocol === 'dot' ? <TextField label={t('storage.profile.dot')} value={dotHostname} onChangeText={setDotHostname} placeholder="dns.example.com" /> : null}
          {protocol !== 'plain' ? <><Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>{t('storage.profile.bootstrapHelp')}</Text><Row><TextField label={t('storage.profile.bootstrapIpv4')} value={ipv4} onChangeText={setIpv4} multiline placeholder="1.1.1.1" /><TextField label={t('storage.profile.bootstrapIpv6')} value={ipv6} onChangeText={setIpv6} multiline placeholder="2606:4700:4700::1111" /></Row></> : null}
          <Segmented options={filteringOptions} value={filtering} onChange={setFiltering} />
          <TextField label={t('storage.profile.tags')} value={profileTags} onChangeText={setProfileTags} placeholder="custom, office" />
          <ErrorBanner message={profileForm.errors.map((item) => translateKnownError(locale, item)).join('\n')} />
          <Row>
            <Button label={t('common.add')} onPress={() => execute('profileAdd', profileForm.payload)} loading={working} disabled={!profileForm.canSubmit} />
            <Button label={t('common.update')} onPress={() => execute('profileUpdate', profileForm.payload)} variant="secondary" loading={working} disabled={!profileForm.canSubmit} />
            <Button label={t('common.delete')} onPress={() => execute('profileDelete', { id: profileForm.payload.id })} variant="danger" loading={working} disabled={!profileForm.canDelete} />
          </Row>
          <Row>{customProfiles.map((profile) => <Pill key={profile.id} label={profile.name} onPress={() => editProfile(profile.id)} tone="amber" />)}</Row>
        </Section>

        <Section title={t('storage.suite.title')} subtitle={t('storage.suite.subtitle')}>
          <Row>
            <TextField label={t('storage.suite.id')} value={suiteId} onChangeText={setSuiteId} placeholder="work-stack" />
            <TextField label={t('storage.suite.name')} value={suiteName} onChangeText={setSuiteName} placeholder="Work Stack" />
          </Row>
          <TextField label={t('storage.suite.domains')} value={suiteDomains} onChangeText={setSuiteDomains} multiline placeholder="github.com\nexpo.dev" />
          <TextField label={t('storage.suite.tags')} value={suiteTags} onChangeText={setSuiteTags} placeholder="custom, work" />
          <ErrorBanner message={suiteForm.errors.map((item) => translateKnownError(locale, item)).join('\n')} />
          <Row>
            <Button label={t('storage.suite.add')} onPress={() => execute('suiteAdd', suiteForm.payload)} loading={working} disabled={!suiteForm.canSubmit} />
            <Button label={t('storage.suite.update')} onPress={() => execute('suiteUpdate', suiteForm.payload)} variant="secondary" loading={working} disabled={!suiteForm.canSubmit} />
            <Button label={t('storage.suite.delete')} onPress={() => execute('suiteDelete', { id: suiteForm.payload.id })} variant="danger" loading={working} disabled={!suiteForm.canDelete} />
          </Row>
          <Row>{customSuites.map((suite) => <Pill key={suite.id} label={suite.name} onPress={() => editSuite(suite.id)} tone="green" />)}</Row>
        </Section>
      </AdaptiveColumns>

      {Platform.OS === 'ios' && iosDnsSettingsEnabled ? (
        <Section title={t('policy.nativeDns.title')} subtitle={t('policy.nativeDns.subtitle')}>
          <View style={cardStyle}>
            {nativeDnsPresentation ? (
              <Row>
                <Metric label={t('policy.nativeDns.available')} value={t(nativeDnsPresentation.availabilityKey)} tone={nativeDnsPresentation.tone} />
                <Metric label={t('policy.nativeDns.installed')} value={t(nativeDnsPresentation.installedKey)} tone={nativeDnsStatus?.installed ? 'green' : 'neutral'} />
                <Metric label={t('policy.nativeDns.enabled')} value={t(nativeDnsPresentation.enabledKey)} tone={nativeDnsPresentation.tone} />
              </Row>
            ) : null}
            <Row>{encryptedProfiles.map((profile) => <Pill key={profile.id} label={`${profile.name} (${profile.protocol.toUpperCase()})`} selected={profile.id === selectedEncryptedProfileID} onPress={() => setSelectedEncryptedProfileID(profile.id)} tone="blue" />)}</Row>
            {encryptedProfiles.length === 0 ? <EmptyState text={t('policy.nativeDns.empty')} /> : null}
            {selectedEncryptedProfile ? <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>{iosDnsPlan.canInstall ? t('policy.nativeDns.ready', { profile: selectedEncryptedProfile.name }) : t(`policy.nativeDns.reason.${iosDnsPlan.reason}`)}</Text> : null}
            <Row>
              <Button label={t('policy.nativeDns.install')} onPress={installDnsSettings} loading={nativeDnsWorking} disabled={!iosDnsPlan.canInstall || !nativeDnsStatus?.available} />
              <Button label={t('policy.nativeDns.remove')} onPress={removeDnsSettings} variant="danger" loading={nativeDnsWorking} disabled={!nativeDnsStatus?.installed} />
              <Button label={t('policy.nativeDns.refresh')} onPress={refreshNativeDnsStatus} variant="secondary" loading={nativeDnsWorking} />
            </Row>
            <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>{t('policy.nativeDns.enableHelp')}</Text>
            {nativeDnsStatus?.reason ? <ErrorBanner message={nativeDnsStatus.reason} /> : null}
          </View>
        </Section>
      ) : null}

      <Section title={t('language.title')} subtitle={t('language.subtitle')}>
        <Row>{languageOptions.map((option) => <Button key={option.value} label={option.value === 'system' ? t('language.auto') : option.label} onPress={() => setLanguagePreference(option.value)} variant={languagePreference === option.value ? 'primary' : 'secondary'} />)}</Row>
      </Section>
    </Screen>
  );
}

const cardStyle = { backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 } as const;
