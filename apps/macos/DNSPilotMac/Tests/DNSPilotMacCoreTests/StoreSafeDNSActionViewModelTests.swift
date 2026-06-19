import XCTest
@testable import DNSPilotMacCore

final class StoreSafeDNSActionViewModelTests: XCTestCase {
    func testGuidedApplyConfirmationExplainsStoreSafeBehavior() {
        let viewModel = StoreSafeDNSActionConfirmationViewModel.guidedApply(
            profileName: "Cloudflare",
            dnsServers: ["1.1.1.1", "1.0.0.1"],
            hasRestoreDNS: true
        )

        XCTAssertEqual(viewModel.title, "Confirm guided DNS apply")
        XCTAssertEqual(viewModel.confirmLabel, "Copy DNS + Open Settings")
        XCTAssertTrue(viewModel.message.contains("Cloudflare"))
        XCTAssertTrue(viewModel.message.contains("2 DNS server(s)"))
        XCTAssertTrue(viewModel.message.contains("will not change system DNS automatically"))
        XCTAssertTrue(viewModel.message.contains("restore data is available"))
    }

    func testGuidedApplyConfirmationWarnsWhenRestoreDNSIsUnavailable() {
        let viewModel = StoreSafeDNSActionConfirmationViewModel.guidedApply(
            profileName: nil,
            dnsServers: ["9.9.9.9"],
            hasRestoreDNS: false
        )

        XCTAssertTrue(viewModel.message.contains("recommended DNS"))
        XCTAssertTrue(viewModel.message.contains("Current DNS was not captured"))
    }

    func testMacOSFlushGuidanceProvidesChecklistAndConfirmation() {
        let viewModel = StoreSafeDNSFlushGuidanceViewModel()

        XCTAssertEqual(viewModel.buttonLabel, "Flush DNS...")
        XCTAssertEqual(viewModel.confirmation.title, "Confirm DNS flush guidance")
        XCTAssertEqual(viewModel.confirmation.confirmLabel, "Copy Flush Checklist")
        XCTAssertTrue(viewModel.confirmation.message.contains("cannot run sudo DNS flush commands"))
        XCTAssertTrue(viewModel.checklistText.contains("sudo dscacheutil -flushcache"))
        XCTAssertTrue(viewModel.checklistText.contains("sudo killall -HUP mDNSResponder"))
    }
}
