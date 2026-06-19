import XCTest
@testable import DNSPilotMacCore

final class ProductGoalReadinessViewModelTests: XCTestCase {
    func testDefaultReadinessTracksMainProductGoals() {
        let viewModel = ProductGoalReadinessViewModel()

        XCTAssertEqual(viewModel.rows.map(\.id), [
            "fastest-dns",
            "balanced-dns",
            "apply-selected-dns",
            "flush-dns",
            "saved-domains",
            "game-server-checks",
        ])
    }

    func testApplyAndFlushStayHonestAboutStoreSafeLimits() {
        let viewModel = ProductGoalReadinessViewModel()

        let apply = viewModel.rows.first { $0.id == "apply-selected-dns" }
        let flush = viewModel.rows.first { $0.id == "flush-dns" }

        XCTAssertEqual(apply?.status, .storeSafeGuided)
        XCTAssertEqual(apply?.statusLabel, "Store-safe guided")
        XCTAssertTrue(apply?.caveat.contains("Power edition") == true)

        XCTAssertEqual(flush?.status, .storeSafeGuided)
        XCTAssertTrue(flush?.caveat.contains("admin") == true)
    }

    func testGameChecksArePresentedAsEstimates() {
        let viewModel = ProductGoalReadinessViewModel()

        let gameChecks = viewModel.rows.first { $0.id == "game-server-checks" }

        XCTAssertEqual(gameChecks?.status, .estimated)
        XCTAssertTrue(gameChecks?.caveat.contains("not ICMP") == true)
        XCTAssertTrue(gameChecks?.summary.contains("Dota 2 SEA") == true)
    }
}
