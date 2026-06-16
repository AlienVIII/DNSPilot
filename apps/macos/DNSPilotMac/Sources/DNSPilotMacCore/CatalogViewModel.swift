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

    public var profileSummaries: [CatalogProfileSummary] {
        catalog?.profiles.map(CatalogProfileSummary.init(profile:)) ?? []
    }

    public var testSuiteSummaries: [CatalogTestSuiteSummary] {
        catalog?.testSuites.map(CatalogTestSuiteSummary.init(testSuite:)) ?? []
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

public struct CatalogProfileSummary: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let serverSummary: String
    public let filteringLabel: String

    public init(profile: CatalogProfile) {
        id = profile.id
        name = profile.name
        description = profile.description
        serverSummary = "\(profile.ipv4Servers.count) IPv4 / \(profile.ipv6Servers.count) IPv6"
        filteringLabel = Self.label(for: profile.filteringType)
    }

    private static func label(for filteringType: CatalogFilteringType) -> String {
        switch filteringType {
        case .none:
            "Unfiltered"
        case .malware:
            "Malware"
        case .family:
            "Family"
        case .ads:
            "Ads"
        case .security:
            "Security"
        }
    }
}

public struct CatalogTestSuiteSummary: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let domainCountLabel: String

    public init(testSuite: CatalogTestSuite) {
        id = testSuite.id
        name = testSuite.name
        description = testSuite.description
        domainCountLabel = testSuite.domains.count == 1
            ? "1 domain"
            : "\(testSuite.domains.count) domains"
    }
}

public struct PreviewCatalogBridge: DNSPilotCatalogBridge {
    public init() {}

