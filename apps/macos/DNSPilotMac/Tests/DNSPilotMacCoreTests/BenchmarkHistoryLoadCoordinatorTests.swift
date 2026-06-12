import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkHistoryLoadCoordinatorTests: XCTestCase {
    func testCoordinatorReturnsLoadedViewModelForHistoryPayload() {
        let coordinator = BenchmarkHistoryLoadCoordinator(
            runner: BenchmarkHistoryRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: FixedHistoryProcessRunner(
                    output: BenchmarkProcessOutput(exitCode: 0, standardOutput: historyListJSON, standardError: "")
                )
            ),
            catalog: makeHistoryCatalog()
        )

        let outcome = coordinator.load(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(
            outcome,
            .loaded(BenchmarkHistoryViewModel(
                payload: try! BenchmarkHistoryJSONDecoder.decode(historyListJSON),
                catalog: makeHistoryCatalog()
            ))
        )
    }

    func testCoordinatorReturnsProcessFailureMessage() {
        let coordinator = BenchmarkHistoryLoadCoordinator(
            runner: BenchmarkHistoryRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: FixedHistoryProcessRunner(
                    output: BenchmarkProcessOutput(exitCode: 2, standardOutput: "", standardError: "storage failed")
                )
            ),
            catalog: makeHistoryCatalog()
        )

        let outcome = coordinator.load(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(outcome, .failed("storage failed"))
    }

    func testCoordinatorReturnsParseFailureMessage() {
        let coordinator = BenchmarkHistoryLoadCoordinator(
            runner: BenchmarkHistoryRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: FixedHistoryProcessRunner(
                    output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "not-json", standardError: "")
                )
            ),
            catalog: makeHistoryCatalog()
        )

        let outcome = coordinator.load(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(outcome, .failed("Could not parse benchmark history."))
    }
}

private final class FixedHistoryProcessRunner: BenchmarkProcessRunning {
    private let output: BenchmarkProcessOutput

    init(output: BenchmarkProcessOutput) {
        self.output = output
    }

    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?
    ) throws -> BenchmarkProcessOutput {
        output
    }
}
