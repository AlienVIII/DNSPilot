import assert from "node:assert/strict";
import test from "node:test";

import { actionTransport } from "./action-transport.js";

test("routes core, policy, recommendation, and persistence actions to the native runtime when it is available", () => {
  assert.equal(actionTransport({ action: "catalog", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "capabilities", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "applyPolicy", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "applyPlan", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "recommendSample", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "profileList", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "suiteUpdate", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "historyClear", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "benchmark", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "compare", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "systemBenchmark", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "pathEstimate", nativeAvailable: true }), "native");
  assert.equal(actionTransport({ action: "pathCompare", nativeAvailable: true }), "native");
});

test("leaves unknown actions on the bridge", () => {
  assert.equal(actionTransport({ action: "unsupported", nativeAvailable: true }), "bridge");
});

test("falls back to the bridge when a native runtime is absent", () => {
  assert.equal(actionTransport({ action: "catalog", nativeAvailable: false }), "bridge");
});
