const notePatterns = [
  {
    match: /^Best DNS lookup estimate for FastestRawDns mode\.$/,
    key: "check.note.fastestRawDns",
  },
  {
    match: /^Recommended profile: ([^.]+)\.$/,
    key: "check.note.recommendedProfile",
    params: (match) => ({ profileId: match[1] }),
  },
  {
    match: /^This estimates DNS lookup behavior, not TCP, TLS, HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior\.$/,
    key: "check.note.dnsOnlyScope",
  },
];

const resolverDiagnosisKeys = new Map([
  ["Measurement is running.", "check.resolver.running"],
  ["Measured successfully.", "check.resolver.success"],
  ["All samples timed out.", "check.resolver.timeout"],
  ["All samples failed.", "check.resolver.failed"],
  ["Some samples failed or timed out.", "check.resolver.degraded"],
]);

const actionKeys = new Map([
  ["compare", "benchmark.mode.compare"],
  ["pathCompare", "benchmark.mode.pathCompare"],
  ["systemBenchmark", "benchmark.mode.systemBenchmark"],
]);

export function presentHealth(value, t) {
  return presentEnum(value, "check.health", t);
}

export function presentConfidence(value, t) {
  return presentEnum(value, "check.confidence", t);
}

export function presentResolverStatus(value, t) {
  return presentEnum(value, "status", t);
}

export function presentResolverDiagnosis(value, t) {
  const key = resolverDiagnosisKeys.get(String(value ?? ""));
  return key ? t(key) : String(value ?? "");
}

export function presentAction(value, t) {
  const key = actionKeys.get(String(value ?? ""));
  return key ? t(key) : String(value ?? "");
}

export function presentNote(value, t) {
  const text = String(value ?? "");
  for (const pattern of notePatterns) {
    const match = text.match(pattern.match);
    if (match) return t(pattern.key, pattern.params ? pattern.params(match) : {});
  }
  return text;
}

export function presentProcessReason(value, t) {
  const text = String(value ?? "");
  if (text === "Benchmark is running.") return t("check.process.running");
  if (text === "Completed without a recommendation.") return t("check.process.noRecommendation");
  if (text === "Every resolver failed during DNS lookup.") return t("check.process.allResolversFailed");
  if (text === "No usable TCP connect targets were produced.") return t("check.process.noConnectTargets");
  return presentNote(text, t);
}

function presentEnum(value, prefix, t) {
  const normalized = String(value ?? "").trim().toLowerCase();
  const key = `${prefix}.${normalized}`;
  const translated = t(key);
  return translated === key ? String(value ?? "") : translated;
}
