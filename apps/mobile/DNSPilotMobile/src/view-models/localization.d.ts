export type SupportedLocale = 'en' | 'vi';
export type LanguagePreference = 'system' | SupportedLocale;

export type DeviceLocale = {
  languageTag?: string | null;
  languageCode?: string | null;
};

export type Translator = (key: string, params?: Record<string, string | number | boolean | null | undefined>) => string;

export const defaultLocale: SupportedLocale;
export const supportedLocales: readonly SupportedLocale[];
export const languageOptions: readonly { label: string; value: LanguagePreference }[];

export function resolveLocale(input?: {
  preference?: LanguagePreference | string;
  deviceLocales?: DeviceLocale[];
}): SupportedLocale;

export function createTranslator(locale: SupportedLocale | string): Translator;

export function translate(
  locale: SupportedLocale | string,
  key: string,
  params?: Record<string, string | number | boolean | null | undefined>
): string;

export function translateKnownError(locale: SupportedLocale | string, message: string): string;
