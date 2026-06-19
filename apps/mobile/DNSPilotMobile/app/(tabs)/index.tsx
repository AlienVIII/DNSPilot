import React, { useEffect, useState } from 'react';
import { Text, View } from 'react-native';

import { compactJson } from '@/src/api/dnspilot';
import { Button, CodeBlock, ErrorBanner, Metric, Row, Screen, Section, TextField, palette } from '@/src/components/ui';
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
        title="DNSPilot Mobile"
        subtitle="Expo shell for testing the Rust core and CLI contracts through a local bridge. No mobile DNS mutation is performed.">
        <TextField label="Bridge URL" value={urlDraft} onChangeText={setUrlDraft} placeholder="http://localhost:8787" />
        <Row>
          <Button
            label="Use URL"
            onPress={() => {
              setBridgeUrl(urlDraft.trim());
            }}
            variant="secondary"
          />
          <Button label="Refresh" onPress={() => refreshAll().catch(() => undefined)} loading={loading} />
          <Button label="Init DB" onPress={initializeStorage} variant="secondary" loading={working} />
        </Row>
        <ErrorBanner message={error} />
      </Section>

      <Section title="Status" subtitle={health?.dbPath ? `SQLite: ${health.dbPath}` : 'Start npm run bridge before testing.'}>
        <Row>
          <Metric label="Bridge" value={health?.ok ? 'up' : 'down'} tone={health?.ok ? 'green' : 'amber'} />
          <Metric label="Profiles" value={profiles.length} tone="blue" />
          <Metric label="Suites" value={suites.length} tone="green" />
          <Metric label="Capabilities" value={capabilities.length} tone="amber" />
          <Metric label="History" value={history.length} tone="neutral" />
        </Row>
      </Section>

      <Section title="Smoke Sample" subtitle="Uses dnspilot-cli recommend-sample, not mobile-side scoring.">
        <Button label="Run sample recommendation" onPress={loadSample} loading={working} />
        {sample ? <CodeBlock text={compactJson(sample, 2400)} /> : null}
      </Section>

      <Section title="Test Boundary" subtitle="This app is an Expo Go test shell. Release-grade direct Rust binding is a later native bridge task.">
        <View style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 6, padding: 12 }}>
          <Text selectable style={{ color: palette.text, fontSize: 14, fontWeight: '700' }}>
            Covered CLI surface
          </Text>
          <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
            Catalog, capabilities, preflight, apply policy, apply plan, benchmark, system benchmark, compare, path estimate, path compare, profile storage, suite storage, history, and sample recommendation.
          </Text>
        </View>
      </Section>
    </Screen>
  );
}
