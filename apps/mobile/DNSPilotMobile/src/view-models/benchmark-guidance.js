const confidenceValues = new Set(["high", "medium", "low", "inconclusive"]);
const gateHealthValues = new Set(["healthy", "degraded", "failed", "inconclusive"]);

export function buildApplyPlanRequest({ platform, result, profiles = [], environment = {} }) {
  const data = result?.data ?? {};
  const summary = data.summary ?? {};
  const recommendation = data.recommendation ?? {};
  const profileId = recommendation?.profile_id ?? summary?.recommended_profile_id;
  if (!profileId) {
    return null;
  }

  const profile = profiles.find((item) => item?.id === profileId);
  const run = Array.isArray(data.runs) ? data.runs.find((item) => item?.profile_id === profileId) : undefined;

  return {
    platform,
    profileId,
    profileName: profile?.name ?? profileId,
    testedResolver: run?.resolver ?? profileServers(profile)[0] ?? "",
    confidence: normalizeValue(recommendation?.confidence, confidenceValues, "medium"),
    gateHealth: normalizeValue(summary?.health, gateHealthValues, "inconclusive"),
    environment: {
      vpnActive: Boolean(environment.vpnActive),
      mdmProfileActive: Boolean(environment.mdmProfileActive),
      corporateDnsDetected: Boolean(environment.corporateDnsDetected),
      captivePortalDetected: Boolean(environment.captivePortalDetected),
    },
  };
}

function profileServers(profile) {
  if (!profile) {
    return [];
  }
  return [...(profile.ipv4_servers ?? []), ...(profile.ipv6_servers ?? [])];
}

function normalizeValue(value, allowed, fallback) {
  const text = String(value ?? "").trim().toLowerCase();
  return allowed.has(text) ? text : fallback;
}
