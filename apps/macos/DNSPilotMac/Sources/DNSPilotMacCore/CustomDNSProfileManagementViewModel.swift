public struct CustomDNSProfileManagementViewModel: Equatable, Sendable {
    public let rows: [CustomDNSProfileManagementRow]

    public init(profiles: [CatalogProfile], reservedProfileIDs: Set<String>? = nil) {
        var seenIDs = Set<String>()
        let reservedIDs = reservedProfileIDs ?? Set(
            profiles
                .filter { !Self.isEditableCustomPlainProfile($0) }
                .map(\.id)
        )
        rows = profiles
            .filter(Self.isEditableCustomPlainProfile)
            .filter { profile in
                seenIDs.insert(profile.id).inserted
            }
            .map { profile in
                CustomDNSProfileManagementRow(
                    profile: profile,
                    hasReservedIDCollision: reservedIDs.contains(profile.id)
                )
            }
    }

    private static func isEditableCustomPlainProfile(_ profile: CatalogProfile) -> Bool {
        profile.protocol == .plain
            && (profile.useCase == "custom" || profile.tags.contains("custom"))
    }
}

public struct CustomDNSProfileManagementRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let detailLabel: String
    public let ipv4ServerCount: Int
    public let ipv6ServerCount: Int
    public let ipv4ServersText: String
    public let ipv6ServersText: String
    public let opensAsNewProfile: Bool
    public let editHelpLabel: String
    public let warningLabel: String?
    public let hasReservedIDCollision: Bool

    public init(profile: CatalogProfile, hasReservedIDCollision: Bool = false) {
        id = profile.id
        name = profile.name
        ipv4ServerCount = profile.ipv4Servers.count
        ipv6ServerCount = profile.ipv6Servers.count
        detailLabel = "\(profile.ipv4Servers.count) IPv4 / \(profile.ipv6Servers.count) IPv6"
        ipv4ServersText = profile.ipv4Servers.joined(separator: "\n")
        ipv6ServersText = profile.ipv6Servers.joined(separator: "\n")
        opensAsNewProfile = hasReservedIDCollision
        self.hasReservedIDCollision = hasReservedIDCollision
        editHelpLabel = hasReservedIDCollision ? "Copy to new profile" : "Edit profile"
        warningLabel = hasReservedIDCollision
            ? "Built-in ID conflict. Edit creates a new custom-* copy; delete this legacy row after saving."
            : nil
    }
}
