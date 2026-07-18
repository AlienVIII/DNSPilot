import assert from "node:assert/strict";
import test from "node:test";

import { buildIosDnsSettingsRequest } from "./native-dns-settings.js";

test("builds an iOS DNS Settings request for a DoH profile with bootstrap addresses", () => {
  const result = buildIosDnsSettingsRequest({
    id: "cloudflare-doh",
    name: "Cloudflare DoH",
    protocol: "doh",
    doh_url: "https://cloudflare-dns.com/dns-query",
    ipv4_servers: ["1.1.1.1", "1.0.0.1"],
  });

  assert.equal(result.canInstall, true);
  assert.deepEqual(result.request, {
    description: "DNSPilot: Cloudflare DoH",
    protocol: "doh",
    serverAddresses: ["1.1.1.1", "1.0.0.1"],
    dohUrl: "https://cloudflare-dns.com/dns-query",
  });
});

test("rejects plain DNS because iOS DNS Settings is reserved for encrypted DNS", () => {
  const result = buildIosDnsSettingsRequest({
    name: "Plain DNS",
    protocol: "plain",
    ipv4_servers: ["1.1.1.1"],
  });

  assert.equal(result.canInstall, false);
  assert.equal(result.reason, "encrypted-protocol-required");
});

test("requires bootstrap addresses before installing a DoT profile", () => {
  const result = buildIosDnsSettingsRequest({
    name: "Quad9 DoT",
    protocol: "dot",
    dot_hostname: "dns.quad9.net",
  });

  assert.equal(result.canInstall, false);
  assert.equal(result.reason, "bootstrap-address-required");
});

test("rejects invalid encrypted DNS endpoints", () => {
  const result = buildIosDnsSettingsRequest({
    name: "Bad DoH",
    protocol: "doh",
    doh_url: "http://dns.example/dns-query",
    ipv4_servers: ["1.1.1.1"],
  });

  assert.equal(result.canInstall, false);
  assert.equal(result.reason, "valid-doh-url-required");
});
