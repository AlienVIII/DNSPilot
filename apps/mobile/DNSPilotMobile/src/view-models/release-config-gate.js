const STORE_BUNDLE_ID = "com.dnspilot.mobile";
const IOS_DNS_PLUGIN = "withIosDnsSettings";
const DEV_CLIENT_PLUGIN = "expo-dev-client";

function pluginNames(plugins = []) {
  return plugins.map((plugin) => (Array.isArray(plugin) ? plugin[0] : plugin));
}

function fail(scope, problems) {
  if (problems.length > 0) {
    throw new Error(`${scope}:\n- ${problems.join("\n- ")}`);
  }
}

function hasPlugin(names, expected) {
  return names.some((name) => String(name).includes(expected));
}

function consumerMetadataProblems(config) {
  const problems = [];
  if (config?.ios?.bundleIdentifier !== STORE_BUNDLE_ID) {
    problems.push(`iOS bundle identifier must be ${STORE_BUNDLE_ID}`);
  }
  if (config?.android?.package !== STORE_BUNDLE_ID) {
    problems.push(`Android package must be ${STORE_BUNDLE_ID}`);
  }
  for (const locale of ["en", "vi"]) {
    if (!config?.locales?.[locale]) {
      problems.push(`locale ${locale} must be declared`);
    }
  }
  return problems;
}

function productionRuntimeProblems(config) {
  const problems = [];
  const names = pluginNames(config?.plugins);
  if (hasPlugin(names, DEV_CLIENT_PLUGIN)) {
    problems.push("must exclude expo-dev-client");
  }
  if (config?.ios?.infoPlist?.NSLocalNetworkUsageDescription) {
    problems.push("must omit NSLocalNetworkUsageDescription");
  }
  return problems;
}

export function assertStoreReleaseConfig(config) {
  const names = pluginNames(config?.plugins);
  const problems = [
    ...consumerMetadataProblems(config),
    ...productionRuntimeProblems(config),
  ];
  if (hasPlugin(names, IOS_DNS_PLUGIN)) {
    problems.push("must exclude the restricted iOS DNS Settings plugin");
  }
  if (config?.extra?.iosDnsSettingsEnabled !== false) {
    problems.push("iosDnsSettingsEnabled must be false");
  }
  fail("Store release config is unsafe", problems);
}

export function assertIosDnsExperimentConfig(config) {
  const names = pluginNames(config?.plugins);
  const problems = [
    ...consumerMetadataProblems(config),
    ...productionRuntimeProblems(config),
  ];
  if (!hasPlugin(names, IOS_DNS_PLUGIN)) {
    problems.push("must include the iOS DNS Settings plugin");
  }
  if (config?.extra?.iosDnsSettingsEnabled !== true) {
    problems.push("iosDnsSettingsEnabled must be true");
  }
  fail("Opt-in iOS DNS config is invalid", problems);
}

export function assertEasBuildProfiles(easConfig) {
  const build = easConfig?.build ?? {};
  const problems = [];
  if (easConfig?.cli?.requireCommit !== true) {
    problems.push("cli.requireCommit must be true");
  }
  if (build?.development?.developmentClient !== true || build?.development?.distribution !== "internal") {
    problems.push("development must be an internal development-client build");
  }
  if (build?.preview?.distribution !== "internal" || build?.preview?.android?.buildType !== "apk") {
    problems.push("preview must be an internal Android APK build");
  }
  if (build?.production?.autoIncrement !== true) {
    problems.push("production must auto-increment app versions");
  }
  if (build?.production?.android?.buildType !== "app-bundle") {
    problems.push("production Android buildType must be app-bundle");
  }
  for (const profile of [build?.production, build?.["production-ios-dns"]]) {
    if (profile?.ios?.image !== "sdk-57") {
      problems.push("production iOS profiles must use the Expo sdk-57 image");
    }
  }
  if (build?.production?.android?.image !== "sdk-57") {
    problems.push("production Android profile must use the Expo sdk-57 image");
  }
  if (build?.["production-ios-dns"]?.autoIncrement !== true) {
    problems.push("production-ios-dns must auto-increment app versions");
  }
  if (build?.["production-ios-dns"]?.env?.DNSPILOT_IOS_DNS_SETTINGS !== "1") {
    problems.push("production-ios-dns must explicitly opt in to DNS Settings");
  }
  fail("EAS build profile contract is invalid", problems);
}

export function assertAndroidStoreManifest(manifest) {
  const source = String(manifest ?? "");
  const forbidden = [
    "android.permission.BIND_VPN_SERVICE",
    "android.permission.SYSTEM_ALERT_WINDOW",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.VIBRATE",
    "android.net.VpnService",
    "expo-dev-client",
    "expo.modules.devlauncher",
    "expo.modules.devmenu",
  ];
  const matches = forbidden.filter((value) => source.includes(value));
  fail("Android Store manifest is unsafe", matches.map((value) => `must exclude ${value}`));
}

export function assertAndroidStoreDex(dexText) {
  const source = String(dexText ?? "");
  const forbidden = [
    "expo/modules/devlauncher",
    "expo/modules/devmenu",
  ];
  const matches = forbidden.filter((value) => source.includes(value));
  fail("Android Store dex is unsafe", matches.map((value) => `must exclude ${value}`));
}
