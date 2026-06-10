public protocol DNSPilotCatalogBridge {
    func loadCatalog() throws -> CatalogSnapshot
}

public struct CatalogViewModel {
    public let catalog: CatalogSnapshot?
    public let loadErrorMessage: String?

    public var profileCount: Int {
        catalog?.profiles.count ?? 0
    }

    public var testSuiteCount: Int {
        catalog?.testSuites.count ?? 0
    }

    public var filteredProfileCount: Int {
        catalog?.profiles.filter { $0.filteringType != .none }.count ?? 0
    }

    public var hasAzureSuite: Bool {
        catalog?.testSuites.contains { $0.id == "azure-microsoft" } ?? false
    }

    public init(bridge: DNSPilotCatalogBridge = PreviewCatalogBridge()) {
        do {
            catalog = try bridge.loadCatalog()
            loadErrorMessage = nil
        } catch {
            catalog = nil
            loadErrorMessage = error.localizedDescription
        }
    }
}

public struct PreviewCatalogBridge: DNSPilotCatalogBridge {
    public init() {}

    public func loadCatalog() -> CatalogSnapshot {
        CatalogSnapshot(
            profiles: [
                CatalogProfile(
                    id: "cloudflare",
                    name: "Cloudflare",
                    description: "Fast unfiltered public DNS.",
                    ipv4Servers: ["1.1.1.1", "1.0.0.1"],
                    ipv6Servers: ["2606:4700:4700::1111"],
                    protocol: .plain,
                    dohURL: nil,
                    dotHostname: nil,
                    filteringType: .none,
                    tags: ["general", "unfiltered"],
                    useCase: "performance",
                    securityNotes: []
                ),
                CatalogProfile(
                    id: "quad9",
                    name: "Quad9",
                    description: "Security-oriented DNS that blocks known malicious domains.",
                    ipv4Servers: ["9.9.9.9", "149.112.112.112"],
                    ipv6Servers: ["2620:fe::fe"],
                    protocol: .plain,
                    dohURL: nil,
                    dotHostname: nil,
                    filteringType: .security,
                    tags: ["security", "filtered"],
                    useCase: "filtering",
                    securityNotes: ["Filtered DNS may intentionally block some domains."]
                ),
            ],
            testSuites: [
                CatalogTestSuite(
                    id: "azure-microsoft",
                    name: "Azure / Microsoft",
                    description: "Microsoft login, Azure portal, APIs, storage, and CDN checks.",
                    domains: ["portal.azure.com", "login.microsoftonline.com"],
                    tags: ["developer", "cloud", "microsoft"]
                )
            ]
        )
    }
}
