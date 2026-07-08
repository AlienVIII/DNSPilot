import React, { useEffect, useMemo, useState } from 'react';
import { Modal, Text, View } from 'react-native';

import { compactJson } from '@/src/api/dnspilot';
import { AdaptiveColumns, Button, CodeBlock, ErrorBanner, HelpButton, Metric, Pill, Row, Screen, Section, Segmented, TextField, palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { openNativeSettings } from '@/src/utils/native-settings';
import { buildDeviceSetupPlan, deviceTargets, normalizeBridgeUrl, type DeviceTarget, type DeviceSetupStatus } from '@/src/view-models/device-setup';
import type { Translator } from '@/src/view-models/localization';
import { buildSystemAccessPrompt, type SystemAccessAction, type SystemAccessPrompt, type SystemAccessStatus } from '@/src/view-models/system-access';

const defaultDeviceTarget = process.env.EXPO_OS === 'android' ? 'android-device' : process.env.EXPO_OS === 'web' ? 'web' : 'ios-device';

export default function OverviewScreen() {
  const {
    bridgeUrl,
    setBridgeUrl,
    health,
    profiles,
    suites,
    capabilities,
    history,
    loading,
    error,
    refreshAll,
    runAction,
    languagePreference,
    setLanguagePreference,
    languageOptions,
    locale,
    t,
  } = useDNSPilot();
  const [urlDraft, setUrlDraft] = useState(bridgeUrl);
  const [deviceTarget, setDeviceTarget] = useState<DeviceTarget>(defaultDeviceTarget);
  const [systemPromptVisible, setSystemPromptVisible] = useState(true);
  const [systemActionStatus, setSystemActionStatus] = useState<string | null>(null);
  const [systemActionWorking, setSystemActionWorking] = useState(false);
  const [sample, setSample] = useState<unknown>(null);
  const [working, setWorking] = useState(false);
  const normalizedBridgeUrl = normalizeBridgeUrl(urlDraft);
  const deviceSetupPlan = useMemo(
    () =>
      buildDeviceSetupPlan({
        target: deviceTarget,
        bridgeUrl: urlDraft,
        health,
      }),
    [deviceTarget, health, urlDraft]
  );
  const systemAccessPrompt = useMemo(
    () =>
      buildSystemAccessPrompt({
        platform: deviceTarget,
        bridgeStatus: health?.ok ? 'success' : error ? 'failed' : 'unknown',
        locale,
      }),
    [deviceTarget, error, health?.ok, locale]
  );
  const targetOptions = useMemo(
    () =>
      deviceTargets.map((target) => ({
        value: target.value,
        label: t(`device.target.${target.value}`),
      })),
    [t]
  );

  useEffect(() => {
    refreshAll().catch(() => undefined);
  }, [refreshAll]);

  async function initializeStorage() {
    setWorking(true);
    try {
      await runAction('storageSmoke');
      await refreshAll();
    } finally {
      setWorking(false);
    }
  }

  async function loadSample() {
    setWorking(true);
    try {
      const result = await runAction('recommendSample');
      setSample(result.data);
    } finally {
      setWorking(false);
    }
  }

  async function runSystemAccessAction(action: SystemAccessAction) {
    if (action.kind === 'open-settings') {
      try {
        await openNativeSettings(action.target);
        setSystemActionStatus(t('systemAccess.settings.opened'));
      } catch {
        setSystemActionStatus(t('systemAccess.settings.failed'));
      }
      return;
    }

    if (systemActionWorking) {
      return;
    }
    setSystemActionWorking(true);
    setSystemActionStatus(t('systemAccess.retest.running'));
    try {
      await runAction('systemBenchmark', {
        domains: ['cloudflare.com', 'google.com'],
        attempts: 1,
        ipFamily: 'both',
        timeoutMs: 800,
        dnsTimeoutMs: 800,
        platform: systemBenchmarkPlatformForTarget(deviceTarget),
        saveHistory: false,
      });
      setSystemActionStatus(t('systemAccess.retest.done'));
    } catch {
      setSystemActionStatus(t('systemAccess.retest.failed'));
    } finally {
      setSystemActionWorking(false);
    }
  }

  return (
    <Screen>
      <SystemAccessModal
        visible={systemPromptVisible && systemAccessPrompt.shouldPrompt}
        prompt={systemAccessPrompt}
        status={systemActionStatus}
        t={t}
        working={systemActionWorking}
        onClose={() => setSystemPromptVisible(false)}
        onAction={runSystemAccessAction}
      />
      <Section
        title={t('overview.title')}
        subtitle={t('overview.subtitle')}
        action={<HelpButton label={t('tutorial.openA11y')} onPress={() => setSystemPromptVisible(true)} />}>
        <Section title={t('language.title')} subtitle={t('language.subtitle')}>
          <Row>
            {languageOptions.map((option) => (
              <Button
                key={option.value}
                label={option.value === 'system' ? t('language.auto') : option.label}
                onPress={() => setLanguagePreference(option.value)}
                variant={languagePreference === option.value ? 'primary' : 'secondary'}
              />
            ))}
          </Row>
        </Section>
        <TextField label={t('overview.bridgeUrl')} value={urlDraft} onChangeText={setUrlDraft} placeholder="http://localhost:8787" />
        <Section title={t('device.title')} subtitle={t('device.subtitle')}>
          <Segmented options={targetOptions} value={deviceTarget} onChange={setDeviceTarget} />
          <Row>
            <SetupStatusCard
              title={t('device.metric.bridge')}
              status={deviceSetupPlan.bridge.status}
              statusLabel={t(`status.${deviceSetupPlan.bridge.status}`)}
              text={t(`device.code.${deviceSetupPlan.bridge.code}`)}
            />
            <SetupStatusCard
              title={t('device.metric.permission')}
              status={deviceSetupPlan.permission.status}
              statusLabel={t(`status.${deviceSetupPlan.permission.status}`)}
              text={t(`device.code.${deviceSetupPlan.permission.code}`)}
            />
            <SetupStatusCard title={t('device.metric.policy')} status="success" statusLabel={t('status.success')} text={t('device.policy.noMutation')} />
          </Row>
          <Row>
            {normalizedBridgeUrl && normalizedBridgeUrl !== urlDraft.trim() ? (
              <Button label={t('device.useNormalized')} onPress={() => setUrlDraft(normalizedBridgeUrl)} variant="secondary" />
            ) : null}
            {deviceSetupPlan.recommendedPreset === 'android-emulator' ? (
              <Button label={t('device.useAndroidEmulator')} onPress={() => setUrlDraft('http://10.0.2.2:8787')} variant="secondary" />
            ) : null}
          </Row>
        </Section>
        <Row>
          <Button
            label={t('overview.useUrl')}
            onPress={() => {
              setBridgeUrl(urlDraft.trim());
            }}
            variant="secondary"
          />
          <Button label={t('common.refresh')} onPress={() => refreshAll().catch(() => undefined)} loading={loading} />
          <Button label={t('overview.initDb')} onPress={initializeStorage} variant="secondary" loading={working} />
        </Row>
        <ErrorBanner message={error} />
      </Section>

      <AdaptiveColumns>
        <Section
          title={t('overview.status.title')}
          subtitle={health?.dbPath ? t('overview.status.subtitleReady', { path: health.dbPath }) : t('overview.status.subtitleMissing')}>
          <Row>
            <Metric label={t('overview.metric.bridge')} value={health?.ok ? t('common.up') : t('common.down')} tone={health?.ok ? 'green' : 'amber'} />
            <Metric label={t('overview.metric.profiles')} value={profiles.length} tone="blue" />
            <Metric label={t('overview.metric.suites')} value={suites.length} tone="green" />
            <Metric label={t('overview.metric.capabilities')} value={capabilities.length} tone="amber" />
            <Metric label={t('overview.metric.history')} value={history.length} tone="neutral" />
          </Row>
        </Section>

        <Section title={t('overview.smoke.title')} subtitle={t('overview.smoke.subtitle')}>
          <Button label={t('overview.smoke.run')} onPress={loadSample} loading={working} />
          {sample ? <CodeBlock text={compactJson(sample, 2400)} /> : null}
        </Section>
      </AdaptiveColumns>

      <Section title={t('overview.boundary.title')} subtitle={t('overview.boundary.subtitle')}>
        <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 6, padding: 12 }}>
          <Text selectable style={{ color: palette.text, fontSize: 14, fontWeight: '700' }}>
            {t('overview.boundary.coveredTitle')}
          </Text>
          <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
            {t('overview.boundary.coveredBody')}
          </Text>
        </View>
      </Section>

      <Section title={t('overview.native.title')} subtitle={t('overview.native.subtitle')}>
        <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
          <Text selectable style={{ color: palette.text, fontSize: 14, fontWeight: '800' }}>
            iOS/iPadOS
          </Text>
          <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
            {t('overview.native.ios')}
          </Text>
          <Text selectable style={{ color: palette.text, fontSize: 14, fontWeight: '800' }}>
            Android
          </Text>
          <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
            {t('overview.native.android')}
          </Text>
        </View>
      </Section>
    </Screen>
  );
}

