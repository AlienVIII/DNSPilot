import XCTest
@testable import DNSPilotMacCore

final class BenchmarkProgressViewModelTests: XCTestCase {
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
                "* Planned input: 2 domain(s), 2 resolver(s), 1 attempt(s); worst-case DNS phase about 6.4s.",
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
}

private func makeProgressResultViewModel(savedHistoryID: String?) -> BenchmarkResultViewModel {
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
            runs: [],
            recommendation: nil,
            savedHistoryID: savedHistoryID,
            warning: "Path warning."
        ),
        catalog: nil
    )
}
