import { SymbolView } from 'expo-symbols';
import { Tabs } from 'expo-router';

import Colors from '@/constants/Colors';
import { useColorScheme } from '@/components/useColorScheme';
import { useClientOnlyValue } from '@/components/useClientOnlyValue';
import { TutorialHeaderButton } from '@/src/components/app-tutorial';
import { useDNSPilot } from '@/src/state/dnspilot-context';

const icons = {
  index: { ios: 'checkmark.circle', android: 'check_circle', web: 'check_circle' },
  profiles: { ios: 'slider.horizontal.3', android: 'tune', web: 'tune' },
  history: { ios: 'clock.arrow.circlepath', android: 'history', web: 'history' },
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
        headerRight: () => <TutorialHeaderButton />,
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: t('tabs.checkDns'),
          tabBarIcon: ({ color }) => <TabIcon name="index" color={String(color)} />,
        }}
      />
      <Tabs.Screen
        name="profiles"
        options={{
          title: t('tabs.profiles'),
          tabBarIcon: ({ color }) => <TabIcon name="profiles" color={String(color)} />,
        }}
      />
      <Tabs.Screen
        name="history"
        options={{
          title: t('tabs.history'),
          tabBarIcon: ({ color }) => <TabIcon name="history" color={String(color)} />,
        }}
      />
      <Tabs.Screen
        name="benchmark"
        options={{
          href: null,
        }}
      />
      <Tabs.Screen
        name="catalog"
        options={{
          href: null,
        }}
      />
      <Tabs.Screen
        name="storage"
        options={{
          href: null,
        }}
      />
      <Tabs.Screen
        name="policy"
        options={{
          href: null,
        }}
      />
    </Tabs>
  );
}
