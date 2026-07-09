const languagePreferences = new Set(["system", "en", "vi"]);

export function normalizeAppPreferences(input = {}, defaults = {}) {
  const values = objectLike(input);
  const fallback = objectLike(defaults);
  const defaultBridgeUrl = safeText(fallback.bridgeUrl) || "http://localhost:8787";
  const defaultLanguagePreference = normalizeLanguage(fallback.languagePreference) ?? "system";
  const bridgeUrl = safeText(values.bridgeUrl) || defaultBridgeUrl;
  const languagePreference = normalizeLanguage(values.languagePreference) ?? defaultLanguagePreference;

  return {
    bridgeUrl,
    languagePreference,
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
