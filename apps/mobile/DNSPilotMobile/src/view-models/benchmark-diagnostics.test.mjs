import assert from "node:assert/strict";
import { test } from "node:test";

import { buildBenchmarkDiagnostics } from "./benchmark-diagnostics.js";

const failedCompare = {
  ok: true,
  action: "compare",
  args: [
    "compare",
    "--profile-id",
    "cloudflare",
    "--profile-id",
    "google-public-dns",
    "--domain",
    "example.com",
  ],
  progress: [
    { type: "resolver_started", profile_id: "cloudflare", resolver: "1.1.1.1:53", index: 1, total: 2 },
    {
      type: "resolver_finished",
      profile_id: "cloudflare",
      resolver: "1.1.1.1:53",
      status: "failed",
      elapsed_ms: 4.25,
      failure_rate: 1,
      timeout_rate: 0,
      index: 1,
      total: 2,
    },
    { type: "resolver_started", profile_id: "google-public-dns", resolver: "8.8.8.8:53", index: 2, total: 2 },
    {
      type: "resolver_finished",
      profile_id: "google-public-dns",
      resolver: "8.8.8.8:53",
      status: "failed",
      elapsed_ms: 5.5,
      failure_rate: 1,
      timeout_rate: 0,
      index: 2,
      total: 2,
    },
  ],
  data: {
    summary: {
      measurement_scope: "dns-only",
      mode: "fastest-raw-dns",
      health: "failed",
      primary_issue: "all-resolvers-failed",
      can_recommend: false,
      safety_notes: ["Every candidate failed the measured scope."],
      resolver_count: 2,
      domain_count: 1,
      recommended_profile_id: null,
    },
    runs: [
      {
        profile_id: "cloudflare",
        resolver: "1.1.1.1:53",
        metrics: { failure_rate: 1, timeout_rate: 0, median_dns_latency_ms: null },
      },
      {
        profile_id: "google-public-dns",
        resolver: "8.8.8.8:53",
        metrics: { failure_rate: 1, timeout_rate: 0, median_dns_latency_ms: null },
      },
    ],
    warning: "DNS-only comparison estimates resolver lookup latency and reliability.",
  },
};

test("diagnostics identify DNS failure and resolver rows", () => {
  const diagnostics = buildBenchmarkDiagnostics({
    mode: "compare",
    result: failedCompare,
    startedAtMs: 1_000,
    endedAtMs: 1_950,
  });

  assert.equal(diagnostics.status, "failed");
  assert.equal(diagnostics.failedStepId, "dns");
  assert.equal(diagnostics.elapsedMs, 950);
  assert.equal(diagnostics.reason, "Every resolver failed during DNS lookup.");
  assert.deepEqual(
    diagnostics.steps.map((step) => [step.id, step.status]),
    [
      ["prepare", "success"],
      ["dns", "failed"],
      ["connect", "idle"],
      ["tls", "idle"],
      ["save", "idle"],
    ]
  );
  assert.deepEqual(
    diagnostics.resolvers.map((resolver) => [resolver.profileId, resolver.status, resolver.elapsedMs]),
    [
      ["cloudflare", "failed", 4.25],
      ["google-public-dns", "failed", 5.5],
    ]
  );
  assert.match(diagnostics.report, /Mode: compare/);
  assert.match(diagnostics.report, /Failed step: DNS lookup/);
  assert.match(diagnostics.report, /cloudflare .* failed/);
  assert.match(diagnostics.debugLog, /dnspilot-cli compare/);
});

test("diagnostics report bridge errors before process result exists", () => {
  const diagnostics = buildBenchmarkDiagnostics({
    mode: "pathCompare",
    error: new Error("invalid --domain 'bad domain'"),
    startedAtMs: 2_000,
    endedAtMs: 2_020,
  });

  assert.equal(diagnostics.status, "failed");
  assert.equal(diagnostics.failedStepId, "prepare");
  assert.equal(diagnostics.reason, "invalid --domain 'bad domain'");
  assert.equal(diagnostics.steps[0].status, "failed");
  assert.match(diagnostics.report, /Status: failed/);
  assert.match(diagnostics.debugLog, /invalid --domain/);
});

test("diagnostics keep later steps running or idle while process is active", () => {
  const diagnostics = buildBenchmarkDiagnostics({
    mode: "pathCompare",
    startedAtMs: 3_000,
  });

  assert.equal(diagnostics.status, "running");
  assert.deepEqual(
    diagnostics.steps.map((step) => [step.id, step.status]),
    [
      ["prepare", "success"],
      ["dns", "running"],
      ["connect", "idle"],
      ["tls", "idle"],
      ["save", "idle"],
    ]
  );
  assert.equal(diagnostics.reason, "Benchmark is running.");
});
