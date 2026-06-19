public enum ProductGoalReadinessStatus: String, Equatable, Sendable {
    case supported
    case storeSafeGuided
    case estimated

    public var label: String {
        switch self {
        case .supported:
            "Supported"
        case .storeSafeGuided:
            "Store-safe guided"
        case .estimated:
            "Estimate"
        }
    }

    public var systemImage: String {
        switch self {
        case .supported:
            "checkmark.circle"
        case .storeSafeGuided:
            "hand.raised"
        case .estimated:
            "gauge.with.dots.needle.bottom.50percent"
        }
    }
}

public struct ProductGoalReadinessRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: ProductGoalReadinessStatus
    public let summary: String
    public let caveat: String

    public init(
        id: String,
        title: String,
        status: ProductGoalReadinessStatus,
        summary: String,
        caveat: String
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.summary = summary
        self.caveat = caveat
    }

    public var statusLabel: String {
        status.label
    }

    public var systemImage: String {
        status.systemImage
    }
}

public struct ProductGoalReadinessViewModel: Equatable, Sendable {
    public let rows: [ProductGoalReadinessRow]

    public init(rows: [ProductGoalReadinessRow] = Self.defaultRows) {
        self.rows = rows
    }

    public static let defaultRows: [ProductGoalReadinessRow] = [
        ProductGoalReadinessRow(
            id: "fastest-dns",
            title: "Fastest DNS check",
            status: .supported,
            summary: "Benchmark ranks observed DNS latency and reports the fastest observed candidate.",
            caveat: "Fastest DNS is a connection-path estimate, not a full browser or app speed claim."
        ),
        ProductGoalReadinessRow(
            id: "balanced-dns",
            title: "Balanced DNS recommendation",
            status: .supported,
            summary: "Recommendation favors reliability, confidence, and safe keep-current decisions over raw speed.",
            caveat: "VPN, MDM, captive portal, IPv6 reachability, and Secure DNS can reduce confidence."
        ),
        ProductGoalReadinessRow(
            id: "apply-selected-dns",
            title: "Apply selected DNS",
            status: .storeSafeGuided,
            summary: "Selected plain DNS profiles can be copied and opened in macOS Network Settings after confirmation.",
            caveat: "True one-click system mutation is available only in Power edition paths such as DNSPILOT_ENABLE_POWER_ACTIONS=1 or a future privileged helper."
        ),
        ProductGoalReadinessRow(
            id: "flush-dns",
            title: "Flush DNS",
            status: .storeSafeGuided,
            summary: "DNS Pilot provides a confirmed, copyable flush checklist for the current macOS build.",
            caveat: "Real cache flush requires admin authorization through DNSPILOT_ENABLE_POWER_ACTIONS=1 or a trusted helper outside the store-safe app."
        ),
        ProductGoalReadinessRow(
            id: "saved-domains",
            title: "Saved domain suites",
            status: .supported,
            summary: "Built-in Azure, YouTube, GitHub, ChatGPT, and custom domain suites are available.",
            caveat: "Domains should be edited when a company, game, or SaaS vendor changes hostnames."
        ),
        ProductGoalReadinessRow(
            id: "game-server-checks",
            title: "Game server checks",
            status: .estimated,
            summary: "Game Ping covers Dota 2 SEA, CS2, and Riot/League endpoints with DNS + TCP probes.",
            caveat: "This is not ICMP ping or in-match UDP latency; some game traffic uses private routing."
        ),
    ]
}
