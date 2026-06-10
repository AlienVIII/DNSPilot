public enum CatalogDNSProtocol: String, Decodable, Equatable {
    case plain
    case doh
    case dot
}

public enum CatalogFilteringType: String, Decodable, Equatable {
    case none
    case malware
    case family
    case ads
    case security
}

public struct CatalogProfile: Decodable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let ipv4Servers: [String]
    public let ipv6Servers: [String]
    public let `protocol`: CatalogDNSProtocol
    public let dohURL: String?
    public let dotHostname: String?
    public let filteringType: CatalogFilteringType
    public let tags: [String]
    public let useCase: String
    public let securityNotes: [String]

    public init(
        id: String,
        name: String,
        description: String,
        ipv4Servers: [String],
        ipv6Servers: [String],
        protocol: CatalogDNSProtocol,
        dohURL: String?,
        dotHostname: String?,
        filteringType: CatalogFilteringType,
        tags: [String],
        useCase: String,
        securityNotes: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ipv4Servers = ipv4Servers
        self.ipv6Servers = ipv6Servers
        self.protocol = `protocol`
        self.dohURL = dohURL
        self.dotHostname = dotHostname
        self.filteringType = filteringType
        self.tags = tags
        self.useCase = useCase
        self.securityNotes = securityNotes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ipv4Servers = "ipv4_servers"
        case ipv6Servers = "ipv6_servers"
        case `protocol`
        case dohURL = "doh_url"
        case dotHostname = "dot_hostname"
        case filteringType = "filtering_type"
        case tags
        case useCase = "use_case"
        case securityNotes = "security_notes"
    }
}

public struct CatalogTestSuite: Decodable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let domains: [String]
    public let tags: [String]

    public init(id: String, name: String, description: String, domains: [String], tags: [String]) {
        self.id = id
        self.name = name
        self.description = description
        self.domains = domains
        self.tags = tags
    }
}

public struct CatalogSnapshot: Decodable, Equatable {
    public let schemaVersion: Int
    public let profiles: [CatalogProfile]
    public let testSuites: [CatalogTestSuite]

    public init(
        schemaVersion: Int = ShellPayloadSchema.supportedVersion,
        profiles: [CatalogProfile],
        testSuites: [CatalogTestSuite]
    ) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
        self.testSuites = testSuites
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case profiles
        case testSuites
    }
}
