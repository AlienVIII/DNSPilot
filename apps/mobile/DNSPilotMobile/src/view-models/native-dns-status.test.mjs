import assert from "node:assert/strict";
import test from "node:test";

import { buildNativeDnsStatus } from "./native-dns-status.js";

test("presents an installed but user-disabled iOS DNS configuration clearly", () => {
  assert.deepEqual(
    buildNativeDnsStatus({ available: true, installed: true, enabled: false, protocol: "doh" }),
    {
      availabilityKey: "policy.nativeDns.status.available",
      installedKey: "policy.nativeDns.status.installed",
      enabledKey: "policy.nativeDns.status.disabled",
      tone: "amber",
    }
  );
});

test("presents enabled and unavailable states without implying the app changed DNS", () => {
  assert.deepEqual(buildNativeDnsStatus({ available: true, installed: true, enabled: true, protocol: "dot" }), {
    availabilityKey: "policy.nativeDns.status.available",
    installedKey: "policy.nativeDns.status.installed",
    enabledKey: "policy.nativeDns.status.enabled",
    tone: "green",
  });
  assert.deepEqual(buildNativeDnsStatus({ available: false, installed: false, enabled: false }), {
    availabilityKey: "policy.nativeDns.status.unavailable",
    installedKey: "policy.nativeDns.status.notInstalled",
    enabledKey: "policy.nativeDns.status.disabled",
    tone: "red",
  });
});
