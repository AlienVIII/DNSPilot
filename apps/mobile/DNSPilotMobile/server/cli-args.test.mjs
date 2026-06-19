import assert from "node:assert/strict";
import { test } from "node:test";

import { buildCliArgs } from "./dev-server.mjs";

const dbPath = "/tmp/dnspilot-mobile-test.sqlite";

test("catalog maps to the catalog command", () => {
  assert.deepEqual(buildCliArgs("catalog", {}, dbPath), ["catalog"]);
});

test("compare maps selected profiles, domains, and history storage", () => {
  assert.deepEqual(
    buildCliArgs(
      "compare",
      {
        profileIds: ["cloudflare", "google-public-dns"],
        domains: ["github.com", "expo.dev"],
        attempts: 2,
        ipFamily: "ipv4-only",
        timeoutMs: 900,
        saveHistory: true,
      },
      dbPath
    ),
    [
      "compare",
      "--profile-db",
      dbPath,
      "--profile-id",
      "cloudflare",
      "--profile-id",
      "google-public-dns",
      "--domain",
      "github.com",
      "--domain",
      "expo.dev",
      "--attempts",
      "2",
      "--ip-family",
      "ipv4-only",
      "--timeout-ms",
      "900",
      "--save-db",
      dbPath,
      "--progress-jsonl",
    ]
  );
});

test("profile add maps custom DNS metadata", () => {
  assert.deepEqual(
    buildCliArgs(
      "profileAdd",
      {
        id: "office-dns",
        name: "Office DNS",
        protocol: "plain",
        ipv4Servers: ["10.0.0.10"],
        ipv6Servers: ["2001:db8::10"],
        filtering: "security",
        tags: ["custom", "office"],
      },
      dbPath
    ),
    [
      "profile-add",
      "--db",
      dbPath,
      "--id",
      "office-dns",
      "--name",
      "Office DNS",
      "--protocol",
      "plain",
      "--ipv4",
      "10.0.0.10",
      "--ipv6",
      "2001:db8::10",
      "--filtering",
      "security",
      "--tag",
      "custom",
      "--tag",
      "office",
    ]
  );
});

test("unknown action is rejected before spawning a process", () => {
  assert.throws(() => buildCliArgs("rm", {}, dbPath), /Unsupported action/);
});
