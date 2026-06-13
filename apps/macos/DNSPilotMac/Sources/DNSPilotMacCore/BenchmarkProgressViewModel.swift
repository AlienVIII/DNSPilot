public enum BenchmarkFailureStep: String, Equatable, Sendable {
    case preparingBenchmark
    case resolvingDNS
    case measuringConnection
    case parsingResult
    case savingHistory

    public var label: String {
        switch self {
        case .preparingBenchmark:
            "Preparing benchmark"
        case .resolvingDNS:
            "Resolving DNS"
        case .measuringConnection:
            "Measuring TCP"
        case .parsingResult:
            "Parsing result"
        case .savingHistory:
            "Saving history"
        }
    }
}

public struct BenchmarkExecutionFailure: Equatable, Sendable, ExpressibleByStringLiteral {
    public let message: String
    public let failedStep: BenchmarkFailureStep
    public let suggestion: String
    public let debugLog: String

    public init(
        message: String,
        failedStep: BenchmarkFailureStep,
        suggestion: String? = nil,
        debugLog: String
    ) {
        self.message = message
        self.failedStep = failedStep
        self.suggestion = suggestion ?? Self.defaultSuggestion(for: failedStep)
        self.debugLog = debugLog
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(message: value, failedStep: .preparingBenchmark, debugLog: value)
    }

    public func issueReport(modeLabel: String, elapsedMS: Int?) -> String {
        var lines = [
            "Benchmark failed",
            "Mode: \(modeLabel)",
            "Failed at: \(failedStep.label)",
            "Reason: \(message)",
            "Suggestion: \(suggestion)",
        ]
        if let elapsedMS {
            lines.append("Elapsed: \(elapsedMS) ms")
        }
        lines.append("")
        lines.append("Debug log:")
        lines.append(debugLog)
        return lines.joined(separator: "\n")
    }

    private static func defaultSuggestion(for step: BenchmarkFailureStep) -> String {
        switch step {
        case .preparingBenchmark:
            "Check selected profiles, target domains, and CLI availability."
        case .resolvingDNS:
            "Try DNS + TCP or check resolver, firewall, VPN, or network configuration."
        case .measuringConnection:
            "Check network reachability, firewall, VPN, captive portal, or try DNS only."
        case .parsingResult:
            "Keep the debug log and verify the CLI output schema matches the app version."
        case .savingHistory:
            "Check Application Support storage permissions and available disk space."
        }
    }
}

public enum BenchmarkProgressStatus: String, Equatable, Sendable {
    case idle
    case running
    case success
    case degraded
    case failed
}

public struct BenchmarkProgressStepViewModel: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: BenchmarkProgressStatus

    public init(id: String, title: String, status: BenchmarkProgressStatus) {
        self.id = id
        self.title = title
        self.status = status
    }
}

public struct BenchmarkProgressResolverTarget: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let resolver: String

    public init(id: String, name: String, resolver: String) {
        self.id = id
        self.name = name
        self.resolver = resolver
    }
}

public struct BenchmarkResolverStatusViewModel: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let resolver: String
    public let status: BenchmarkProgressStatus
    public let detail: String

    public init(
        id: String,
        name: String,
        resolver: String,
        status: BenchmarkProgressStatus,
        detail: String
    ) {
        self.id = id
        self.name = name
        self.resolver = resolver
        self.status = status
        self.detail = detail
    }
}

public struct BenchmarkProgressPlanSummary: Equatable, Sendable {
    public let resolverCount: Int
    public let domainCount: Int
    public let attempts: Int
    public let dnsTimeoutMS: Int
    public let connectTimeoutMS: Int
    public let maxConnectTargetsPerDomain: Int
    public let resolverTargets: [BenchmarkProgressResolverTarget]

