import Foundation

public struct BenchmarkHistoryPayload: Decodable, Equatable {
    public let db: String
    public let schemaVersion: Int
    public let benchmarkHistoryCount: Int
    public let records: [BenchmarkHistoryRecord]

    private enum CodingKeys: String, CodingKey {
        case db
        case schemaVersion = "schema_version"
        case benchmarkHistoryCount = "benchmark_history_count"
        case records = "benchmark_history"
    }
}

public struct BenchmarkHistoryRecord: Decodable, Equatable, Identifiable {
    public let id: String
    public let startedAt: String
    public let scope: BenchmarkMeasurementScope
    public let mode: BenchmarkRecommendationMode
    public let domains: [String]
    public let resolverProfileIDs: [String]
    public let metrics: [BenchmarkResultMetrics]
    public let gate: BenchmarkHistoryGate
    public let recommendationProfileID: String?
    public let notes: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
        case scope
        case mode
        case domains
        case resolverProfileIDs = "resolver_profile_ids"
        case metrics
        case gate
        case recommendationProfileID = "recommendation_profile_id"
        case notes
    }
}

public struct BenchmarkHistoryGate: Decodable, Equatable {
    public let canRecommend: Bool
    public let health: BenchmarkHealth
    public let primaryIssue: String
    public let notes: [String]

    private enum CodingKeys: String, CodingKey {
        case canRecommend = "can_recommend"
        case health
        case primaryIssue = "primary_issue"
        case notes
    }
}

public enum BenchmarkHistoryJSONDecoder {
    public static func decode(_ json: String) throws -> BenchmarkHistoryPayload {
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(BenchmarkHistoryPayload.self, from: data)
        try ShellPayloadSchema.validate(payload.schemaVersion)
        return payload
    }
}

public struct BenchmarkHistoryViewModel: Equatable {
    public let rows: [BenchmarkHistoryRow]

    public init(payload: BenchmarkHistoryPayload, catalog: CatalogSnapshot?) {
        let profileNames = Dictionary(
            uniqueKeysWithValues: (catalog?.profiles ?? []).map { ($0.id, $0.name) }
        )
        rows = payload.records.reversed().map { record in
            BenchmarkHistoryRow(record: record, profileNames: profileNames)
        }
    }
}

public struct BenchmarkHistoryRow: Equatable, Identifiable {
    public let id: String
    public let scope: BenchmarkMeasurementScope
    public let health: BenchmarkHealth
    public let domains: [String]
    public let resolverCount: Int
    public let canRecommend: Bool
    public let keepsCurrentDNS: Bool
    public let recommendedProfileName: String?
    public let title: String
    public let domainSummary: String
    public let resolverSummary: String
    public let healthLabel: String
    public let recommendationLabel: String
    public let applyGuidanceLabel: String

    init(record: BenchmarkHistoryRecord, profileNames: [String: String]) {
        id = record.id
        scope = record.scope
        health = record.gate.health
        domains = record.domains
        resolverCount = record.resolverProfileIDs.count
        canRecommend = record.gate.canRecommend
        title = Self.scopeLabel(for: record.scope)
        domainSummary = Self.summary(values: record.domains, empty: "No domains")
        resolverSummary = "\(record.resolverProfileIDs.count) resolver\(record.resolverProfileIDs.count == 1 ? "" : "s")"
        healthLabel = Self.healthLabel(for: record.gate.health)

        let shouldKeepCurrentDNS = Self.shouldKeepCurrentDNS(for: record)
        keepsCurrentDNS = shouldKeepCurrentDNS
        if shouldKeepCurrentDNS {
            recommendedProfileName = nil
            recommendationLabel = "Keep current DNS"
            applyGuidanceLabel = "Do not apply from this saved run"
        } else if record.gate.canRecommend,
                  let profileID = record.recommendationProfileID {
            let profileName = profileNames[profileID] ?? profileID
            recommendedProfileName = profileName
            if record.gate.health == .healthy {
                recommendationLabel = "Recommended: \(profileName)"
            } else {
                recommendationLabel = "Best measured: \(profileName)"
            }
            applyGuidanceLabel = "Retest before applying saved recommendation"
        } else {
            recommendedProfileName = nil
            recommendationLabel = "No recommendation"
            applyGuidanceLabel = "Run a fresh benchmark before applying DNS"
        }
    }

    private static func summary(values: [String], empty: String) -> String {
        guard let first = values.first else {
            return empty
        }
        let remainingCount = values.count - 1
        guard remainingCount > 0 else {
            return first
        }
        return "\(first) + \(remainingCount) more"
    }

    private static func shouldKeepCurrentDNS(for record: BenchmarkHistoryRecord) -> Bool {
        if record.gate.primaryIssue == "all-resolvers-low-reliability" {
            return true
        }
        guard record.gate.canRecommend,
              record.gate.health != .healthy,
              record.recommendationProfileID != nil,
              !record.metrics.isEmpty else {
            return false
        }
        return record.metrics.allSatisfy { $0.failureRate >= 0.5 }
    }

    private static func scopeLabel(for scope: BenchmarkMeasurementScope) -> String {
        switch scope {
        case .dnsOnly:
            "DNS only"
        case .dnsTCP:
            "DNS + TCP"
        case .dnsTCPTLS:
            "DNS + TCP + TLS"
        }
    }

    private static func healthLabel(for health: BenchmarkHealth) -> String {
        switch health {
        case .healthy:
            "Healthy"
        case .degraded:
            "Degraded"
        case .failed:
            "Failed"
        case .inconclusive:
            "Inconclusive"
        }
    }
}
