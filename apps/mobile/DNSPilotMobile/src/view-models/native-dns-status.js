export function buildNativeDnsStatus(status) {
  const available = Boolean(status?.available);
  const installed = available && Boolean(status?.installed);
  const enabled = installed && Boolean(status?.enabled);

  return {
    availabilityKey: available ? "policy.nativeDns.status.available" : "policy.nativeDns.status.unavailable",
    installedKey: installed ? "policy.nativeDns.status.installed" : "policy.nativeDns.status.notInstalled",
    enabledKey: enabled ? "policy.nativeDns.status.enabled" : "policy.nativeDns.status.disabled",
    tone: enabled ? "green" : installed ? "amber" : "red",
  };
}
