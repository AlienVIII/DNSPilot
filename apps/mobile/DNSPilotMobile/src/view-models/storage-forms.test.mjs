import assert from "node:assert/strict";
import { test } from "node:test";

import { buildProfileForm, buildSuiteForm } from "./storage-forms.js";

test("plain profile form requires a name and at least one DNS server", () => {
  const empty = buildProfileForm({
    profileId: "",
    profileName: "",
    protocol: "plain",
    ipv4: "",
    ipv6: "",
    profileTags: "",
  });

  assert.equal(empty.canSubmit, false);
  assert.match(empty.errors.join(" "), /Profile name/);
  assert.match(empty.errors.join(" "), /DNS server/);

  const valid = buildProfileForm({
    profileId: "",
    profileName: "Office DNS",
    protocol: "plain",
    ipv4: "10.0.0.10",
    ipv6: "",
    filtering: "security",
    profileTags: "office",
  });

  assert.equal(valid.canSubmit, true);
  assert.equal(valid.payload.id, "office-dns");
  assert.deepEqual(valid.payload.ipv4Servers, ["10.0.0.10"]);
  assert.deepEqual(valid.payload.tags, ["office", "custom"]);
});

test("encrypted profile form validates protocol-specific target", () => {
  const doh = buildProfileForm({
    profileId: "secure-doh",
    profileName: "Secure DoH",
    protocol: "doh",
    dohUrl: "http://dns.example/dns-query",
    profileTags: "custom",
  });

  assert.equal(doh.canSubmit, false);
  assert.match(doh.errors.join(" "), /https/);

  const dot = buildProfileForm({
    profileId: "secure-dot",
    profileName: "Secure DoT",
    protocol: "dot",
    dotHostname: "dns.example.com",
    profileTags: "",
  });

  assert.equal(dot.canSubmit, true);
  assert.equal(dot.payload.dotHostname, "dns.example.com");
  assert.deepEqual(dot.payload.tags, ["custom"]);
});

test("suite form requires domains and preserves custom tag", () => {
  const empty = buildSuiteForm({
    suiteId: "",
    suiteName: "Vietnam Apps",
    suiteDomains: "",
    suiteTags: "vietnam",
  });

  assert.equal(empty.canSubmit, false);
  assert.match(empty.errors.join(" "), /domain/);

  const valid = buildSuiteForm({
    suiteId: "",
    suiteName: "Vietnam Apps",
    suiteDomains: "zing.vn\nvnexpress.net",
    suiteTags: "vietnam",
  });

  assert.equal(valid.canSubmit, true);
  assert.equal(valid.payload.id, "vietnam-apps");
  assert.deepEqual(valid.payload.domains, ["zing.vn", "vnexpress.net"]);
  assert.deepEqual(valid.payload.tags, ["vietnam", "custom"]);
});
