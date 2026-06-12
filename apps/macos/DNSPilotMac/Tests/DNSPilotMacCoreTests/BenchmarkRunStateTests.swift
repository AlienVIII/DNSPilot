import XCTest
@testable import DNSPilotMacCore

final class BenchmarkRunStateTests: XCTestCase {
    func testStateStartsIdleAndMovesToRunningWithRunID() {
        var state = BenchmarkRunStateMachine()

        let runID = state.start()

        XCTAssertEqual(state.state, .running(runID: runID))
    }

    func testStateMovesFromRunningToCancellingThenCancelled() {
        var state = BenchmarkRunStateMachine()
        let runID = state.start()

        state.requestCancel(runID: runID)
        XCTAssertEqual(state.state, .cancelling(runID: runID))

        state.finishCancelled(runID: runID)
        XCTAssertEqual(state.state, .cancelled)
    }

    func testStateIgnoresCompletionForStaleRunID() {
        var state = BenchmarkRunStateMachine()
        let oldRunID = state.start()
        let currentRunID = state.start()

        state.finishCompleted(runID: oldRunID)

        XCTAssertEqual(state.state, .running(runID: currentRunID))
    }

    func testStateIgnoresCompletionAfterCancellationRequested() {
        var state = BenchmarkRunStateMachine()
        let runID = state.start()

        state.requestCancel(runID: runID)
        state.finishCompleted(runID: runID)

        XCTAssertEqual(state.state, .cancelling(runID: runID))
    }

    func testStateRecordsFailureForCurrentRunningRun() {
        var state = BenchmarkRunStateMachine()
        let runID = state.start()

        state.finishFailed(runID: runID, message: "resolver timed out")

        XCTAssertEqual(state.state, .failed("resolver timed out"))
    }
}
