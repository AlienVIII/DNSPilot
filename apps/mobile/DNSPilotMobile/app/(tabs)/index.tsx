import React, { useEffect, useState } from 'react';
import { Text, View } from 'react-native';

import { compactJson } from '@/src/api/dnspilot';
import { AdaptiveColumns, Button, CodeBlock, ErrorBanner, Metric, Row, Screen, Section, TextField, palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';

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
    t,
  } = useDNSPilot();
  const [urlDraft, setUrlDraft] = useState(bridgeUrl);
  const [sample, setSample] = useState<unknown>(null);
  const [working, setWorking] = useState(false);

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

  return (
    <Screen>
      <Section
        title={t('overview.title')}
        subtitle={t('overview.subtitle')}>
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
