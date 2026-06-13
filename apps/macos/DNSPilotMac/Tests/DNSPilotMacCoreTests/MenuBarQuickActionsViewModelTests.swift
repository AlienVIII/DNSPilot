import XCTest
@testable import DNSPilotMacCore

final class MenuBarQuickActionsViewModelTests: XCTestCase {
    func testQuickActionsExposeBenchmarkAndHistoryDestinations() {
        let viewModel = MenuBarQuickActionsViewModel()

        let destinations = viewModel.actions.compactMap { action -> MenuBarQuickDestination? in
            if case .destination(let destination) = action.kind {
                return destination
            }
            return nil
        }

        XCTAssertEqual(destinations, [.openApp, .benchmark, .history])
    }

    func testQuickActionTitlesStayShortForMenuBar() {
        let viewModel = MenuBarQuickActionsViewModel()

        XCTAssertTrue(viewModel.actions.allSatisfy { $0.title.count <= 30 })
    }
}
