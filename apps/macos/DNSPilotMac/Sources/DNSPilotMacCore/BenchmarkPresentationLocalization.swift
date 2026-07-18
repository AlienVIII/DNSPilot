import Foundation

public extension BenchmarkResultViewModel {
    func localizedScopeLabel(localizer: DNSPilotLocalizer) -> String {
        measurementScope.localizedLabel(localizer: localizer)
    }

    func localizedHealthLabel(localizer: DNSPilotLocalizer) -> String {
        health.localizedLabel(localizer: localizer)
    }

    func localizedConfidenceLabel(localizer: DNSPilotLocalizer) -> String {
        guard let recommendationConfidence else {
            return localizer.text(.confidenceInconclusive)
        }
        return localizer.formatted(
            .confidenceWithLevel,
            recommendationConfidence.localizedLabel(localizer: localizer)
        )
    }

    func localizedRecommendationLabel(localizer: DNSPilotLocalizer) -> String {
        if recommendsKeepingCurrentDNS {
            return localizer.text(.keepCurrentDNS)
        }
        if canRecommend, let recommendedProfileName {
            if health == .healthy,
               recommendationConfidence == .high || recommendationConfidence == .medium {
                return localizer.formatted(.recommendedProfile, recommendedProfileName)
            }
            return localizer.formatted(.bestMeasuredCandidate, recommendedProfileName)
        }
        return localizer.text(.noRecommendation)
    }

    func localizedFastestObservedLabel(localizer: DNSPilotLocalizer) -> String {
        guard let fastest = rows
            .filter({ row in
                guard let median = row.medianDNSLatencyMS else {
                    return false
                }
                return median.isFinite && row.failureRate < 1
            })
            .min(by: { lhs, rhs in
                let lhsMedian = lhs.medianDNSLatencyMS ?? .infinity
                let rhsMedian = rhs.medianDNSLatencyMS ?? .infinity
                if lhsMedian == rhsMedian {
                    return lhs.failureRate < rhs.failureRate
                }
                return lhsMedian < rhsMedian
            }),
            let median = fastest.medianDNSLatencyMS else {
            return localizer.text(.fastestObservedUnavailable)
        }
        return localizer.formatted(
            .fastestObservedDNS,
            fastest.name,
            Int(median.rounded()),
            Int((fastest.failureRate.clamped(to: 0...1) * 100).rounded())
        )
    }

    func localizedBalancedRecommendationLabel(localizer: DNSPilotLocalizer) -> String {
        let name = recommendedProfileName ?? localizedRecommendationLabel(localizer: localizer)
        return localizer.formatted(.balancedRecommendation, name)
    }

    func localizedSavedHistoryLabel(localizer: DNSPilotLocalizer) -> String? {
        guard let shortSavedHistoryID else {
            return nil
        }
        return localizer.formatted(.savedRun, shortSavedHistoryID)
    }

    func localizedRecordFamilyLabel(localizer: DNSPilotLocalizer) -> String? {
        recordFamily?.localizedLabel(localizer: localizer)
    }
}

public extension BenchmarkResultRow {
    func localizedFailureRateLabel(localizer: DNSPilotLocalizer) -> String {
        let base = localizer.formatted(
            .failedRate,
            Int((failureRate.clamped(to: 0...1) * 100).rounded())
        )
        var families = [String]()
        if ipv4Health < 0.75 {
            families.append("IPv4")
        }
        if ipv6Health < 0.75 {
            families.append("IPv6")
        }
        guard !families.isEmpty else {
            return base
        }
        return localizer.formatted(.failedRateWeakFamily, base, families.joined(separator: "/"))
    }

    func localizedDiagnosisLabel(localizer: DNSPilotLocalizer) -> String {
        let labels = issues.map { issue in
            switch issue {
            case .dnsLookupFailures:
                localizer.text(.diagnosisDNSLookupFailures)
            case .tcpPathFailures:
                localizer.text(.diagnosisTCPPathFailures)
            case .noUsableAddressAnswers:
                localizer.text(.diagnosisNoUsableAddresses)
            case .ipv4Weak:
                localizer.text(.diagnosisIPv4Weak)
            case .ipv6Weak:
                localizer.text(.diagnosisIPv6Weak)
            case .timeouts:
                localizer.text(.diagnosisTimeouts)
            case .allProbesFailed:
                localizer.text(.diagnosisAllProbesFailed)
            }
        }
        return labels.isEmpty ? localizer.text(.diagnosisNoIssues) : labels.joined(separator: ", ")
    }
}

