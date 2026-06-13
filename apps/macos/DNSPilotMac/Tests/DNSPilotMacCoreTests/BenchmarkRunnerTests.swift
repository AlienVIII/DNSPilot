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

    func testRunnerRequestsProgressJSONLAndForwardsEventsWhenObserverIsProvided() throws {
        let event = BenchmarkProgressEvent(
            type: .resolverStarted,
            measurementScope: .dnsOnly,
            profileID: "cloudflare",
            resolver: "1.1.1.1:53",
            index: 1,
            total: 1,
            status: nil,
            failureRate: nil,
            timeoutRate: nil
        )
        let processRunner = RecordingBenchmarkProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "{}", standardError: ""),
            progressEvents: [event]
        )
        let runner = BenchmarkRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let receivedEvents = LockedProgressEvents()

        _ = try runner.run(plan: makeValidBenchmarkPlan()) { event in
            receivedEvents.append(event)
        }

        XCTAssertTrue(processRunner.invocations[0].arguments.contains("--progress-jsonl"))
        XCTAssertEqual(receivedEvents.values, [event])
    }

    func testProgressEventDecoderMapsResolverFinishedJSONLine() throws {
        let event = try BenchmarkProgressEventJSONDecoder.decode(
            """
            {"type":"resolver_finished","measurement_scope":"dns-tcp","profile_id":"cloudflare","resolver":"1.1.1.1:53","index":1,"total":2,"status":"degraded","failure_rate":0.5,"timeout_rate":0.25}
            """
        )

        XCTAssertEqual(event.type, .resolverFinished)
        XCTAssertEqual(event.measurementScope, .dnsTCP)
        XCTAssertEqual(event.profileID, "cloudflare")
        XCTAssertEqual(event.resolver, "1.1.1.1:53")
        XCTAssertEqual(event.index, 1)
        XCTAssertEqual(event.total, 2)
        XCTAssertEqual(event.status, .degraded)
        XCTAssertEqual(event.failureRate, 0.5)
        XCTAssertEqual(event.timeoutRate, 0.25)
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

    func testFoundationRunnerDrainsLargeStdoutWhileProcessRuns() throws {
        let processRunner = FoundationBenchmarkProcessRunner()
        let cancellation = BenchmarkRunCancellation()
        let expectedByteCount = 2_000_000

        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            cancellation.cancel()
        }

        let output = try processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-c", "import sys; sys.stdout.write('x' * \(expectedByteCount))"],
            cancellation: cancellation
        )

        XCTAssertEqual(output.exitCode, 0)
        XCTAssertEqual(output.standardOutput.count, expectedByteCount)
        XCTAssertFalse(cancellation.isCancelled)
    }

    func testFoundationRunnerForwardsProgressJSONLFromStderrAndKeepsRawStderr() throws {
        let processRunner = FoundationBenchmarkProcessRunner()
        let receivedEvents = LockedProgressEvents()
        let output = try processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                """
                import sys
                sys.stderr.write('{"type":"resolver_started","measurement_scope":"dns-only","profile_id":"cloudflare","resolver":"1.1.1.1:53","index":1,"total":1}\\n')
                sys.stderr.write('not-json\\n')
                sys.stdout.write('{"ok": true}')
                """,
            ],
            cancellation: nil
        ) { event in
            receivedEvents.append(event)
        }

        XCTAssertEqual(output.exitCode, 0)
        XCTAssertEqual(output.standardOutput, "{\"ok\": true}")
        XCTAssertTrue(output.standardError.contains("\"resolver_started\""))
        XCTAssertTrue(output.standardError.contains("not-json"))
        XCTAssertEqual(receivedEvents.values.map(\.profileID), ["cloudflare"])
    }
}

private final class LockedProgressEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [BenchmarkProgressEvent] = []

    var values: [BenchmarkProgressEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ event: BenchmarkProgressEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }
}

private final class RecordingBenchmarkProcessRunner: BenchmarkProcessRunning {
    struct Invocation {
        let executableURL: URL
        let arguments: [String]
        let cancellation: BenchmarkRunCancellation?
    }

    private let output: BenchmarkProcessOutput
    private let progressEvents: [BenchmarkProgressEvent]
    private(set) var invocations: [Invocation] = []

    init(output: BenchmarkProcessOutput, progressEvents: [BenchmarkProgressEvent] = []) {
        self.output = output
        self.progressEvents = progressEvents
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

    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?,
        progressHandler: ((BenchmarkProgressEvent) -> Void)?
    ) throws -> BenchmarkProcessOutput {
        invocations.append(
            Invocation(
                executableURL: executableURL,
                arguments: arguments,
                cancellation: cancellation
            )
        )
        progressEvents.forEach { progressHandler?($0) }
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
