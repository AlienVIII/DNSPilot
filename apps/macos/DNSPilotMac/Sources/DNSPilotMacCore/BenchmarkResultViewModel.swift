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
    public let fullSavedHistoryID: String?
    public let recordFamilyLabel: String?
    public let recommendedProfileName: String?
    public let recommendedDNSSettings: BenchmarkRecommendedDNSSettings?
    public let recommendsKeepingCurrentDNS: Bool
    public let hasActionableRecommendation: Bool

    public init(result: BenchmarkResultPayload, catalog: CatalogSnapshot?) {
        let catalogProfiles = catalog?.profiles ?? []
        let profileNames = Dictionary(uniqueKeysWithValues: catalogProfiles.map { ($0.id, $0.name) })
        let profilesByID = Dictionary(uniqueKeysWithValues: catalogProfiles.map { ($0.id, $0) })

        scopeLabel = Self.scopeLabel(for: result.summary.measurementScope)
        healthLabel = Self.healthLabel(for: result.summary.health)
        showsConnectionMetrics = result.summary.measurementScope != .dnsOnly
        rows = result.runs.map { run in
            BenchmarkResultRow(run: run, displayName: profileNames[run.profileID])
        }
        warning = result.warning
        savedHistoryLabel = result.savedHistoryID.map(Self.savedHistoryLabel)
        fullSavedHistoryID = result.savedHistoryID
        recordFamilyLabel = result.summary.recordFamily?.displayLabel

        let recommendedProfileID = result.summary.recommendedProfileID ?? result.recommendation?.profileID
        let recommendedCandidateName = recommendedProfileID.map { profileNames[$0] ?? $0 }
        recommendedProfileName = recommendedCandidateName
        let shouldProtectCurrentDNS = Self.shouldProtectCurrentDNS(
            summary: result.summary,
            runs: result.runs,
            hasMeasuredCandidate: recommendedCandidateName != nil
        )
        let blockedRecommendationLabel = Self.blockedRecommendationLabel(for: result.summary.primaryIssue)
        recommendsKeepingCurrentDNS = shouldProtectCurrentDNS || blockedRecommendationLabel == "Keep current DNS"
        let actionableRecommendation = result.summary.canRecommend
            && recommendedCandidateName != nil
            && !recommendsKeepingCurrentDNS
            && Self.shouldUseStrongRecommendation(
                health: result.summary.health,
                confidence: result.recommendation?.confidence
            )
        hasActionableRecommendation = actionableRecommendation
        if actionableRecommendation,
           let recommendedProfileID,
           let recommendedProfile = profilesByID[recommendedProfileID],
           recommendedProfile.protocol == .plain {
            recommendedDNSSettings = BenchmarkRecommendedDNSSettings(
                profileID: recommendedProfileID,
                profileName: recommendedCandidateName ?? recommendedProfile.name,
                testedResolver: result.runs.first { $0.profileID == recommendedProfileID }?.resolver,
                ipv4Servers: recommendedProfile.ipv4Servers,
                ipv6Servers: recommendedProfile.ipv6Servers
            )
        } else {
            recommendedDNSSettings = nil
        }
        let bestMeasuredNote: String?
        if shouldProtectCurrentDNS, let recommendedCandidateName {
            bestMeasuredNote = "Best measured candidate during this run: \(recommendedCandidateName)."
        } else {
            bestMeasuredNote = nil
        }
        let commonFailureNote = Self.commonPartialFailureNote(for: result.runs)
        let ipFamilyActionNote = Self.ipFamilyActionNote(for: result.runs)

        if recommendsKeepingCurrentDNS {
            recommendationLabel = "Keep current DNS"
        } else if result.summary.canRecommend,
                  let candidateName = recommendedCandidateName {
            if Self.shouldUseStrongRecommendation(health: result.summary.health, confidence: result.recommendation?.confidence) {
                recommendationLabel = "Recommended: \(candidateName)"
            } else {
                recommendationLabel = "Best measured candidate: \(candidateName)"
            }
        } else if let blockedLabel = blockedRecommendationLabel {
            recommendationLabel = blockedLabel
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
            bestMeasuredNote: bestMeasuredNote,
            commonFailureNote: commonFailureNote,
            ipFamilyActionNote: ipFamilyActionNote,
            reasons: result.recommendation?.reasons ?? [],
            caveats: (result.recommendation?.caveats ?? []) + result.runs.flatMap(\.caveats)
        )
    }

    public var resultReport: String {
        resultReportText(elapsedMS: nil)
    }

    public func resultReportText(elapsedMS: Int?) -> String {
        var lines = [
            "Benchmark result",
            "Health: \(healthLabel)",
            "Scope: \(scopeLabel)",
            "Confidence: \(confidenceLabel)",
            "Recommendation: \(recommendationLabel)",
        ]
        let nextStep = BenchmarkResultNextStepViewModel(result: self)
        lines.append(nextStep.title)
        lines.append(contentsOf: nextStep.lines)
        if let elapsedMS {
            lines.append("Completed in: \(BenchmarkElapsedTimeFormatter.label(milliseconds: elapsedMS))")
        }
        if let fullSavedHistoryID {
            lines.append("Saved run: \(fullSavedHistoryID)")
        }
        if let recordFamilyLabel {
            lines.append("DNS records: \(recordFamilyLabel)")
        }
        if let recommendedDNSSettings {
            lines.append("")
            lines.append("Recommended DNS servers:")
            lines.append(recommendedDNSSettings.copyText)
        }

        lines.append("")
        lines.append("Candidates:")
        for row in rows {
            var parts = [
                row.name,
                row.resolver,
                "DNS median \(row.medianDNSLatencyLabel)",
                "DNS P95 \(row.p95DNSLatencyLabel)",
            ]
            if showsConnectionMetrics {
                parts.append("TCP median \(row.medianConnectLatencyLabel)")
            }
            parts.append("Failure \(row.failureRateLabel)")
            parts.append("Diagnosis \(row.diagnosisLabel)")
            lines.append(parts.joined(separator: " | "))
        }

        if !notes.isEmpty {
            lines.append("")
            lines.append("Notes:")
            lines.append(contentsOf: notes)
        }

        if !warning.isEmpty {
            lines.append("")
            lines.append("Warning:")
            lines.append(warning)
        }

        return lines.joined(separator: "\n")
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

    private static func shouldProtectCurrentDNS(
        summary: BenchmarkResultSummary,
        runs: [BenchmarkResultRun],
        hasMeasuredCandidate: Bool
    ) -> Bool {
        guard summary.canRecommend, hasMeasuredCandidate, summary.health != .healthy, !runs.isEmpty else {
            return false
        }
        return runs.allSatisfy { $0.metrics.failureRate >= 0.5 }
    }

    private static func blockedRecommendationLabel(for primaryIssue: String) -> String? {
        switch primaryIssue {
        case "all-resolvers-low-reliability":
            "Keep current DNS"
        default:
            nil
        }
    }

    private static func userFacingNotes(
        safetyNotes: [String],
        bestMeasuredNote: String?,
        commonFailureNote: String?,
        ipFamilyActionNote: String?,
        reasons: [String],
        caveats: [String]
    ) -> [String] {
        var seen = Set<String>()
        let measuredNotes = bestMeasuredNote.map { [$0] } ?? []
        let commonNotes = commonFailureNote.map { [$0] } ?? []
        let familyNotes = ipFamilyActionNote.map { [$0] } ?? []
        let notes = safetyNotes + measuredNotes + commonNotes + familyNotes + reasons + caveats
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

    private static func ipFamilyActionNote(for runs: [BenchmarkResultRun]) -> String? {
        guard runs.count >= 2 else {
            return nil
        }

        let weakIPv6Count = runs.filter { run in
            run.metrics.failureRate > 0 && run.metrics.ipv6Health < 0.75 && run.metrics.ipv4Health >= 0.75
        }.count
        guard Double(weakIPv6Count) / Double(runs.count) >= 0.6 else {
            return nil
        }

        return "IPv6 looks weak across candidates; try DNS records: A only and retest before changing DNS."
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

public struct BenchmarkRecommendedDNSSettings: Equatable {
    public let profileID: String
    public let profileName: String
    public let testedResolver: String?
    public let ipv4Servers: [String]
    public let ipv6Servers: [String]

    public var allServers: [String] {
        ipv4Servers + ipv6Servers
    }

    public var hasServers: Bool {
        !allServers.isEmpty
    }

    public var serverListText: String {
        allServers.joined(separator: "\n")
    }

    public var copyText: String {
        var lines = [
            "Profile: \(profileName)",
        ]
        if let testedResolver {
            lines.append("Tested resolver: \(testedResolver)")
        }
        if !ipv4Servers.isEmpty {
            lines.append("IPv4 DNS:")
            lines.append(contentsOf: ipv4Servers)
        }
        if !ipv6Servers.isEmpty {
            lines.append("IPv6 DNS:")
            lines.append(contentsOf: ipv6Servers)
        }
        lines.append("DNS Pilot has not changed system DNS. Paste these manually only if this network is not managed by VPN, MDM, or corporate policy.")
        return lines.joined(separator: "\n")
    }

    public var displayLines: [String] {
        var lines = [String]()
        if let testedResolver {
            lines.append("Tested resolver: \(testedResolver).")
        }
        if !ipv4Servers.isEmpty {
            lines.append("IPv4 to paste: \(ipv4Servers.joined(separator: ", ")).")
        }
        if !ipv6Servers.isEmpty {
            lines.append("IPv6 to paste: \(ipv6Servers.joined(separator: ", ")).")
        }
        if allServers.count > 1 {
            lines.append("Only the resolver used in this run was measured directly; extra provider servers are fallback entries.")
        }
        return lines
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
    public let diagnosisLabel: String

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
        failureRateLabel = Self.failureRateLabel(for: run.metrics)
        diagnosisLabel = Self.diagnosisLabel(for: run)
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

    private static func failureRateLabel(for metrics: BenchmarkResultMetrics) -> String {
        let base = "\(percent(metrics.failureRate))% failed"
        guard metrics.failureRate > 0 else {
            return base
        }

        var weakFamilies = [String]()
        if metrics.ipv4Health < 0.75 {
            weakFamilies.append("IPv4")
        }
        if metrics.ipv6Health < 0.75 {
            weakFamilies.append("IPv6")
        }
        guard !weakFamilies.isEmpty else {
            return base
        }
        return "\(base) (\(weakFamilies.joined(separator: "/")) weak)"
    }

    private static func diagnosisLabel(for run: BenchmarkResultRun) -> String {
        var issues = [String]()
        let caveatText = run.caveats.joined(separator: " ").lowercased()

        if caveatText.contains("dns lookups failed") {
            issues.append("DNS lookup failures")
        }
        if caveatText.contains("failed tcp connect") {
            issues.append("TCP path failures")
        }
        if caveatText.contains("no usable a/aaaa") {
            issues.append("No usable A/AAAA answers")
        }
        if run.metrics.ipv4Health < 0.75 {
            issues.append("IPv4 weak")
        }
        if run.metrics.ipv6Health < 0.75 {
            issues.append("IPv6 weak")
        }
        if run.metrics.timeoutRate > 0 {
            issues.append("timeouts")
        }
        if run.metrics.failureRate >= 1, issues.isEmpty {
            issues.append("All probes failed")
        }

        return issues.isEmpty ? "No issues" : issues.joined(separator: ", ")
    }
}

public struct BenchmarkResultNextStepViewModel: Equatable {
    public let title: String
    public let actionLabel: String
    public let canOpenNetworkSettings: Bool
    public let dnsSettings: BenchmarkRecommendedDNSSettings?
    public let lines: [String]

    public init(result: BenchmarkResultViewModel) {
        if result.hasActionableRecommendation, let recommendedProfileName = result.recommendedProfileName {
            title = "Next step: Apply recommended DNS manually"
            actionLabel = "Open Network Settings"
            canOpenNetworkSettings = true
            dnsSettings = result.recommendedDNSSettings
            lines = [
                "DNS Pilot has not changed system DNS.",
                "Recommended profile: \(recommendedProfileName).",
                "Copy the DNS servers, open Network Settings, then paste them into the active network service DNS list.",
                "Only change DNS after checking VPN, MDM, captive portal, and corporate network requirements.",
                "After changing DNS manually, flush cache and run the benchmark again.",
            ]
        } else if result.recommendsKeepingCurrentDNS {
            title = "Next step: Keep current DNS"
            actionLabel = "Copy Next Step"
            canOpenNetworkSettings = false
            dnsSettings = nil
            lines = [
                "DNS Pilot has not changed system DNS.",
                "This run is not reliable enough to change DNS from it.",
                "Retest with DNS + TCP, A only, or a cleaner network before applying a resolver.",
            ]
        } else {
            title = "Next step: Retest before changing DNS"
            actionLabel = "Copy Next Step"
            canOpenNetworkSettings = false
            dnsSettings = nil
            lines = [
                "DNS Pilot has not changed system DNS.",
                "No resolver is strong enough to apply from this run.",
                "Try DNS + TCP, adjust DNS records, or check firewall, VPN, and captive portal state.",
            ]
        }
    }

    public var copyText: String {
        let dnsLines = dnsSettings.map { ["", "Recommended DNS servers:", $0.copyText] } ?? []
        return ([title] + lines + dnsLines).joined(separator: "\n")
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
