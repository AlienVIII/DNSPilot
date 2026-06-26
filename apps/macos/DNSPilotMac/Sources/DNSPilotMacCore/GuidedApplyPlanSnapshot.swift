import Foundation

public struct GuidedApplyPlanSnapshot: Codable, Equatable, Sendable {
    public let profileID: String?
    public let profileName: String?
    public let testedResolver: String?
    public let dnsServers: [String]
    public let restoreDNSServers: [String]
    public let restoreSearchDomains: [String]
    public let notes: [String]
    public let createdAt: Date

    public init(
        profileID: String?,
        profileName: String?,
        testedResolver: String?,
        dnsServers: [String],
        restoreDNSServers: [String] = [],
        restoreSearchDomains: [String] = [],
        notes: [String],
        createdAt: Date
    ) {
        self.profileID = profileID
        self.profileName = profileName
        self.testedResolver = testedResolver
        self.dnsServers = dnsServers
        self.restoreDNSServers = restoreDNSServers
        self.restoreSearchDomains = restoreSearchDomains
        self.notes = notes
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case profileID
        case profileName
        case testedResolver
        case dnsServers
        case restoreDNSServers
        case restoreSearchDomains
        case notes
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileID = try container.decodeIfPresent(String.self, forKey: .profileID)
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName)
        testedResolver = try container.decodeIfPresent(String.self, forKey: .testedResolver)
        dnsServers = try container.decode([String].self, forKey: .dnsServers)
        restoreDNSServers = try container.decodeIfPresent([String].self, forKey: .restoreDNSServers) ?? []
        restoreSearchDomains = try container.decodeIfPresent([String].self, forKey: .restoreSearchDomains) ?? []
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public static func make(
        from viewModel: ApplyPlanViewModel,
        currentDNSBeforeApply: SystemDNSResolverSnapshot? = nil,
        createdAt: Date = Date()
    ) -> GuidedApplyPlanSnapshot? {
        guard viewModel.plan.disposition == .guideOnly, !viewModel.plan.dnsServers.isEmpty else {
            return nil
        }
        return GuidedApplyPlanSnapshot(
            profileID: viewModel.plan.profileID,
            profileName: viewModel.plan.profileName,
            testedResolver: viewModel.plan.testedResolver,
            dnsServers: viewModel.plan.dnsServers,
            restoreDNSServers: currentDNSBeforeApply?.servers ?? [],
            restoreSearchDomains: currentDNSBeforeApply?.searchDomains ?? [],
            notes: viewModel.plan.notes,
            createdAt: createdAt
        )
    }

    public var displayName: String {
        profileName ?? profileID ?? "Recommended DNS"
    }

    public var dnsServerText: String {
        dnsServers.joined(separator: "\n")
    }

    public var restoreDNSServerText: String {
        restoreDNSServers.joined(separator: "\n")
    }

    public func isFresh(now: Date = Date(), maxAge: TimeInterval = 86_400) -> Bool {
        now.timeIntervalSince(createdAt) <= maxAge
    }

    public var copyText: String {
        var lines = [
            "DNS Pilot guided apply",
            "DNS Pilot has not changed system DNS.",
            "Profile: \(displayName)",
        ]
        if let testedResolver {
            lines.append("Tested resolver: \(testedResolver)")
        }
        if !restoreDNSServers.isEmpty {
            lines.append("Current DNS before apply:")
            lines.append(restoreDNSServerText)
        } else {
            lines.append("Current DNS before apply: unavailable")
        }
        if !restoreSearchDomains.isEmpty {
            lines.append("Search domains before apply:")
            lines.append(contentsOf: restoreSearchDomains)
        }
        lines.append("DNS servers:")
        lines.append(dnsServerText)
        lines.append("Steps:")
        lines.append("1. Open macOS Network Settings.")
        lines.append("2. Paste these DNS servers into the active network service.")
        lines.append("3. Apply changes, then flush/reconnect if results look stale.")
        lines.append("4. Run System DNS validation in DNS Pilot.")
        if !notes.isEmpty {
            lines.append("Notes:")
            lines.append(contentsOf: notes)
        }
        return lines.joined(separator: "\n")
    }
}

public final class GuidedApplyPlanStore {
    private let userDefaults: UserDefaults
    private let key: String
    private let maxAge: TimeInterval
    private let now: () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "DNSPilot.lastGuidedApplyPlan",
        maxAge: TimeInterval = 86_400,
        now: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.maxAge = maxAge
        self.now = now
    }

    public func load() -> GuidedApplyPlanSnapshot? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        do {
            let snapshot = try decoder.decode(GuidedApplyPlanSnapshot.self, from: data)
            guard snapshot.isFresh(now: now(), maxAge: maxAge) else {
                clear()
                return nil
            }
            return snapshot
        } catch {
            clear()
            return nil
        }
    }

    public func save(_ snapshot: GuidedApplyPlanSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }

    public func clear() {
        userDefaults.removeObject(forKey: key)
    }
}
