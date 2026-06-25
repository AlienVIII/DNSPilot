export type DeviceTarget = 'ios-device' | 'android-device' | 'ios-simulator' | 'android-emulator' | 'web';
export type DeviceSetupStatus = 'idle' | 'running' | 'success' | 'failed';
export type RecommendedPreset = 'current' | 'localhost' | 'mac-lan' | 'android-emulator';

export type DeviceSetupPlan = {
  target: DeviceTarget;
  bridgeUrl: string;
  bridge: {
    status: DeviceSetupStatus;
    code:
      | 'bridge-url-missing'
      | 'localhost-not-device-reachable'
      | 'android-emulator-needs-10-0-2-2'
      | 'device-needs-private-lan'
      | 'bridge-ready'
      | 'bridge-not-verified';
  };
  recommendedPreset: RecommendedPreset;
  permission: {
    status: DeviceSetupStatus;
    code: 'ios-local-network' | 'android-normal-network' | 'web-browser-network';
    runtimePromptExpected: boolean;
  };
  policy: {
    canMutateSystemDns: false;
    usesVpnService: false;
    canClaimSpeedImprovement: false;
    mode: 'guided-settings';
  };
  realDevice: boolean;
};

export const deviceTargets: readonly { label: string; value: DeviceTarget }[];

export function normalizeBridgeUrl(value: string): string;

export function buildDeviceSetupPlan(input?: {
  target?: DeviceTarget;
  bridgeUrl?: string;
  health?: { ok?: boolean } | null;
}): DeviceSetupPlan;
