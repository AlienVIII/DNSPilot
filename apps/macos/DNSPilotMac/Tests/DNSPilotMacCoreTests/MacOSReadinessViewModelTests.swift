import XCTest
@testable import DNSPilotMacCore

final class MacOSReadinessViewModelTests: XCTestCase {
    func testPermissionReadinessExplainsAskAsNeededPowerFlow() {
        let viewModel = MacOSPermissionReadinessViewModel(
            isPowerActionsEnabled: true,
            isDirectAdminAvailable: true
        )

        XCTAssertEqual(viewModel.rows.map(\.id), [
            "network-client",
            "system-dns-settings",
            "admin-apply-flush",
            "power-mode-flag",
            "no-silent-mutation",
        ])
        XCTAssertEqual(viewModel.rows.first { $0.id == "admin-apply-flush" }?.status, .ready)
        XCTAssertTrue(viewModel.rows.first { $0.id == "admin-apply-flush" }?.detail.contains("when you press") == true)
        XCTAssertEqual(viewModel.rows.first { $0.id == "power-mode-flag" }?.status, .ready)
        XCTAssertTrue(viewModel.rows.first { $0.id == "power-mode-flag" }?.detail.contains("Apply Now") == true)
        XCTAssertTrue(viewModel.copyText.contains("administrator approval"))
    }

    func testPermissionReadinessMarksPowerFlagManualWhenDisabled() {
        let viewModel = MacOSPermissionReadinessViewModel(
            isPowerActionsEnabled: false,
            isDirectAdminAvailable: true
        )

        XCTAssertEqual(viewModel.rows.first { $0.id == "admin-apply-flush" }?.status, .manual)
        XCTAssertTrue(viewModel.rows.first { $0.id == "admin-apply-flush" }?.detail.contains("available in this Power/direct-install build") == true)
        XCTAssertEqual(viewModel.rows.first { $0.id == "power-mode-flag" }?.status, .manual)
        XCTAssertTrue(viewModel.rows.first { $0.id == "power-mode-flag" }?.detail.contains("setup") == true)
        XCTAssertTrue(viewModel.rows.first { $0.id == "system-dns-settings" }?.detail.contains("does not provide a System Settings toggle") == true)
    }

    func testPermissionReadinessDoesNotOfferDirectAdminInStoreSafeBuild() {
        let viewModel = MacOSPermissionReadinessViewModel(
            isPowerActionsEnabled: false,
            isDirectAdminAvailable: false
        )

        XCTAssertEqual(viewModel.rows.first { $0.id == "admin-apply-flush" }?.status, .manual)
        XCTAssertTrue(viewModel.rows.first { $0.id == "admin-apply-flush" }?.detail.contains("Store-safe build does not expose Direct Admin Actions") == true)
        XCTAssertTrue(viewModel.rows.first { $0.id == "power-mode-flag" }?.detail.contains("Unavailable in the App Store-safe build") == true)
    }

    func testPublishReadinessSeparatesStoreAndPowerEditionWork() {
        let viewModel = MacOSPublishReadinessViewModel()

        XCTAssertEqual(viewModel.rows.first?.id, "minimum-macos")
        XCTAssertEqual(viewModel.rows.first { $0.id == "store-sandbox" }?.status, .ready)
        XCTAssertEqual(viewModel.rows.first { $0.id == "release-preflight" }?.status, .ready)
        XCTAssertTrue(viewModel.rows.first { $0.id == "release-preflight" }?.detail.contains("./script/preflight_macos_release.sh") == true)
        XCTAssertEqual(viewModel.rows.first { $0.id == "privacy-manifest" }?.status, .ready)
        XCTAssertTrue(viewModel.rows.first { $0.id == "privacy-manifest" }?.detail.contains("CA92.1") == true)
        XCTAssertEqual(viewModel.rows.first { $0.id == "release-signing" }?.status, .manual)
        XCTAssertEqual(viewModel.rows.first { $0.id == "power-edition-split" }?.status, .ready)
        XCTAssertTrue(viewModel.copyText.contains("App Store edition"))
        XCTAssertTrue(viewModel.copyText.contains("Power edition"))
        XCTAssertTrue(viewModel.copyText.contains("--include-power"))
        XCTAssertTrue(viewModel.copyText.contains("PrivacyInfo.xcprivacy"))
    }
}
