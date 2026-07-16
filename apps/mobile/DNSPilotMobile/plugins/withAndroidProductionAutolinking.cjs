const { withPodfile, withSettingsGradle } = require("@expo/config-plugins");

const DEV_CLIENT_PACKAGES = [
  "expo-dev-client",
  "expo-dev-launcher",
  "expo-dev-menu",
  "expo-dev-menu-interface",
];
const IOS_DNS_SETTINGS_PACKAGE = "dns-settings";

const SETTINGS_MARKER = "// DNSPILOT_PRODUCTION_AUTOLINKING";
const PODFILE_MARKER = "# DNSPILOT_PRODUCTION_AUTOLINKING";

function withAndroidProductionAutolinking(config) {
  config = withSettingsGradle(config, (nextConfig) => {
    nextConfig.modResults.contents = patchSettingsGradle(nextConfig.modResults.contents);
    return nextConfig;
  });
  return withPodfile(config, (nextConfig) => {
    nextConfig.modResults.contents = patchPodfile(nextConfig.modResults.contents);
    return nextConfig;
  });
}

function patchSettingsGradle(contents) {
  if (contents.includes(SETTINGS_MARKER)) {
    return contents;
  }
  const target = "expoAutolinking.useExpoModules()";
  const guard = [
    SETTINGS_MARKER,
    "def dnspilotBuildProfile = System.getenv('EAS_BUILD_PROFILE') ?: ''",
    "def dnspilotProductionBuild = System.getenv('DNSPILOT_PRODUCTION_BUILD') == '1'",
    "def dnspilotExcludeDevClient = dnspilotProductionBuild || (dnspilotBuildProfile != '' && dnspilotBuildProfile != 'development')",
    "if (dnspilotExcludeDevClient) {",
    `  expoAutolinking.exclude = ${gradleStringList(DEV_CLIENT_PACKAGES)}`,
    "}",
    target,
  ].join("\n");

  return contents.replace(target, guard);
}

function patchPodfile(contents) {
  if (contents.includes(PODFILE_MARKER)) {
    return contents;
  }
  const target = "  use_expo_modules!";
  const guard = [
    `  ${PODFILE_MARKER}`,
    "  dnspilot_build_profile = ENV['EAS_BUILD_PROFILE'] || ''",
    "  dnspilot_production_build = ENV['DNSPILOT_PRODUCTION_BUILD'] == '1'",
    "  dnspilot_ios_dns_settings = ENV['DNSPILOT_IOS_DNS_SETTINGS'] == '1' || dnspilot_build_profile == 'production-ios-dns'",
    "  dnspilot_exclude_dev_client = dnspilot_production_build || (dnspilot_build_profile != '' && dnspilot_build_profile != 'development')",
    `  dnspilot_dev_client_packages = ${rubyStringList(DEV_CLIENT_PACKAGES)}`,
    `  dnspilot_expo_excluded_packages = dnspilot_exclude_dev_client ? dnspilot_dev_client_packages.dup : []`,
    `  dnspilot_expo_excluded_packages << "${IOS_DNS_SETTINGS_PACKAGE}" unless dnspilot_ios_dns_settings`,
    "  dnspilot_expo_autolinking_options = dnspilot_expo_excluded_packages.empty? ? {} : { exclude: dnspilot_expo_excluded_packages }",
    "  use_expo_modules!(dnspilot_expo_autolinking_options)",
  ].join("\n");

  return contents.replace(target, guard);
}

function gradleStringList(values) {
  return `[${values.map((value) => `"${value}"`).join(", ")}]`;
}

function rubyStringList(values) {
  return `[${values.map((value) => `"${value}"`).join(", ")}]`;
}

module.exports = withAndroidProductionAutolinking;
module.exports.patchPodfile = patchPodfile;
module.exports.patchSettingsGradle = patchSettingsGradle;
