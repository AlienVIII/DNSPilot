import assert from "node:assert/strict";
import { test } from "node:test";

import { buildSystemAccessPrompt } from "./system-access.js";

test("iOS startup prompt checks Local Network and refuses fake DNS mutation", () => {
  const prompt = buildSystemAccessPrompt({
    platform: "ios",
    bridgeStatus: "failed",
    locale: "en",
  });

  assert.equal(prompt.shouldPrompt, true);
  assert.equal(prompt.actions[0].target, "ios-app-settings");
  assert.ok(prompt.actions.some((action) => action.id === "retest-system-dns" && action.kind === "retest-system-dns"));
  assert.ok(prompt.checks.some((check) => check.id === "local-network" && check.status === "needs-action"));
  assert.ok(prompt.checks.some((check) => check.id === "dns-apply" && check.status === "os-gated"));
  assert.ok(prompt.checks.some((check) => check.id === "dns-flush" && check.status === "unsupported"));
  assert.match(prompt.summary, /OS-controlled/);
  assert.doesNotMatch(prompt.summary, /speed improvement|apply fastest/i);
});

test("Android startup prompt opens Private DNS settings without VpnService or silent mutation", () => {
  const prompt = buildSystemAccessPrompt({
    platform: "android-play",
    bridgeStatus: "unknown",
    locale: "en",
  });

  assert.equal(prompt.shouldPrompt, true);
  assert.equal(prompt.actions[0].target, "android-private-dns");
  assert.ok(prompt.actions.some((action) => action.id === "retest-system-dns" && action.kind === "retest-system-dns"));
  assert.ok(prompt.checks.some((check) => check.id === "private-dns" && check.status === "os-gated"));
  assert.ok(prompt.checks.some((check) => check.id === "dns-flush" && check.status === "unsupported"));
  assert.match(prompt.summary, /does not use VpnService/);
  assert.doesNotMatch(prompt.summary, /speed improvement|apply fastest/i);
});
