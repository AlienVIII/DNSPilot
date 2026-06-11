public enum BenchmarkPlanMode: Equatable {
    case dnsOnlyCompare
    case connectionPathCompare
}

public struct BenchmarkPlanValidation: Equatable {
    public let canRun: Bool
    public let issues: [String]

    public init(issues: [String]) {
        self.issues = issues
        canRun = issues.isEmpty
    }
}

public struct BenchmarkPlanViewModel: Equatable {
    public let catalog: CatalogSnapshot
    public let selectedProfileIDs: [String]
    public let selectedSuiteID: String?
    public let customDomains: [String]
    public let attempts: Int
    public let mode: BenchmarkPlanMode

    public var domains: [String] {
        let suiteDomains = selectedSuiteID.flatMap { id in
            catalog.testSuites.first { $0.id == id }?.domains
        } ?? []
        return Self.uniquePreservingOrder(suiteDomains + customDomains)
    }

    public var validation: BenchmarkPlanValidation {
        var issues: [String] = []
        if plainResolvers.isEmpty {
            issues.append("Select at least one plain DNS profile.")
        }
        if domains.isEmpty {
            issues.append("Select a test suite or add custom domains.")
        }
        if attempts < 1 {
            issues.append("Attempts must be at least 1.")
        }
        return BenchmarkPlanValidation(issues: issues)
    }

    public var commandArguments: [String] {
        var args = [mode == .dnsOnlyCompare ? "compare" : "path-compare"]
        for resolver in plainResolvers {
            args.append("--resolver")
            args.append("\(resolver.id)=\(resolver.socketAddress)")
        }
        for domain in domains {
            args.append("--domain")
            args.append(domain)
        }
        args.append("--attempts")
        args.append(String(attempts))
        return args
    }

    private var plainResolvers: [PlainResolver] {
        selectedProfileIDs.compactMap { id in
            guard let profile = catalog.profiles.first(where: { $0.id == id }),
                  profile.protocol == .plain
            else {
                return nil
            }
            if let ipv4 = profile.ipv4Servers.first {
                return PlainResolver(id: profile.id, socketAddress: "\(ipv4):53")
            }
            if let ipv6 = profile.ipv6Servers.first {
                return PlainResolver(id: profile.id, socketAddress: "[\(ipv6)]:53")
            }
            return nil
        }
    }

    public init(
        catalog: CatalogSnapshot,
        selectedProfileIDs: [String],
        selectedSuiteID: String?,
        customDomains: [String],
        attempts: Int,
        mode: BenchmarkPlanMode
    ) {
        self.catalog = catalog
        self.selectedProfileIDs = selectedProfileIDs
        self.selectedSuiteID = selectedSuiteID
        self.customDomains = customDomains
        self.attempts = attempts
        self.mode = mode
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let normalized = value.lowercased()
            guard seen.insert(normalized).inserted else {
                continue
            }
            result.append(value)
        }
        return result
    }
}

private struct PlainResolver: Equatable {
    let id: String
    let socketAddress: String
}
