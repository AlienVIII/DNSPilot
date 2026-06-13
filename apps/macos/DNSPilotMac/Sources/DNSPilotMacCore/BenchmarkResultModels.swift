import Foundation

public enum BenchmarkMeasurementScope: String, Decodable, Equatable {
    case dnsOnly = "dns-only"
    case dnsTCP = "dns-tcp"
    case dnsTCPTLS = "dns-tcp-tls"
}

public enum BenchmarkRecommendationMode: String, Decodable, Equatable {
    case fastestRawDNS = "fastest-raw-dns"
    case bestOverall = "best-overall"
}

public enum BenchmarkHealth: String, Decodable, Equatable {
    case healthy
    case degraded
    case failed
    case inconclusive
}

public enum BenchmarkConfidence: String, Decodable, Equatable {
    case high
    case medium
    case low
    case inconclusive
}

public struct BenchmarkResultPayload: Decodable, Equatable {
    public let summary: BenchmarkResultSummary
    public let runs: [BenchmarkResultRun]
    public let recommendation: BenchmarkRecommendation?
    public let savedHistoryID: String?
    public let warning: String

    private enum CodingKeys: String, CodingKey {
        case summary
        case runs
        case recommendation
        case savedHistoryID = "saved_history_id"
        case warning
    }
}

public struct BenchmarkResultSummary: Decodable, Equatable {
    public let measurementScope: BenchmarkMeasurementScope
    public let mode: BenchmarkRecommendationMode
    public let health: BenchmarkHealth
    public let primaryIssue: String
    public let canRecommend: Bool
    public let safetyNotes: [String]
    public let resolverCount: Int
    public let domainCount: Int
    public let attemptsPerRecord: Int
    public let timeoutMS: Int?
    public let dnsTimeoutMS: Int?
    public let connectTimeoutMS: Int?
    public let tlsHandshakeTimeoutMS: Int?
    public let connectPort: Int?
    public let maxConnectTargetsPerDomain: Int?
    public let tlsEnabled: Bool?
    public let trustStore: String?
    public let tlsSampleCount: Int?
    public let recommendedProfileID: String?
    public let recordFamily: BenchmarkRecordFamily?

    private enum CodingKeys: String, CodingKey {
        case measurementScope = "measurement_scope"
        case mode
        case health
        case primaryIssue = "primary_issue"
        case canRecommend = "can_recommend"
        case safetyNotes = "safety_notes"
        case resolverCount = "resolver_count"
        case domainCount = "domain_count"
        case attemptsPerRecord = "attempts_per_record"
        case timeoutMS = "timeout_ms"
        case dnsTimeoutMS = "dns_timeout_ms"
        case connectTimeoutMS = "connect_timeout_ms"
        case tlsHandshakeTimeoutMS = "tls_handshake_timeout_ms"
        case connectPort = "connect_port"
        case maxConnectTargetsPerDomain = "max_connect_targets_per_domain"
        case tlsEnabled = "tls_enabled"
        case trustStore = "trust_store"
        case tlsSampleCount = "tls_sample_count"
        case recommendedProfileID = "recommended_profile_id"
        case recordFamily = "ip_family"
    }

    public init(
        measurementScope: BenchmarkMeasurementScope,
        mode: BenchmarkRecommendationMode,
        health: BenchmarkHealth,
        primaryIssue: String,
        canRecommend: Bool,
        safetyNotes: [String],
        resolverCount: Int,
        domainCount: Int,
        attemptsPerRecord: Int,
        timeoutMS: Int?,
        dnsTimeoutMS: Int?,
        connectTimeoutMS: Int?,
        tlsHandshakeTimeoutMS: Int?,
        connectPort: Int?,
        maxConnectTargetsPerDomain: Int?,
        tlsEnabled: Bool?,
        trustStore: String?,
        tlsSampleCount: Int?,
        recommendedProfileID: String?,
        recordFamily: BenchmarkRecordFamily? = nil
    ) {
        self.measurementScope = measurementScope
        self.mode = mode
        self.health = health
        self.primaryIssue = primaryIssue
        self.canRecommend = canRecommend
        self.safetyNotes = safetyNotes
        self.resolverCount = resolverCount
        self.domainCount = domainCount
        self.attemptsPerRecord = attemptsPerRecord
        self.timeoutMS = timeoutMS
        self.dnsTimeoutMS = dnsTimeoutMS
        self.connectTimeoutMS = connectTimeoutMS
        self.tlsHandshakeTimeoutMS = tlsHandshakeTimeoutMS
        self.connectPort = connectPort
        self.maxConnectTargetsPerDomain = maxConnectTargetsPerDomain
        self.tlsEnabled = tlsEnabled
        self.trustStore = trustStore
        self.tlsSampleCount = tlsSampleCount
        self.recommendedProfileID = recommendedProfileID
        self.recordFamily = recordFamily
    }
}

public struct BenchmarkResultRun: Decodable, Equatable {
    public let profileID: String
    public let resolver: String
    public let metrics: BenchmarkResultMetrics
    public let caveats: [String]

    private enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case resolver
        case metrics
        case caveats
    }

    public init(
        profileID: String,
        resolver: String,
        metrics: BenchmarkResultMetrics,
        caveats: [String] = []
    ) {
        self.profileID = profileID
        self.resolver = resolver
        self.metrics = metrics
        self.caveats = caveats
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileID = try container.decode(String.self, forKey: .profileID)
        resolver = try container.decode(String.self, forKey: .resolver)
        metrics = try container.decode(BenchmarkResultMetrics.self, forKey: .metrics)
        caveats = try container.decodeIfPresent([String].self, forKey: .caveats) ?? []
    }
}

public struct BenchmarkResultMetrics: Decodable, Equatable {
    public let profileID: String
    public let medianDNSLatencyMS: Double?
    public let p95DNSLatencyMS: Double?
    public let failureRate: Double
    public let timeoutRate: Double
    public let medianConnectLatencyMS: Double?
    public let ipv4Health: Double
    public let ipv6Health: Double
    public let priorityFit: Double

    private enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case medianDNSLatencyMS = "median_dns_latency_ms"
        case p95DNSLatencyMS = "p95_dns_latency_ms"
        case failureRate = "failure_rate"
        case timeoutRate = "timeout_rate"
        case medianConnectLatencyMS = "median_connect_latency_ms"
        case ipv4Health = "ipv4_health"
        case ipv6Health = "ipv6_health"
        case priorityFit = "priority_fit"
    }
}

public struct BenchmarkRecommendation: Decodable, Equatable {
    public let profileID: String
    public let score: Double
    public let confidence: BenchmarkConfidence
    public let reasons: [String]
    public let caveats: [String]

    private enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case score
        case confidence
        case reasons
        case caveats
    }
}

public enum BenchmarkResultJSONDecoder {
    public static func decode(_ json: String) throws -> BenchmarkResultPayload {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(BenchmarkResultPayload.self, from: data)
    }
}
