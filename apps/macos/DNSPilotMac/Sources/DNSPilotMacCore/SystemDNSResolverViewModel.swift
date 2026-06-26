import Foundation

public struct SystemDNSResolverSnapshot: Equatable, Sendable {
    public let servers: [String]
    public let searchDomains: [String]
    public let supplementalResolverCount: Int
    public let loadedAt: Date?

    public init(
        servers: [String],
        searchDomains: [String],
        supplementalResolverCount: Int,
        loadedAt: Date?
    ) {
        self.servers = servers
        self.searchDomains = searchDomains
        self.supplementalResolverCount = supplementalResolverCount
        self.loadedAt = loadedAt
    }

    public static let unavailable = SystemDNSResolverSnapshot(
        servers: [],
        searchDomains: [],
        supplementalResolverCount: 0,
        loadedAt: nil
    )
}

public struct SystemDNSResolverViewModel: Equatable {
    public let snapshot: SystemDNSResolverSnapshot

    public init(snapshot: SystemDNSResolverSnapshot) {
        self.snapshot = snapshot
    }

    public var resolverLabel: String {
        guard !snapshot.servers.isEmpty else {
            return "Resolver: current macOS system resolver"
        }
        return "Resolver: \(snapshot.servers.joined(separator: ", "))"
    }

    public var detailLines: [String] {
        guard !snapshot.servers.isEmpty else {
            return ["DNS server addresses are unavailable; System DNS validation still uses the current macOS resolver path."]
        }

        var lines = [String]()
        if !snapshot.searchDomains.isEmpty {
            lines.append("Search domains: \(snapshot.searchDomains.joined(separator: ", "))")
        }
        if snapshot.supplementalResolverCount > 0 {
            lines.append("Supplemental/scoped resolvers: \(snapshot.supplementalResolverCount)")
        }
        lines.append("System DNS validation uses the current macOS resolver path, including VPN, MDM, and scoped DNS behavior.")
        return lines
    }

    public var copyText: String {
        var lines = ["Current macOS DNS"]
        if snapshot.servers.isEmpty {
            lines.append("DNS servers unavailable")
        } else {
            lines.append("DNS servers:")
            lines.append(contentsOf: snapshot.servers)
        }
        if !snapshot.searchDomains.isEmpty {
            lines.append("Search domains:")
            lines.append(contentsOf: snapshot.searchDomains)
        }
        if snapshot.supplementalResolverCount > 0 {
            lines.append("Supplemental/scoped resolvers: \(snapshot.supplementalResolverCount)")
        }
        lines.append("DNS Pilot has not changed system DNS.")
        return lines.joined(separator: "\n")
    }
}
