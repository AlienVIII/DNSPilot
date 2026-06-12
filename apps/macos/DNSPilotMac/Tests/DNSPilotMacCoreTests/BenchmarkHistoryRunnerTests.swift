import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkHistoryRunnerTests: XCTestCase {
    func testRunnerPassesHistoryListArgumentsToProcessRunner() throws {
        let processRunner = RecordingHistoryProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: historyListJSON, standardError: "")
        )
        let runner = BenchmarkHistoryRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        _ = try runner.load(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(processRunner.invocations.count, 1)
        XCTAssertEqual(processRunner.invocations[0].executableURL.path, "/usr/local/bin/dnspilot")
        XCTAssertEqual(
            processRunner.invocations[0].arguments,
            ["history-list", "--db", "/tmp/dnspilot.sqlite"]
        )
    }

    func testRunnerDecodesHistoryPayload() throws {
        let processRunner = RecordingHistoryProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: historyListJSON, standardError: "")
        )
        let runner = BenchmarkHistoryRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        let payload = try runner.load(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(payload.records[0].id, "compare-run-1")
    }

    func testRunnerThrowsProcessFailureForNonZeroExit() throws {
        let processRunner = RecordingHistoryProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 2, standardOutput: "", standardError: "storage failed")
        )
        let runner = BenchmarkHistoryRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        XCTAssertThrowsError(try runner.load(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))) { error in
            XCTAssertEqual(
                error as? BenchmarkHistoryRunnerError,
                .processFailed("storage failed")
            )
        }
    }
}

private final class RecordingHistoryProcessRunner: BenchmarkProcessRunning {
    struct Invocation {
        let executableURL: URL
        let arguments: [String]
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
        invocations.append(Invocation(executableURL: executableURL, arguments: arguments))
        return output
    }
}