    public func loadCatalog() -> CatalogSnapshot {
        CatalogSnapshot(
            profiles: [
                Self.profile(
                    id: "cloudflare",
                    name: "Cloudflare",
                    description: "Fast unfiltered public DNS.",
                    ipv4Servers: ["1.1.1.1", "1.0.0.1"],
                    ipv6Servers: ["2606:4700:4700::1111", "2606:4700:4700::1001"],
                    filteringType: .none,
                    tags: ["general", "unfiltered"]
                ),
                Self.profile(
                    id: "cloudflare-malware",
                    name: "Cloudflare Malware Blocking",
                    description: "Cloudflare DNS with malware blocking.",
                    ipv4Servers: ["1.1.1.2", "1.0.0.2"],
                    ipv6Servers: ["2606:4700:4700::1112", "2606:4700:4700::1002"],
                    filteringType: .malware,
                    tags: ["security", "filtered"]
                ),
                Self.profile(
                    id: "cloudflare-family",
                    name: "Cloudflare Family",
                    description: "Cloudflare DNS with malware and adult-content filtering.",
                    ipv4Servers: ["1.1.1.3", "1.0.0.3"],
                    ipv6Servers: ["2606:4700:4700::1113", "2606:4700:4700::1003"],
                    filteringType: .family,
                    tags: ["family", "filtered"]
                ),
                Self.profile(
                    id: "google-public-dns",
                    name: "Google Public DNS",
                    description: "Google unfiltered public DNS.",
                    ipv4Servers: ["8.8.8.8", "8.8.4.4"],
                    ipv6Servers: ["2001:4860:4860::8888", "2001:4860:4860::8844"],
                    filteringType: .none,
                    tags: ["general", "unfiltered"]
                ),
                Self.profile(
                    id: "quad9",
                    name: "Quad9",
                    description: "Security-oriented DNS that blocks known malicious domains.",
                    ipv4Servers: ["9.9.9.9", "149.112.112.112"],
                    ipv6Servers: ["2620:fe::fe", "2620:fe::9"],
                    filteringType: .security,
                    tags: ["security", "filtered"]
                ),
                Self.profile(
                    id: "opendns",
                    name: "OpenDNS",
                    description: "Cisco OpenDNS public resolver.",
                    ipv4Servers: ["208.67.222.222", "208.67.220.220"],
                    ipv6Servers: ["2620:119:35::35", "2620:119:53::53"],
                    filteringType: .none,
                    tags: ["general", "unfiltered"]
                ),
                Self.profile(
                    id: "opendns-familyshield",
                    name: "OpenDNS FamilyShield",
                    description: "OpenDNS resolver preconfigured for family filtering.",
                    ipv4Servers: ["208.67.222.123", "208.67.220.123"],
                    ipv6Servers: [],
                    filteringType: .family,
                    tags: ["family", "filtered"]
                ),
                Self.profile(
                    id: "adguard-dns",
                    name: "AdGuard DNS",
                    description: "Ad-blocking and privacy-oriented DNS.",
                    ipv4Servers: ["94.140.14.14", "94.140.15.15"],
                    ipv6Servers: ["2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"],
                    filteringType: .ads,
                    tags: ["ads", "filtered"]
                ),
                Self.profile(
                    id: "cleanbrowsing-family",
                    name: "CleanBrowsing Family",
                    description: "Family filtering DNS profile.",
                    ipv4Servers: ["185.228.168.168", "185.228.169.168"],
                    ipv6Servers: ["2a0d:2a00:1::", "2a0d:2a00:2::"],
                    filteringType: .family,
                    tags: ["family", "filtered"]
                ),
                Self.profile(
                    id: "fpt-telecom-dns",
                    name: "FPT Telecom DNS",
                    description: "Vietnam ISP DNS from FPT Telecom.",
                    ipv4Servers: ["210.245.24.20", "210.245.24.22"],
                    ipv6Servers: ["2405:4800:0:1::1", "2405:4800:0:1::2"],
                    filteringType: .none,
                    tags: ["vietnam", "isp", "unfiltered"]
                ),
                Self.profile(
                    id: "vnpt-dns",
                    name: "VNPT DNS",
                    description: "Vietnam ISP DNS commonly used on VNPT networks.",
                    ipv4Servers: ["203.162.4.191", "203.162.4.190"],
                    ipv6Servers: [],
                    filteringType: .none,
                    tags: ["vietnam", "isp", "unfiltered"]
                ),
                Self.profile(
                    id: "viettel-dns",
                    name: "Viettel DNS",
                    description: "Vietnam ISP DNS commonly used on Viettel networks.",
                    ipv4Servers: ["203.113.131.1", "203.113.131.2"],
                    ipv6Servers: [],
                    filteringType: .none,
                    tags: ["vietnam", "isp", "unfiltered"]
                ),
            ],
            testSuites: [
                Self.suite(
                    id: "general",
                    name: "General Browsing",
                    description: "Common browsing, video, Apple, and CDN checks.",
                    domains: ["google.com", "youtube.com", "facebook.com", "apple.com", "cloudflare.com"],
                    tags: ["general"]
                ),
                Self.suite(
                    id: "developer",
                    name: "Developer",
                    description: "GitHub, npm, Expo, and Docker workflow checks.",
                    domains: ["github.com", "api.github.com", "registry.npmjs.org", "npmjs.com", "expo.dev", "docker.com"],
                    tags: ["developer"]
                ),
                Self.suite(
                    id: "azure-microsoft",
                    name: "Azure / Microsoft",
                    description: "Microsoft login, Azure portal, APIs, storage, and CDN checks.",
                    domains: [
                        "portal.azure.com",
                        "management.azure.com",
                        "login.microsoftonline.com",
                        "dev.azure.com",
                        "azureedge.net",
                        "blob.core.windows.net",
                        "microsoft.com",
                        "office.com",
                    ],
                    tags: ["developer", "cloud", "microsoft"]
                ),
                Self.suite(
                    id: "google-firebase",
                    name: "Google / Firebase",
                    description: "Firebase and Google API checks.",
                    domains: [
                        "firebase.googleapis.com",
                        "firestore.googleapis.com",
                        "fcm.googleapis.com",
                        "googleapis.com",
                        "accounts.google.com",
                    ],
                    tags: ["developer", "cloud", "google"]
                ),
                Self.suite(
                    id: "vietnam-daily",
                    name: "Vietnam / Daily",
                    description: "Vietnamese commerce, media, messaging, and general browsing checks.",
                    domains: ["vnexpress.net", "shopee.vn", "tiki.vn", "zalo.me", "google.com", "youtube.com"],
                    tags: ["vietnam", "daily"]
                ),
            ]
        )
    }

    private static func profile(
        id: String,
        name: String,
        description: String,
        ipv4Servers: [String],
        ipv6Servers: [String],
        filteringType: CatalogFilteringType,
        tags: [String]
    ) -> CatalogProfile {
        CatalogProfile(
            id: id,
            name: name,
            description: description,
            ipv4Servers: ipv4Servers,
            ipv6Servers: ipv6Servers,
            protocol: .plain,
            dohURL: nil,
            dotHostname: nil,
            filteringType: filteringType,
            tags: tags,
            useCase: filteringType == .none ? "performance" : "filtering",
            securityNotes: filteringType == .none ? [] : ["Filtered DNS may intentionally block some domains."]
        )
    }

    private static func suite(
        id: String,
        name: String,
        description: String,
        domains: [String],
        tags: [String]
    ) -> CatalogTestSuite {
        CatalogTestSuite(
            id: id,
            name: name,
            description: description,
            domains: domains,
            tags: tags
        )
    }
}
