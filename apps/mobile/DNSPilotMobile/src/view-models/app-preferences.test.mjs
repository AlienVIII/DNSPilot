import assert from "node:assert/strict";
import test from "node:test";

import {
  deserializeAppPreferences,
  normalizeAppPreferences,
  serializeAppPreferences,
} from "./app-preferences.js";

test("app preferences preserve bridge URL and manual language", () => {
  const preferences = normalizeAppPreferences(
    {
      bridgeUrl: " http://192.168.1.20:8787 ",
      languagePreference: "vi",
    },
    {
      bridgeUrl: "http://localhost:8787",
      languagePreference: "system",
    }
  );

  assert.deepEqual(preferences, {
    bridgeUrl: "http://192.168.1.20:8787",
    languagePreference: "vi",
  });
});

test("app preferences reject invalid values and keep safe defaults", () => {
  const preferences = normalizeAppPreferences(
    {
      bridgeUrl: "   ",
      languagePreference: "fr",
    },
    {
      bridgeUrl: "http://localhost:8787",
      languagePreference: "system",
    }
  );

  assert.deepEqual(preferences, {
    bridgeUrl: "http://localhost:8787",
    languagePreference: "system",
  });
});

test("app preferences normalize non-object input without throwing", () => {
  const preferences = normalizeAppPreferences(null, {
    bridgeUrl: "http://192.168.1.12:8787",
    languagePreference: "en",
  });

  assert.deepEqual(preferences, {
    bridgeUrl: "http://192.168.1.12:8787",
    languagePreference: "en",
  });
});

test("app preferences deserialize corrupted storage without throwing", () => {
  const preferences = deserializeAppPreferences("{bad json", {
    bridgeUrl: "http://localhost:8787",
    languagePreference: "en",
  });

  assert.deepEqual(preferences, {
    bridgeUrl: "http://localhost:8787",
    languagePreference: "en",
  });
});

test("app preferences deserialize non-object storage without throwing", () => {
  const preferences = deserializeAppPreferences("null", {
    bridgeUrl: "http://192.168.1.10:8787",
    languagePreference: "vi",
  });

  assert.deepEqual(preferences, {
    bridgeUrl: "http://192.168.1.10:8787",
    languagePreference: "vi",
  });
});

test("app preferences serialize only supported persisted fields", () => {
  const serialized = serializeAppPreferences({
    bridgeUrl: "http://10.0.2.2:8787",
    languagePreference: "en",
    ignored: true,
  });

  assert.equal(serialized, '{"bridgeUrl":"http://10.0.2.2:8787","languagePreference":"en"}');
});

test("app preferences serialize with supplied defaults", () => {
  const serialized = serializeAppPreferences(
    {
      bridgeUrl: "",
      languagePreference: "fr",
    },
    {
      bridgeUrl: "http://192.168.1.20:8787",
      languagePreference: "vi",
    }
  );

  assert.equal(serialized, '{"bridgeUrl":"http://192.168.1.20:8787","languagePreference":"vi"}');
});
