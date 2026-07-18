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

    func testPowerDNSActionViewModelIsHiddenWhenDisabled() {
        let viewModel = MacOSPowerDNSActionViewModel(isEnabled: false)

        XCTAssertNil(viewModel.applyButtonLabel)
        XCTAssertNil(viewModel.flushButtonLabel)
    }

    func testPowerDNSActionViewModelExplainsAdminApplyAndFlush() {
        let viewModel = MacOSPowerDNSActionViewModel(isEnabled: true)

        XCTAssertEqual(viewModel.applyButtonLabel, "Apply Now (Admin)")
        XCTAssertEqual(viewModel.flushButtonLabel, "Flush Now (Admin)")
        XCTAssertTrue(
            viewModel.applyConfirmationMessage(profileName: "Cloudflare", dnsServers: ["1.1.1.1", "1.0.0.1"])
                .contains("administrator approval")
        )
        XCTAssertTrue(
            viewModel.applyConfirmationMessage(profileName: "Cloudflare", dnsServers: ["1.1.1.1", "1.0.0.1"])
                .contains("Cloudflare")
        )
        XCTAssertTrue(viewModel.flushConfirmationMessage.contains("administrator approval"))
    }

    func testPowerRollbackViewModelExplainsAutomaticRestore() {
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .automatic,
            servers: [],
            appliedMode: .servers,
            appliedServers: ["1.1.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let viewModel = PowerDNSRollbackViewModel(
            isEnabled: true,
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: 1_100)
        )

        XCTAssertEqual(viewModel.restoreButtonLabel, "Restore Previous DNS (Admin)")
        XCTAssertTrue(viewModel.confirmationMessage.contains("Wi-Fi"))
        XCTAssertTrue(viewModel.confirmationMessage.contains("automatic DNS"))
    }

    func testPowerRollbackViewModelHidesStaleOrDisabledRestore() {
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["192.168.1.1"],
            appliedMode: .servers,
            appliedServers: ["1.1.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertNil(PowerDNSRollbackViewModel(
            isEnabled: false,
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: 1_100)
        ).restoreButtonLabel)
        XCTAssertNil(PowerDNSRollbackViewModel(
            isEnabled: true,
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: 100_000)
        ).restoreButtonLabel)
    }

    func testPowerRollbackViewModelHidesLegacySnapshotWithoutAppliedState() {
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["192.168.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertNil(PowerDNSRollbackViewModel(
            isEnabled: true,
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: 1_100)
        ).restoreButtonLabel)
    }
}
