import assert from "node:assert/strict";
import { test } from "node:test";

import { buildDeviceSetupPlan, normalizeBridgeUrl } from "./device-setup.js";

test("normalizes bare host bridge URLs to http and trims slashes", () => {
  assert.equal(normalizeBridgeUrl("192.168.1.20:8787/"), "http://192.168.1.20:8787");
});

test("iOS real device rejects localhost and requires Mac LAN URL", () => {
  const plan = buildDeviceSetupPlan({
    target: "ios-device",
    bridgeUrl: "http://localhost:8787",
    health: null,
  });

  assert.equal(plan.bridge.status, "failed");
  assert.equal(plan.bridge.code, "localhost-not-device-reachable");
  assert.equal(plan.recommendedPreset, "mac-lan");
  assert.equal(plan.permission.code, "ios-local-network");
  assert.equal(plan.policy.canMutateSystemDns, false);
});

test("Android emulator accepts 10.0.2.2 and keeps consumer DNS mutation disabled", () => {
  const plan = buildDeviceSetupPlan({
    target: "android-emulator",
    bridgeUrl: "http://10.0.2.2:8787",
    health: { ok: true },
  });

  assert.equal(plan.bridge.status, "success");
  assert.equal(plan.bridge.code, "bridge-ready");
  assert.equal(plan.permission.code, "android-normal-network");
  assert.equal(plan.policy.usesVpnService, false);
  assert.equal(plan.policy.canMutateSystemDns, false);
});

test("private LAN URL is ready for iOS real device when bridge health is up", () => {
  const plan = buildDeviceSetupPlan({
    target: "ios-device",
    bridgeUrl: "http://192.168.1.20:8787",
    health: { ok: true },
  });

  assert.equal(plan.bridge.status, "success");
  assert.equal(plan.bridge.code, "bridge-ready");
  assert.equal(plan.recommendedPreset, "current");
});
