import * as IntentLauncher from 'expo-intent-launcher';
import * as Linking from 'expo-linking';
import { Platform } from 'react-native';

export type NativeSettingsTarget =
  | 'ios-app-settings'
  | 'android-app-settings'
  | 'android-network-settings'
  | 'android-private-dns';

export async function openNativeSettings(target: NativeSettingsTarget) {
  if (Platform.OS !== 'android') {
    await Linking.openSettings();
    return;
  }

  if (target === 'android-private-dns') {
    try {
      await IntentLauncher.startActivityAsync('android.settings.PRIVATE_DNS_SETTINGS');
      return;
    } catch {
      await IntentLauncher.startActivityAsync(IntentLauncher.ActivityAction.WIRELESS_SETTINGS);
      return;
    }
  }

  if (target === 'android-network-settings') {
    try {
      await IntentLauncher.startActivityAsync(IntentLauncher.ActivityAction.WIRELESS_SETTINGS);
      return;
    } catch {
      await IntentLauncher.startActivityAsync(IntentLauncher.ActivityAction.SETTINGS);
      return;
    }
  }

  await Linking.openSettings();
}
