import assert from "node:assert/strict";
import { test } from "node:test";

import { buildBenchmarkPlan, suggestedSuites } from "./benchmark-plan.js";

const suites = [
  { id: "general-browsing", name: "General Browsing", domains: ["google.com", "youtube.com"], tags: ["default"] },
  { id: "vietnam-daily", name: "Vietnam / Daily", domains: ["vnexpress.net", "shopee.vn"], tags: ["vietnam", "daily"] },
];

test("benchmark plan validates compare payload before bridge call", () => {
  const empty = buildBenchmarkPlan({
    mode: "compare",
    selectedProfiles: [],
    suites,
    suiteId: "",
    domains: "",
    attempts: "",
    timeoutMs: "0",
    connectTimeoutMs: "1000",
    maxTargets: "4",
  });

  assert.equal(empty.canRun, false);
  assert.match(empty.errors.join(" "), /profile/);
  assert.match(empty.errors.join(" "), /domain/);
  assert.match(empty.errors.join(" "), /Attempts/);
  assert.match(empty.errors.join(" "), /DNS timeout/);

  const valid = buildBenchmarkPlan({
    mode: "compare",
    selectedProfiles: ["cloudflare", "quad9"],
    suites,
    suiteId: "vietnam-daily",
    domains: "expo.dev",
    attempts: "2",
    ipFamily: "ipv4-only",
    timeoutMs: "900",
    connectTimeoutMs: "1000",
    maxTargets: "4",
    saveHistory: true,
  });

  assert.equal(valid.canRun, true);
  assert.equal(valid.domainCount, 3);
  assert.equal(valid.historyEnabled, true);
  assert.deepEqual(valid.payload, {
    profileIds: ["cloudflare", "quad9"],
    profileId: "cloudflare",
    suiteId: "vietnam-daily",
    domains: ["expo.dev"],
    attempts: 2,
    ipFamily: "ipv4-only",
    timeoutMs: 900,
    dnsTimeoutMs: 900,
    connectTimeoutMs: 1000,
    maxConnectTargetsPerDomain: 4,
    tlsHandshakeTimeoutMs: undefined,
    platform: "ios",
    saveHistory: true,
  });
});

test("benchmark plan allows system DNS validation without selected profiles", () => {
  const plan = buildBenchmarkPlan({
    mode: "systemBenchmark",
    selectedProfiles: [],
    suites,
    suiteId: "general-browsing",
    domains: "",
    attempts: "1",
    ipFamily: "both",
    timeoutMs: "800",
    connectTimeoutMs: "1000",
    maxTargets: "4",
    benchmarkPlatform: "android-play",
    saveHistory: true,
  });

  assert.equal(plan.canRun, true);
  assert.equal(plan.selectedCount, "system");
  assert.equal(plan.domainCount, 2);
  assert.equal(plan.historyEnabled, false);
  assert.equal(plan.payload.platform, "android-play");
  assert.equal(plan.payload.saveHistory, false);
});

test("benchmark plan validates DNS plus TCP settings", () => {
  const invalid = buildBenchmarkPlan({
    mode: "pathCompare",
    selectedProfiles: ["cloudflare"],
    suites,
    suiteId: "general-browsing",
    domains: "",
    attempts: "1",
    timeoutMs: "800",
    connectTimeoutMs: "0",
    maxTargets: "0",
  });

  assert.equal(invalid.canRun, false);
  assert.match(invalid.errors.join(" "), /TCP timeout/);
  assert.match(invalid.errors.join(" "), /Max targets/);

  const tls = buildBenchmarkPlan({
    mode: "pathCompare",
    selectedProfiles: ["cloudflare"],
    suites,
    suiteId: "general-browsing",
    domains: "",
    attempts: "1",
    timeoutMs: "800",
    connectTimeoutMs: "1200",
    maxTargets: "3",
    tlsEnabled: true,
  });

  assert.equal(tls.canRun, true);
  assert.equal(tls.payload.tlsHandshakeTimeoutMs, 1200);
});

test("suggested suites exposes default and Vietnam quick picks when catalog supports them", () => {
  assert.deepEqual(suggestedSuites(suites), {
    defaultSuiteId: "general-browsing",
    vietnamSuiteId: "vietnam-daily",
  });
});

test("suggested suites recognizes the shared core general suite", () => {
  assert.deepEqual(
    suggestedSuites([
      { id: "general", name: "General", domains: ["example.com"], tags: ["general"] },
      { id: "vietnam-daily", name: "Vietnam", domains: ["vnexpress.net"], tags: ["vietnam"] },
    ]),
    { defaultSuiteId: "general", vietnamSuiteId: "vietnam-daily" }
  );
});
