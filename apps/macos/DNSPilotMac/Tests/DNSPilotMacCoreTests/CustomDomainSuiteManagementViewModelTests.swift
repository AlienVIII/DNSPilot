import XCTest
@testable import DNSPilotMacCore

final class CustomDomainSuiteManagementViewModelTests: XCTestCase {
    func testViewModelListsOnlyCustomSuites() {
        let viewModel = CustomDomainSuiteManagementViewModel(
            testSuites: [
                makeSuite(id: "general", description: "Built-in suite.", tags: ["general"]),
                makeSuite(id: "azure-lab", description: "Custom domain test suite.", tags: ["azure"]),
                makeSuite(id: "office-lab", description: "Office domains.", tags: ["custom"]),
            ]
        )

        XCTAssertEqual(viewModel.rows.map(\.id), ["azure-lab", "office-lab"])
        XCTAssertEqual(viewModel.rows[0].domainsText, "portal.azure.com\nlogin.microsoftonline.com")
        XCTAssertEqual(viewModel.rows[0].domainCountLabel, "2 domains")
    }

    func testViewModelDeduplicatesSuiteIDsForStableSwiftUIRows() {
        let viewModel = CustomDomainSuiteManagementViewModel(
            testSuites: [
                makeSuite(id: "azure-lab", description: "Custom domain test suite.", tags: ["custom"]),
                makeSuite(id: "azure-lab", description: "Custom domain test suite.", tags: ["custom"]),
            ]
        )

        XCTAssertEqual(viewModel.rows.map(\.id), ["azure-lab"])
    }

    func testViewModelMarksLegacyCustomSuiteIDCollisionWithBuiltIn() {
        let viewModel = CustomDomainSuiteManagementViewModel(
            testSuites: [
                makeSuite(id: "developer", description: "Built-in developer suite.", tags: ["developer"]),
                makeSuite(id: "developer", description: "Custom domain test suite.", tags: ["custom"]),
            ]
        )

        XCTAssertEqual(viewModel.rows.map(\.id), ["developer"])
        XCTAssertTrue(viewModel.rows[0].opensAsNewSuite)
        XCTAssertEqual(viewModel.rows[0].editHelpLabel, "Copy to new suite")
        XCTAssertEqual(
            viewModel.rows[0].warningLabel,
            "ID conflicts with a built-in suite. Edit opens a new custom-* copy; delete this legacy row after saving."
        )
    }
}

private func makeSuite(id: String, description: String, tags: [String]) -> CatalogTestSuite {
    CatalogTestSuite(
        id: id,
        name: id,
        description: description,
        domains: ["portal.azure.com", "login.microsoftonline.com"],
        tags: tags
    )
}
