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
  assert.match(prompt.summary, /OS Settings/);
  assert.match(prompt.checks.find((check) => check.id === "dns-apply").detail, /OS\/user applies/);
  assert.match(prompt.checks.find((check) => check.id === "dns-flush").detail, /cannot flush mobile system DNS cache/);
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
  assert.match(prompt.summary, /never changes DNS silently/);
  assert.match(prompt.checks.find((check) => check.id === "network-access").detail, /no VpnService/);
  assert.match(prompt.checks.find((check) => check.id === "private-dns").detail, /Android Settings/);
  assert.doesNotMatch(prompt.summary, /speed improvement|apply fastest/i);
});
