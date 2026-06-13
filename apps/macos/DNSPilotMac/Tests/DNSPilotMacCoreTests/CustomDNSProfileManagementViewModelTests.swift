import XCTest
@testable import DNSPilotMacCore

final class CustomDNSProfileManagementViewModelTests: XCTestCase {
    func testViewModelListsOnlyCustomPlainProfiles() {
        let viewModel = CustomDNSProfileManagementViewModel(
            profiles: [
                makeManagementProfile(id: "cloudflare", useCase: "performance", tags: [], protocol: .plain),
                makeManagementProfile(id: "custom-plain", useCase: "custom", tags: ["custom"], protocol: .plain),
                makeManagementProfile(id: "custom-doh", useCase: "custom", tags: ["custom"], protocol: .doh),
            ]
        )

        XCTAssertEqual(viewModel.rows.map(\.id), ["custom-plain"])
        XCTAssertEqual(viewModel.rows[0].ipv4ServersText, "1.1.1.1")
        XCTAssertEqual(viewModel.rows[0].ipv6ServersText, "2606:4700:4700::1111")
    }

    func testViewModelDeduplicatesProfileIDsForStableSwiftUIRows() {
        let viewModel = CustomDNSProfileManagementViewModel(
            profiles: [
                makeManagementProfile(id: "custom-plain", useCase: "custom", tags: ["custom"], protocol: .plain),
                makeManagementProfile(id: "custom-plain", useCase: "custom", tags: ["custom"], protocol: .plain),
            ]
        )

        XCTAssertEqual(viewModel.rows.map(\.id), ["custom-plain"])
    }

    func testViewModelMarksLegacyCustomProfileIDCollisionWithBuiltIn() {
        let viewModel = CustomDNSProfileManagementViewModel(
            profiles: [
                makeManagementProfile(id: "cloudflare", useCase: "performance", tags: [], protocol: .plain),
                makeManagementProfile(id: "cloudflare", useCase: "custom", tags: ["custom"], protocol: .plain),
            ]
        )

        XCTAssertEqual(viewModel.rows.map(\.id), ["cloudflare"])
        XCTAssertTrue(viewModel.rows[0].opensAsNewProfile)
        XCTAssertEqual(viewModel.rows[0].editHelpLabel, "Copy to new profile")
        XCTAssertEqual(
            viewModel.rows[0].warningLabel,
            "Built-in ID conflict. Edit creates a new custom-* copy; delete this legacy row after saving."
        )
    }
}

private func makeManagementProfile(
    id: String,
    useCase: String,
    tags: [String],
    protocol dnsProtocol: CatalogDNSProtocol
) -> CatalogProfile {
    CatalogProfile(
        id: id,
        name: id,
        description: "Profile",
        ipv4Servers: ["1.1.1.1"],
        ipv6Servers: ["2606:4700:4700::1111"],
        protocol: dnsProtocol,
        dohURL: dnsProtocol == .doh ? "https://dns.example/dns-query" : nil,
        dotHostname: nil,
        filteringType: .none,
        tags: tags,
        useCase: useCase,
        securityNotes: []
    )
}
