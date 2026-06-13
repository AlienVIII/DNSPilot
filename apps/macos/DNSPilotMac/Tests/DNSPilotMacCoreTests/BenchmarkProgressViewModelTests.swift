import XCTest
@testable import DNSPilotMacCore

final class BenchmarkProgressViewModelTests: XCTestCase {
    func testFailureIssueReportIncludesContextAndDebugLog() {
        let failure = BenchmarkExecutionFailure(
            message: "DNS lookup timeout",
            failedStep: .resolvingDNS,
            debugLog: "arguments: compare --profiles cloudflare\nstderr: timed out"
        )

        XCTAssertEqual(
            failure.issueReport(modeLabel: "DNS only", elapsedMS: 1_240),
            """
            Benchmark failed
            Mode: DNS only
            Failed at: Resolving DNS
            Reason: DNS lookup timeout
            Suggestion: Try DNS + TCP or check resolver, firewall, VPN, or network configuration.
            Elapsed: 1240 ms

            Debug log:
            arguments: compare --profiles cloudflare
            stderr: timed out
            """
        )
    }

    func testProgressShowsDnsOnlyResolvingWhileRunning() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false
        )

        XCTAssertEqual(
            viewModel.steps.map { "\($0.title):\($0.status.rawValue)" },
            [
                "Preparing benchmark:success",
                "Resolving DNS:running",
                "Parsing result:idle",
                "Saving history:idle",
            ]
        )
    }

    func testProgressStaysVisibleWhileCancelling() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .cancelling(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false,
            planSummary: BenchmarkProgressPlanSummary(
                resolverCount: 1,
                domainCount: 1,
                attempts: 1,
                resolverTargets: [
                    BenchmarkProgressResolverTarget(id: "cloudflare", name: "Cloudflare", resolver: "1.1.1.1:53"),
                ]
            )
        )

        XCTAssertEqual(
            viewModel.steps.map { "\($0.title):\($0.status.rawValue)" },
            [
                "Preparing benchmark:success",
                "Resolving DNS:running",
                "Parsing result:idle",
                "Saving history:idle",
            ]
        )
        XCTAssertEqual(
            viewModel.currentStepVerboseLines,
            [
                "* Cancellation requested; waiting for the CLI process to stop.",
                "* Output is still drained so the final state and debug log stay consistent.",
            ]
        )
        XCTAssertEqual(
            viewModel.resolverStatuses.map { "\($0.name):\($0.status.rawValue):\($0.detail)" },
            [
                "Cloudflare:running:Cancelling",
            ]
        )
    }

    func testProgressShowsDnsOnlyVerboseLinesWhileRunning() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false,
            planSummary: BenchmarkProgressPlanSummary(
                resolverCount: 2,
                domainCount: 3,
                attempts: 1,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000
            )
        )

        XCTAssertEqual(
            viewModel.currentStepVerboseLines,
            [
                "* Resolving 3 domain(s) with 2 resolver(s), 1 attempt(s), A + AAAA.",
                "* Worst-case DNS wait before output: about 9.6s; stdout is drained while the CLI runs.",
                "* CLI probes resolvers sequentially; per-resolver rows update from progress events when available.",
            ]
        )
    }

    func testProgressUsesSelectedRecordFamilyInVerboseLinesAndWorstCase() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false,
            planSummary: BenchmarkProgressPlanSummary(
                resolverCount: 2,
                domainCount: 3,
                attempts: 1,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000,
                recordFamily: .ipv4Only
            )
        )

        XCTAssertEqual(
            viewModel.currentStepVerboseLines,
            [
                "* Resolving 3 domain(s) with 2 resolver(s), 1 attempt(s), A only.",
                "* Worst-case DNS wait before output: about 4.8s; stdout is drained while the CLI runs.",
                "* CLI probes resolvers sequentially; per-resolver rows update from progress events when available.",
            ]
        )
    }

    func testProgressShowsResolverRowsWhileRunning() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false,
            planSummary: BenchmarkProgressPlanSummary(
                resolverCount: 2,
                domainCount: 1,
                attempts: 1,
                resolverTargets: [
                    BenchmarkProgressResolverTarget(id: "cloudflare", name: "Cloudflare", resolver: "1.1.1.1:53"),
                    BenchmarkProgressResolverTarget(id: "google", name: "Google", resolver: "8.8.8.8:53"),
                ]
            )
        )

        XCTAssertEqual(
            viewModel.resolverStatuses.map { "\($0.name):\($0.status.rawValue):\($0.detail)" },
            [
                "Cloudflare:running:Waiting for final JSON",
                "Google:running:Waiting for final JSON",
            ]
        )
    }

    func testProgressShowsLiveResolverRowsFromProgressEvents() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false,
            planSummary: BenchmarkProgressPlanSummary(
                resolverCount: 3,
                domainCount: 1,
                attempts: 1,
                resolverTargets: [
                    BenchmarkProgressResolverTarget(id: "cloudflare", name: "Cloudflare", resolver: "1.1.1.1:53"),
                    BenchmarkProgressResolverTarget(id: "quad9", name: "Quad9", resolver: "9.9.9.9:53"),
                    BenchmarkProgressResolverTarget(id: "google", name: "Google", resolver: "8.8.8.8:53"),
                ]
            ),
            progressEvents: [
                BenchmarkProgressEvent(
                    type: .resolverFinished,
                    measurementScope: .dnsOnly,
                    profileID: "cloudflare",
                    resolver: "1.1.1.1:53",
                    index: 1,
                    total: 3,
                    status: .success,
                    failureRate: 0,
                    timeoutRate: 0,
                    elapsedMS: 123.4
                ),
                BenchmarkProgressEvent(
                    type: .resolverStarted,
                    measurementScope: .dnsOnly,
                    profileID: "quad9",
                    resolver: "9.9.9.9:53",
                    index: 2,
                    total: 3,
                    status: nil,
                    failureRate: nil,
                    timeoutRate: nil
                ),
            ]
        )

        XCTAssertEqual(
            viewModel.resolverStatuses.map { "\($0.name):\($0.status.rawValue):\($0.detail)" },
            [
                "Cloudflare:success:0% failed - 123 ms",
                "Quad9:running:Running 2/3",
                "Google:idle:Pending",
            ]
        )
    }

    func testProgressShowsCurrentResolverVerboseLinesFromProgressEvents() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false,
            planSummary: BenchmarkProgressPlanSummary(
                resolverCount: 3,
                domainCount: 1,
                attempts: 1,
                resolverTargets: [
                    BenchmarkProgressResolverTarget(id: "cloudflare", name: "Cloudflare", resolver: "1.1.1.1:53"),
                    BenchmarkProgressResolverTarget(id: "quad9", name: "Quad9", resolver: "9.9.9.9:53"),
                    BenchmarkProgressResolverTarget(id: "google", name: "Google", resolver: "8.8.8.8:53"),
                ]
            ),
            progressEvents: [
                BenchmarkProgressEvent(
                    type: .resolverFinished,
                    measurementScope: .dnsOnly,
                    profileID: "cloudflare",
                    resolver: "1.1.1.1:53",
                    index: 1,
                    total: 3,
                    status: .success,
                    failureRate: 0,
                    timeoutRate: 0,
                    elapsedMS: 123.4
                ),
                BenchmarkProgressEvent(
                    type: .resolverStarted,
                    measurementScope: .dnsOnly,
                    profileID: "quad9",
                    resolver: "9.9.9.9:53",
                    index: 2,
                    total: 3,
                    status: nil,
                    failureRate: nil,
                    timeoutRate: nil
                ),
            ]
        )

        XCTAssertEqual(
            viewModel.currentStepVerboseLines,
            [
                "* Current resolver: Quad9 (9.9.9.9:53), 2/3.",
                "* Waiting for this resolver to finish; elapsed time is shown on completion.",
            ]
        )
    }

    func testProgressShowsDnsTcpProbeWhileRunning() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .connectionPathCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false
        )

        XCTAssertEqual(
            viewModel.steps.map { "\($0.title):\($0.status.rawValue)" },
            [
                "Preparing benchmark:success",
                "Resolving DNS:running",
                "Measuring TCP:running",
                "Parsing result:idle",
                "Saving history:idle",
            ]
        )
    }

    func testProgressShowsDnsTcpVerboseLinesWhileRunning() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .connectionPathCompare,
            state: .running(runID: BenchmarkRunID(1)),
            outcome: nil,
            historySaved: false,
            planSummary: BenchmarkProgressPlanSummary(
                resolverCount: 2,
                domainCount: 2,
                attempts: 1,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000
            )
        )

        XCTAssertEqual(
            viewModel.currentStepVerboseLines,
            [
                "* Resolving DNS, then probing TCP :443 for returned endpoints.",
                "* Planned input: 2 domain(s), 2 resolver(s), 1 attempt(s); worst-case DNS phase about 6.4s, TCP phase about 16.0s.",
                "* CLI probes resolvers sequentially; per-resolver rows update from progress events when available.",
            ]
        )
    }

    func testProgressMarksFailedStepFromFailure() {
        let failure = BenchmarkExecutionFailure(
            message: "resolver timed out",
            failedStep: .resolvingDNS,
            debugLog: "stderr: resolver timed out"
        )
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .failed("resolver timed out"),
            outcome: .failed(failure),
            historySaved: false
        )

        XCTAssertEqual(
            viewModel.steps.map { "\($0.title):\($0.status.rawValue)" },
            [
                "Preparing benchmark:success",
                "Resolving DNS:failed",
                "Parsing result:idle",
                "Saving history:idle",
            ]
        )
    }

    func testProgressMarksSavedHistoryWhenCompleted() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .connectionPathCompare,
            state: .completed,
            outcome: .completed(makeProgressResultViewModel(savedHistoryID: "path-compare-run-1")),
            historySaved: true
        )

        XCTAssertEqual(viewModel.steps.last?.title, "Saving history")
        XCTAssertEqual(viewModel.steps.last?.status, .success)
    }

    func testProgressShowsResolverRowsAfterCompletedResult() {
        let viewModel = BenchmarkProgressViewModel(
            mode: .dnsOnlyCompare,
            state: .completed,
            outcome: .completed(
                makeProgressResultViewModel(
                    savedHistoryID: nil,
                    runs: [
                        makeProgressRun(profileID: "cloudflare", medianDNS: 10, failureRate: 0),
                        makeProgressRun(profileID: "bad", medianDNS: nil, failureRate: 1),
                    ]
                )
            ),
            historySaved: false
        )

        XCTAssertEqual(
            viewModel.resolverStatuses.map { "\($0.id):\($0.status.rawValue):\($0.detail)" },
            [
                "cloudflare:success:0% failed",
                "bad:failed:100% failed",
            ]
        )
    }
}

private func makeProgressResultViewModel(
    savedHistoryID: String?,
    runs: [BenchmarkResultRun] = []
) -> BenchmarkResultViewModel {
    BenchmarkResultViewModel(
        result: BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .healthy,
                primaryIssue: "none",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 500,
                connectTimeoutMS: 500,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 2,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: "cloudflare"
            ),
            runs: runs,
            recommendation: nil,
            savedHistoryID: savedHistoryID,
            warning: "Path warning."
        ),
        catalog: nil
    )
}

private func makeProgressRun(
    profileID: String,
    medianDNS: Double?,
    failureRate: Double
) -> BenchmarkResultRun {
    BenchmarkResultRun(
        profileID: profileID,
        resolver: "\(profileID).resolver:53",
        metrics: BenchmarkResultMetrics(
            profileID: profileID,
            medianDNSLatencyMS: medianDNS,
            p95DNSLatencyMS: medianDNS,
            failureRate: failureRate,
            timeoutRate: failureRate,
            medianConnectLatencyMS: nil,
            ipv4Health: 1 - failureRate,
            ipv6Health: 1 - failureRate,
            priorityFit: 1
        )
    )
}
