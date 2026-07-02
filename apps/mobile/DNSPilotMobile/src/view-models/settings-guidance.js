import { translate } from "./localization.js";

export function buildSettingsGuidance({ platform, applyPlan, locale = "en" }) {
  const plan = applyPlan ?? {};
  const notes = Array.isArray(plan.notes) ? plan.notes : [];
  const dnsServers = Array.isArray(plan.dns_servers) ? plan.dns_servers : [];
  const profileName = plan.profile_name ?? "selected DNS profile";
  const t = (key, params = {}) => translate(locale, key, params);
  const servers = dnsServers.join(", ") || t("settings.noneAvailable");
  const target = settingsTargetFor({ platform, plan });
  const actions = dnsServers.length > 0 ? guidanceActions({ platform, servers, target, t }) : [openSettingsAction({ target, t }), retestAction(t)];

  if (plan.disposition === "protect-current-dns") {
    return {
      mode: "protect",
      title: platform === "android-play" ? t("settings.protected.title.android") : t("settings.protected.title.ios"),
      canMutateSystemDns: false,
      steps: [t("settings.protected.step")],
      claims: [t("settings.protected.claim")],
      actions: [],
      notes,
    };
  }

  if (platform === "android-play") {
    return {
      mode: "guide",
      title: t("settings.android.title"),
      canMutateSystemDns: false,
      steps: [
        t("settings.android.review", { profileName }),
        t("settings.android.open"),
        t("settings.android.copy", { servers }),
        t("settings.android.retest"),
      ],
      claims: [t("settings.android.claim")],
      actions,
      notes,
    };
  }

  return {
    mode: "guide",
    title: t("settings.ios.title"),
    canMutateSystemDns: false,
    steps: [
      t("settings.ios.review", { profileName }),
      t("settings.ios.profile"),
      t("settings.ios.copy", { servers }),
      t("settings.ios.retest"),
    ],
    claims: [t("settings.ios.claim")],
    actions,
    notes,
  };
}

function guidanceActions({ platform, servers, target, t }) {
  return [
    {
      id: "prepare-os-apply",
      kind: "prepare-os-apply",
      label: platform === "android-play" ? t("settings.action.applyAndroid") : t("settings.action.prepareIos"),
      value: servers,
      target,
    },
    {
      id: "copy-dns-servers",
      kind: "copy",
      label: t("settings.action.copyDns"),
      value: servers,
    },
    openSettingsAction({ target, t }),
    retestAction(t),
  ];
}

function openSettingsAction({ target, t }) {
  return {
    id: "open-settings",
    kind: "open-settings",
    label: t("settings.action.openSettings"),
    target,
  };
}

function retestAction(t) {
  return {
    id: "retest-system-dns",
    kind: "retest-system-dns",
    label: t("settings.action.retestSystemDns"),
  };
}

function settingsTargetFor({ platform, plan }) {
  if (platform === "android-play") {
    return plan.private_dns_hostname || plan.dot_hostname ? "android-private-dns" : "android-network-settings";
  }
  return "ios-app-settings";
}

export function guidanceActionStatus({ actionKind, phase, locale = "en" }) {
  const t = (key) => translate(locale, key);
  if (phase === "running") {
    return actionKind === "retest-system-dns" ? t("settings.action.retesting") : t("settings.action.working");
  }
  if (phase === "failed") {
    return t("settings.action.failed");
  }
  if (actionKind === "prepare-os-apply") {
    return t("settings.action.prepared");
  }
  if (actionKind === "copy") {
    return t("settings.action.copied");
  }
  if (actionKind === "open-settings") {
    return t("settings.action.openedSettings");
  }
  return t("settings.action.retested");
}
