import assert from "node:assert/strict";
import { test } from "node:test";

import { buildConsumerResult } from "./consumer-result.js";

const profiles = [
  { id: "cloudflare", name: "Cloudflare", protocol: "plain", ipv4_servers: ["1.1.1.1"] },
  { id: "google-public-dns", name: "Google Public DNS", protocol: "plain", ipv4_servers: ["8.8.8.8"] },
  { id: "quad9-doh", name: "Quad9 Secure", protocol: "doh", doh_url: "https://dns.quad9.net/dns-query", ipv4_servers: ["9.9.9.9"] },
];

function result(overrides = {}) {
  return {
    data: {
      summary: {
        measurement_scope: "dns-only",
        health: "healthy",
        can_recommend: true,
        recommended_profile_id: "google-public-dns",
        safety_notes: ["Measured on the current network."],
      },
      recommendation: {
        profile_id: "google-public-dns",
        confidence: "high",
        reasons: ["Reliable across the selected domains."],
        caveats: ["Retest after changing networks."],
      },
      runs: [
        { profile_id: "cloudflare", resolver: "1.1.1.1:53", metrics: { median_dns_latency_ms: 12.2, failure_rate: 0.2 } },
        { profile_id: "google-public-dns", resolver: "8.8.8.8:53", metrics: { median_dns_latency_ms: 14.1, failure_rate: 0 } },
      ],
      ...overrides,
    },
  };
}

test("separates fastest observed DNS from the balanced recommendation", () => {
  const presentation = buildConsumerResult({ result: result(), profiles, platform: "android-play" });

  assert.deepEqual(presentation.fastestObserved, {
    profileId: "cloudflare",
    profileName: "Cloudflare",
    medianDnsLatencyMs: 12,
    failureRate: 0.2,
  });
  assert.equal(presentation.recommendation.profileName, "Google Public DNS");
  assert.equal(presentation.recommendation.kind, "recommended");
  assert.deepEqual(presentation.primaryAction, { kind: "guide-settings", profileId: "google-public-dns" });
  assert.deepEqual(presentation.notes, [
    "Measured on the current network.",
    "Reliable across the selected domains.",
    "Retest after changing networks.",
  ]);
});

test("keeps current DNS when all measured candidates are unreliable", () => {
  const presentation = buildConsumerResult({
    result: result({
      summary: {
        measurement_scope: "dns-only",
        health: "degraded",
        can_recommend: true,
        primary_issue: "all-resolvers-low-reliability",
        recommended_profile_id: "cloudflare",
      },
      recommendation: { profile_id: "cloudflare", confidence: "low" },
      runs: [
        { profile_id: "cloudflare", metrics: { median_dns_latency_ms: 12, failure_rate: 0.8 } },
        { profile_id: "google-public-dns", metrics: { median_dns_latency_ms: 14, failure_rate: 0.9 } },
      ],
    }),
    profiles,
    platform: "android-play",
  });

  assert.equal(presentation.keepCurrentDNS, true);
  assert.equal(presentation.recommendation.kind, "keep-current");
  assert.equal(presentation.primaryAction, null);
});

test("uses the entitled iOS DNS Settings action only for encrypted profiles", () => {
  const presentation = buildConsumerResult({
    result: result({
      summary: { measurement_scope: "dns-only", health: "healthy", can_recommend: true, recommended_profile_id: "quad9-doh" },
      recommendation: { profile_id: "quad9-doh", confidence: "medium" },
      runs: [{ profile_id: "quad9-doh", metrics: { median_dns_latency_ms: 18, failure_rate: 0 } }],
    }),
    profiles,
    platform: "ios",
    iosDnsSettingsAvailable: true,
  });

  assert.deepEqual(presentation.primaryAction, { kind: "install-ios-dns-settings", profileId: "quad9-doh" });
});

test("does not create a setup action for inconclusive evidence", () => {
  const presentation = buildConsumerResult({
    result: result({
      summary: { measurement_scope: "dns-only", health: "inconclusive", can_recommend: true, recommended_profile_id: "cloudflare" },
      recommendation: { profile_id: "cloudflare", confidence: "low" },
    }),
    profiles,
    platform: "ios",
  });

  assert.equal(presentation.recommendation.kind, "best-measured");
  assert.equal(presentation.primaryAction, null);
});
