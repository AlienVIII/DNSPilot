import XCTest
@testable import DNSPilotMacCore

final class BenchmarkRunControlsViewModelTests: XCTestCase {
    func testIdleStateCanRunWhenSetupIsReady() {
        let viewModel = BenchmarkRunControlsViewModel(state: .idle, setupCanRun: true)

        XCTAssertEqual(viewModel.primaryLabel, "Run")
        XCTAssertTrue(viewModel.isPrimaryEnabled)
        XCTAssertFalse(viewModel.showsCancel)
    }

    func testRunningStateShowsCancelAndDisablesPrimary() {
        let runID = BenchmarkRunID(1)
        let viewModel = BenchmarkRunControlsViewModel(state: .running(runID: runID), setupCanRun: true)

        XCTAssertEqual(viewModel.primaryLabel, "Running")
        XCTAssertFalse(viewModel.isPrimaryEnabled)
        XCTAssertTrue(viewModel.showsCancel)
        XCTAssertTrue(viewModel.isCancelEnabled)
    }

    func testCancellingStateDisablesCancelUntilRunFinishes() {
        let runID = BenchmarkRunID(1)
        let viewModel = BenchmarkRunControlsViewModel(state: .cancelling(runID: runID), setupCanRun: true)

        XCTAssertEqual(viewModel.primaryLabel, "Cancelling")
        XCTAssertFalse(viewModel.isPrimaryEnabled)
        XCTAssertTrue(viewModel.showsCancel)
        XCTAssertFalse(viewModel.isCancelEnabled)
    }

    func testUnavailableSetupDisablesRun() {
        let viewModel = BenchmarkRunControlsViewModel(state: .idle, setupCanRun: false)

        XCTAssertEqual(viewModel.primaryLabel, "Run")
        XCTAssertFalse(viewModel.isPrimaryEnabled)
        XCTAssertFalse(viewModel.showsCancel)
    }
}
