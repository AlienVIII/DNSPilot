import assert from "node:assert/strict";
import { test } from "node:test";

import { assertAuditResponseUsable, assertNoUnapprovedHighAuditFindings } from "./npm-audit-policy.js";

const knownMetroChain = {
  vulnerabilities: {
    "image-size": {
      severity: "high",
      via: [
        { source: 1138808, name: "image-size" },
        { source: 1138809, name: "image-size" },
      ],
    },
    metro: { severity: "high", via: ["image-size"] },
    expo: { severity: "high", via: ["@expo/metro"] },
  },
};

test("allows only the documented unremediable Metro image-size advisory chain", () => {
  assert.doesNotThrow(() => assertNoUnapprovedHighAuditFindings(knownMetroChain));
});

test("rejects a new high-severity package finding", () => {
  assert.throws(
    () => assertNoUnapprovedHighAuditFindings({ vulnerabilities: { lodash: { severity: "high", via: [] } } }),
    /lodash/
  );
});

test("rejects a new direct image-size advisory", () => {
  assert.throws(
    () => assertNoUnapprovedHighAuditFindings({ vulnerabilities: { "image-size": { severity: "high", via: [{ source: 9999999, name: "image-size" }] } } }),
    /9999999/
  );
});

test("rejects a direct advisory on an otherwise allowed Metro-chain package", () => {
  assert.throws(
    () => assertNoUnapprovedHighAuditFindings({ vulnerabilities: { expo: { severity: "high", via: [{ source: 9999999, name: "expo" }] } } }),
    /9999999/
  );
});

test("rejects an unusable npm audit response", () => {
  assert.throws(
    () => assertAuditResponseUsable({ error: { summary: "registry unavailable" } }),
    /registry unavailable/
  );
});
