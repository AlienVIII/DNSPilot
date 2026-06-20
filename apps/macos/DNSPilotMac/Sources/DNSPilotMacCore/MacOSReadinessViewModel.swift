public enum MacOSReadinessStatus: String, Equatable, Sendable {
    case ready
    case manual
    case blocked

    public var label: String {
        switch self {
        case .ready:
            "Ready"
        case .manual:
            "Manual"
        case .blocked:
            "Blocked"
        }
    }

    public var systemImage: String {
        switch self {
        case .ready:
            "checkmark.circle"
        case .manual:
            "hand.raised"
        case .blocked:
            "exclamationmark.triangle"
        }
    }
}

public struct MacOSReadinessRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: MacOSReadinessStatus
    public let detail: String

    public init(id: String, title: String, status: MacOSReadinessStatus, detail: String) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
    }

    public var statusLabel: String {
        status.label
    }

    public var systemImage: String {
        status.systemImage
    }
}

public struct MacOSPermissionReadinessViewModel: Equatable, Sendable {
    public let rows: [MacOSReadinessRow]

    public init(isPowerActionsEnabled: Bool) {
        rows = [
            MacOSReadinessRow(
                id: "network-client",
                title: "Network access",
                status: .ready,
                detail: "The store entitlement template includes App Sandbox outbound network client access for DNS and TCP checks."
            ),
            MacOSReadinessRow(
                id: "system-dns-settings",
                title: "System DNS settings",
                status: .manual,
                detail: "Store-safe builds open macOS Network Settings when user action is required; macOS does not provide a pre-grant permission for plain DNS edits."
            ),
            MacOSReadinessRow(
                id: "admin-apply-flush",
                title: "Admin apply / flush",
                status: .manual,
                detail: "Power builds ask for administrator approval only when you press Apply Now or Flush Now."
            ),
            MacOSReadinessRow(
                id: "power-mode-flag",
                title: "Power mode flag",
                status: isPowerActionsEnabled ? .ready : .manual,
                detail: isPowerActionsEnabled
                    ? "DNSPILOT_ENABLE_POWER_ACTIONS is enabled for this launch."
                    : "Launch with DNSPILOT_ENABLE_POWER_ACTIONS=1 to expose admin apply/flush actions."
            ),
            MacOSReadinessRow(
                id: "no-silent-mutation",
                title: "No silent mutation",
                status: .ready,
                detail: "DNS Pilot does not change system DNS without explicit confirmation and either Settings handoff or administrator approval."
            ),
        ]
    }

    public var copyText: String {
        var lines = ["DNS Pilot macOS permission readiness"]
        for row in rows {
            lines.append("- \(row.statusLabel): \(row.title) - \(row.detail)")
        }
        lines.append("Power actions request administrator approval only at the moment of apply/flush.")
        return lines.joined(separator: "\n")
    }
}

public struct MacOSPublishReadinessViewModel: Equatable, Sendable {
    public let rows: [MacOSReadinessRow]

    public init() {
        rows = [
            MacOSReadinessRow(
                id: "minimum-macos",
                title: "macOS minimum target",
                status: .ready,
                detail: "The package and bundle validator target macOS 14.0."
            ),
            MacOSReadinessRow(
                id: "store-sandbox",
                title: "App Store sandbox",
                status: .ready,
                detail: "Store entitlement templates keep App Sandbox enabled and allow outbound network client access."
            ),
            MacOSReadinessRow(
                id: "release-signing",
                title: "Release signing",
                status: .manual,
                detail: "Developer ID or Mac App Store signing identity and provisioning are required outside this worktree."
            ),
            MacOSReadinessRow(
                id: "app-store-entitlements",
                title: "App Store entitlement review",
                status: .manual,
                detail: "NetworkExtension DNS Settings entitlement and App Store metadata must be reviewed in Apple Developer/App Store Connect."
            ),
            MacOSReadinessRow(
                id: "privacy-copy",
                title: "Privacy and review notes",
                status: .manual,
                detail: "Explain DNS benchmarking, no silent DNS mutation, local storage, and optional Power edition separation in review notes."
            ),
            MacOSReadinessRow(
                id: "power-edition-split",
                title: "Power edition split",
                status: .ready,
                detail: "App Store edition remains guided; Power edition uses explicit administrator approval and should be distributed separately."
            ),
        ]
    }

    public var copyText: String {
        var lines = ["DNS Pilot publish checklist"]
        lines.append("App Store edition:")
        for row in rows where row.id != "power-edition-split" {
            lines.append("- \(row.statusLabel): \(row.title) - \(row.detail)")
        }
        lines.append("Power edition:")
        if let powerRow = rows.first(where: { $0.id == "power-edition-split" }) {
            lines.append("- \(powerRow.statusLabel): \(powerRow.title) - \(powerRow.detail)")
        }
        return lines.joined(separator: "\n")
    }
}
