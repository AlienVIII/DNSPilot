import assert from "node:assert/strict";
import { test } from "node:test";

import { buildCheckEntryState, buildQuickCheck, quickCheckPresets } from "./consumer-check.js";

const profiles = [
  { id: "cloudflare", protocol: "plain" },
  { id: "google-public-dns", protocol: "plain" },
  { id: "quad9", protocol: "plain" },
  { id: "dns-over-https", protocol: "doh" },
];

const suites = [
  { id: "general", name: "General", domains: ["example.com"], tags: ["general"] },
  { id: "vietnam-daily", name: "Vietnam", domains: ["vnexpress.net"], tags: ["vietnam"] },
  { id: "gaming-dota2-sea", name: "Dota 2 SEA", domains: ["dota2.com"], tags: ["gaming", "dota2"] },
];

test("quick check defaults to DNS-only General with preferred plain resolvers", () => {
  const check = buildQuickCheck({ profiles, suites, platform: "ios" });

  assert.equal(check.mode, "compare");
  assert.equal(check.suiteId, "general");
  assert.deepEqual(check.selectedProfiles, ["cloudflare", "google-public-dns", "quad9"]);
  assert.equal(check.tlsEnabled, false);
  assert.equal(check.benchmarkPlatform, "ios");
  assert.equal(check.saveHistory, true);
});

test("quick check uses the selected supported preset", () => {
  const check = buildQuickCheck({ profiles, suites, platform: "android-play", presetID: "gaming-dota2-sea" });

  assert.equal(check.suiteId, "gaming-dota2-sea");
  assert.equal(check.benchmarkPlatform, "android-play");
});

test("quick check falls back to available plain resolvers and General when a preset is unavailable", () => {
  const check = buildQuickCheck({
    profiles: [{ id: "custom", protocol: "plain" }, { id: "encrypted", protocol: "dot" }],
    suites: [{ id: "general-browsing", name: "General", domains: ["example.com"], tags: ["default"] }],
    presetID: "gaming-dota2-sea",
  });

  assert.deepEqual(check.selectedProfiles, ["custom"]);
  assert.equal(check.suiteId, "general-browsing");
});

test("quick check exposes only catalog-supported consumer presets", () => {
  assert.deepEqual(
    quickCheckPresets(suites).map((preset) => preset.id),
    ["general", "vietnam-daily", "gaming-dota2-sea"]
  );
});

test("native Check DNS entry does not show a system settings sheet before user requests setup", () => {
  assert.deepEqual(buildCheckEntryState({ nativeRuntime: true }), {
    showsSystemAccessSheet: false,
    showsBridgeConfiguration: false,
  });
});
