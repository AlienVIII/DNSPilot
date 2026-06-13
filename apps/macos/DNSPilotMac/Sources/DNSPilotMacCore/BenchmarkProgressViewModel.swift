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
    public let recordFamily: BenchmarkRecordFamily
    public let resolverTargets: [BenchmarkProgressResolverTarget]

    public init(
        resolverCount: Int,
        domainCount: Int,
        attempts: Int,
        dnsTimeoutMS: Int = 800,
        connectTimeoutMS: Int = 1_000,
        maxConnectTargetsPerDomain: Int = 4,
        recordFamily: BenchmarkRecordFamily = .both,
        resolverTargets: [BenchmarkProgressResolverTarget] = []
    ) {
        self.resolverCount = resolverCount
        self.domainCount = domainCount
        self.attempts = attempts
        self.dnsTimeoutMS = dnsTimeoutMS
        self.connectTimeoutMS = connectTimeoutMS
        self.maxConnectTargetsPerDomain = maxConnectTargetsPerDomain
        self.recordFamily = recordFamily
        self.resolverTargets = resolverTargets
    }

    public init(plan: BenchmarkPlanViewModel) {
        self.init(
            resolverCount: plan.resolverCount,
            domainCount: plan.domains.count,
            attempts: plan.attempts,
            dnsTimeoutMS: plan.dnsTimeoutMS,
            connectTimeoutMS: plan.connectTimeoutMS,
            maxConnectTargetsPerDomain: plan.maxConnectTargetsPerDomain,
            recordFamily: plan.recordFamily,
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
        planSummary: BenchmarkProgressPlanSummary? = nil,
        progressEvents: [BenchmarkProgressEvent] = []
    ) {
        let failure: BenchmarkExecutionFailure? = {
            if case .failed(let failure) = outcome {
                return failure
            }
            return nil
        }()
        let isCancelling = {
            if case .cancelling = state {
                return true
            }
            return false
        }()
        let isActive = {
            if case .running = state {
                return true
            }
            return isCancelling
        }()
        let isCompleted = state == .completed

        var nextSteps: [BenchmarkProgressStepViewModel] = [
            Self.step(.preparingBenchmark, status: Self.status(for: .preparingBenchmark, failure: failure, isRunning: isActive, isCompleted: isCompleted)),
            Self.step(.resolvingDNS, status: Self.status(for: .resolvingDNS, failure: failure, isRunning: isActive, isCompleted: isCompleted)),
        ]

        if mode == .connectionPathCompare {
            nextSteps.append(
                Self.step(.measuringConnection, status: Self.status(for: .measuringConnection, failure: failure, isRunning: isActive, isCompleted: isCompleted))
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
            isRunning: isActive,
            isCancelling: isCancelling,
            planSummary: planSummary,
            progressEvents: progressEvents
        )
        resolverStatuses = Self.resolverStatuses(
            isRunning: isActive,
            isCancelling: isCancelling,
            failure: failure,
            outcome: outcome,
            targets: planSummary?.resolverTargets ?? [],
            progressEvents: progressEvents
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
        isCancelling: Bool,
        planSummary: BenchmarkProgressPlanSummary?,
        progressEvents: [BenchmarkProgressEvent]
    ) -> [String] {
        guard isRunning else {
            return []
        }
        if isCancelling {
            return [
                "* Cancellation requested; waiting for the CLI process to stop.",
                "* Output is still drained so the final state and debug log stay consistent.",
            ]
        }
        guard let planSummary else {
            return [
                "* Running benchmark command.",
                "* Waiting for CLI output; cancel is available if the network blocks.",
                "* CLI probes resolvers sequentially; per-resolver rows update from progress events when available.",
            ]
        }
        if let progressLines = progressEventVerboseLines(
            progressEvents,
            planSummary: planSummary
        ) {
            return progressLines
        }

        let dnsSeconds = worstCaseDNSSeconds(summary: planSummary)
        let tcpSeconds = worstCaseTCPSeconds(summary: planSummary)
        switch mode {
        case .dnsOnlyCompare:
            return [
                "* Resolving \(planSummary.domainCount) domain(s) with \(planSummary.resolverCount) resolver(s), \(planSummary.attempts) attempt(s), \(planSummary.recordFamily.displayLabel).",
                "* Worst-case DNS wait before output: about \(dnsSeconds); stdout is drained while the CLI runs.",
                "* CLI probes resolvers sequentially; per-resolver rows update from progress events when available.",
            ]
        case .connectionPathCompare:
            return [
                "* Resolving DNS, then probing TCP :443 for returned endpoints.",
                "* Planned input: \(planSummary.domainCount) domain(s), \(planSummary.resolverCount) resolver(s), \(planSummary.attempts) attempt(s); worst-case DNS phase about \(dnsSeconds), TCP phase about \(tcpSeconds).",
                "* CLI probes resolvers sequentially; per-resolver rows update from progress events when available.",
            ]
        }
    }

    private static func progressEventVerboseLines(
        _ progressEvents: [BenchmarkProgressEvent],
        planSummary: BenchmarkProgressPlanSummary
    ) -> [String]? {
        guard let event = progressEvents.last else {
            return nil
        }
        let resolverName = planSummary.resolverTargets.first { $0.id == event.profileID }?.name ?? event.profileID
        switch event.type {
        case .resolverStarted:
            return [
                "* Current resolver: \(resolverName) (\(event.resolver)), \(event.index)/\(event.total).",
                "* Waiting for this resolver to finish; elapsed time is shown on completion.",
            ]
        case .resolverFinished:
            return [
                "* Last finished: \(resolverName) (\(event.resolver)), \(detail(for: event)).",
                "* Waiting for the next resolver event or final JSON output.",
            ]
        }
    }

    private static func resolverStatuses(
        isRunning: Bool,
        isCancelling: Bool,
        failure: BenchmarkExecutionFailure?,
        outcome: BenchmarkExecutionOutcome?,
        targets: [BenchmarkProgressResolverTarget],
        progressEvents: [BenchmarkProgressEvent]
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
            if !progressEvents.isEmpty {
                let latestEvents = latestProgressEventsByProfileID(progressEvents)
                return targets.map { target in
                    if let event = latestEvents[target.id] {
                        return BenchmarkResolverStatusViewModel(
                            id: target.id,
                            name: target.name,
                            resolver: target.resolver,
                            status: status(for: event),
                            detail: detail(for: event)
                        )
                    }

                    return BenchmarkResolverStatusViewModel(
                        id: target.id,
                        name: target.name,
                        resolver: target.resolver,
                        status: .idle,
                        detail: "Pending"
                    )
                }
            }

            return targets.map { target in
                BenchmarkResolverStatusViewModel(
                    id: target.id,
                    name: target.name,
                    resolver: target.resolver,
                    status: .running,
                    detail: isCancelling ? "Cancelling" : "Waiting for final JSON"
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

    private static func latestProgressEventsByProfileID(
        _ events: [BenchmarkProgressEvent]
    ) -> [String: BenchmarkProgressEvent] {
        var latestEvents: [String: BenchmarkProgressEvent] = [:]
        for event in events {
            latestEvents[event.profileID] = event
        }
        return latestEvents
    }

    private static func status(for event: BenchmarkProgressEvent) -> BenchmarkProgressStatus {
        switch event.type {
        case .resolverStarted:
            return .running
        case .resolverFinished:
            switch event.status {
            case .success:
                return .success
            case .degraded:
                return .degraded
            case .failed:
                return .failed
            case nil:
                return .success
            }
        }
    }

    private static func detail(for event: BenchmarkProgressEvent) -> String {
        switch event.type {
        case .resolverStarted:
            return "Running \(event.index)/\(event.total)"
        case .resolverFinished:
            let summary = event.failureRate.map { "\(percent($0))% failed" } ?? "Finished"
            guard let elapsedMS = event.elapsedMS else {
                return summary
            }
            return "\(summary) - \(formatElapsedMS(elapsedMS))"
        }
    }

    private static func percent(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }

    private static func formatElapsedMS(_ value: Double) -> String {
        "\(Int(max(value, 0).rounded())) ms"
    }

    private static func worstCaseDNSSeconds(summary: BenchmarkProgressPlanSummary) -> String {
        let totalMilliseconds = summary.resolverCount
            * summary.domainCount
            * summary.recordFamily.recordTypeCount
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
