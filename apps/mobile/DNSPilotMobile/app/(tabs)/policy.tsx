import * as Clipboard from 'expo-clipboard';
import React, { useEffect, useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { BridgeResult, compactJson, profileServers } from '@/src/api/dnspilot';
import { DNSSettings, type DNSSettingsStatus } from '@/modules/dns-settings/src/DNSSettingsModule';
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
  ToggleRow,
  palette,
} from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { openNativeSettings } from '@/src/utils/native-settings';
import { buildSettingsGuidance, guidanceActionStatus, type SettingsGuidance } from '@/src/view-models/settings-guidance';
import { buildIosDnsSettingsRequest } from '@/src/view-models/native-dns-settings';

type MobilePlatform = 'ios' | 'android-play';
type GateHealth = 'healthy' | 'degraded' | 'failed' | 'inconclusive';
type Confidence = 'high' | 'medium' | 'low' | 'inconclusive';

export default function PolicyScreen() {
  const { profiles, capabilities, error, runAction, locale, t } = useDNSPilot();
  const [platform, setPlatform] = useState<MobilePlatform>('ios');
  const [profileId, setProfileId] = useState('');
  const [testedResolver, setTestedResolver] = useState('');
  const [gateHealth, setGateHealth] = useState<GateHealth>('healthy');
  const [confidence, setConfidence] = useState<Confidence>('high');
  const [vpnActive, setVpnActive] = useState(false);
  const [mdmProfileActive, setMdmProfileActive] = useState(false);
  const [corporateDnsDetected, setCorporateDnsDetected] = useState(false);
  const [captivePortalDetected, setCaptivePortalDetected] = useState(false);
  const [working, setWorking] = useState(false);
  const [results, setResults] = useState<Record<string, BridgeResult>>({});
  const [settingsActionStatus, setSettingsActionStatus] = useState<string | null>(null);
  const [settingsActionWorking, setSettingsActionWorking] = useState(false);
  const [iosProfileId, setIosProfileId] = useState('');
  const [nativeDnsStatus, setNativeDnsStatus] = useState<DNSSettingsStatus | null>(null);
  const [nativeDnsWorking, setNativeDnsWorking] = useState(false);

  const plainProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'plain'), [profiles]);
  const selectedProfile = plainProfiles.find((profile) => profile.id === profileId);
  const encryptedProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'doh' || profile.protocol === 'dot'), [profiles]);
  const selectedIosProfile = encryptedProfiles.find((profile) => profile.id === iosProfileId);
  const iosDnsPlan = useMemo(() => buildIosDnsSettingsRequest(selectedIosProfile), [selectedIosProfile]);
  const capability = capabilities.find((item) => item.platform === platform);
  const guidance = results.applyPlan
    ? buildSettingsGuidance({ platform, applyPlan: results.applyPlan.data, locale })
    : null;
  const platformOptions = useMemo(
    () => [
      { label: t('platform.ios'), value: 'ios' as const },
      { label: t('platform.android'), value: 'android-play' as const },
    ],
    [t]
  );
  const healthOptions = useMemo(
    () => [
      { label: t('policy.option.healthy'), value: 'healthy' as const },
      { label: t('policy.option.degraded'), value: 'degraded' as const },
      { label: t('policy.option.failed'), value: 'failed' as const },
      { label: t('policy.option.inconclusive'), value: 'inconclusive' as const },
    ],
    [t]
  );
  const confidenceOptions = useMemo(
    () => [
      { label: t('policy.option.high'), value: 'high' as const },
      { label: t('policy.option.medium'), value: 'medium' as const },
      { label: t('policy.option.low'), value: 'low' as const },
      { label: t('policy.option.inconclusive'), value: 'inconclusive' as const },
    ],
    [t]
  );

  useEffect(() => {
    if (!profileId && plainProfiles.length > 0) {
      setProfileId(plainProfiles[0].id);
    }
  }, [plainProfiles, profileId]);

  useEffect(() => {
    if (selectedProfile && !testedResolver) {
      setTestedResolver(profileServers(selectedProfile)[0] ?? '');
    }
  }, [selectedProfile, testedResolver]);

  useEffect(() => {
    if (!iosProfileId && encryptedProfiles.length > 0) {
      setIosProfileId(encryptedProfiles[0].id);
    }
  }, [encryptedProfiles, iosProfileId]);

  useEffect(() => {
    if (platform !== 'ios') return;
    DNSSettings.getStatus().then(setNativeDnsStatus).catch((caught: unknown) => {
      setNativeDnsStatus({ available: false, installed: false, enabled: false, reason: errorMessage(caught) });
    });
  }, [platform]);

  async function runPolicy() {
    setWorking(true);
    setSettingsActionStatus(null);
    try {
      const environment = {
        vpnActive,
        mdmProfileActive,
        corporateDnsDetected,
        captivePortalDetected,
      };
      const nextEntries = await Promise.all([
        runAction('capability', { platform }),
        runAction('preflight', { platform, scope: 'direct-resolver-benchmark' }),
        runAction('preflight', { platform, scope: 'system-dns-validation' }),
        runAction('applyPolicy', { platform, environment }),
        runAction('applyPlan', {
          platform,
          profileId,
          testedResolver,
          confidence,
          gateHealth,
          environment,
        }),
      ]);
      setResults({
        capability: nextEntries[0],
        directPreflight: nextEntries[1],
        systemPreflight: nextEntries[2],
        applyPolicy: nextEntries[3],
        applyPlan: nextEntries[4],
      });
    } finally {
      setWorking(false);
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
        const next = await runAction('systemBenchmark', {
          platform,
          domains: ['github.com', 'expo.dev'],
          attempts: 1,
          ipFamily: 'both',
          timeoutMs: 800,
        });
        setResults((current) => ({ ...current, systemBenchmark: next }));
      }
      setSettingsActionStatus(guidanceActionStatus({ actionKind: action.kind, phase: 'success', locale }));
    } catch {
      setSettingsActionStatus(guidanceActionStatus({ actionKind: action.kind, phase: 'failed', locale }));
    } finally {
      setSettingsActionWorking(false);
    }
  }

  async function refreshNativeDnsStatus() {
    setNativeDnsWorking(true);
    try {
      setNativeDnsStatus(await DNSSettings.getStatus());
    } catch (caught) {
      setNativeDnsStatus({ available: false, installed: false, enabled: false, reason: errorMessage(caught) });
    } finally {
      setNativeDnsWorking(false);
    }
  }

  async function installNativeDnsSettings() {
    if (!iosDnsPlan.request) return;
    setNativeDnsWorking(true);
    try {
      setNativeDnsStatus(await DNSSettings.install(iosDnsPlan.request));
    } catch (caught) {
      setNativeDnsStatus({ available: false, installed: false, enabled: false, reason: errorMessage(caught) });
    } finally {
      setNativeDnsWorking(false);
    }
  }

  async function removeNativeDnsSettings() {
    setNativeDnsWorking(true);
    try {
      setNativeDnsStatus(await DNSSettings.remove());
    } catch (caught) {
      setNativeDnsStatus({ available: false, installed: false, enabled: false, reason: errorMessage(caught) });
    } finally {
      setNativeDnsWorking(false);
    }
  }

  return (
    <Screen>
      <Section title={t('policy.title')} subtitle={t('policy.subtitle')}>
        <Segmented options={platformOptions} value={platform} onChange={setPlatform} />
        <Row>
          <Metric label={t('policy.metric.apply')} value={capability?.apply ?? t('common.unknown')} tone="blue" />
          <Metric label={t('policy.metric.flush')} value={capability?.flush ?? t('common.unknown')} tone="amber" />
          <Metric label={t('policy.metric.storeSafe')} value={capability?.store_safe ? t('common.yes') : t('common.no')} tone={capability?.store_safe ? 'green' : 'red'} />
        </Row>
        <ErrorBanner message={error} />
      </Section>

      <AdaptiveColumns>
        <Section title={t('policy.input.title')} subtitle={t('policy.input.subtitle')}>
          <Segmented options={healthOptions} value={gateHealth} onChange={setGateHealth} />
          <Segmented options={confidenceOptions} value={confidence} onChange={setConfidence} />
          <TextField label={t('policy.testedResolver')} value={testedResolver} onChangeText={setTestedResolver} placeholder="1.1.1.1" />
          <Row>
            {plainProfiles.map((profile) => (
              <Pill
                key={profile.id}
                label={profile.name}
                selected={profileId === profile.id}
                onPress={() => {
                  setProfileId(profile.id);
                  setTestedResolver(profileServers(profile)[0] ?? '');
                }}
                tone={profile.tags?.includes('custom') ? 'amber' : 'neutral'}
              />
            ))}
          </Row>
        </Section>

        <Section title={t('policy.protected.title')} subtitle={t('policy.protected.subtitle')}>
          <ToggleRow label={t('benchmark.toggle.vpn')} value={vpnActive} onValueChange={setVpnActive} />
          <ToggleRow label={t('benchmark.toggle.mdm')} value={mdmProfileActive} onValueChange={setMdmProfileActive} />
          <ToggleRow label={t('benchmark.toggle.corporateDns')} value={corporateDnsDetected} onValueChange={setCorporateDnsDetected} />
          <ToggleRow label={t('benchmark.toggle.captivePortal')} value={captivePortalDetected} onValueChange={setCaptivePortalDetected} />
          <Button label={t('policy.loadPayloads')} onPress={runPolicy} loading={working} />
        </Section>
      </AdaptiveColumns>

      <Section title={t('policy.nativeDns.title')} subtitle={t('policy.nativeDns.subtitle')}>
        {platform !== 'ios' ? (
          <EmptyState text={t('policy.nativeDns.iosOnly')} />
        ) : (
          <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 10, padding: 12 }}>
            <Row>
              <Metric label={t('policy.nativeDns.available')} value={nativeDnsStatus?.available ? t('common.yes') : t('common.no')} tone={nativeDnsStatus?.available ? 'green' : 'amber'} />
              <Metric label={t('policy.nativeDns.installed')} value={nativeDnsStatus?.installed ? t('common.yes') : t('common.no')} tone={nativeDnsStatus?.installed ? 'green' : 'neutral'} />
              <Metric label={t('policy.nativeDns.enabled')} value={nativeDnsStatus?.enabled ? t('common.yes') : t('common.no')} tone={nativeDnsStatus?.enabled ? 'green' : 'amber'} />
            </Row>
            {encryptedProfiles.length === 0 ? <EmptyState text={t('policy.nativeDns.empty')} /> : null}
            <Row>
              {encryptedProfiles.map((profile) => (
                <Pill key={profile.id} label={`${profile.name} (${profile.protocol.toUpperCase()})`} selected={iosProfileId === profile.id} onPress={() => setIosProfileId(profile.id)} tone="blue" />
              ))}
            </Row>
            {selectedIosProfile ? (
              <>
                <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>
                  {iosDnsPlan.canInstall ? t('policy.nativeDns.ready', { profile: selectedIosProfile.name }) : t(`policy.nativeDns.reason.${iosDnsPlan.reason}`)}
                </Text>
                <Row>
                  <Button label={t('policy.nativeDns.install')} onPress={installNativeDnsSettings} loading={nativeDnsWorking} disabled={!iosDnsPlan.canInstall} />
                  <Button label={t('policy.nativeDns.refresh')} onPress={refreshNativeDnsStatus} variant="secondary" loading={nativeDnsWorking} />
                  <Button label={t('policy.nativeDns.remove')} onPress={removeNativeDnsSettings} variant="danger" loading={nativeDnsWorking} disabled={!nativeDnsStatus?.installed} />
                </Row>
              </>
            ) : null}
            <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>{t('policy.nativeDns.enableHelp')}</Text>
            {nativeDnsStatus?.reason ? <ErrorBanner message={nativeDnsStatus.reason} /> : null}
          </View>
        )}
      </Section>

      <Section title={t('policy.guided.title')} subtitle={t('policy.guided.subtitle')}>
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
          </View>
        ) : (
          <EmptyState text={t('policy.guided.empty')} />
        )}
      </Section>

      <Section title={t('policy.payloads.title')} subtitle={t('policy.payloads.subtitle')}>
        {Object.keys(results).length === 0 ? <EmptyState text={t('policy.payloads.empty')} /> : null}
        {Object.entries(results).map(([name, result]) => (
          <View key={name} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
            <Text selectable style={{ color: palette.text, fontSize: 15, fontWeight: '800' }}>
              {name}
            </Text>
            <Text selectable style={{ color: palette.muted, fontSize: 12 }}>
              dnspilot-cli {result.args.join(' ')}
            </Text>
            <CodeBlock text={compactJson(result.data, 2600)} />
          </View>
        ))}
      </Section>
    </Screen>
  );
}

function errorMessage(value: unknown) {
  return value instanceof Error ? value.message : String(value ?? 'Native DNS Settings failed.');
}