    public init(
        resolverCount: Int,
        domainCount: Int,
        attempts: Int,
        dnsTimeoutMS: Int = 800,
        connectTimeoutMS: Int = 1_000,
        maxConnectTargetsPerDomain: Int = 4,
        resolverTargets: [BenchmarkProgressResolverTarget] = []
    ) {
        self.resolverCount = resolverCount
        self.domainCount = domainCount
        self.attempts = attempts
        self.dnsTimeoutMS = dnsTimeoutMS
        self.connectTimeoutMS = connectTimeoutMS
        self.maxConnectTargetsPerDomain = maxConnectTargetsPerDomain
        self.resolverTargets = resolverTargets
    }

    public init(plan: BenchmarkPlanViewModel) {
        self.init(
            resolverCount: plan.resolverCount,
            domainCount: plan.domains.count,
            attempts: plan.attempts,
            maxConnectTargetsPerDomain: plan.maxConnectTargetsPerDomain,
            resolverTargets: plan.resolverTargets
        )
    }
}

public struct BenchmarkProgressViewModel: Equatable, Sendable {
    public let steps: [BenchmarkProgressStepViewModel]
    public let currentStepVerboseLines: [String]
    public let resolverStatuses: [BenchmarkResolverStatusViewModel]

    public init(
        mode: BenchmarkPlanMode,
        state: BenchmarkRunState,
        outcome: BenchmarkExecutionOutcome?,
        historySaved: Bool,
        planSummary: BenchmarkProgressPlanSummary? = nil
    ) {
        let failure: BenchmarkExecutionFailure? = {
            if case .failed(let failure) = outcome {
                return failure
            }
            return nil
        }()
        let isRunning = {
            if case .running = state {
                return true
            }
            return false
        }()
        let isCompleted = state == .completed

        var nextSteps: [BenchmarkProgressStepViewModel] = [
            Self.step(.preparingBenchmark, status: Self.status(for: .preparingBenchmark, failure: failure, isRunning: isRunning, isCompleted: isCompleted)),
            Self.step(.resolvingDNS, status: Self.status(for: .resolvingDNS, failure: failure, isRunning: isRunning, isCompleted: isCompleted)),
        ]

        if mode == .connectionPathCompare {
            nextSteps.append(
                Self.step(.measuringConnection, status: Self.status(for: .measuringConnection, failure: failure, isRunning: isRunning, isCompleted: isCompleted))
            )
        }

        nextSteps.append(
            Self.step(.parsingResult, status: Self.status(for: .parsingResult, failure: failure, isRunning: false, isCompleted: isCompleted))
        )
        nextSteps.append(
            Self.step(.savingHistory, status: Self.historyStatus(failure: failure, isCompleted: isCompleted, historySaved: historySaved))
        )
        steps = nextSteps
        currentStepVerboseLines = Self.verboseLines(
            mode: mode,
            isRunning: isRunning,
            planSummary: planSummary
        )
        resolverStatuses = Self.resolverStatuses(
            isRunning: isRunning,
            failure: failure,
            outcome: outcome,
            targets: planSummary?.resolverTargets ?? []
        )
    }

    private static func step(
        _ failureStep: BenchmarkFailureStep,
        status: BenchmarkProgressStatus
    ) -> BenchmarkProgressStepViewModel {
        BenchmarkProgressStepViewModel(
            id: failureStep.rawValue,
            title: failureStep.label,
            status: status
        )
    }

    private static func status(
        for step: BenchmarkFailureStep,
        failure: BenchmarkExecutionFailure?,
        isRunning: Bool,
        isCompleted: Bool
    ) -> BenchmarkProgressStatus {
        if let failure {
            if failure.failedStep == step {
                return .failed
            }
            return order(step) < order(failure.failedStep) ? .success : .idle
        }
        if isCompleted {
            return .success
        }
        if isRunning {
            switch step {
            case .preparingBenchmark:
                return .success
            case .resolvingDNS, .measuringConnection:
                return .running
            case .parsingResult, .savingHistory:
                return .idle
            }
        }
        return .idle
    }

    private static func historyStatus(
        failure: BenchmarkExecutionFailure?,
        isCompleted: Bool,
        historySaved: Bool
    ) -> BenchmarkProgressStatus {
        if failure?.failedStep == .savingHistory {
            return .failed
        }
        return isCompleted && historySaved ? .success : .idle
    }

