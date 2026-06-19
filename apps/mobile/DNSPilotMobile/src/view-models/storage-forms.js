const protocols = new Set(["plain", "doh", "dot"]);
const filteringTypes = new Set(["none", "malware", "family", "ads", "security"]);

export function buildProfileForm(input) {
  const protocol = protocols.has(input.protocol) ? input.protocol : "plain";
  const name = text(input.profileName);
  const payload = {
    id: text(input.profileId) || safeId(name),
    name,
    protocol,
    ipv4Servers: protocol === "plain" ? lines(input.ipv4) : [],
    ipv6Servers: protocol === "plain" ? lines(input.ipv6) : [],
    dohUrl: protocol === "doh" ? text(input.dohUrl) || undefined : undefined,
    dotHostname: protocol === "dot" ? text(input.dotHostname) || undefined : undefined,
    filtering: filteringTypes.has(input.filtering) ? input.filtering : "none",
    tags: withCustomTag(lines(input.profileTags)),
  };
  const errors = [];

  if (!payload.id) {
    errors.push("Profile ID or name is required.");
  }
  if (!payload.name) {
    errors.push("Profile name is required.");
  }
  if (protocol === "plain" && payload.ipv4Servers.length + payload.ipv6Servers.length === 0) {
    errors.push("Plain DNS profile needs at least one DNS server.");
  }
  if (protocol === "doh" && !payload.dohUrl?.startsWith("https://")) {
    errors.push("DoH profile needs an https:// URL.");
  }
  if (protocol === "dot" && !payload.dotHostname) {
    errors.push("DoT profile needs a hostname.");
  }

  return {
    payload,
    errors,
    canSubmit: errors.length === 0,
    canDelete: Boolean(payload.id),
  };
}

export function buildSuiteForm(input) {
  const name = text(input.suiteName);
  const payload = {
    id: text(input.suiteId) || safeId(name),
    name,
    domains: lines(input.suiteDomains),
    tags: withCustomTag(lines(input.suiteTags)),
  };
  const errors = [];

  if (!payload.id) {
    errors.push("Suite ID or name is required.");
  }
  if (!payload.name) {
    errors.push("Suite name is required.");
  }
  if (payload.domains.length === 0) {
    errors.push("Suite needs at least one domain.");
  }

  return {
    payload,
    errors,
    canSubmit: errors.length === 0,
    canDelete: Boolean(payload.id),
  };
}

function lines(value) {
  return String(value ?? "")
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function text(value) {
  return String(value ?? "").trim();
}

function safeId(value) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function withCustomTag(tags) {
  return [...new Set([...tags, "custom"])];
}