function statusTone(status: DeviceSetupStatus) {
  if (status === 'success') return 'green';
  if (status === 'failed') return 'red';
  if (status === 'running') return 'amber';
  return 'neutral';
}

function systemAccessTone(status: SystemAccessStatus) {
  if (status === 'ready') return 'green';
  if (status === 'unsupported') return 'red';
  if (status === 'needs-action' || status === 'os-gated') return 'amber';
  return 'neutral';
}

function systemBenchmarkPlatformForTarget(target: DeviceTarget) {
  return target === 'android-device' || target === 'android-emulator' ? 'android-play' : 'ios';
}

function SetupStatusCard({ title, status, statusLabel, text }: { title: string; status: DeviceSetupStatus; statusLabel: string; text: string }) {
  return (
    <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, flexGrow: 1, gap: 8, minWidth: 220, padding: 12 }}>
      <View style={{ alignItems: 'center', flexDirection: 'row', gap: 8, justifyContent: 'space-between' }}>
        <Text selectable style={{ color: palette.text, flex: 1, fontSize: 14, fontWeight: '800' }}>
          {title}
        </Text>
        <Pill label={statusLabel} tone={statusTone(status)} />
      </View>
      <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>
        {text}
      </Text>
    </View>
  );
}

function SystemAccessModal({
  visible,
  prompt,
  status,
  t,
  working,
  onClose,
  onAction,
}: {
  visible: boolean;
  prompt: SystemAccessPrompt;
  status?: string | null;
  t: Translator;
  working: boolean;
  onClose: () => void;
  onAction: (action: SystemAccessAction) => void;
}) {
  const [expandedCheckID, setExpandedCheckID] = useState<string | null>(null);

  return (
    <Modal animationType="slide" transparent visible={visible} onRequestClose={onClose}>
      <View style={{ backgroundColor: 'rgba(15, 23, 42, 0.42)', flex: 1, justifyContent: 'flex-end' }}>
        <View style={{ backgroundColor: palette.background, borderTopLeftRadius: 8, borderTopRightRadius: 8, gap: 14, padding: 16 }}>
          <View style={{ gap: 4 }}>
            <Text selectable style={{ color: palette.text, fontSize: 22, fontWeight: '800' }}>
              {prompt.title}
            </Text>
            <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
              {prompt.summary}
            </Text>
          </View>
          <View style={{ gap: 8 }}>
            {prompt.checks.map((check) => {
              const expanded = expandedCheckID === check.id;
              return (
                <View key={check.id} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 6, padding: 12 }}>
                  <View style={{ alignItems: 'center', flexDirection: 'row', gap: 8, justifyContent: 'space-between' }}>
                    <Text selectable style={{ color: palette.text, flex: 1, fontSize: 14, fontWeight: '800' }}>
                      {check.label}
                    </Text>
                    <Pill label={t(`systemAccess.status.${check.status}`)} tone={systemAccessTone(check.status)} />
                    <HelpButton label={t('common.moreInfo')} onPress={() => setExpandedCheckID(expanded ? null : check.id)} />
                  </View>
                  {expanded ? (
                    <Text selectable style={{ color: palette.muted, fontSize: 12, lineHeight: 17 }}>
                      {check.detail}
                    </Text>
                  ) : null}
                </View>
              );
            })}
          </View>
          {status ? (
            <View style={{ backgroundColor: palette.blueSoft, borderColor: '#bfdbfe', borderRadius: 8, borderWidth: 1, padding: 10 }}>
              <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
                {status}
              </Text>
            </View>
          ) : null}
          <Row>
            {prompt.actions.map((action) => (
              <Button
                key={action.id}
                label={action.label}
                onPress={() => onAction(action)}
                variant="secondary"
                disabled={working && action.kind !== 'retest-system-dns'}
                loading={working && action.kind === 'retest-system-dns'}
              />
            ))}
            <Button label={t('common.continue')} onPress={onClose} />
          </Row>
        </View>
      </View>
    </Modal>
  );
}
