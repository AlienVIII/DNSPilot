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
        savedHistoryLabel = result.savedHistoryID.map(Self.savedHistoryLabel)

        if result.summary.canRecommend,
           let recommendedProfileID = result.summary.recommendedProfileID ?? result.recommendation?.profileID {
            let candidateName = profileNames[recommendedProfileID] ?? recommendedProfileID
            if Self.shouldUseStrongRecommendation(health: result.summary.health, confidence: result.recommendation?.confidence) {
                recommendationLabel = "Recommended: \(candidateName)"
            } else {
                recommendationLabel = "Best measured candidate: \(candidateName)"
            }
        } else {
            recommendationLabel = "No recommendation"
        }

        if let confidence = result.recommendation?.confidence {
            confidenceLabel = "\(Self.confidenceLabel(for: confidence)) confidence"
        } else {
            confidenceLabel = "Inconclusive"
        }

        notes = Self.userFacingNotes(
            safetyNotes: result.summary.safetyNotes,
            commonFailureNote: Self.commonPartialFailureNote(for: result.runs),
            reasons: result.recommendation?.reasons ?? [],
            caveats: result.recommendation?.caveats ?? []
        )
    }

    private static func shouldUseStrongRecommendation(
        health: BenchmarkHealth,
        confidence: BenchmarkConfidence?
    ) -> Bool {
        guard health == .healthy else {
            return false
        }
        return confidence == .high || confidence == .medium
    }

    private static func userFacingNotes(
        safetyNotes: [String],
        commonFailureNote: String?,
        reasons: [String],
        caveats: [String]
    ) -> [String] {
        var seen = Set<String>()
        let commonNotes = commonFailureNote.map { [$0] } ?? []
        let notes = safetyNotes + commonNotes + reasons + caveats
        return notes.filter { note in
            guard !note.lowercased().hasPrefix("recommended profile:") else {
                return false
            }
            return seen.insert(note).inserted
        }
    }

    private static func commonPartialFailureNote(for runs: [BenchmarkResultRun]) -> String? {
        guard runs.count >= 2 else {
            return nil
        }

        let partialFailureRates = runs
            .map(\.metrics.failureRate)
            .filter { $0 > 0 && $0 < 1 }
        guard Double(partialFailureRates.count) / Double(runs.count) >= 0.6 else {
            return nil
        }

        let lowest = partialFailureRates.min() ?? 0
        let highest = partialFailureRates.max() ?? 0
        guard highest - lowest <= 0.10 else {
            return nil
        }

        return "Many candidates failed at a similar partial rate; this can indicate current network, VPN, firewall, captive portal, or IPv6 reachability limits rather than one bad DNS provider."
    }

    private static func savedHistoryLabel(for id: String) -> String {
        "Saved run: \(shortHistoryID(id))"
    }

    private static func shortHistoryID(_ id: String) -> String {
        let parts = id.split(separator: "-")
        let uuidGroupLengths = [8, 4, 4, 4, 12]
        if parts.count >= uuidGroupLengths.count + 1 {
            let tail = Array(parts.suffix(uuidGroupLengths.count))
            let hasUUIDTail = zip(tail, uuidGroupLengths).allSatisfy { part, length in
                part.count == length && part.allSatisfy(\.isHexDigit)
            }

            if hasUUIDTail {
                let readableParts = Array(parts.dropLast(uuidGroupLengths.count)) + [tail[0]]
                return "\(readableParts.joined(separator: "-"))..."
            }
        }

        guard id.count > 28 else {
            return id
        }
        return "\(id.prefix(25))..."
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
        if run.metrics.failureRate >= 1 {
            status = .failed
        } else if run.metrics.failureRate > 0 {
            status = .degraded
        } else {
            status = .success
        }
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
