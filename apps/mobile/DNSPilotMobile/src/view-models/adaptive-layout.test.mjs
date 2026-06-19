import assert from "node:assert/strict";
import { test } from "node:test";

import { layoutForWidth } from "./adaptive-layout.js";

test("phone width stays single column", () => {
  assert.deepEqual(layoutForWidth(430), {
    kind: "phone",
    columns: 1,
    maxContentWidth: 640,
    gap: 14,
  });
});

test("tablet width uses two columns without stretching full screen", () => {
  assert.deepEqual(layoutForWidth(900), {
    kind: "tablet",
    columns: 2,
    maxContentWidth: 1080,
    gap: 16,
  });
});

test("wide desktop keeps readable maximum content width", () => {
  assert.deepEqual(layoutForWidth(1366), {
    kind: "expanded",
    columns: 2,
    maxContentWidth: 1180,
    gap: 18,
  });
});
