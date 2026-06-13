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

public struct BenchmarkProgressPlanSummary: Equatable, Sendable {
    public let resolverCount: Int
    public let domainCount: Int
    public let attempts: Int
    public let dnsTimeoutMS: Int
    public let connectTimeoutMS: Int

    public init(
        resolverCount: Int,
        domainCount: Int,
        attempts: Int,
        dnsTimeoutMS: Int = 800,
        connectTimeoutMS: Int = 1_000
    ) {
        self.resolverCount = resolverCount
        self.domainCount = domainCount
        self.attempts = attempts
        self.dnsTimeoutMS = dnsTimeoutMS
        self.connectTimeoutMS = connectTimeoutMS
    }

    public init(plan: BenchmarkPlanViewModel) {
        self.init(
            resolverCount: plan.resolverCount,
            domainCount: plan.domains.count,
            attempts: plan.attempts
        )
    }
}

public struct BenchmarkProgressViewModel: Equatable, Sendable {
    public let steps: [BenchmarkProgressStepViewModel]
    public let currentStepVerboseLines: [String]

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
            ]
        }

        let dnsSeconds = worstCaseDNSSeconds(summary: planSummary)
        switch mode {
        case .dnsOnlyCompare:
            return [
                "* Resolving \(planSummary.domainCount) domain(s) with \(planSummary.resolverCount) resolver(s), \(planSummary.attempts) attempt(s), A + AAAA.",
                "* Worst-case DNS wait before output: about \(dnsSeconds); stdout is drained while the CLI runs.",
            ]
        case .connectionPathCompare:
            return [
                "* Resolving DNS, then probing TCP :443 for returned endpoints.",
                "* Planned input: \(planSummary.domainCount) domain(s), \(planSummary.resolverCount) resolver(s), \(planSummary.attempts) attempt(s); worst-case DNS phase about \(dnsSeconds).",
            ]
        }
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
}
