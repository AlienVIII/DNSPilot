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

    func testSetupDefaultsPreferUnfilteredProfilesForGeneralBenchmarks() {
        let baseCatalog = makeSetupCatalog()
        let catalog = CatalogSnapshot(
            profiles: [
                CatalogProfile(
                    id: "filtered-first",
                    name: "Filtered First",
                    description: "Filtered DNS.",
                    ipv4Servers: ["1.1.1.2"],
                    ipv6Servers: [],
                    protocol: .plain,
                    dohURL: nil,
                    dotHostname: nil,
                    filteringType: .malware,
                    tags: [],
                    useCase: "filtering",
                    securityNotes: []
                ),
            ] + baseCatalog.profiles,
            testSuites: baseCatalog.testSuites
        )

        let viewModel = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli"))
        )

        XCTAssertEqual(viewModel.selectedProfileIDs, ["cloudflare", "google-public-dns"])
    }

    func testSetupDefaultsUseFilteredProfilesOnlyToFillMissingUnfilteredSlots() {
        let catalog = CatalogSnapshot(
            profiles: [
                CatalogProfile(
                    id: "filtered-first",
                    name: "Filtered First",
                    description: "Filtered DNS.",
                    ipv4Servers: ["1.1.1.2"],
                    ipv6Servers: [],
                    protocol: .plain,
                    dohURL: nil,
                    dotHostname: nil,
                    filteringType: .malware,
                    tags: [],
                    useCase: "filtering",
                    securityNotes: []
                ),
                CatalogProfile(
                    id: "unfiltered",
                    name: "Unfiltered",
                    description: "Plain DNS.",
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
                    id: "filtered-second",
                    name: "Filtered Second",
                    description: "Filtered DNS.",
                    ipv4Servers: ["1.1.1.3"],
                    ipv6Servers: [],
                    protocol: .plain,
                    dohURL: nil,
                    dotHostname: nil,
                    filteringType: .family,
                    tags: [],
                    useCase: "filtering",
                    securityNotes: []
                ),
            ],
            testSuites: makeSetupCatalog().testSuites
        )

        let viewModel = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli"))
        )

        XCTAssertEqual(viewModel.selectedProfileIDs, ["unfiltered", "filtered-first"])
    }

    func testQuickRunPresetUsesFastSafeDefaults() {
        let viewModel = BenchmarkSetupViewModel.quickRunPreset(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli"))
        )

        XCTAssertEqual(viewModel.mode, .dnsOnlyCompare)
        XCTAssertEqual(viewModel.attempts, 1)
        XCTAssertEqual(viewModel.dnsTimeoutMS, 800)
        XCTAssertEqual(viewModel.connectTimeoutMS, 800)
        XCTAssertEqual(viewModel.maxConnectTargetsPerDomain, 2)
        XCTAssertEqual(viewModel.selectedProfileIDs, ["cloudflare", "google-public-dns"])
        XCTAssertNil(viewModel.selectedSuiteID)
        XCTAssertEqual(
            viewModel.customDomainsText,
            "github.com\nlogin.microsoftonline.com\nvnexpress.net"
        )
        XCTAssertEqual(viewModel.runPlanSummary, "DNS only, A + AAAA, 2 resolvers, 3 domains, 1 attempt")
    }

    func testGamingSuiteIsAvailableToBenchmarkAndExplainsItsLimit() {
        let baseCatalog = makeSetupCatalog()
        let catalog = CatalogSnapshot(
            profiles: baseCatalog.profiles,
            testSuites: baseCatalog.testSuites + [
                CatalogTestSuite(
                    id: "gaming-dota2-sea",
                    name: "Gaming / Dota 2 SEA",
                    description: "Dota 2 endpoint check.",
                    domains: ["steamcommunity.com"],
                    tags: ["gaming", "dota2", "sea"]
                ),
            ]
        )
        let viewModel = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: "gaming-dota2-sea",
            customDomainsText: "",
            attempts: 1,
            mode: .connectionPathCompare
        )

        XCTAssertTrue(viewModel.isGamingSuiteSelected)
        XCTAssertEqual(
            viewModel.gameCheckDisclaimer,
            "Game check estimates DNS and TCP connection timing. It is not ICMP ping or in-match UDP latency."
        )
        XCTAssertEqual(viewModel.plan.commandArguments.first, "path-compare")
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
        XCTAssertEqual(
            encryptedOption?.detailLabel(localizer: DNSPilotLocalizer(language: .english)),
            "Requires macOS DNS profile"
        )
        XCTAssertEqual(
            encryptedOption?.helpText(localizer: DNSPilotLocalizer(language: .vietnamese)),
            "DNS mã hóa dùng luồng cấu hình DNS của macOS và chưa được đưa vào benchmark DNS thường trực tiếp."
        )
    }

    func testSetupProfileAndSuiteOptionsLocalizeHelpText() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli"))
        )
        let vietnamese = DNSPilotLocalizer(language: .vietnamese)

        XCTAssertEqual(
            viewModel.profileOptions.first?.helpText(localizer: vietnamese),
            "Cấu hình DNS thường. Máy chủ được test tuân theo tùy chọn Máy chủ phân giải."
        )
        XCTAssertEqual(
            viewModel.suiteOptions.first?.helpText(localizer: vietnamese),
            "Kiểm tra các domain đã lưu trong bộ test này."
        )
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
        XCTAssertEqual(
            partialSelection.profileSelectionState,
            .selectedRunnableProfiles(selected: 1, runnable: 2)
        )
        XCTAssertEqual(
            allSelected.profileSelectionState,
            .selectedRunnableProfiles(selected: 2, runnable: 2)
        )
    }

    func testSetupWarnsWhenFilteredAndUnfilteredProfilesAreMixed() {
        let catalog = makeFilteringSetupCatalog()
        let mixedSelection = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare", "filtered"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            mode: .dnsOnlyCompare
        )
        let unfilteredOnly = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["cloudflare"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            mode: .dnsOnlyCompare
        )
        let filteredOnly = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: ["filtered"],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            mode: .dnsOnlyCompare
        )

        XCTAssertEqual(
            mixedSelection.profileSelectionCaveat,
            "Filtered DNS is selected with unfiltered resolvers; compare filtering goals separately."
        )
        XCTAssertNil(unfilteredOnly.profileSelectionCaveat)
        XCTAssertNil(filteredOnly.profileSelectionCaveat)
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
        XCTAssertEqual(
            viewModel.profileOptions.first { $0.id == "google-public-dns" }?.detailLabel(
                localizer: DNSPilotLocalizer(language: .english)
            ),
            "No IPv6 resolver"
        )
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

    func testSetupExplainsSystemDNSValidationFlushPolicy() {
        let viewModel = BenchmarkSetupViewModel(
            catalog: makeSetupCatalog(),
            executableAvailability: .ready(URL(fileURLWithPath: "/tmp/dnspilot-cli")),
            selectedProfileIDs: [],
            selectedSuiteID: "developer",
            customDomainsText: "",
            attempts: 1,
            mode: .systemDNSValidation
        )

        XCTAssertTrue(viewModel.canRun)
        XCTAssertEqual(
            viewModel.runPlanSummary,
            "System DNS, A + AAAA, 1 resolver, 1 domain, 1 attempt"
        )
        XCTAssertEqual(
            viewModel.flushPolicySummary,
            "System DNS validation should flush macOS DNS cache before testing."
        )
        XCTAssertEqual(
            viewModel.systemDNSFlushChecklistText,
            """
            System DNS validation checklist
            1. Apply DNS manually in macOS Network Settings.
            2. If allowed, flush local DNS cache before validating:
               sudo dscacheutil -flushcache
               sudo killall -HUP mDNSResponder
            3. Run System DNS validation in DNS Pilot.
            4. Treat browser Secure DNS, VPN, MDM, captive portal, and app caches as possible distortions.
            """
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

private func makeFilteringSetupCatalog() -> CatalogSnapshot {
    let baseCatalog = makeSetupCatalog()
    return CatalogSnapshot(
        profiles: baseCatalog.profiles + [
            CatalogProfile(
                id: "filtered",
                name: "Filtered",
                description: "Filtered DNS.",
                ipv4Servers: ["1.1.1.2"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .malware,
                tags: [],
                useCase: "filtering",
                securityNotes: []
            ),
        ],
        testSuites: baseCatalog.testSuites
    )
}
