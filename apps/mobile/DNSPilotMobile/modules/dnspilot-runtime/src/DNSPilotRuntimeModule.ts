import { requireOptionalNativeModule } from 'expo';

type NativeDNSPilotRuntimeModule = {
  isAvailable(): boolean;
  runAction(action: string, payloadJson: string): Promise<string>;
};

const nativeModule = requireOptionalNativeModule<NativeDNSPilotRuntimeModule>('DNSPilotRuntime');

export const DNSPilotRuntime = {
  isAvailable: () => nativeModule?.isAvailable() ?? false,
  async runAction<T>(action: string, payload: Record<string, unknown> = {}): Promise<T> {
    if (!nativeModule) {
      throw new Error('DNSPilot native runtime is unavailable in this build.');
    }
    return JSON.parse(await nativeModule.runAction(action, JSON.stringify(payload))) as T;
  },
};
