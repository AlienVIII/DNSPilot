import assert from "node:assert/strict";
import { test } from "node:test";

import {
  createTranslator,
  languageOptions,
  resolveLocale,
  supportedLocales,
  translate,
  translateKnownError,
} from "./localization.js";

test("resolves Vietnamese from Expo locale objects when following system", () => {
  const locale = resolveLocale({
    preference: "system",
    deviceLocales: [{ languageTag: "vi-VN", languageCode: "vi" }],
  });

  assert.equal(locale, "vi");
});

test("manual language preference wins over device locale", () => {
  const locale = resolveLocale({
    preference: "en",
    deviceLocales: [{ languageTag: "vi-VN", languageCode: "vi" }],
  });

  assert.equal(locale, "en");
});

test("unsupported locale falls back to English", () => {
  const locale = resolveLocale({
    preference: "system",
    deviceLocales: [{ languageTag: "fr-FR", languageCode: "fr" }],
  });

  assert.equal(locale, "en");
});

test("translator falls back to English and interpolates values", () => {
  const t = createTranslator("vi");

  assert.equal(t("overview.title"), "DNSPilot Mobile");
  assert.equal(t("test.fallbackCount", { count: 3 }), "3 profiles");
  assert.equal(translate("vi", "missing.key"), "missing.key");
});

test("language options expose system, English, and Vietnamese", () => {
  assert.deepEqual(supportedLocales, ["en", "vi"]);
  assert.deepEqual(
    languageOptions.map((option) => option.value),
    ["system", "en", "vi"]
  );
});

test("known validation errors translate to Vietnamese and unknown errors remain intact", () => {
  assert.equal(
    translateKnownError("vi", "Select at least one DNS profile."),
    "Chọn ít nhất một DNS profile."
  );
  assert.equal(translateKnownError("vi", "Bridge offline."), "Bridge offline.");
});
