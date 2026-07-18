import { Link, Stack } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { palette } from '@/src/components/ui';
import { useDNSPilot } from '@/src/state/dnspilot-context';

export default function NotFoundScreen() {
  const { t } = useDNSPilot();

  return (
    <>
      <Stack.Screen options={{ title: t('nav.notFound') }} />
      <View style={styles.container}>
        <Text selectable style={styles.title}>
          {t('nav.notFound.message')}
        </Text>

        <Link href="/" style={styles.link}>
          <Text style={styles.linkText}>{t('nav.notFound.openCheckDns')}</Text>
        </Link>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    backgroundColor: palette.background,
    justifyContent: 'center',
    padding: 20,
  },
  title: {
    color: palette.text,
    fontSize: 20,
    fontWeight: 'bold',
  },
  link: {
    marginTop: 15,
    paddingVertical: 15,
  },
  linkText: {
    fontSize: 14,
    color: palette.blue,
  },
});
