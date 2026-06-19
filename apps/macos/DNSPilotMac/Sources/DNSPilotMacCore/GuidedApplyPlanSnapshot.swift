import Foundation

public struct GuidedApplyPlanSnapshot: Codable, Equatable, Sendable {
    public let profileID: String?
    public let profileName: String?
    public let testedResolver: String?
    public let dnsServers: [String]
    public let notes: [String]
    public let createdAt: Date

    public init(
        profileID: String?,
        profileName: String?,
        testedResolver: String?,
        dnsServers: [String],
        notes: [String],
        createdAt: Date
    ) {
        self.profileID = profileID
        self.profileName = profileName
        self.testedResolver = testedResolver
        self.dnsServers = dnsServers
        self.notes = notes
        self.createdAt = createdAt
    }

    public static func make(
        from viewModel: ApplyPlanViewModel,
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

    public var copyText: String {
        var lines = [
            "DNS Pilot guided apply",
            "DNS Pilot has not changed system DNS.",
            "Profile: \(displayName)",
        ]
        if let testedResolver {
            lines.append("Tested resolver: \(testedResolver)")
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
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "DNSPilot.lastGuidedApplyPlan"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() -> GuidedApplyPlanSnapshot? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        do {
            return try decoder.decode(GuidedApplyPlanSnapshot.self, from: data)
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
