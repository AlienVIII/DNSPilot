const { withEntitlementsPlist } = require("@expo/config-plugins");

const ENTITLEMENT = "com.apple.developer.networking.networkextension";
const DNS_SETTINGS = "dns-settings";

function withIosDnsSettings(config) {
  return withEntitlementsPlist(config, (nextConfig) => {
    const current = nextConfig.modResults[ENTITLEMENT] ?? [];
    nextConfig.modResults[ENTITLEMENT] = [...new Set([...current, DNS_SETTINGS])];
    return nextConfig;
  });
}

module.exports = withIosDnsSettings;
module.exports.ENTITLEMENT = ENTITLEMENT;
module.exports.DNS_SETTINGS = DNS_SETTINGS;
