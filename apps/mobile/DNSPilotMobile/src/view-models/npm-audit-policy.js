const knownMetroImageSizeChain = new Set([
  "@expo/cli",
  "@expo/metro",
  "@expo/metro-config",
  "@react-native/community-cli-plugin",
  "@react-native/metro-config",
  "@react-native/virtualized-lists",
  "expo",
  "image-size",
  "metro",
  "metro-config",
  "metro-transform-worker",
  "react-native",
  "react-native-reanimated",
  "react-native-worklets",
]);

const knownImageSizeAdvisorySources = new Set([1138808, 1138809]);

export function assertNoUnapprovedHighAuditFindings(audit) {
  const unapproved = [];

  for (const [name, finding] of Object.entries(audit?.vulnerabilities ?? {})) {
    const severity = String(finding?.severity ?? "").toLowerCase();
    if (severity !== "high" && severity !== "critical") continue;

    if (severity === "critical" || !knownMetroImageSizeChain.has(name)) {
      unapproved.push(`${name} (${severity})`);
      continue;
    }

    const directAdvisories = (finding.via ?? []).filter((via) => typeof via === "object" && via !== null);
    const unexpectedSources = directAdvisories
      .map((via) => via.source)
      .filter((source) => name !== "image-size" || !knownImageSizeAdvisorySources.has(source));
    if (unexpectedSources.length > 0) {
      unapproved.push(`${name} (unexpected advisory source ${unexpectedSources.join(", ")})`);
    }
  }

  if (unapproved.length > 0) {
    throw new Error(`Unapproved production npm audit finding(s): ${unapproved.join(", ")}`);
  }
}

export function assertAuditResponseUsable(audit) {
  if (audit?.error) {
    throw new Error(`npm audit did not complete: ${audit.error.summary ?? audit.error.message ?? "unknown error"}`);
  }
}
