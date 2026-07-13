const languagePreferences = new Set(["system", "en", "vi"]);

export function normalizeAppPreferences(input = {}, defaults = {}) {
  const values = objectLike(input);
  const fallback = objectLike(defaults);
  const defaultBridgeUrl = safeText(fallback.bridgeUrl) || "http://localhost:8787";
  const defaultLanguagePreference = normalizeLanguage(fallback.languagePreference) ?? "system";
  const defaultTutorialCompletionVersion = normalizeTutorialCompletionVersion(fallback.tutorialCompletionVersion) ?? 0;
  const bridgeUrl = safeText(values.bridgeUrl) || defaultBridgeUrl;
  const languagePreference = normalizeLanguage(values.languagePreference) ?? defaultLanguagePreference;
  const tutorialCompletionVersion = normalizeTutorialCompletionVersion(values.tutorialCompletionVersion) ?? defaultTutorialCompletionVersion;

  return {
    bridgeUrl,
    languagePreference,
    tutorialCompletionVersion,
  };
}

export function deserializeAppPreferences(raw, defaults = {}) {
  try {
    return normalizeAppPreferences(JSON.parse(String(raw ?? "{}")), defaults);
  } catch {
    return normalizeAppPreferences({}, defaults);
  }
}

export function serializeAppPreferences(input = {}, defaults = {}) {
  return JSON.stringify(normalizeAppPreferences(input, defaults));
}

function objectLike(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function safeText(value) {
  return String(value ?? "").trim();
}

function normalizeLanguage(value) {
  const text = safeText(value);
  return languagePreferences.has(text) ? text : undefined;
}

function normalizeTutorialCompletionVersion(value) {
  const number = Number(value);
  return Number.isInteger(number) && number >= 0 ? number : undefined;
}
