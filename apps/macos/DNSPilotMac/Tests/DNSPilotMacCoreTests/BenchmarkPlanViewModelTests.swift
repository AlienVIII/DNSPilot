import XCTest
@testable import DNSPilotMacCore

final class BenchmarkPlanViewModelTests: XCTestCase {
    func testBenchmarkPlanBuildsCompareArgsFromSelectedProfilesAndSuite() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: ["cloudflare", "google-public-dns"],
            selectedSuiteID: "developer",
            customDomains: [],
            attempts: 2,
            dnsTimeoutMS: 1_200,
            mode: .dnsOnlyCompare
        )

        XCTAssertTrue(viewModel.validation.canRun)
        XCTAssertEqual(viewModel.domains, ["github.com", "registry.npmjs.org"])
        XCTAssertEqual(
            viewModel.commandArguments,
            [
                "compare",
                "--resolver", "cloudflare=1.1.1.1:53",
                "--resolver", "google-public-dns=8.8.8.8:53",
                "--domain", "github.com",
                "--domain", "registry.npmjs.org",
                "--attempts", "2",
                "--ip-family", "both",
                "--timeout-ms", "1200",
            ]
        )
    }

    func testBenchmarkPlanBuildsPathCompareArgsWithCustomDomains() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: nil,
            customDomains: ["portal.azure.com", "login.microsoftonline.com"],
            attempts: 1,
            dnsTimeoutMS: 900,
            connectTimeoutMS: 700,
            maxConnectTargetsPerDomain: 2,
            mode: .connectionPathCompare
        )

        XCTAssertTrue(viewModel.validation.canRun)
        XCTAssertEqual(
            viewModel.commandArguments,
            [
                "path-compare",
                "--resolver", "cloudflare=1.1.1.1:53",
                "--domain", "portal.azure.com",
                "--domain", "login.microsoftonline.com",
                "--attempts", "1",
                "--ip-family", "both",
                "--dns-timeout-ms", "900",
                "--connect-timeout-ms", "700",
                "--max-connect-targets-per-domain", "2",
            ]
        )
    }

    func testBenchmarkPlanBuildsSystemDNSValidationArgsWithoutProfiles() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: [],
            selectedSuiteID: "developer",
            customDomains: ["login.microsoftonline.com"],
            attempts: 2,
            dnsTimeoutMS: 1_100,
            recordFamily: .ipv6Only,
            mode: .systemDNSValidation
        )

        XCTAssertTrue(viewModel.validation.canRun)
        XCTAssertEqual(viewModel.resolverCount, 1)
        XCTAssertEqual(
            viewModel.resolverTargets,
            [
                BenchmarkProgressResolverTarget(
                    id: "system-dns",
                    name: "System DNS",
                    resolver: "macOS system resolver"
                ),
            ]
        )
        XCTAssertEqual(
            viewModel.commandArguments,
            [
                "system-benchmark",
                "--platform", "macos-store",
                "--domain", "github.com",
                "--domain", "registry.npmjs.org",
                "--domain", "login.microsoftonline.com",
                "--attempts", "2",
                "--ip-family", "ipv6-only",
                "--timeout-ms", "1100",
            ]
        )
    }

    func testBenchmarkPlanRejectsEncryptedProfilesAndMissingDomains() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: ["custom-doh"],
            selectedSuiteID: nil,
            customDomains: [],
            attempts: 1,
            mode: .dnsOnlyCompare
        )

        XCTAssertFalse(viewModel.validation.canRun)
        XCTAssertTrue(viewModel.validation.issues.contains("Select at least one plain DNS profile."))
        XCTAssertTrue(viewModel.validation.issues.contains("Select a test suite or add custom domains."))
    }

    func testBenchmarkPlanRejectsInvalidCustomDomainsBeforeProcessExecution() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: nil,
            customDomains: ["https://portal.azure.com", "-bad.example", "bad_label.example"],
            attempts: 1,
            mode: .dnsOnlyCompare
        )

        XCTAssertFalse(viewModel.validation.canRun)
        XCTAssertTrue(
            viewModel.validation.issues.contains(
                "Invalid custom domain: https://portal.azure.com"
            )
        )
        XCTAssertTrue(viewModel.validation.issues.contains("Invalid custom domain: -bad.example"))
        XCTAssertTrue(viewModel.validation.issues.contains("Invalid custom domain: bad_label.example"))
    }

    func testBenchmarkPlanAllowsTrailingDotCustomDomainLikeRustCore() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: nil,
            customDomains: ["example.com."],
            attempts: 1,
            mode: .dnsOnlyCompare
        )

        XCTAssertTrue(viewModel.validation.canRun)
        XCTAssertTrue(viewModel.commandArguments.contains("example.com."))
    }

    func testBenchmarkPlanPassesIPv4OnlyRecordFamily() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: "developer",
            customDomains: [],
            attempts: 1,
            recordFamily: .ipv4Only,
            mode: .dnsOnlyCompare
        )

        XCTAssertTrue(viewModel.validation.canRun)
        XCTAssertEqual(viewModel.recordFamily.displayLabel, "A only")
        XCTAssertEqual(
            viewModel.commandArguments,
            [
                "compare",
                "--resolver", "cloudflare=1.1.1.1:53",
                "--domain", "github.com",
                "--domain", "registry.npmjs.org",
                "--attempts", "1",
                "--ip-family", "ipv4-only",
                "--timeout-ms", "800",
            ]
        )
    }

    func testBenchmarkOptionHelpIsLocalizedThroughTheCatalog() {
        let english = DNSPilotLocalizer(language: .english)
        let vietnamese = DNSPilotLocalizer(language: .vietnamese)

        XCTAssertEqual(english.text(.recordAAndAAAAHelp), "Query A (IPv4) and AAAA (IPv6) records.")
        XCTAssertEqual(vietnamese.text(.recordAAndAAAAHelp), "Hỏi cả bản ghi A (IPv4) và AAAA (IPv6).")
        XCTAssertEqual(english.text(.modeDNSTCPHelp), "Measure DNS lookup, then TCP connect timing for resolved addresses.")
        XCTAssertEqual(vietnamese.text(.resolverIPv6Help), "Chỉ dùng địa chỉ máy chủ DNS IPv6, ví dụ 2606:4700:4700::1111.")
    }

    func testBenchmarkPlanCanUseIPv6ResolverTransport() {
        let viewModel = BenchmarkPlanViewModel(
            catalog: makeBenchmarkCatalog(),
            selectedProfileIDs: ["cloudflare", "google-public-dns"],
            selectedSuiteID: "developer",
            customDomains: [],
            attempts: 1,
            resolverTransport: .ipv6Only,
            mode: .dnsOnlyCompare
        )

        XCTAssertTrue(viewModel.validation.canRun)
        XCTAssertEqual(viewModel.resolverCount, 1)
        XCTAssertEqual(
            viewModel.commandArguments,
            [
                "compare",
                "--resolver", "cloudflare=[2606:4700:4700::1111]:53",
                "--domain", "github.com",
                "--domain", "registry.npmjs.org",
                "--attempts", "1",
                "--ip-family", "both",
                "--timeout-ms", "800",
            ]
        )
    }
}

private func makeBenchmarkCatalog() -> CatalogSnapshot {
    CatalogSnapshot(
        profiles: [
            CatalogProfile(
                id: "cloudflare",
                name: "Cloudflare",
                description: "Fast unfiltered public DNS.",
                ipv4Servers: ["1.1.1.1", "1.0.0.1"],
                ipv6Servers: ["2606:4700:4700::1111"],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: ["general"],
                useCase: "performance",
                securityNotes: []
            ),
            CatalogProfile(
                id: "google-public-dns",
                name: "Google Public DNS",
                description: "Google unfiltered public DNS.",
                ipv4Servers: ["8.8.8.8"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: ["general"],
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
                tags: ["custom"],
                useCase: "privacy",
                securityNotes: []
            ),
        ],
        testSuites: [
            CatalogTestSuite(
                id: "developer",
                name: "Developer",
                description: "Developer workflow checks.",
                domains: ["github.com", "registry.npmjs.org"],
                tags: ["developer"]
            )
        ]
    )
}
