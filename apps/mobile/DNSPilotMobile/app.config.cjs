const base = require("./app.json").expo;

function shouldIncludeDevClient() {
  const profile = process.env.EAS_BUILD_PROFILE ?? "";
  if (process.env.DNSPILOT_INCLUDE_DEV_CLIENT === "1") {
    return true;
  }
  if (process.env.DNSPILOT_PRODUCTION_BUILD === "1") {
    return false;
  }
  return profile === "" || profile === "development";
}

function pluginsForProfile(sourcePlugins = []) {
  const plugins = sourcePlugins.filter((plugin) => {
    const name = Array.isArray(plugin) ? plugin[0] : plugin;
    return shouldIncludeDevClient() || name !== "expo-dev-client";
  });
  return [...plugins, "./plugins/withAndroidProductionAutolinking.cjs"];
}

module.exports = ({ config } = {}) => {
  const sourceConfig = config ?? base;
  return {
    ...sourceConfig,
    plugins: pluginsForProfile(sourceConfig.plugins ?? []),
  };
};

module.exports.shouldIncludeDevClient = shouldIncludeDevClient;
