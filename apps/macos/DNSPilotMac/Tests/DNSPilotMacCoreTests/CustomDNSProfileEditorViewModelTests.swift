import XCTest
@testable import DNSPilotMacCore

final class CustomDNSProfileEditorViewModelTests: XCTestCase {
    func testEditorEnablesSaveForValidIdleForm() {
        let viewModel = CustomDNSProfileEditorViewModel(
            name: "Office DNS",
            ipv4ServersText: "1.1.1.1",
            ipv6ServersText: "",
            state: .idle
        )

        XCTAssertTrue(viewModel.canSave)
        XCTAssertEqual(viewModel.saveButtonLabel, "Save Profile")
        XCTAssertEqual(viewModel.profileIDLabel, "Profile ID: custom-office-dns")
        XCTAssertTrue(viewModel.issues.isEmpty)
        XCTAssertNil(viewModel.statusMessage)
    }

    func testEditorDisablesSaveAndShowsIssuesForInvalidForm() {
        let viewModel = CustomDNSProfileEditorViewModel(
            name: "",
            ipv4ServersText: "not-an-ip",
            ipv6ServersText: "",
            state: .idle
        )

        XCTAssertFalse(viewModel.canSave)
        XCTAssertEqual(
            viewModel.issues,
            [
                "Name is required.",
                "Invalid IPv4 DNS server: not-an-ip",
            ]
        )
    }

    func testEditorDisablesSaveWhileSaving() {
        let viewModel = CustomDNSProfileEditorViewModel(
            name: "Office DNS",
            ipv4ServersText: "1.1.1.1",
            ipv6ServersText: "",
            state: .saving
        )

        XCTAssertFalse(viewModel.canSave)
        XCTAssertEqual(viewModel.saveButtonLabel, "Saving")
        XCTAssertEqual(viewModel.statusMessage, "Saving Office DNS...")
    }

    func testEditorShowsSavedAndFailedStatusMessages() {
        let saved = CustomDNSProfileEditorViewModel(
            name: "Office DNS",
            ipv4ServersText: "1.1.1.1",
            ipv6ServersText: "",
            state: .saved(profileID: "office-dns", name: "Office DNS")
        )
        let failed = CustomDNSProfileEditorViewModel(
            name: "Office DNS",
            ipv4ServersText: "1.1.1.1",
            ipv6ServersText: "",
            state: .failed("profile already exists")
        )

        XCTAssertEqual(saved.statusMessage, "Saved Office DNS as office-dns.")
        XCTAssertEqual(failed.statusMessage, "profile already exists")
    }
}
