export const deviceTargets = Object.freeze([
  { label: "iOS device", value: "ios-device" },
  { label: "Android device", value: "android-device" },
  { label: "iOS Simulator", value: "ios-simulator" },
  { label: "Android emulator", value: "android-emulator" },
  { label: "Web", value: "web" },
]);

const realDeviceTargets = new Set(["ios-device", "android-device"]);

export function normalizeBridgeUrl(value) {
  const text = String(value ?? "").trim();
  if (!text) {
    return "";
  }
  const withScheme = /^[a-z][a-z0-9+.-]*:\/\//i.test(text) ? text : `http://${text}`;
  try {
    const parsed = new URL(withScheme);
    parsed.pathname = parsed.pathname.replace(/\/+$/, "");
    parsed.search = "";
    parsed.hash = "";
    return parsed.toString().replace(/\/$/, "");
  } catch {
    return withScheme.replace(/\/+$/, "");
  }
}

export function buildDeviceSetupPlan({ target = "ios-device", bridgeUrl = "", health = null } = {}) {
  const normalizedBridgeUrl = normalizeBridgeUrl(bridgeUrl);
  const host = hostFor(normalizedBridgeUrl);
  const isLocalhost = host === "localhost" || host === "127.0.0.1" || host === "::1";
  const isAndroidEmulatorBridge = host === "10.0.2.2";
  const isPrivateLan = isPrivateIpv4(host);
  const isRealDevice = realDeviceTargets.has(target);
  const bridge = bridgeStatus({
    target,
    health,
    isLocalhost,
    isAndroidEmulatorBridge,
    isPrivateLan,
    normalizedBridgeUrl,
  });

  return {
    target,
    bridgeUrl: normalizedBridgeUrl,
    bridge,
    recommendedPreset: recommendedPreset({ target, bridge, isPrivateLan, isAndroidEmulatorBridge }),
    permission: permissionForTarget(target),
    policy: {
      canMutateSystemDns: false,
      usesVpnService: false,
      canClaimSpeedImprovement: false,
      mode: "guided-settings",
    },
    realDevice: isRealDevice,
  };
}

function bridgeStatus({ target, health, isLocalhost, isAndroidEmulatorBridge, isPrivateLan, normalizedBridgeUrl }) {
  if (!normalizedBridgeUrl) {
    return { status: "idle", code: "bridge-url-missing" };
  }
  if (realDeviceTargets.has(target) && isLocalhost) {
    return { status: "failed", code: "localhost-not-device-reachable" };
  }
  if (target === "android-emulator" && !isAndroidEmulatorBridge) {
    return { status: "running", code: "android-emulator-needs-10-0-2-2" };
  }
  if (realDeviceTargets.has(target) && !isPrivateLan) {
    return { status: "running", code: "device-needs-private-lan" };
  }
  if (health?.ok) {
    return { status: "success", code: "bridge-ready" };
  }
  return { status: "running", code: "bridge-not-verified" };
}

function recommendedPreset({ target, bridge, isPrivateLan, isAndroidEmulatorBridge }) {
  if (bridge.code === "localhost-not-device-reachable" || bridge.code === "device-needs-private-lan") {
    return "mac-lan";
  }
  if (target === "android-emulator" && !isAndroidEmulatorBridge) {
    return "android-emulator";
  }
  if (isPrivateLan || isAndroidEmulatorBridge || bridge.code === "bridge-ready") {
    return "current";
  }
  return "localhost";
}

function permissionForTarget(target) {
  if (target === "ios-device" || target === "ios-simulator") {
    return {
      status: "running",
      code: "ios-local-network",
      runtimePromptExpected: target === "ios-device",
    };
  }
  if (target === "android-device" || target === "android-emulator") {
    return {
      status: "success",
      code: "android-normal-network",
      runtimePromptExpected: false,
    };
  }
  return {
    status: "success",
    code: "web-browser-network",
    runtimePromptExpected: false,
  };
}

function hostFor(value) {
  try {
    return new URL(value).hostname;
  } catch {
    return "";
  }
}

function isPrivateIpv4(value) {
  const parts = String(value ?? "").split(".").map(Number);
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) {
    return false;
  }
  return (
    parts[0] === 10 ||
    (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) ||
    (parts[0] === 192 && parts[1] === 168)
  );
}
