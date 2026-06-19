import React, { useEffect, useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { BridgeResult, compactJson, profileServers } from '@/src/api/dnspilot';
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
import { buildSettingsGuidance } from '@/src/view-models/settings-guidance';

type MobilePlatform = 'ios' | 'android-play';
type GateHealth = 'healthy' | 'degraded' | 'failed' | 'inconclusive';
type Confidence = 'high' | 'medium' | 'low' | 'inconclusive';

const platformOptions: { label: string; value: MobilePlatform }[] = [
  { label: 'iOS', value: 'ios' },
  { label: 'Android', value: 'android-play' },
];

const healthOptions: { label: string; value: GateHealth }[] = [
  { label: 'Healthy', value: 'healthy' },
  { label: 'Degraded', value: 'degraded' },
  { label: 'Failed', value: 'failed' },
  { label: 'Inconclusive', value: 'inconclusive' },
];

const confidenceOptions: { label: string; value: Confidence }[] = [
  { label: 'High', value: 'high' },
  { label: 'Medium', value: 'medium' },
  { label: 'Low', value: 'low' },
  { label: 'Inconclusive', value: 'inconclusive' },
];

export default function PolicyScreen() {
  const { profiles, capabilities, error, runAction } = useDNSPilot();
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
    ? buildSettingsGuidance({ platform, applyPlan: results.applyPlan.data })
    : null;

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
      <Section title="Policy" subtitle="Mobile store-safe apply guidance. Protected-network signals should suppress risky apply prompts.">
        <Segmented options={platformOptions} value={platform} onChange={setPlatform} />
        <Row>
          <Metric label="Apply" value={capability?.apply ?? 'unknown'} tone="blue" />
          <Metric label="Flush" value={capability?.flush ?? 'unknown'} tone="amber" />
          <Metric label="Store safe" value={capability?.store_safe ? 'yes' : 'no'} tone={capability?.store_safe ? 'green' : 'red'} />
        </Row>
        <ErrorBanner message={error} />
      </Section>

      <Section title="Recommendation Input" subtitle="Simulates the completed benchmark result passed into apply-plan.">
        <Segmented options={healthOptions} value={gateHealth} onChange={setGateHealth} />
        <Segmented options={confidenceOptions} value={confidence} onChange={setConfidence} />
        <TextField label="Tested resolver" value={testedResolver} onChangeText={setTestedResolver} placeholder="1.1.1.1" />
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

      <Section title="Protected Network Signals" subtitle="These flags should force protect-current-dns or remove apply prompts when needed.">
        <ToggleRow label="VPN active" value={vpnActive} onValueChange={setVpnActive} />
        <ToggleRow label="MDM profile active" value={mdmProfileActive} onValueChange={setMdmProfileActive} />
        <ToggleRow label="Corporate DNS detected" value={corporateDnsDetected} onValueChange={setCorporateDnsDetected} />
        <ToggleRow label="Captive portal detected" value={captivePortalDetected} onValueChange={setCaptivePortalDetected} />
        <Button label="Load policy payloads" onPress={runPolicy} loading={working} />
      </Section>

      <Section title="Guided Flow" subtitle="Capability-based OS flow. The app does not silently mutate system DNS.">
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
          </View>
        ) : (
          <EmptyState text="Load policy payloads to generate the OS guidance flow." />
        )}
      </Section>

      <Section title="Payloads" subtitle="Raw core/CLI JSON is selectable for issue reports.">
        {Object.keys(results).length === 0 ? <EmptyState text="No policy payload loaded yet." /> : null}
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
