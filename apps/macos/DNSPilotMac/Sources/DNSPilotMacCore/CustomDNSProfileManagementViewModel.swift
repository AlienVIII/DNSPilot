public struct CustomDNSProfileManagementViewModel: Equatable, Sendable {
    public let rows: [CustomDNSProfileManagementRow]

    public init(profiles: [CatalogProfile]) {
        var seenIDs = Set<String>()
        rows = profiles
            .filter(Self.isEditableCustomPlainProfile)
            .filter { profile in
                seenIDs.insert(profile.id).inserted
            }
            .map(CustomDNSProfileManagementRow.init(profile:))
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
    public let ipv4ServersText: String
    public let ipv6ServersText: String

    public init(profile: CatalogProfile) {
        id = profile.id
        name = profile.name
        detailLabel = "\(profile.ipv4Servers.count) IPv4 / \(profile.ipv6Servers.count) IPv6"
        ipv4ServersText = profile.ipv4Servers.joined(separator: "\n")
        ipv6ServersText = profile.ipv6Servers.joined(separator: "\n")
    }
}
