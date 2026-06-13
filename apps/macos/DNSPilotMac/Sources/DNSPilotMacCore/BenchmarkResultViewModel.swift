import Foundation

public struct BenchmarkResultViewModel: Equatable {
    public let scopeLabel: String
    public let healthLabel: String
    public let recommendationLabel: String
    public let confidenceLabel: String
    public let showsConnectionMetrics: Bool
    public let rows: [BenchmarkResultRow]
    public let notes: [String]
    public let warning: String
    public let savedHistoryLabel: String?

    public init(result: BenchmarkResultPayload, catalog: CatalogSnapshot?) {
        let profileNames = Dictionary(
            uniqueKeysWithValues: (catalog?.profiles ?? []).map { ($0.id, $0.name) }
        )

        scopeLabel = Self.scopeLabel(for: result.summary.measurementScope)
        healthLabel = Self.healthLabel(for: result.summary.health)
        showsConnectionMetrics = result.summary.measurementScope != .dnsOnly
        rows = result.runs.map { run in
            BenchmarkResultRow(run: run, displayName: profileNames[run.profileID])
        }
        warning = result.warning
        savedHistoryLabel = result.savedHistoryID.map { "Saved: \($0)" }

        if result.summary.canRecommend,
           let recommendedProfileID = result.summary.recommendedProfileID ?? result.recommendation?.profileID {
            recommendationLabel = "Recommended: \(profileNames[recommendedProfileID] ?? recommendedProfileID)"
        } else {
            recommendationLabel = "No recommendation"
        }

        if let confidence = result.recommendation?.confidence {
            confidenceLabel = "\(Self.confidenceLabel(for: confidence)) confidence"
        } else {
            confidenceLabel = "Inconclusive"
        }

        notes = result.summary.safetyNotes
            + (result.recommendation?.reasons ?? [])
            + (result.recommendation?.caveats ?? [])
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

    private static func confidenceLabel(for confidence: BenchmarkConfidence) -> String {
        switch confidence {
        case .high:
            "High"
        case .medium:
            "Medium"
        case .low:
            "Low"
        case .inconclusive:
            "Inconclusive"
        }
    }
}

public struct BenchmarkResultRow: Equatable, Identifiable {
    public let id: String
    public let profileID: String
    public let name: String
    public let resolver: String
    public let status: BenchmarkProgressStatus
    public let statusDetail: String
    public let medianDNSLatencyLabel: String
    public let p95DNSLatencyLabel: String
    public let medianConnectLatencyLabel: String
    public let failureRateLabel: String

    public init(run: BenchmarkResultRun, displayName: String?) {
        id = run.profileID
        profileID = run.profileID
        name = displayName ?? run.profileID
        resolver = run.resolver
        status = run.metrics.failureRate >= 1 ? .failed : .success
        statusDetail = "\(Self.percent(run.metrics.failureRate))% failed"
        medianDNSLatencyLabel = Self.latencyLabel(
            run.metrics.medianDNSLatencyMS,
            failureRate: run.metrics.failureRate
        )
        p95DNSLatencyLabel = Self.latencyLabel(
            run.metrics.p95DNSLatencyMS,
            failureRate: run.metrics.failureRate
        )
        medianConnectLatencyLabel = Self.latencyLabel(
            run.metrics.medianConnectLatencyMS,
            failureRate: run.metrics.failureRate
        )
        failureRateLabel = "\(Self.percent(run.metrics.failureRate))% failed"
    }

    private static func latencyLabel(_ value: Double?, failureRate: Double) -> String {
        guard let value, value.isFinite else {
            return "n/a"
        }
        if failureRate >= 1, value <= 0 {
            return "n/a"
        }
        return "\(Int(value.rounded())) ms"
    }

    private static func percent(_ value: Double) -> Int {
        Int((value.clamped(to: 0...1) * 100).rounded())
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
