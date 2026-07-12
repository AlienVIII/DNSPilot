import { translate } from "./localization.js";

export function buildSystemAccessPrompt({ platform, bridgeStatus = "unknown", nativeRuntime = false, locale = "en" }) {
  const t = (key, params = {}) => translate(locale, key, params);
  const isAndroid = platform === "android-play" || platform === "android-device";
  const checks = isAndroid ? androidChecks({ bridgeStatus, nativeRuntime, t }) : iosChecks({ bridgeStatus, nativeRuntime, t });
  return {
    shouldPrompt: true,
    title: t("systemAccess.title"),
    summary: isAndroid
      ? t("systemAccess.summary.android")
      : nativeRuntime
        ? t("systemAccess.summary.iosNative")
        : t("systemAccess.summary.ios"),
    checks,
    actions: isAndroid
      ? [
          {
            id: "open-private-dns",
            kind: "open-settings",
            target: "android-private-dns",
            label: t("systemAccess.action.openPrivateDns"),
          },
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
          retestSystemDnsAction(t),
        ]
      : [
          {
            id: "open-app-settings",
            kind: "open-settings",
            target: "ios-app-settings",
            label: t("systemAccess.action.openAppSettings"),
          },
          retestSystemDnsAction(t),
        ],
  };
}

function iosChecks({ bridgeStatus, nativeRuntime, t }) {
  const networkCheck = nativeRuntime
    ? {
        id: "network-access",
        label: t("systemAccess.check.networkAccess"),
        status: "ready",
        detail: t("systemAccess.detail.nativeNetwork"),
      }
    : {
        id: "local-network",
        label: t("systemAccess.check.localNetwork"),
        status: bridgeStatus === "success" ? "ready" : "needs-action",
        detail: t("systemAccess.detail.localNetwork"),
      };
  return [
    networkCheck,
    dnsApplyCheck(t, "ios"),
    dnsFlushCheck(t),
  ];
}

function androidChecks({ bridgeStatus, nativeRuntime, t }) {
  return [
    {
      id: "network-access",
      label: t("systemAccess.check.networkAccess"),
      status: nativeRuntime || bridgeStatus === "success" ? "ready" : "unknown",
      detail: nativeRuntime ? t("systemAccess.detail.nativeNetwork") : t("systemAccess.detail.networkAccess"),
    },
    {
      id: "private-dns",
      label: t("systemAccess.check.privateDns"),
      status: "os-gated",
      detail: t("systemAccess.detail.privateDns"),
    },
    dnsApplyCheck(t, "android"),
    dnsFlushCheck(t),
  ];
}

function dnsApplyCheck(t, platform) {
  return {
    id: "dns-apply",
    label: t("systemAccess.check.dnsApply"),
    status: "os-gated",
    detail: t(`systemAccess.detail.dnsApply.${platform}`),
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

function retestSystemDnsAction(t) {
  return {
    id: "retest-system-dns",
    kind: "retest-system-dns",
    label: t("systemAccess.action.retestSystemDns"),
  };
}
