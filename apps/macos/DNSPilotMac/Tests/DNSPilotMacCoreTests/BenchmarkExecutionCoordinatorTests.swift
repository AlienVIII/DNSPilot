import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkExecutionCoordinatorTests: XCTestCase {
    func testCoordinatorReturnsCompletedResultForSuccessfulCLIOutput() {
        let coordinator = BenchmarkExecutionCoordinator(
            runner: BenchmarkRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: FixedProcessRunner(
                    output: BenchmarkProcessOutput(
                        exitCode: 0,
                        standardOutput: successfulCompareJSON,
                        standardError: ""
                    )
                )
            ),
            catalog: makeExecutionCatalog()
        )

        let outcome = coordinator.execute(plan: makeExecutionPlan())

        XCTAssertEqual(
            outcome,
            .completed(
                BenchmarkResultViewModel(
                    result: try! BenchmarkResultJSONDecoder.decode(successfulCompareJSON),
                    catalog: makeExecutionCatalog()
                )
            )
        )
    }

    func testCoordinatorReturnsProcessErrorForNonZeroExit() {
        let coordinator = BenchmarkExecutionCoordinator(
            runner: BenchmarkRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: FixedProcessRunner(
                    output: BenchmarkProcessOutput(
                        exitCode: 2,
                        standardOutput: "",
                        standardError: "resolver timed out"
                    )
                )
            ),
            catalog: makeExecutionCatalog()
        )

        let outcome = coordinator.execute(plan: makeExecutionPlan())

        XCTAssertEqual(
            outcome,
            .failed(
                    BenchmarkExecutionFailure(
                        message: "resolver timed out",
                        failedStep: .resolvingDNS,
                        debugLog: """
                        exit code: 2

                        stderr:
                        resolver timed out

                        arguments:
                        compare --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1 --timeout-ms 800
                        """
                    )
                )
            )
    }

    func testCoordinatorReturnsValidationErrorsWithoutRunningProcess() {
        let processRunner = FixedProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: successfulCompareJSON, standardError: "")
        )
        let coordinator = BenchmarkExecutionCoordinator(
            runner: BenchmarkRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: processRunner
            ),
            catalog: makeExecutionCatalog()
        )

        let outcome = coordinator.execute(
            plan: BenchmarkPlanViewModel(
                catalog: makeExecutionCatalog(),
                selectedProfileIDs: [],
                selectedSuiteID: "developer",
                customDomains: [],
                attempts: 1,
                mode: .dnsOnlyCompare
            )
        )

        XCTAssertEqual(
            outcome,
            .failed(
                BenchmarkExecutionFailure(
                    message: "Select at least one plain DNS profile.",
                    failedStep: .preparingBenchmark,
                    debugLog: "Select at least one plain DNS profile."
                )
            )
        )
        XCTAssertEqual(processRunner.runCount, 0)
    }

    func testCoordinatorReturnsParseErrorForInvalidJSON() {
        let coordinator = BenchmarkExecutionCoordinator(
            runner: BenchmarkRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: FixedProcessRunner(
                    output: BenchmarkProcessOutput(
                        exitCode: 0,
                        standardOutput: "not json",
                        standardError: ""
                    )
                )
            ),
            catalog: makeExecutionCatalog()
        )

        let outcome = coordinator.execute(plan: makeExecutionPlan())

        XCTAssertEqual(
            outcome,
            .failed(
                    BenchmarkExecutionFailure(
                        message: "Could not parse benchmark result: data corrupted at root - The given data was not valid JSON.",
                        failedStep: .parsingResult,
                        debugLog: """
                        parse_error:
                        data corrupted at root - The given data was not valid JSON.

                        exit code: 0

                        stdout:
                        not json

                        arguments:
                        compare --resolver cloudflare=1.1.1.1:53 --domain github.com --attempts 1 --timeout-ms 800
                        """
                    )
            )
        )
    }

    func testCoordinatorReturnsFailureForFailedBenchmarkPayload() {
        let coordinator = BenchmarkExecutionCoordinator(
            runner: BenchmarkRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: FixedProcessRunner(
                    output: BenchmarkProcessOutput(
                        exitCode: 0,
                        standardOutput: failedCompareJSON,
                        standardError: ""
                    )
                )
            ),
            catalog: makeExecutionCatalog()
        )

        let outcome = coordinator.execute(plan: makeExecutionPlan())

        guard case .failed(let failure) = outcome else {
            return XCTFail("Expected failed outcome, got \(outcome)")
        }
        XCTAssertEqual(failure.message, "DNS lookup failed for all selected resolvers.")
        XCTAssertEqual(failure.failedStep, .resolvingDNS)
        XCTAssertTrue(failure.debugLog.contains("\"health\": \"failed\""))
        XCTAssertTrue(failure.debugLog.contains("arguments:"))
    }

    func testCoordinatorPassesCancellationToRunner() {
        let processRunner = FixedProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: successfulCompareJSON, standardError: "")
        )
        let coordinator = BenchmarkExecutionCoordinator(
            runner: BenchmarkRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: processRunner
            ),
            catalog: makeExecutionCatalog()
        )
        let cancellation = BenchmarkRunCancellation()

        _ = coordinator.execute(plan: makeExecutionPlan(), cancellation: cancellation)

        XCTAssertTrue(processRunner.receivedCancellation === cancellation)
    }

    func testCoordinatorPassesPersistenceToRunner() {
        let processRunner = FixedProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: successfulCompareJSON, standardError: "")
        )
        let coordinator = BenchmarkExecutionCoordinator(
            runner: BenchmarkRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: processRunner
            ),
            catalog: makeExecutionCatalog()
        )
        let persistence = BenchmarkHistoryPersistence(
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            historyID: "compare-run-1"
        )

        _ = coordinator.execute(plan: makeExecutionPlan(), persistence: persistence)

        XCTAssertEqual(
            Array(processRunner.receivedArguments.suffix(4)),
            ["--save-db", "/tmp/dnspilot.sqlite", "--history-id", "compare-run-1"]
        )
    }
}

