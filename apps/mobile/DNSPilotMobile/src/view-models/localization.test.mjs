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

test("primary option labels are localized for Vietnamese real-device checks", () => {
  const t = createTranslator("vi");

  assert.equal(t("benchmark.mode.pathCompare"), "DNS + TCP");
  assert.equal(t("benchmark.mode.systemBenchmark"), "DNS hệ thống");
  assert.equal(t("benchmark.family.ipv4Only"), "Chỉ A");
  assert.equal(t("platform.android"), "Android");
  assert.equal(t("storage.filtering.family"), "Gia đình");
});

test("consumer navigation and quick-check labels are localized", () => {
  const t = createTranslator("vi");

  assert.equal(t("tabs.checkDns"), "Kiểm tra DNS");
  assert.equal(t("tabs.profiles"), "Profile");
  assert.equal(t("check.runQuick"), "Kiểm tra nhanh");
  assert.equal(t("nav.notFound.openCheckDns"), "Mở Kiểm tra DNS");
});