public extension BenchmarkResultNextStepViewModel {
    func localizedTitle(localizer: DNSPilotLocalizer) -> String {
        switch kind {
        case .applyRecommended:
            localizer.text(.nextStepApplyRecommended)
        case .manualApplyUnavailable:
            localizer.text(.nextStepManualUnavailable)
        case .keepCurrentDNS:
            localizer.text(.nextStepKeepCurrentDNS)
        case .retest:
            localizer.text(.nextStepRetest)
        }
    }

    func localizedActionLabel(localizer: DNSPilotLocalizer) -> String {
        kind == .applyRecommended ? localizer.text(.copyDNSOpenSettings) : localizer.text(.copyNextStep)
    }

    func localizedLines(localizer: DNSPilotLocalizer) -> [String] {
        let unchanged = localizer.text(.nextStepNoSystemDNSChange)
        switch kind {
        case .applyRecommended:
            return [
                unchanged,
                localizer.formatted(.nextStepRecommendedProfile, recommendedProfileName ?? "DNS"),
                localizer.text(.nextStepApplyInstructions),
                localizer.text(.nextStepManagedNetworkWarning),
                localizer.text(.nextStepRetestAfterApply),
            ]
        case .manualApplyUnavailable:
            return [
                unchanged,
                localizer.text(.nextStepManualUnavailableDetail),
                localizer.text(.nextStepManualUnavailableAction),
            ]
        case .keepCurrentDNS:
            return [
                unchanged,
                localizer.text(.nextStepKeepCurrentDetail),
                localizer.text(.nextStepKeepCurrentAction),
            ]
        case .retest:
            return [
                unchanged,
                localizer.text(.nextStepRetestDetail),
                localizer.text(.nextStepRetestAction),
            ]
        }
    }
}

public extension BenchmarkHistoryRow {
    func localizedTitle(localizer: DNSPilotLocalizer) -> String {
        scope.localizedLabel(localizer: localizer)
    }

    func localizedDomainSummary(localizer: DNSPilotLocalizer) -> String {
        guard let first = domains.first else {
            return localizer.text(.historyNoDomains)
        }
        let remaining = domains.count - 1
        return remaining == 0 ? first : localizer.formatted(.historyDomainSummary, first, remaining)
    }

    func localizedResolverSummary(localizer: DNSPilotLocalizer) -> String {
        localizer.formatted(.historyResolverCount, resolverCount)
    }

    func localizedHealthLabel(localizer: DNSPilotLocalizer) -> String {
        health.localizedLabel(localizer: localizer)
    }

    func localizedRecommendationLabel(localizer: DNSPilotLocalizer) -> String {
        if keepsCurrentDNS {
            return localizer.text(.keepCurrentDNS)
        }
        if canRecommend, let recommendedProfileName {
            return health == .healthy
                ? localizer.formatted(.recommendedProfile, recommendedProfileName)
                : localizer.formatted(.bestMeasuredCandidate, recommendedProfileName)
        }
        return localizer.text(.noRecommendation)
    }

    func localizedApplyGuidanceLabel(localizer: DNSPilotLocalizer) -> String {
        if keepsCurrentDNS {
            return localizer.text(.historyDoNotApply)
        }
        return canRecommend && recommendedProfileName != nil
            ? localizer.text(.historyRetestBeforeApply)
            : localizer.text(.historyRunFreshBenchmark)
    }
}

public extension ApplyPlanViewModel {
    func localizedStatusLabel(localizer: DNSPilotLocalizer) -> String {
        switch plan.disposition {
        case .applyWithUserApproval:
            localizer.text(.applyPlanReady)
        case .guideOnly:
            localizer.text(.applyPlanGuided)
        case .protectCurrentDNS:
            localizer.text(.applyPlanProtected)
        case .unsupported:
            localizer.text(.applyPlanUnsupported)
        case .notRecommended:
            localizer.text(.applyPlanRetest)
        }
    }

