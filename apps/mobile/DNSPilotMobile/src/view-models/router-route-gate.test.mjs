import assert from "node:assert/strict";
import { test } from "node:test";

import { assertNoUnresolvedExpoRoutes } from "./router-route-gate.js";

test("rejects Expo Router unresolved route warnings", () => {
  assert.throws(
    () => assertNoUnresolvedExpoRoutes(' WARN  No route named "profiles" exists in nested children: ["index"] '),
    /profiles/
  );
});

test("accepts clean Expo Router output", () => {
  assert.doesNotThrow(() => assertNoUnresolvedExpoRoutes('Exported 12 bundles.'));
});
