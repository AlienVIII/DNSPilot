import React, { useEffect, useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { BridgeResult, compactJson, profileServers } from '@/src/api/dnspilot';
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
import { buildSettingsGuidance } from '@/src/view-models/settings-guidance';

type MobilePlatform = 'ios' | 'android-play';
type GateHealth = 'healthy' | 'degraded' | 'failed' | 'inconclusive';
type Confidence = 'high' | 'medium' | 'low' | 'inconclusive';

const platformOptions: { label: string; value: MobilePlatform }[] = [
  { label: 'iOS', value: 'ios' },
  { label: 'Android', value: 'android-play' },
];

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

  const plainProfiles = useMemo(() => profiles.filter((profile) => profile.protocol === 'plain'), [profiles]);
  const selectedProfile = plainProfiles.find((profile) => profile.id === profileId);
  const capability = capabilities.find((item) => item.platform === platform);
  const guidance = results.applyPlan
    ? buildSettingsGuidance({ platform, applyPlan: results.applyPlan.data, locale })
    : null;
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

  async function runPolicy() {
    setWorking(true);
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