    private static func order(_ step: BenchmarkFailureStep) -> Int {
        switch step {
        case .preparingBenchmark:
            0
        case .resolvingDNS:
            1
        case .measuringConnection:
            2
        case .parsingResult:
            3
        case .savingHistory:
            4
        }
    }

    private static func verboseLines(
        mode: BenchmarkPlanMode,
        isRunning: Bool,
        planSummary: BenchmarkProgressPlanSummary?
    ) -> [String] {
        guard isRunning else {
            return []
        }
        guard let planSummary else {
            return [
                "* Running benchmark command.",
                "* Waiting for CLI output; cancel is available if the network blocks.",
                "* Resolver status rows update after the CLI returns; current process output is drained for issue diagnostics.",
            ]
        }

        let dnsSeconds = worstCaseDNSSeconds(summary: planSummary)
        let tcpSeconds = worstCaseTCPSeconds(summary: planSummary)
        switch mode {
        case .dnsOnlyCompare:
            return [
                "* Resolving \(planSummary.domainCount) domain(s) with \(planSummary.resolverCount) resolver(s), \(planSummary.attempts) attempt(s), A + AAAA.",
                "* Worst-case DNS wait before output: about \(dnsSeconds); stdout is drained while the CLI runs.",
                "* Resolver status rows update after the CLI returns; current process output is drained for issue diagnostics.",
            ]
        case .connectionPathCompare:
            return [
                "* Resolving DNS, then probing TCP :443 for returned endpoints.",
                "* Planned input: \(planSummary.domainCount) domain(s), \(planSummary.resolverCount) resolver(s), \(planSummary.attempts) attempt(s); worst-case DNS phase about \(dnsSeconds), TCP phase about \(tcpSeconds).",
                "* Resolver status rows update after the CLI returns; current process output is drained for issue diagnostics.",
            ]
        }
    }

    private static func resolverStatuses(
        isRunning: Bool,
        failure: BenchmarkExecutionFailure?,
        outcome: BenchmarkExecutionOutcome?,
        targets: [BenchmarkProgressResolverTarget]
    ) -> [BenchmarkResolverStatusViewModel] {
        if case .completed(let resultViewModel) = outcome {
            return resultViewModel.rows.map { row in
                BenchmarkResolverStatusViewModel(
                    id: row.profileID,
                    name: row.name,
                    resolver: row.resolver,
                    status: row.status,
                    detail: row.statusDetail
                )
            }
        }

        if isRunning {
            return targets.map { target in
                BenchmarkResolverStatusViewModel(
                    id: target.id,
                    name: target.name,
                    resolver: target.resolver,
                    status: .running,
                    detail: "Queued in batch"
                )
            }
        }

        if let failure {
            return targets.map { target in
                BenchmarkResolverStatusViewModel(
                    id: target.id,
                    name: target.name,
                    resolver: target.resolver,
                    status: failure.failedStep == .preparingBenchmark ? .idle : .failed,
                    detail: failure.failedStep == .parsingResult ? "Result parsing failed" : "Benchmark failed"
                )
            }
        }

        return []
    }

    private static func worstCaseDNSSeconds(summary: BenchmarkProgressPlanSummary) -> String {
        let totalMilliseconds = summary.resolverCount
            * summary.domainCount
            * 2
            * summary.attempts
            * summary.dnsTimeoutMS
        let seconds = Double(totalMilliseconds) / 1_000
        return String(format: "%.1fs", seconds)
    }

    private static func worstCaseTCPSeconds(summary: BenchmarkProgressPlanSummary) -> String {
        let totalMilliseconds = summary.resolverCount
            * summary.domainCount
            * summary.maxConnectTargetsPerDomain
            * summary.attempts
            * summary.connectTimeoutMS
        let seconds = Double(totalMilliseconds) / 1_000
        return String(format: "%.1fs", seconds)
    }
}
