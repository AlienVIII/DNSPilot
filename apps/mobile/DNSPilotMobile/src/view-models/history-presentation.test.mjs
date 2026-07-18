import assert from "node:assert/strict";
import { test } from "node:test";

import { buildHistoryRows } from "./history-presentation.js";

test("history labels saved recommendations as retest-only guidance", () => {
  const rows = buildHistoryRows({
    records: [
      {
        id: "run-1",
        scope: "dns-only",
        mode: "compare",
        domains: ["example.com", "example.org"],
        recommendation_profile_id: "cloudflare",
      },
    ],
    profiles: [{ id: "cloudflare", name: "Cloudflare" }],
  });

  assert.deepEqual(rows, [
    {
      id: "run-1",
      title: "DNS only",
      domainSummary: "example.com + 1 more",
      recommendation: "Cloudflare",
      requiresRetest: true,
    },
  ]);
});

test("history has no setup affordance when a record has no recommendation", () => {
  const [row] = buildHistoryRows({ records: [{ id: "run-2", scope: "dns-tcp", domains: [] }], profiles: [] });

  assert.equal(row.recommendation, null);
  assert.equal(row.requiresRetest, false);
});
