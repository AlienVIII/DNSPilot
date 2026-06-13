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
                "* Resolver status rows update after the CLI returns; current process output is drained for issue diagnostics.",
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
                "Cloudflare:running:Queued in batch",
                "Google:running:Queued in batch",
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
                "* Resolver status rows update after the CLI returns; current process output is drained for issue diagnostics.",
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
