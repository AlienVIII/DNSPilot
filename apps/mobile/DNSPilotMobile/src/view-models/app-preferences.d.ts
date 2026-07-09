import type { LanguagePreference } from './localization';

export type AppPreferences = {
  bridgeUrl: string;
  languagePreference: LanguagePreference;
};

export function normalizeAppPreferences(input?: Partial<AppPreferences>, defaults?: AppPreferences): AppPreferences;
export function deserializeAppPreferences(raw: string | null | undefined, defaults?: AppPreferences): AppPreferences;
export function serializeAppPreferences(input?: Partial<AppPreferences>, defaults?: AppPreferences): string;