    func localizedActionLabel(localizer: DNSPilotLocalizer) -> String {
        switch plan.disposition {
        case .applyWithUserApproval:
            localizer.text(.applyWithApproval)
        case .guideOnly:
            localizer.text(.copyDNSOpenSettings)
        case .protectCurrentDNS:
            localizer.text(.keepCurrentDNS)
        case .unsupported:
            localizer.text(.applyPlanUnsupported)
        case .notRecommended:
            localizer.text(.applyPlanRetest)
        }
    }

    func localizedHeadline(localizer: DNSPilotLocalizer) -> String {
        if let profileName = plan.profileName ?? plan.profileID {
            return localizer.formatted(.recommendedProfile, profileName)
        }
        return localizer.formatted(.applyPlanHeadline, localizedStatusLabel(localizer: localizer))
    }
}

public extension CustomDNSProfileManagementRow {
    func localizedDetailLabel(localizer: DNSPilotLocalizer) -> String {
        localizer.formatted(.customProfileServerCounts, ipv4ServerCount, ipv6ServerCount)
    }

    func localizedEditHelpLabel(localizer: DNSPilotLocalizer) -> String {
        hasReservedIDCollision ? localizer.text(.copyToNewProfileHelp) : localizer.text(.editProfileHelp)
    }

    func localizedWarningLabel(localizer: DNSPilotLocalizer) -> String? {
        hasReservedIDCollision ? localizer.text(.builtInIDConflict) : nil
    }
}

public extension CustomDomainSuiteManagementRow {
    func localizedDomainCountLabel(localizer: DNSPilotLocalizer) -> String {
        localizer.formatted(.suiteDomainCount, domainCount)
    }

    func localizedEditHelpLabel(localizer: DNSPilotLocalizer) -> String {
        hasReservedIDCollision ? localizer.text(.copyToNewSuiteHelp) : localizer.text(.editSuiteHelp)
    }

    func localizedWarningLabel(localizer: DNSPilotLocalizer) -> String? {
        hasReservedIDCollision ? localizer.text(.builtInIDConflict) : nil
    }
}

public extension BenchmarkMeasurementScope {
    func localizedLabel(localizer: DNSPilotLocalizer) -> String {
        switch self {
        case .dnsOnly:
            localizer.text(.scopeDNSOnly)
        case .dnsTCP:
            localizer.text(.scopeDNSTCP)
        case .dnsTCPTLS:
            localizer.text(.scopeDNSTCPTLS)
        }
    }
}

public extension BenchmarkPlanMode {
    func localizedLabel(localizer: DNSPilotLocalizer) -> String {
        switch self {
        case .dnsOnlyCompare:
            localizer.text(.modeDNSOnly)
        case .connectionPathCompare:
            localizer.text(.modeDNSTCP)
        case .systemDNSValidation:
            localizer.text(.modeSystemDNS)
        }
    }
}

public extension BenchmarkResolverTransport {
    func localizedSummaryLabel(localizer: DNSPilotLocalizer) -> String? {
        switch self {
        case .automatic:
            nil
        case .ipv4Only:
            localizer.text(.recordIPv4)
        case .ipv6Only:
            localizer.text(.recordIPv6)
        }
    }
}

public extension BenchmarkHealth {
    func localizedLabel(localizer: DNSPilotLocalizer) -> String {
        switch self {
        case .healthy:
            localizer.text(.healthHealthy)
        case .degraded:
            localizer.text(.healthDegraded)
        case .failed:
            localizer.text(.healthFailed)
        case .inconclusive:
            localizer.text(.healthInconclusive)
        }
    }
}

public extension BenchmarkConfidence {
    func localizedLabel(localizer: DNSPilotLocalizer) -> String {
        switch self {
        case .high:
            localizer.text(.confidenceHigh)
        case .medium:
            localizer.text(.confidenceMedium)
        case .low:
            localizer.text(.confidenceLow)
        case .inconclusive:
            localizer.text(.confidenceInconclusive)
        }
    }
}

public extension BenchmarkRecordFamily {
    func localizedLabel(localizer: DNSPilotLocalizer) -> String {
        switch self {
        case .both:
            localizer.text(.recordAAndAAAA)
        case .ipv4Only:
            localizer.text(.recordAOnly)
        case .ipv6Only:
            localizer.text(.recordAAAAOnly)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
