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

        XCTAssertEqual(destinations, [.openApp, .benchmark, .quickBenchmark, .systemDNSValidation, .history, .networkSettings])
    }

    func testQuickActionTitlesStayShortForMenuBar() {
        let viewModel = MenuBarQuickActionsViewModel()

        XCTAssertTrue(viewModel.actions.allSatisfy { $0.title.count <= 30 })
    }

    func testQuickActionsExposeStoreSafeSettingsFallback() {
        let viewModel = MenuBarQuickActionsViewModel()

        let action = viewModel.actions.first { $0.id == "network-settings" }

        XCTAssertEqual(action?.title, "Open Network Settings")
        XCTAssertEqual(action?.systemImage, "gearshape")
        XCTAssertEqual(action?.kind, .destination(.networkSettings))
    }

    func testQuickActionsExposeSystemDNSValidation() {
        let viewModel = MenuBarQuickActionsViewModel()

        let action = viewModel.actions.first { $0.id == "validate-system-dns" }

        XCTAssertEqual(action?.title, "Validate System DNS")
        XCTAssertEqual(action?.systemImage, "checkmark.seal")
        XCTAssertEqual(action?.kind, .destination(.systemDNSValidation))
    }
}
