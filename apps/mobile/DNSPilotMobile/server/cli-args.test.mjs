import assert from "node:assert/strict";
import { test } from "node:test";

import {
  bridgeUrls,
  createBridgeConfig,
  createBridgeServer,
  createJobStore,
  buildCliArgs,
} from "./dev-server.mjs";

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

test("bridge URL helper stays on loopback unless LAN mode is explicit", () => {
  const urls = bridgeUrls(8787, {
    lo0: [{ address: "127.0.0.1", family: "IPv4", internal: true }],
    en0: [{ address: "192.168.1.20", family: "IPv4", internal: false }],
    utun: [{ address: "10.8.0.5", family: "IPv4", internal: false }],
    public: [{ address: "203.0.113.7", family: "IPv4", internal: false }],
    v6: [{ address: "fe80::1", family: "IPv6", internal: false }],
  });

  assert.deepEqual(urls, ["http://localhost:8787"]);
  assert.deepEqual(
    bridgeUrls(
      8787,
      {
        en0: [{ address: "192.168.1.20", family: "IPv4", internal: false }],
        utun: [{ address: "10.8.0.5", family: "IPv4", internal: false }],
      },
      { lan: true }
    ),
    ["http://localhost:8787", "http://192.168.1.20:8787", "http://10.8.0.5:8787"]
  );
});

test("bridge uses an app-owned database and does not disclose local paths", async () => {
  const dbPath = "/tmp/dnspilot-owned.sqlite";
  const jobStore = createJobStore({
    runCommand: async (_action, _payload, receivedDbPath) => {
      assert.equal(receivedDbPath, dbPath);
      return { ok: true, action: "catalog", args: ["catalog"], data: {} };
    },
  });
  const server = createBridgeServer(jobStore, {
    dbPath,
    security: createBridgeConfig({}),
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = server.address().port;

  const health = await fetch(`http://127.0.0.1:${port}/health`);
  const healthBody = await health.json();
  assert.equal(health.status, 200);
  assert.deepEqual(healthBody, { ok: true, service: "dnspilot-mobile-bridge", mode: "loopback" });

  const response = await fetch(`http://127.0.0.1:${port}/api/cli`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "catalog", dbPath: "/tmp/attacker.sqlite" }),
  });
  assert.equal(response.status, 200);
  await response.json();
  await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
});

test("LAN bridge requires its per-run bearer token", async () => {
  const security = createBridgeConfig({ DNSPILOT_MOBILE_BRIDGE_LAN: "1", DNSPILOT_MOBILE_BRIDGE_TOKEN: "test-token" });
  const server = createBridgeServer(createJobStore(), { security });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = server.address().port;

  const denied = await fetch(`http://127.0.0.1:${port}/health`);
  assert.equal(denied.status, 401);
  const allowed = await fetch(`http://127.0.0.1:${port}/health`, {
    headers: { authorization: "Bearer test-token" },
  });
  assert.equal(allowed.status, 200);
  await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
});