private final class FixedProcessRunner: BenchmarkProcessRunning {
    private let output: BenchmarkProcessOutput
    private(set) var runCount = 0
    private(set) var receivedCancellation: BenchmarkRunCancellation?
    private(set) var receivedArguments: [String] = []

    init(output: BenchmarkProcessOutput) {
        self.output = output
    }

    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?
    ) throws -> BenchmarkProcessOutput {
        runCount += 1
        receivedCancellation = cancellation
        receivedArguments = arguments
        return output
    }
}

private func makeExecutionPlan() -> BenchmarkPlanViewModel {
    BenchmarkPlanViewModel(
        catalog: makeExecutionCatalog(),
        selectedProfileIDs: ["cloudflare"],
        selectedSuiteID: "developer",
        customDomains: [],
        attempts: 1,
        mode: .dnsOnlyCompare
    )
}

private func makeExecutionCatalog() -> CatalogSnapshot {
    CatalogSnapshot(
        profiles: [
            CatalogProfile(
                id: "cloudflare",
                name: "Cloudflare",
                description: "Fast public DNS.",
                ipv4Servers: ["1.1.1.1"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: [],
                useCase: "performance",
                securityNotes: []
            ),
        ],
        testSuites: [
            CatalogTestSuite(
                id: "developer",
                name: "Developer",
                description: "Developer domains.",
                domains: ["github.com"],
                tags: []
            ),
        ]
    )
}

private let successfulCompareJSON = """
{
  "summary": {
    "measurement_scope": "dns-only",
    "mode": "fastest-raw-dns",
    "health": "healthy",
    "primary_issue": "none",
    "can_recommend": true,
    "safety_notes": [],
    "resolver_count": 1,
    "domain_count": 1,
    "attempts_per_record": 1,
    "timeout_ms": 500,
    "recommended_profile_id": "cloudflare"
  },
  "runs": [
    {
      "profile_id": "cloudflare",
      "resolver": "1.1.1.1:53",
      "metrics": {
        "profile_id": "cloudflare",
        "median_dns_latency_ms": 4.0,
        "p95_dns_latency_ms": 4.0,
        "failure_rate": 0.0,
        "timeout_rate": 0.0,
        "median_connect_latency_ms": 0.0,
        "ipv4_health": 1.0,
        "ipv6_health": 0.0,
        "priority_fit": 1.0
      }
    }
  ],
  "recommendation": {
    "decision": { "apply-profile": "cloudflare" },
    "profile_id": "cloudflare",
    "score": 0.98,
    "confidence": "high",
    "reasons": ["Lowest median DNS latency."],
    "caveats": []
  },
  "saved_history_id": null,
  "warning": "DNS-only warning."
}
"""

private let failedCompareJSON = """
{
  "summary": {
    "measurement_scope": "dns-only",
    "mode": "fastest-raw-dns",
    "health": "failed",
    "primary_issue": "all-resolvers-failed",
    "can_recommend": false,
    "safety_notes": ["Every candidate failed the measured scope."],
    "resolver_count": 1,
    "domain_count": 1,
    "attempts_per_record": 1,
    "timeout_ms": 200,
    "recommended_profile_id": null
  },
  "runs": [
    {
      "profile_id": "cloudflare",
      "resolver": "1.1.1.1:53",
      "metrics": {
        "profile_id": "cloudflare",
        "median_dns_latency_ms": null,
        "p95_dns_latency_ms": null,
        "failure_rate": 1.0,
        "timeout_rate": 1.0,
        "median_connect_latency_ms": null,
        "ipv4_health": 0.0,
        "ipv6_health": 0.0,
        "priority_fit": 1.0
      }
    }
  ],
  "recommendation": null,
  "saved_history_id": null,
  "warning": "DNS-only warning."
}
"""
