const preferredProfileIDs = ["cloudflare", "google-public-dns", "quad9"];

const presetDefinitions = [
  { id: "general", suiteIDs: ["general", "general-browsing"], tags: ["general", "default"] },
  { id: "vietnam-daily", suiteIDs: ["vietnam-daily"], tags: ["vietnam"] },
  { id: "gaming-steam-valve", suiteIDs: ["gaming-steam-valve"], tags: ["gaming", "steam"] },
  { id: "gaming-dota2-sea", suiteIDs: ["gaming-dota2-sea"], tags: ["gaming", "dota2"] },
  { id: "gaming-cs2", suiteIDs: ["gaming-cs2"], tags: ["gaming", "cs2"] },
  { id: "gaming-riot-lol", suiteIDs: ["gaming-riot-lol"], tags: ["gaming", "riot"] },
];

export function buildQuickCheck({ profiles = [], suites = [], platform = "ios", presetID = "general" } = {}) {
  const selectedPreset = quickCheckPresets(suites).find((preset) => preset.id === presetID) ?? quickCheckPresets(suites)[0];
  const plainProfiles = profiles.filter((profile) => profile?.protocol === "plain" && profile?.id);
  const preferred = preferredProfileIDs.filter((id) => plainProfiles.some((profile) => profile.id === id));

  return {
    mode: "compare",
    selectedProfiles: preferred.length ? preferred : plainProfiles.slice(0, 3).map((profile) => profile.id),
    suiteId: selectedPreset?.suiteId,
    domains: "",
    attempts: "2",
    ipFamily: "both",
    timeoutMs: "800",
    connectTimeoutMs: "1000",
    maxTargets: "4",
    tlsEnabled: false,
    benchmarkPlatform: platform === "android-play" ? "android-play" : "ios",
    saveHistory: true,
  };
}

export function buildCheckEntryState({ nativeRuntime = false } = {}) {
  return {
    showsSystemAccessSheet: false,
    showsBridgeConfiguration: !nativeRuntime,
  };
}

export function quickCheckPresets(suites = []) {
  return presetDefinitions.flatMap((definition) => {
    const suite = suiteForDefinition(suites, definition);
    return suite ? [{ id: definition.id, suiteId: suite.id, name: suite.name, tags: suite.tags ?? [] }] : [];
  });
}

function suiteForDefinition(suites, definition) {
  return (
    suites.find((suite) => definition.suiteIDs.includes(suite?.id)) ??
    suites.find((suite) => definition.tags.every((tag) => suite?.tags?.includes(tag)))
  );
}
