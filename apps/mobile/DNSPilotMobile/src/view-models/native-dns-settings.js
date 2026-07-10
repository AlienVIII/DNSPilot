export function buildIosDnsSettingsRequest(profile) {
  const name = text(profile?.name) || "Selected DNS";
  const protocol = text(profile?.protocol);
  const serverAddresses = uniqueAddresses(profile);

  if (protocol !== "doh" && protocol !== "dot") {
    return unavailable("encrypted-protocol-required");
  }
  if (serverAddresses.length === 0) {
    return unavailable("bootstrap-address-required");
  }
  if (protocol === "doh") {
    const dohUrl = text(profile?.doh_url);
    if (!isHttpsUrl(dohUrl)) {
      return unavailable("valid-doh-url-required");
    }
    return available({
      description: `DNSPilot: ${name}`,
      protocol,
      serverAddresses,
      dohUrl,
    });
  }

  const dotHostname = text(profile?.dot_hostname);
  if (!isHostname(dotHostname)) {
    return unavailable("valid-dot-hostname-required");
  }
  return available({
    description: `DNSPilot: ${name}`,
    protocol,
    serverAddresses,
    dotHostname,
  });
}

function available(request) {
  return { canInstall: true, request, reason: null };
}

function unavailable(reason) {
  return { canInstall: false, request: null, reason };
}

function uniqueAddresses(profile) {
  return [...new Set([...(profile?.ipv4_servers ?? []), ...(profile?.ipv6_servers ?? [])].map(text).filter(isIpAddress))];
}

function text(value) {
  return String(value ?? "").trim();
}

function isHttpsUrl(value) {
  try {
    return new URL(value).protocol === "https:";
  } catch {
    return false;
  }
}

function isHostname(value) {
  return value.length <= 253 && /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$/i.test(value);
}

function isIpAddress(value) {
  if (/^(?:\d{1,3}\.){3}\d{1,3}$/.test(value)) {
    return value.split(".").every((part) => Number(part) <= 255);
  }
  return /^[0-9a-f:]+$/i.test(value) && value.includes(":");
}
