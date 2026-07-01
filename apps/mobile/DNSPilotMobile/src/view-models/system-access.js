import { translate } from "./localization.js";

export function buildSystemAccessPrompt({ platform, bridgeStatus = "unknown", locale = "en" }) {
  const t = (key, params = {}) => translate(locale, key, params);
  const isAndroid = platform === "android-play" || platform === "android-device";
  const checks = isAndroid ? androidChecks({ bridgeStatus, t }) : iosChecks({ bridgeStatus, t });
  return {
    shouldPrompt: true,
    title: t("systemAccess.title"),
    summary: isAndroid ? t("systemAccess.summary.android") : t("systemAccess.summary.ios"),
    checks,
    actions: isAndroid
      ? [
          {
            id: "open-network-settings",
            kind: "open-settings",
            target: "android-network-settings",
            label: t("systemAccess.action.openNetworkSettings"),
          },
          {
            id: "open-app-settings",
            kind: "open-settings",
            target: "android-app-settings",
            label: t("systemAccess.action.openAppSettings"),
          },
        ]
      : [
          {
            id: "open-app-settings",
            kind: "open-settings",
            target: "ios-app-settings",
            label: t("systemAccess.action.openAppSettings"),
          },
        ],
  };
}

function iosChecks({ bridgeStatus, t }) {
  return [
    {
      id: "local-network",
      label: t("systemAccess.check.localNetwork"),
      status: bridgeStatus === "success" ? "ready" : "needs-action",
      detail: t("systemAccess.detail.localNetwork"),
    },
    dnsApplyCheck(t),
    dnsFlushCheck(t),
  ];
}

function androidChecks({ bridgeStatus, t }) {
  return [
    {
      id: "network-access",
      label: t("systemAccess.check.networkAccess"),
      status: bridgeStatus === "success" ? "ready" : "unknown",
      detail: t("systemAccess.detail.networkAccess"),
    },
    {
      id: "private-dns",
      label: t("systemAccess.check.privateDns"),
      status: "os-gated",
      detail: t("systemAccess.detail.privateDns"),
    },
    dnsApplyCheck(t),
    dnsFlushCheck(t),
  ];
}

function dnsApplyCheck(t) {
  return {
    id: "dns-apply",
    label: t("systemAccess.check.dnsApply"),
    status: "os-gated",
    detail: t("systemAccess.detail.dnsApply"),
  };
}

function dnsFlushCheck(t) {
  return {
    id: "dns-flush",
    label: t("systemAccess.check.dnsFlush"),
    status: "unsupported",
    detail: t("systemAccess.detail.dnsFlush"),
  };
}
