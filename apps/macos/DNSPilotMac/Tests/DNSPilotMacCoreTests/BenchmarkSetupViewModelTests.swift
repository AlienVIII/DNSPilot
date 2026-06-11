import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkSetupViewModelTests: XCTestCase {
    func testSetupDefaultsSelectRunnableProfilesAndFirstSuite() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli"))
        )

        XCTAssertEqual(viewModel.selectedProfileIDs, ["cloudflare", "google-public-dns"])
        XCTAssertEqual(viewModel.selectedSuiteID, "developer")
        XCTAssertTrue(viewModel.canRun)
        XCTAssertEqual(viewModel.readinessIssues, [])
    }

    func testSetupParsesCustomDomainTextIntoPlan() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: nil,
            customDomainsText: "portal.azure.com, login.microsoftonline.com\nmanagement.azure.com",
            attempts: 2,
            mode: .connectionPathCompare
        )

        XCTAssertEqual(
            viewModel.plan.domains,
            ["portal.azure.com", "login.microsoftonline.com", "management.azure.com"]
        )
        XCTAssertEqual(viewModel.plan.commandArguments.first, "path-compare")
        XCTAssertTrue(viewModel.canRun)
    }

    func testSetupBlocksRunWhenExecutableIsUnavailable() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .unavailable("CLI missing")
        )

        XCTAssertFalse(viewModel.canRun)
        XCTAssertEqual(viewModel.readinessIssues, ["CLI missing"])
    }

    func testSetupMarksEncryptedProfilesAsNotRunnableForPlainBenchmark() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli"))
        )

        let encryptedOption = viewModel.profileOptions.first { $0.id == "custom-doh" }
        XCTAssertEqual(encryptedOption?.isRunnable, false)
        XCTAssertEqual(encryptedOption?.detailLabel, "Requires OS DNS profile flow")
    }
}

private func makeSetupCatalog() -> CatalogSnapshot {
    CatalogSnapshot(
        profiles: [
            CatalogProfile(
                id: "cloudflare",
                name: "Cloudflare",
                description: "Fast public DNS.",
                ipv4Servers: ["1.1.1.1"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: [],
                useCase: "performance",
                securityNotes: []
            ),
            CatalogProfile(
                id: "google-public-dns",
                name: "Google Public DNS",
                description: "Google public DNS.",
                ipv4Servers: ["8.8.8.8"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: [],
                useCase: "performance",
                securityNotes: []
            ),
            CatalogProfile(
                id: "custom-doh",
                name: "Custom DoH",
                description: "Encrypted DNS endpoint.",
                ipv4Servers: [],
                ipv6Servers: [],
                protocol: .doh,
                dohURL: "https://dns.example/dns-query",
                dotHostname: nil,
                filteringType: .none,
                tags: [],
                useCase: "privacy",
                securityNotes: []
            ),
        ],
        testSuites: [
            CatalogTestSuite(
                id: "developer",
                name: "Developer",
                description: "Developer domains.",
                domains: ["github.com"],
                tags: []
            ),
        ]
    )
}
