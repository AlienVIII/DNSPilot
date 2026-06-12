import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkRunnerTests: XCTestCase {
    func testRunnerPassesPlanArgumentsToProcessRunner() throws {
        let processRunner = RecordingBenchmarkProcessRunner(
            output: BenchmarkProcessOutput(
                exitCode: 0,
                standardOutput: "{\"ok\":true}",
                standardError: ""
            )
        )
        let runner = BenchmarkRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        let result = try runner.run(plan: makeValidBenchmarkPlan())

        XCTAssertEqual(processRunner.invocations.count, 1)
        XCTAssertEqual(processRunner.invocations.first?.executableURL.path, "/usr/local/bin/dnspilot")
        XCTAssertEqual(processRunner.invocations.first?.arguments.first, "compare")
        XCTAssertTrue(processRunner.invocations.first?.arguments.contains("cloudflare=1.1.1.1:53") == true)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.standardOutput, "{\"ok\":true}")
    }

    func testRunnerRejectsInvalidPlanWithoutStartingProcess() throws {
        let processRunner = RecordingBenchmarkProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = BenchmarkRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        XCTAssertThrowsError(try runner.run(plan: makeInvalidBenchmarkPlan())) { error in
            XCTAssertEqual(
                error as? BenchmarkRunnerError,
                .invalidPlan(issues: ["Select at least one plain DNS profile."])
            )
        }
        XCTAssertTrue(processRunner.invocations.isEmpty)
    }

    func testRunnerKeepsNonZeroExitOutputForDisplay() throws {
        let processRunner = RecordingBenchmarkProcessRunner(
            output: BenchmarkProcessOutput(
                exitCode: 2,
                standardOutput: "",
                standardError: "resolver timed out"
            )
        )
        let runner = BenchmarkRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        let result = try runner.run(plan: makeValidBenchmarkPlan())

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.exitCode, 2)
        XCTAssertEqual(result.standardError, "resolver timed out")
    }

    func testRunnerPassesCancellationToProcessRunner() throws {
        let processRunner = RecordingBenchmarkProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "{}", standardError: "")
        )
        let runner = BenchmarkRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let cancellation = BenchmarkRunCancellation()

        _ = try runner.run(plan: makeValidBenchmarkPlan(), cancellation: cancellation)

        XCTAssertTrue(processRunner.invocations.first?.cancellation === cancellation)
    }

    func testRunnerAppendsHistoryPersistenceArguments() throws {
        let processRunner = RecordingBenchmarkProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "{}", standardError: "")
        )
        let runner = BenchmarkRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let persistence = BenchmarkHistoryPersistence(
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            historyID: "compare-run-1"
        )

        _ = try runner.run(plan: makeValidBenchmarkPlan(), persistence: persistence)

        XCTAssertEqual(
            Array(processRunner.invocations[0].arguments.suffix(4)),
            ["--save-db", "/tmp/dnspilot.sqlite", "--history-id", "compare-run-1"]
        )
    }

    func testFoundationRunnerTerminatesProcessWhenCancellationIsRequested() throws {
        let processRunner = FoundationBenchmarkProcessRunner()
        let cancellation = BenchmarkRunCancellation()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            cancellation.cancel()
        }

        let start = Date()
        let output = try processRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["5"],
            cancellation: cancellation
        )

        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        XCTAssertNotEqual(output.exitCode, 0)
        XCTAssertTrue(cancellation.isCancelled)
    }
}

private final class RecordingBenchmarkProcessRunner: BenchmarkProcessRunning {
    struct Invocation {
        let executableURL: URL
        let arguments: [String]
        let cancellation: BenchmarkRunCancellation?
    }

    private let output: BenchmarkProcessOutput
    private(set) var invocations: [Invocation] = []

    init(output: BenchmarkProcessOutput) {
        self.output = output
    }

    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?
    ) throws -> BenchmarkProcessOutput {
        invocations.append(
            Invocation(
                executableURL: executableURL,
                arguments: arguments,
                cancellation: cancellation
            )
        )
        return output
    }
}

private func makeValidBenchmarkPlan() -> BenchmarkPlanViewModel {
    BenchmarkPlanViewModel(
        catalog: makeRunnerCatalog(),
        selectedProfileIDs: ["cloudflare"],
        selectedSuiteID: "developer",
        customDomains: [],
        attempts: 1,
        mode: .dnsOnlyCompare
    )
}

private func makeInvalidBenchmarkPlan() -> BenchmarkPlanViewModel {
    BenchmarkPlanViewModel(
        catalog: makeRunnerCatalog(),
        selectedProfileIDs: [],
        selectedSuiteID: "developer",
        customDomains: [],
        attempts: 1,
        mode: .dnsOnlyCompare
    )
}

private func makeRunnerCatalog() -> CatalogSnapshot {
    CatalogSnapshot(
        profiles: [
            CatalogProfile(
                id: "cloudflare",
                name: "Cloudflare",
                description: "Fast unfiltered public DNS.",
                ipv4Servers: ["1.1.1.1"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: ["general"],
                useCase: "performance",
                securityNotes: []
            ),
        ],
        testSuites: [
            CatalogTestSuite(
                id: "developer",
                name: "Developer",
                description: "Developer workflow checks.",
                domains: ["github.com"],
                tags: ["developer"]
            ),
        ]
    )
}
