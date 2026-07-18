const strongConfidence = new Set(["high", "medium"]);

export function buildConsumerResult({ result, profiles = [], platform = "ios", iosDnsSettingsAvailable = false } = {}) {
  const data = result?.data ?? {};
  const summary = data.summary ?? {};
  const recommendation = data.recommendation ?? {};
  const runs = Array.isArray(data.runs) ? data.runs : [];
  const recommendedProfileID = text(recommendation.profile_id) || text(summary.recommended_profile_id);
  const profile = profiles.find((item) => item?.id === recommendedProfileID);
  const confidence = confidenceValue(recommendation.confidence);
  const keepCurrentDNS = shouldKeepCurrentDNS(summary, runs, recommendedProfileID);
  const recommendationKind = recommendationKindFor({ keepCurrentDNS, summary, recommendedProfileID, confidence });

  return {
    scope: text(summary.measurement_scope) || "unknown",
    health: text(summary.health) || "inconclusive",
    confidence,
    fastestObserved: fastestObserved(runs, profiles),
    recommendation: {
      kind: recommendationKind,
      profileId: recommendedProfileID || null,
      profileName: profile?.name ?? recommendedProfileID ?? null,
    },
    keepCurrentDNS,
    notes: notesFor(summary, recommendation, runs),
    primaryAction: primaryActionFor({ recommendationKind, profile, platform, iosDnsSettingsAvailable }),
  };
}

function fastestObserved(runs, profiles) {
  const fastest = runs
    .filter((run) => Number.isFinite(Number(run?.metrics?.median_dns_latency_ms)) && Number(run?.metrics?.failure_rate) < 1)
    .sort((left, right) => {
      const latency = Number(left.metrics.median_dns_latency_ms) - Number(right.metrics.median_dns_latency_ms);
      return latency || Number(left.metrics.failure_rate) - Number(right.metrics.failure_rate);
    })[0];
  if (!fastest) return null;

  const profileID = text(fastest.profile_id);
  const profile = profiles.find((item) => item?.id === profileID);
  return {
    profileId: profileID,
    profileName: profile?.name ?? profileID,
    medianDnsLatencyMs: Math.round(Number(fastest.metrics.median_dns_latency_ms)),
    failureRate: Number(fastest.metrics.failure_rate) || 0,
  };
}

function shouldKeepCurrentDNS(summary, runs, recommendedProfileID) {
  if (summary.primary_issue === "all-resolvers-low-reliability") return true;
  return Boolean(
    summary.can_recommend &&
      recommendedProfileID &&
      summary.health !== "healthy" &&
      runs.length > 0 &&
      runs.every((run) => Number(run?.metrics?.failure_rate) >= 0.5)
  );
}

function recommendationKindFor({ keepCurrentDNS, summary, recommendedProfileID, confidence }) {
  if (keepCurrentDNS) return "keep-current";
  if (!recommendedProfileID) return "none";
  return summary.health === "healthy" && strongConfidence.has(confidence) ? "recommended" : "best-measured";
}

function primaryActionFor({ recommendationKind, profile, platform, iosDnsSettingsAvailable }) {
  if (recommendationKind !== "recommended" || !profile?.id) return null;
  if (platform === "ios" && iosDnsSettingsAvailable && (profile.protocol === "doh" || profile.protocol === "dot")) {
    return { kind: "install-ios-dns-settings", profileId: profile.id };
  }
  return { kind: "guide-settings", profileId: profile.id };
}

function notesFor(summary, recommendation, runs) {
  const values = [
    ...(Array.isArray(summary.safety_notes) ? summary.safety_notes : []),
    ...(Array.isArray(recommendation.reasons) ? recommendation.reasons : []),
    ...(Array.isArray(recommendation.caveats) ? recommendation.caveats : []),
    ...runs.flatMap((run) => (Array.isArray(run?.caveats) ? run.caveats : [])),
  ];
  return [...new Set(values.map(text).filter(Boolean))];
}

function confidenceValue(value) {
  const normalized = text(value).toLowerCase();
  return ["high", "medium", "low", "inconclusive"].includes(normalized) ? normalized : "inconclusive";
}

function text(value) {
  return String(value ?? "").trim();
}
