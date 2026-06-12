import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CustomDNSProfileFormViewModelTests: XCTestCase {
    func testFormBuildsProfileAddArgumentsForIPv4AndIPv6() {
        let viewModel = CustomDNSProfileFormViewModel(
            name: "My Lab DNS",
            ipv4ServersText: "1.1.1.1, 8.8.8.8",
            ipv6ServersText: "2606:4700:4700::1111\n2001:4860:4860::8888"
        )

        XCTAssertTrue(viewModel.canSave)
        XCTAssertEqual(viewModel.profileID, "my-lab-dns")
        XCTAssertEqual(viewModel.issues, [])
        XCTAssertEqual(
            viewModel.profileAddArguments(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite")),
            [
                "profile-add",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "my-lab-dns",
                "--name", "My Lab DNS",
                "--ipv4", "1.1.1.1",
                "--ipv4", "8.8.8.8",
                "--ipv6", "2606:4700:4700::1111",
                "--ipv6", "2001:4860:4860::8888",
                "--tag", "custom",
            ]
        )
    }

    func testFormRejectsMissingServers() {
        let viewModel = CustomDNSProfileFormViewModel(
            name: "Empty DNS",
            ipv4ServersText: "",
            ipv6ServersText: ""
        )

        XCTAssertFalse(viewModel.canSave)
        XCTAssertEqual(viewModel.issues, ["Add at least one IPv4 or IPv6 DNS server."])
    }

    func testFormRejectsInvalidFamilyAndDuplicateServers() {
        let viewModel = CustomDNSProfileFormViewModel(
            name: "Broken",
            ipv4ServersText: "1.1.1.1 2606:4700:4700::1111 1.1.1.1",
            ipv6ServersText: "not-ip"
        )

        XCTAssertFalse(viewModel.canSave)
        XCTAssertEqual(
            viewModel.issues,
            [
                "Invalid IPv4 DNS server: 2606:4700:4700::1111",
                "Duplicate IPv4 DNS server: 1.1.1.1",
                "Invalid IPv6 DNS server: not-ip",
            ]
        )
    }

    func testFormUsesFallbackProfileIDWhenNameHasNoSafeCharacters() {
        let viewModel = CustomDNSProfileFormViewModel(
            name: "!!!",
            ipv4ServersText: "1.1.1.1",
            ipv6ServersText: ""
        )

        XCTAssertEqual(viewModel.profileID, "custom-dns")
    }
}
