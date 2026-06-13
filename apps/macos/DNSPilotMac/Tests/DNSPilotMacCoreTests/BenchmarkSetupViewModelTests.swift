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
        XCTAssertEqual(viewModel.runnableProfileIDs, ["cloudflare", "google-public-dns"])
        XCTAssertEqual(viewModel.selectedSuiteID, "developer")
        XCTAssertEqual(viewModel.recordFamily, .both)
        XCTAssertEqual(viewModel.resolverTransport, .automatic)
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

    func testSetupSummarizesRunnableProfileSelection() {
        let partialSelection = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            mode: .dnsOnlyCompare
        )
        let allSelected = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare", "google-public-dns"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            mode: .dnsOnlyCompare
        )

        XCTAssertEqual(partialSelection.profileSelectionSummary, "1 of 2 runnable selected")
        XCTAssertEqual(allSelected.profileSelectionSummary, "2 of 2 runnable selected")
    }

    func testSetupSummarizesRunPlanBeforeStarting() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare", "google-public-dns"],
            selectedSuiteID: "developer",
            customDomainsText: "github.com",
            attempts: 2,
            mode: .connectionPathCompare
        )

        XCTAssertEqual(viewModel.runPlanSummary, "DNS + TCP, A + AAAA, 2 resolvers, 1 domain, 2 attempts, 4 TCP targets/domain")
    }

    func testSetupSummarizesIPv4OnlyRecordFamily() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            recordFamily: .ipv4Only,
            mode: .dnsOnlyCompare
        )

        XCTAssertEqual(viewModel.runPlanSummary, "DNS only, A only, 1 resolver, 1 domain, 1 attempt")
        XCTAssertNil(viewModel.estimatedDurationWarning)
    }

    func testSetupFiltersRunnableProfilesByResolverTransport() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare", "google-public-dns"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            resolverTransport: .ipv6Only,
            mode: .dnsOnlyCompare
        )

        XCTAssertEqual(viewModel.runnableProfileIDs, ["cloudflare"])
        XCTAssertEqual(viewModel.profileSelectionSummary, "1 of 1 runnable selected")
        XCTAssertEqual(viewModel.runPlanSummary, "DNS only, IPv6 resolver, A + AAAA, 1 resolver, 1 domain, 1 attempt")
        XCTAssertEqual(
            viewModel.plan.commandArguments,
            [
                "compare",
                "--resolver", "cloudflare=[2606:4700:4700::1111]:53",
                "--domain", "github.com",
                "--attempts", "1",
                "--ip-family", "both",
                "--timeout-ms", "800",
            ]
        )
    }

    func testSetupWarnsWhenWorstCaseBenchmarkDurationIsLong() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare", "google-public-dns"],
            selectedSuiteID: "developer",
            customDomainsText: "azure.microsoft.com login.microsoftonline.com management.azure.com",
            attempts: 3,
            mode: .connectionPathCompare
        )

        XCTAssertEqual(
            viewModel.estimatedDurationWarning,
            "Estimated worst-case wait: about 134.4 s. Reduce profiles, domains, or attempts if this looks too long."
        )
    }

    func testSetupDoesNotWarnForShortBenchmarks() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            mode: .dnsOnlyCompare
        )

        XCTAssertNil(viewModel.estimatedDurationWarning)
    }

    func testSetupExplainsDirectResolverFlushPolicy() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli"))
        )

        XCTAssertEqual(
            viewModel.flushPolicySummary,
            "Direct resolver test; system DNS flush is not required."
        )
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
                ipv6Servers: ["2606:4700:4700::1111"],
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
