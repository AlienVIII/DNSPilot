import assert from "node:assert/strict";
import { test } from "node:test";

import { buildSettingsGuidance, guidanceActionStatus } from "./settings-guidance.js";

test("iOS guidance stays store-safe and profile/settings based", () => {
  const guidance = buildSettingsGuidance({
    platform: "ios",
    applyPlan: {
      platform: "ios",
      apply_capability: "apple-network-extension-dns-settings",
      disposition: "guide-only",
      profile_name: "Cloudflare",
      tested_resolver: "1.1.1.1",
      dns_servers: ["1.1.1.1", "1.0.0.1"],
      can_apply: false,
      notes: ["Store-safe build must guide plain DNS changes through OS settings."],
    },
  });

  assert.equal(guidance.mode, "guide");
  assert.match(guidance.title, /iOS/);
  assert.equal(guidance.canMutateSystemDns, false);
  assert.ok(guidance.steps.some((step) => step.includes("DNS Settings profile")));
  assert.ok(guidance.steps.some((step) => step.includes("1.1.1.1")));
  assert.deepEqual(
    guidance.actions.map((action) => action.kind),
    ["prepare-os-apply", "copy", "open-settings", "retest-system-dns"]
  );
  assert.equal(guidance.actions[0].value, "1.1.1.1, 1.0.0.1");
  assert.doesNotMatch(guidance.claims.join(" "), /fastest|speed improvement|silent/i);
  assert.doesNotMatch(JSON.stringify(guidance.actions), /silent|mutate|vpn/i);
});

test("Android guidance uses settings and avoids VpnService or silent mutation", () => {
  const guidance = buildSettingsGuidance({
    platform: "android-play",
    applyPlan: {
      platform: "android-play",
      apply_capability: "guided-settings",
      disposition: "guide-only",
      profile_name: "Cloudflare",
      tested_resolver: "1.1.1.1",
      dns_servers: ["1.1.1.1", "1.0.0.1"],
      can_apply: false,
      notes: ["Platform requires guided settings; do not perform hidden DNS changes."],
    },
  });

  assert.equal(guidance.mode, "guide");
  assert.match(guidance.title, /Android/);
  assert.equal(guidance.canMutateSystemDns, false);
  assert.ok(guidance.steps.some((step) => step.includes("Private DNS")));
  assert.deepEqual(
    guidance.actions.map((action) => action.kind),
    ["prepare-os-apply", "copy", "open-settings", "retest-system-dns"]
  );
  assert.equal(guidance.actions[0].target, "android-network-settings");
  assert.equal(guidance.actions[0].value, "1.1.1.1, 1.0.0.1");
  assert.doesNotMatch(guidance.steps.join(" "), /VpnService|silent/i);
});

test("iOS guidance exposes app settings and retest without pretending to mutate DNS", () => {
  const guidance = buildSettingsGuidance({
    platform: "ios",
    applyPlan: {
      platform: "ios",
      apply_capability: "apple-network-extension-dns-settings",
      disposition: "guide-only",
      profile_name: "Cloudflare",
      tested_resolver: "1.1.1.1",
      dns_servers: ["1.1.1.1", "1.0.0.1"],
      can_apply: false,
      notes: [],
    },
  });

  assert.deepEqual(
    guidance.actions.map((action) => action.kind),
    ["prepare-os-apply", "copy", "open-settings", "retest-system-dns"]
  );
  assert.equal(guidance.actions[0].target, "ios-app-settings");
  assert.equal(guidance.canMutateSystemDns, false);
  assert.doesNotMatch(JSON.stringify(guidance.actions), /silent|VpnService/i);
});

test("protected network guidance suppresses apply flow", () => {
  const guidance = buildSettingsGuidance({
    platform: "ios",
    applyPlan: {
      platform: "ios",
      apply_capability: "apple-network-extension-dns-settings",
      disposition: "protect-current-dns",
      profile_name: null,
      tested_resolver: "1.1.1.1",
      dns_servers: [],
      can_apply: false,
      notes: ["VPN is active; protect current DNS and avoid apply prompts."],
    },
  });

  assert.equal(guidance.mode, "protect");
  assert.equal(guidance.steps.length, 1);
  assert.match(guidance.steps[0], /Keep current DNS/);
  assert.deepEqual(guidance.actions, []);
  assert.equal(guidance.canMutateSystemDns, false);
});

test("Vietnamese iOS guidance localizes user-facing steps", () => {
  const guidance = buildSettingsGuidance({
    platform: "ios",
    locale: "vi",
    applyPlan: {
      platform: "ios",
      apply_capability: "apple-network-extension-dns-settings",
      disposition: "guide-only",
      profile_name: "Cloudflare",
      tested_resolver: "1.1.1.1",
      dns_servers: ["1.1.1.1", "1.0.0.1"],
      can_apply: false,
      notes: [],
    },
  });

  assert.match(guidance.title, /iOS\/iPadOS/);
  assert.ok(guidance.steps.some((step) => step.includes("profile DNS Settings")));
  assert.ok(guidance.steps.some((step) => step.includes("1.1.1.1")));
  assert.doesNotMatch(guidance.claims.join(" "), /silent|speed improvement|fastest/i);
});

test("guidance action status reports progress, success, and failure in the selected locale", () => {
  assert.equal(
    guidanceActionStatus({ actionKind: "retest-system-dns", phase: "running", locale: "en" }),
    "Retesting System DNS..."
  );
  assert.equal(
    guidanceActionStatus({ actionKind: "open-settings", phase: "success", locale: "en" }),
    "Settings opened."
  );
  assert.match(guidanceActionStatus({ actionKind: "copy", phase: "failed", locale: "en" }), /Action failed/);
  assert.match(guidanceActionStatus({ actionKind: "prepare-os-apply", phase: "failed", locale: "vi" }), /Thao tác thất bại/);
});
