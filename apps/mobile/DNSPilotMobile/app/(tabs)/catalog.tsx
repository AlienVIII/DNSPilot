import React, { useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { isCustomProfile, isCustomSuite, profileServers } from '@/src/api/dnspilot';
import { Button, EmptyState, ErrorBanner, Metric, Pill, Row, Screen, Section, TextField, palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { compactList } from '@/src/utils/forms';

type Filter = 'all' | 'plain' | 'encrypted' | 'custom';

export default function CatalogScreen() {
  const { profiles, suites, capabilities, error, loading, refreshAll, t } = useDNSPilot();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const filterOptions = useMemo(
    () => [
      { label: t('catalog.filter.all'), value: 'all' as const },
      { label: t('catalog.filter.plain'), value: 'plain' as const },
      { label: t('catalog.filter.encrypted'), value: 'encrypted' as const },
      { label: t('catalog.filter.custom'), value: 'custom' as const },
    ],
    [t]
  );

  const visibleProfiles = useMemo(() => {
    const term = query.trim().toLowerCase();
    return profiles.filter((profile) => {
      const matchesTerm =
        term.length === 0 ||
        [profile.id, profile.name, profile.description, ...(profile.tags ?? [])].some((part) =>
          String(part ?? '').toLowerCase().includes(term)
        );
      const matchesFilter =
        filter === 'all' ||
        (filter === 'plain' && profile.protocol === 'plain') ||
        (filter === 'encrypted' && profile.protocol !== 'plain') ||
        (filter === 'custom' && isCustomProfile(profile));
      return matchesTerm && matchesFilter;
    });
  }, [filter, profiles, query]);

  return (
    <Screen>
      <Section title={t('catalog.title')} subtitle={t('catalog.subtitle')}>
        <TextField label={t('common.search')} value={query} onChangeText={setQuery} placeholder={t('catalog.placeholder')} />
        <Row>
          {filterOptions.map((option) => (
            <Pill key={option.value} label={option.label} selected={filter === option.value} onPress={() => setFilter(option.value)} />
          ))}
        </Row>
        <Row>
          <Metric label={t('overview.metric.profiles')} value={profiles.length} tone="blue" />
          <Metric label={t('overview.metric.suites')} value={suites.length} tone="green" />
          <Metric label={t('catalog.metric.mobilePlatforms')} value={capabilities.filter((item) => item.platform === 'ios' || item.platform === 'android-play').length} tone="amber" />
        </Row>
        <Button label={t('catalog.refresh')} onPress={() => refreshAll().catch(() => undefined)} loading={loading} />
        <ErrorBanner message={error} />
      </Section>

      <Section title={t('catalog.profiles.title')} subtitle={t('catalog.profiles.subtitle', { count: visibleProfiles.length })}>
        {visibleProfiles.length === 0 ? <EmptyState text={t('catalog.profiles.empty')} /> : null}
        {visibleProfiles.map((profile) => (
          <View key={profile.id} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'space-between' }}>
              <Text selectable style={{ color: palette.text, flexShrink: 1, fontSize: 16, fontWeight: '800' }}>
                {profile.name}
              </Text>
              <Pill label={profile.protocol} tone={profile.protocol === 'plain' ? 'blue' : 'amber'} />
            </View>
            <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
              {profile.description}
            </Text>
            <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
              {t('catalog.profile.meta', {
                id: profile.id,
                filtering: profile.filtering_type ?? t('common.none'),
                servers: compactList(profileServers(profile)),
              })}
            </Text>
            <Row>
              {(profile.tags ?? []).map((tag) => (
                <Pill key={tag} label={tag === 'custom' ? t('common.custom') : tag} tone={tag === 'custom' ? 'amber' : 'neutral'} />
              ))}
            </Row>
          </View>
        ))}
      </Section>

      <Section title={t('catalog.suites.title')} subtitle={t('catalog.suites.subtitle')}>
        {suites.length === 0 ? <EmptyState text={t('catalog.suites.empty')} /> : null}
        {suites.map((suite) => (
          <View key={suite.id} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'space-between' }}>
              <Text selectable style={{ color: palette.text, flexShrink: 1, fontSize: 16, fontWeight: '800' }}>
                {suite.name}
              </Text>
              {isCustomSuite(suite) ? <Pill label={t('common.custom')} tone="amber" /> : null}
            </View>
            <Text selectable style={{ color: palette.muted, fontSize: 13, lineHeight: 18 }}>
              {suite.description}
            </Text>
            <Text selectable style={{ color: palette.slate, fontSize: 12, lineHeight: 17 }}>
              {suite.domains.join(', ')}
            </Text>
          </View>
        ))}
      </Section>
    </Screen>
  );
}
