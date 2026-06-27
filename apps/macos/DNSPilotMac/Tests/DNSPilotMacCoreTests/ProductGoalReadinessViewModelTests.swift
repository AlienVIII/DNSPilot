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

    func testEveryGoalHasEntryPointAndValidationEvidence() {
        let viewModel = ProductGoalReadinessViewModel()

        for row in viewModel.rows {
            XCTAssertFalse(row.entryPoint.isEmpty, "Missing entry point for \(row.id)")
            XCTAssertFalse(row.validationEvidence.isEmpty, "Missing validation evidence for \(row.id)")
        }
    }

    func testVietnameseReadinessLocalizesUserFacingGoalCopy() {
        let localizer = DNSPilotLocalizer(language: .vietnamese)
        let viewModel = ProductGoalReadinessViewModel(localizer: localizer)

        XCTAssertEqual(viewModel.rows.first?.title, "Kiểm tra DNS nhanh nhất")
        XCTAssertEqual(viewModel.rows.first?.status.localizedLabel(localizer: localizer), "Đã hỗ trợ")
        XCTAssertTrue(viewModel.rows.first?.entryPoint.contains("Benchmark") == true)
    }

    func testApplyAndFlushStayHonestAboutStoreSafeLimits() {
        let viewModel = ProductGoalReadinessViewModel()

        let apply = viewModel.rows.first { $0.id == "apply-selected-dns" }
        let flush = viewModel.rows.first { $0.id == "flush-dns" }

        XCTAssertEqual(apply?.status, .storeSafeGuided)
        XCTAssertEqual(apply?.statusLabel, "Store-safe guided")
        XCTAssertTrue(apply?.caveat.contains("Power edition") == true)
        XCTAssertTrue(apply?.caveat.contains("DNSPilotPowerActionsEnabled") == true)
        XCTAssertTrue(apply?.caveat.contains("DNSPILOT_ENABLE_POWER_ACTIONS") == true)
        XCTAssertTrue(apply?.entryPoint.contains("Catalog") == true)
        XCTAssertTrue(apply?.validationEvidence.contains("MacOSPowerDNSActionRunnerTests") == true)

        XCTAssertEqual(flush?.status, .storeSafeGuided)
        XCTAssertTrue(flush?.caveat.contains("admin") == true)
        XCTAssertTrue(flush?.caveat.contains("DNSPilotPowerActionsEnabled") == true)
        XCTAssertTrue(flush?.caveat.contains("DNSPILOT_ENABLE_POWER_ACTIONS") == true)
        XCTAssertTrue(flush?.entryPoint.contains("Menu Bar") == true)
        XCTAssertTrue(flush?.validationEvidence.contains("MacOSPowerDNSActionRunnerTests") == true)
    }

    func testGameChecksArePresentedAsEstimates() {
        let viewModel = ProductGoalReadinessViewModel()

        let gameChecks = viewModel.rows.first { $0.id == "game-server-checks" }

        XCTAssertEqual(gameChecks?.status, .estimated)
        XCTAssertTrue(gameChecks?.caveat.contains("not ICMP") == true)
        XCTAssertTrue(gameChecks?.summary.contains("Dota 2 SEA") == true)
        XCTAssertTrue(gameChecks?.entryPoint.contains("Game Ping") == true)
        XCTAssertTrue(gameChecks?.validationEvidence.contains("GamePingPlanViewModelTests") == true)
    }
}
