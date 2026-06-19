export function buildSettingsGuidance({ platform, applyPlan }) {
  const plan = applyPlan ?? {};
  const notes = Array.isArray(plan.notes) ? plan.notes : [];
  const dnsServers = Array.isArray(plan.dns_servers) ? plan.dns_servers : [];
  const profileName = plan.profile_name ?? "selected DNS profile";

  if (plan.disposition === "protect-current-dns") {
    return {
      mode: "protect",
      title: titleFor(platform, "Protected network detected"),
      canMutateSystemDns: false,
      steps: ["Keep current DNS settings. Do not offer apply prompts until protected-network signals clear."],
      claims: ["Protect current DNS on VPN, MDM, corporate DNS, or captive portal networks."],
      notes,
    };
  }

  if (platform === "android-play") {
    return {
      mode: "guide",
      title: "Android guided DNS settings",
      canMutateSystemDns: false,
      steps: [
        `Review ${profileName} after the foreground benchmark result.`,
        `Use Android Settings > Network & internet > Private DNS or network DNS settings where the device supports it.`,
        `Copy DNS servers for manual entry: ${dnsServers.join(", ") || "none available"}.`,
        "Retest with System DNS validation after the user changes settings.",
      ],
      claims: ["Guided settings only. No VpnService and no hidden DNS changes in the consumer app."],
      notes,
    };
  }

  return {
    mode: "guide",
    title: "iOS/iPadOS DNS Settings guidance",
    canMutateSystemDns: false,
    steps: [
      `Review ${profileName} after the foreground benchmark result.`,
      "Use a user-approved DNS Settings profile when NetworkExtension entitlement and review allow it.",
      `Copy DNS servers for manual/profile entry: ${dnsServers.join(", ") || "none available"}.`,
      "Retest with System DNS validation after the user enables the profile or changes settings.",
    ],
    claims: ["Guidance only for plain DNS. No DNSJumper-style system DNS switching."],
    notes,
  };
}

function titleFor(platform, suffix) {
  if (platform === "android-play") {
    return `Android ${suffix}`;
  }
  return `iOS/iPadOS ${suffix}`;
}
