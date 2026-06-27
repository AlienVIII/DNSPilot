import XCTest
@testable import DNSPilotMacCore

final class MacOSReadinessViewModelTests: XCTestCase {
    func testPermissionReadinessExplainsAskAsNeededPowerFlow() {
        let viewModel = MacOSPermissionReadinessViewModel(isPowerActionsEnabled: true)

        XCTAssertEqual(viewModel.rows.map(\.id), [
            "network-client",
            "system-dns-settings",
            "admin-apply-flush",
            "power-mode-flag",
            "no-silent-mutation",
        ])
        XCTAssertEqual(viewModel.rows.first { $0.id == "admin-apply-flush" }?.status, .manual)
        XCTAssertTrue(viewModel.rows.first { $0.id == "admin-apply-flush" }?.detail.contains("when you press") == true)
        XCTAssertEqual(viewModel.rows.first { $0.id == "power-mode-flag" }?.status, .ready)
        XCTAssertTrue(viewModel.rows.first { $0.id == "power-mode-flag" }?.detail.contains("Info.plist") == true)
        XCTAssertTrue(viewModel.copyText.contains("administrator approval"))
    }

    func testPermissionReadinessMarksPowerFlagManualWhenDisabled() {
        let viewModel = MacOSPermissionReadinessViewModel(isPowerActionsEnabled: false)

        XCTAssertEqual(viewModel.rows.first { $0.id == "power-mode-flag" }?.status, .manual)
        XCTAssertTrue(viewModel.rows.first { $0.id == "power-mode-flag" }?.detail.contains("DNSPilotPowerActionsEnabled=true") == true)
        XCTAssertTrue(viewModel.rows.first { $0.id == "power-mode-flag" }?.detail.contains("DNSPILOT_ENABLE_POWER_ACTIONS=1") == true)
    }

    func testPublishReadinessSeparatesStoreAndPowerEditionWork() {
        let viewModel = MacOSPublishReadinessViewModel()

        XCTAssertEqual(viewModel.rows.first?.id, "minimum-macos")
        XCTAssertEqual(viewModel.rows.first { $0.id == "store-sandbox" }?.status, .ready)
        XCTAssertEqual(viewModel.rows.first { $0.id == "release-preflight" }?.status, .ready)
        XCTAssertTrue(viewModel.rows.first { $0.id == "release-preflight" }?.detail.contains("./script/preflight_macos_release.sh") == true)
        XCTAssertEqual(viewModel.rows.first { $0.id == "release-signing" }?.status, .manual)
        XCTAssertEqual(viewModel.rows.first { $0.id == "power-edition-split" }?.status, .ready)
        XCTAssertTrue(viewModel.copyText.contains("App Store edition"))
        XCTAssertTrue(viewModel.copyText.contains("Power edition"))
        XCTAssertTrue(viewModel.copyText.contains("--include-power"))
    }
}
