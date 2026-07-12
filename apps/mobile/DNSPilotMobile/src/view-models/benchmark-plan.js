const pathModes = new Set(["pathCompare", "pathEstimate"]);
const historyModes = new Set(["compare", "pathCompare", "benchmark"]);
const ipFamilies = new Set(["both", "ipv4-only", "ipv6-only"]);
const platforms = new Set(["ios", "android-play"]);

export function buildBenchmarkPlan(input) {
  const selectedProfiles = Array.isArray(input.selectedProfiles) ? input.selectedProfiles.filter(Boolean) : [];
  const suite = suiteFor(input.suites, input.suiteId);
  const domainList = lines(input.domains);
  const attempts = positiveInt(input.attempts);
  const dnsTimeout = positiveInt(input.timeoutMs);
  const connectTimeout = positiveInt(input.connectTimeoutMs);
  const maxTargets = positiveInt(input.maxTargets);
  const mode = input.mode ?? "compare";
  const usesPath = pathModes.has(mode);
  const historyEnabled = Boolean(input.saveHistory && historyModes.has(mode));
  const errors = [];

  if (mode !== "systemBenchmark" && selectedProfiles.length === 0) {
    errors.push("Select at least one DNS profile.");
  }
  if (domainList.length + (suite?.domains?.length ?? 0) === 0) {
    errors.push("Add at least one domain or select a suite.");
  }
  if (!attempts) {
    errors.push("Attempts must be a positive whole number.");
  }
  if (!dnsTimeout) {
    errors.push("DNS timeout must be a positive whole number.");
  }
  if (usesPath && !connectTimeout) {
    errors.push("TCP timeout must be a positive whole number.");
  }
  if (usesPath && !maxTargets) {
    errors.push("Max targets per domain must be a positive whole number.");
  }

  const payload = {
    profileIds: selectedProfiles,
    profileId: selectedProfiles[0] ?? "cloudflare",
    suiteId: suite?.id,
    domains: domainList,
    attempts: attempts ?? 1,
    ipFamily: ipFamilies.has(input.ipFamily) ? input.ipFamily : "both",
    timeoutMs: dnsTimeout ?? 800,
    dnsTimeoutMs: dnsTimeout ?? 800,
    connectTimeoutMs: connectTimeout ?? 1000,
    maxConnectTargetsPerDomain: maxTargets ?? 4,
    tlsHandshakeTimeoutMs: input.tlsEnabled ? (connectTimeout ?? 1000) : undefined,
    platform: platforms.has(input.benchmarkPlatform) ? input.benchmarkPlatform : "ios",
    saveHistory: historyEnabled,
  };

  return {
    payload,
    errors,
    canRun: errors.length === 0,
    domainCount: domainList.length + (suite?.domains?.length ?? 0),
    selectedCount: mode === "systemBenchmark" ? "system" : selectedProfiles.length,
    selectedSuite: suite,
    historyEnabled,
  };
}

export function suggestedSuites(suites = []) {
  const defaultSuite =
    suites.find((suite) => suite?.id === "general") ??
    suites.find((suite) => suite?.id === "general-browsing") ??
    suites.find((suite) => suite?.tags?.includes("default") || suite?.tags?.includes("general"));
  const vietnamSuite = suites.find((suite) => suite?.id === "vietnam-daily") ?? suites.find((suite) => suite?.tags?.includes("vietnam"));
  return {
    defaultSuiteId: defaultSuite?.id,
    vietnamSuiteId: vietnamSuite?.id,
  };
}

function suiteFor(suites = [], suiteId) {
  if (!suiteId) {
    return undefined;
  }
  return suites.find((suite) => suite?.id === suiteId);
}

function positiveInt(value) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : undefined;
}

function lines(value) {
  return String(value ?? "")
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}
