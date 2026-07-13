import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { Button, EmptyState, ErrorBanner, Row, Screen, Section, palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { buildHistoryRows } from '@/src/view-models/history-presentation';

export default function HistoryScreen() {
  const { history, profiles, error, refreshAll, runAction, t } = useDNSPilot();
  const [working, setWorking] = useState(false);
  const rows = useMemo(() => buildHistoryRows({ records: [...history].reverse(), profiles }), [history, profiles]);

  async function execute(action: 'historyClear' | 'historyDelete', payload: Record<string, unknown> = {}) {
    setWorking(true);
    try {
      await runAction(action, payload);
      await refreshAll();
    } finally {
      setWorking(false);
    }
  }

  return (
    <Screen>
      <Section title={t('tabs.history')} subtitle={t('storage.history.subtitle')}>
        <Row>
          <Button label={t('common.refresh')} onPress={() => refreshAll().catch(() => undefined)} variant="secondary" loading={working} />
          <Button label={t('storage.history.clear')} onPress={() => execute('historyClear')} variant="danger" loading={working} disabled={rows.length === 0} />
        </Row>
        <ErrorBanner message={error} />
        <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>{t('history.retestHelp')}</Text>
      </Section>

      {rows.length === 0 ? <EmptyState text={t('storage.history.empty')} /> : null}
      {rows.map((row) => (
        <View key={row.id} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
          <Text selectable style={{ color: palette.text, fontSize: 16, fontWeight: '800' }}>{row.title}</Text>
          <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>{row.domainSummary}</Text>
          <Text selectable style={{ color: palette.slate, fontSize: 13, lineHeight: 18 }}>
            {row.recommendation ? `${t('benchmark.recommendation')}: ${row.recommendation}` : t('check.result.none')}
          </Text>
          <Row>
            {row.requiresRetest ? <Button label={t('history.retestBeforeSetup')} onPress={() => router.navigate('/')} variant="secondary" /> : null}
            <Button label={t('storage.history.delete')} onPress={() => execute('historyDelete', { id: row.id })} variant="danger" loading={working} />
          </Row>
        </View>
      ))}
    </Screen>
  );
}
