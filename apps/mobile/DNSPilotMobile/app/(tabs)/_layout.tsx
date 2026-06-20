import { SymbolView } from 'expo-symbols';
import { Tabs } from 'expo-router';

import Colors from '@/constants/Colors';
import { useColorScheme } from '@/components/useColorScheme';
import { useClientOnlyValue } from '@/components/useClientOnlyValue';
import { useDNSPilot } from '@/src/state/dnspilot-context';

const icons = {
  index: { ios: 'speedometer', android: 'speed', web: 'speed' },
  benchmark: { ios: 'chart.xyaxis.line', android: 'query_stats', web: 'query_stats' },
  catalog: { ios: 'list.bullet.rectangle', android: 'list', web: 'list' },
  storage: { ios: 'externaldrive', android: 'storage', web: 'storage' },
  policy: { ios: 'shield.lefthalf.filled', android: 'shield', web: 'shield' },
} as const;

function TabIcon({ name, color }: { name: keyof typeof icons; color: string }) {
  return <SymbolView name={icons[name]} tintColor={color} size={25} />;
}

export default function TabLayout() {
  const colorScheme = useColorScheme();
  const { t } = useDNSPilot();

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors[colorScheme].tint,
        tabBarInactiveTintColor: Colors[colorScheme].tabIconDefault,
        // Disable the static render of the header on web
        // to prevent a hydration error in React Navigation v6.
        headerShown: useClientOnlyValue(false, true),
        headerTitleStyle: { fontWeight: '700' },
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: t('tabs.overview'),
          tabBarIcon: ({ color }) => <TabIcon name="index" color={String(color)} />,
        }}
      />
      <Tabs.Screen
        name="benchmark"
        options={{
          title: t('tabs.benchmark'),
          tabBarIcon: ({ color }) => <TabIcon name="benchmark" color={String(color)} />,
        }}
      />
      <Tabs.Screen
        name="catalog"
        options={{
          title: t('tabs.catalog'),
          tabBarIcon: ({ color }) => <TabIcon name="catalog" color={String(color)} />,
        }}
      />
      <Tabs.Screen
        name="storage"
        options={{
          title: t('tabs.storage'),
          tabBarIcon: ({ color }) => <TabIcon name="storage" color={String(color)} />,
        }}
      />
      <Tabs.Screen
        name="policy"
        options={{
          title: t('tabs.policy'),
          tabBarIcon: ({ color }) => <TabIcon name="policy" color={String(color)} />,
        }}
      />
    </Tabs>
  );
}
