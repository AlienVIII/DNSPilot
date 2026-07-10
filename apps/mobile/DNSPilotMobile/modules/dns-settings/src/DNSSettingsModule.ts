import { requireOptionalNativeModule } from 'expo';

export type DNSSettingsRequest = {
  description: string;
  protocol: 'doh' | 'dot';
  serverAddresses: string[];
  dohUrl?: string;
  dotHostname?: string;
};

export type DNSSettingsStatus = {
  available: boolean;
  installed: boolean;
  enabled: boolean;
  description?: string | null;
  protocol?: 'doh' | 'dot' | null;
  reason?: string;
};

type NativeDNSSettingsModule = {
  getStatus(): Promise<DNSSettingsStatus>;
  install(request: DNSSettingsRequest & { protocolName: DNSSettingsRequest['protocol'] }): Promise<DNSSettingsStatus>;
  remove(): Promise<DNSSettingsStatus>;
};

const nativeModule = requireOptionalNativeModule<NativeDNSSettingsModule>('DNSSettings');

const unavailable: DNSSettingsStatus = {
  available: false,
  installed: false,
  enabled: false,
  reason: 'This DNS Settings capability is available only in an entitled iOS build.',
};

export const DNSSettings = {
  getStatus: () => nativeModule?.getStatus() ?? Promise.resolve(unavailable),
  install: (request: DNSSettingsRequest) => nativeModule?.install({ ...request, protocolName: request.protocol }) ?? Promise.resolve(unavailable),
  remove: () => nativeModule?.remove() ?? Promise.resolve(unavailable),
};
