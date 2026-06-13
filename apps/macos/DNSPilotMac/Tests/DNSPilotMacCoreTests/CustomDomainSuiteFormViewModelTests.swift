import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CustomDomainSuiteFormViewModelTests: XCTestCase {
    func testFormBuildsSuiteAddArguments() {
        let viewModel = CustomDomainSuiteFormViewModel(
            name: "Azure Lab",
            domainsText: "portal.azure.com, login.microsoftonline.com\nblob.core.windows.net"
        )

        XCTAssertTrue(viewModel.canSave)
        XCTAssertEqual(viewModel.suiteID, "azure-lab")
        XCTAssertEqual(viewModel.issues, [])
        XCTAssertEqual(
            viewModel.suiteAddArguments(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite")),
            [
                "suite-add",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "azure-lab",
                "--name", "Azure Lab",
                "--domain", "portal.azure.com",
                "--domain", "login.microsoftonline.com",
                "--domain", "blob.core.windows.net",
                "--tag", "custom",
            ]
        )
    }

    func testFormRejectsInvalidAndDuplicateDomains() {
        let viewModel = CustomDomainSuiteFormViewModel(
            name: "",
            domainsText: "example.com bad..domain EXAMPLE.com"
        )

        XCTAssertFalse(viewModel.canSave)
        XCTAssertEqual(
            viewModel.issues,
            [
                "Suite name is required.",
                "Invalid domain: bad..domain",
                "Duplicate domain: EXAMPLE.com",
            ]
        )
    }

    func testFormUsesFallbackSuiteIDWhenNameHasNoSafeCharacters() {
        let viewModel = CustomDomainSuiteFormViewModel(
            name: "!!!",
            domainsText: "example.com"
        )

        XCTAssertEqual(viewModel.suiteID, "custom-suite")
    }
}
