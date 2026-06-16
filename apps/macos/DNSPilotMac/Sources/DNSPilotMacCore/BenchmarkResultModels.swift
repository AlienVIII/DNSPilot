import Foundation

public enum BenchmarkMeasurementScope: String, Decodable, Equatable, Sendable {
    case dnsOnly = "dns-only"
    case dnsTCP = "dns-tcp"
    case dnsTCPTLS = "dns-tcp-tls"
}

public enum BenchmarkRecommendationMode: String, Decodable, Equatable, Sendable {
    case fastestRawDNS = "fastest-raw-dns"
    case bestOverall = "best-overall"
}

public enum BenchmarkHealth: String, Decodable, Equatable, Sendable {
    case healthy
    case degraded
    case failed
    case inconclusive
}

public enum BenchmarkConfidence: String, Decodable, Equatable, Sendable {
    case high
    case medium
    case low
    case inconclusive
}

public struct BenchmarkResultPayload: Decodable, Equatable, Sendable {
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

public struct BenchmarkResultSummary: Decodable, Equatable, Sendable {
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

public struct BenchmarkResultRun: Decodable, Equatable, Sendable {
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

public struct BenchmarkResultMetrics: Decodable, Equatable, Sendable {
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

public struct BenchmarkRecommendation: Decodable, Equatable, Sendable {
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
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(BenchmarkResultPayload.self, from: data)
        } catch let primaryError {
            guard (try? decoder.decode(BenchmarkPayloadScopeProbe.self, from: data).scope) == "system-dns-validation" else {
                throw primaryError
            }
            return try SystemDNSValidationPayloadAdapter.adapt(
                decoder.decode(SystemDNSValidationPayload.self, from: data)
            )
        }
    }
}

private struct BenchmarkPayloadScopeProbe: Decodable {
    let scope: String?
}

private struct SystemDNSValidationPayload: Decodable {
    let scope: String
    let preflight: SystemDNSValidationPreflight?
    let metrics: BenchmarkResultMetrics
    let samples: [SystemDNSValidationSample]
    let ipFamily: BenchmarkRecordFamily?
    let warning: String

    private enum CodingKeys: String, CodingKey {
        case scope
        case preflight
        case metrics
        case samples
        case ipFamily = "ip_family"
        case warning
    }
}

private struct SystemDNSValidationPreflight: Decodable {
    let notes: [String]
}

private struct SystemDNSValidationSample: Decodable {
    let domain: String
    let recordType: String

    private enum CodingKeys: String, CodingKey {
        case domain
        case recordType = "record_type"
    }
}

private enum SystemDNSValidationPayloadAdapter {
    static func adapt(_ payload: SystemDNSValidationPayload) throws -> BenchmarkResultPayload {
        guard payload.scope == "system-dns-validation" else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Unsupported benchmark payload scope '\(payload.scope)'."
                )
            )
        }

        let domainCount = Set(payload.samples.map(\.domain)).count
        let recordFamily = payload.ipFamily
        let attemptsPerRecord = Self.attemptsPerRecord(
            sampleCount: payload.samples.count,
            domainCount: domainCount,
            recordFamily: recordFamily
        )
        let notes = Self.safetyNotes(from: payload.preflight?.notes ?? [])
        return BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsOnly,
                mode: .fastestRawDNS,
                health: Self.health(for: payload.metrics),
                primaryIssue: Self.primaryIssue(for: payload.metrics),
                canRecommend: false,
                safetyNotes: notes,
                resolverCount: 1,
                domainCount: domainCount,
                attemptsPerRecord: attemptsPerRecord,
                timeoutMS: nil,
                dnsTimeoutMS: nil,
                connectTimeoutMS: nil,
                tlsHandshakeTimeoutMS: nil,
                connectPort: nil,
                maxConnectTargetsPerDomain: nil,
                tlsEnabled: nil,
                trustStore: nil,
                tlsSampleCount: nil,
                recommendedProfileID: nil,
                recordFamily: recordFamily
            ),
            runs: [
                BenchmarkResultRun(
                    profileID: payload.metrics.profileID,
                    resolver: "macOS system resolver",
                    metrics: payload.metrics,
                    caveats: notes
                ),
            ],
            recommendation: nil,
            savedHistoryID: nil,
            warning: payload.warning
        )
    }

    private static func safetyNotes(from preflightNotes: [String]) -> [String] {
        var notes = preflightNotes
        notes.append("System DNS validation does not produce a resolver recommendation.")
        return uniquePreservingOrder(notes)
    }

    private static func health(for metrics: BenchmarkResultMetrics) -> BenchmarkHealth {
        if metrics.failureRate >= 1.0 {
            return .failed
        }
        if metrics.failureRate > 0.0 || metrics.timeoutRate > 0.0 {
            return .degraded
        }
        return .healthy
    }

    private static func primaryIssue(for metrics: BenchmarkResultMetrics) -> String {
        if metrics.failureRate >= 1.0 {
            return "all-resolvers-failed"
        }
        if metrics.failureRate > 0.0 || metrics.timeoutRate > 0.0 {
            return "partial-failure"
        }
        return "none"
    }

    private static func attemptsPerRecord(
        sampleCount: Int,
        domainCount: Int,
        recordFamily: BenchmarkRecordFamily?
    ) -> Int {
        let recordTypeCount = recordFamily?.recordTypeCount ?? 1
        let denominator = max(domainCount * recordTypeCount, 1)
        return max(sampleCount / denominator, 1)
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            guard seen.insert(value).inserted else {
                continue
            }
            result.append(value)
        }
        return result
    }
}
