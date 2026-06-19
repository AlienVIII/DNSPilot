import React, { useMemo, useState } from 'react';
import { Text, View } from 'react-native';

import { isCustomProfile, isCustomSuite, profileServers } from '@/src/api/dnspilot';
import { Button, EmptyState, ErrorBanner, Metric, Pill, Row, Screen, Section, TextField, palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';
import { compactList } from '@/src/utils/forms';

type Filter = 'all' | 'plain' | 'encrypted' | 'custom';

const filterOptions: { label: string; value: Filter }[] = [
  { label: 'All', value: 'all' },
  { label: 'Plain', value: 'plain' },
  { label: 'DoH/DoT', value: 'encrypted' },
  { label: 'Custom', value: 'custom' },
];

export default function CatalogScreen() {
  const { profiles, suites, capabilities, error, loading, refreshAll } = useDNSPilot();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');

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
      <Section title="Catalog" subtitle="Core-owned provider and suite contracts. Custom storage entries are merged by the CLI.">
        <TextField label="Search" value={query} onChangeText={setQuery} placeholder="cloudflare, family, vietnam" />
        <Row>
          {filterOptions.map((option) => (
            <Pill key={option.value} label={option.label} selected={filter === option.value} onPress={() => setFilter(option.value)} />
          ))}
        </Row>
        <Row>
          <Metric label="Profiles" value={profiles.length} tone="blue" />
          <Metric label="Suites" value={suites.length} tone="green" />
          <Metric label="Mobile platforms" value={capabilities.filter((item) => item.platform === 'ios' || item.platform === 'android-play').length} tone="amber" />
        </Row>
        <Button label="Refresh catalog" onPress={() => refreshAll().catch(() => undefined)} loading={loading} />
        <ErrorBanner message={error} />
      </Section>

      <Section title="Profiles" subtitle={`${visibleProfiles.length} matching profiles`}>
        {visibleProfiles.length === 0 ? <EmptyState text="No profiles match the current filter." /> : null}
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
              ID: {profile.id} | Filtering: {profile.filtering_type ?? 'none'} | Servers: {compactList(profileServers(profile))}
            </Text>
            <Row>
              {(profile.tags ?? []).map((tag) => (
                <Pill key={tag} label={tag} tone={tag === 'custom' ? 'amber' : 'neutral'} />
              ))}
            </Row>
          </View>
        ))}
      </Section>

      <Section title="Test Suites" subtitle="Built-in and custom domain groups used by benchmark commands.">
        {suites.length === 0 ? <EmptyState text="No suites loaded." /> : null}
        {suites.map((suite) => (
          <View key={suite.id} style={{ backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 8, borderWidth: 1, gap: 8, padding: 12 }}>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'space-between' }}>
              <Text selectable style={{ color: palette.text, flexShrink: 1, fontSize: 16, fontWeight: '800' }}>
                {suite.name}
              </Text>
              {isCustomSuite(suite) ? <Pill label="custom" tone="amber" /> : null}
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
