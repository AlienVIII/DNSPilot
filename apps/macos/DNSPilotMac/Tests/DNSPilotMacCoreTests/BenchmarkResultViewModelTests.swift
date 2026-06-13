import XCTest
@testable import DNSPilotMacCore

final class BenchmarkResultViewModelTests: XCTestCase {
    func testResultViewModelBuildsRecommendedSummaryAndRows() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsOnly,
                mode: .fastestRawDNS,
                health: .healthy,
                primaryIssue: "none",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 2,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: 500,
                dnsTimeoutMS: nil,
                connectTimeoutMS: nil,
                tlsHandshakeTimeoutMS: nil,
                connectPort: nil,
                maxConnectTargetsPerDomain: nil,
                tlsEnabled: nil,
                trustStore: nil,
                tlsSampleCount: nil,
                recommendedProfileID: "cloudflare"
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 4, failureRate: 0),
                makeResultRun(profileID: "google-public-dns", medianDNS: 8, failureRate: 0),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.97,
                confidence: .high,
                reasons: ["Lowest median DNS latency."],
                caveats: ["Connection path not measured."]
            ),
            savedHistoryID: "compare-run-1",
            warning: "DNS-only warning."
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.scopeLabel, "DNS only")
        XCTAssertEqual(viewModel.healthLabel, "Healthy")
        XCTAssertEqual(viewModel.recommendationLabel, "Recommended: Cloudflare")
        XCTAssertEqual(viewModel.confidenceLabel, "High confidence")
        XCTAssertFalse(viewModel.showsConnectionMetrics)
        XCTAssertEqual(viewModel.rows.map(\.name), ["Cloudflare", "Google Public DNS"])
        XCTAssertEqual(viewModel.rows.first?.medianDNSLatencyLabel, "4 ms")
        XCTAssertEqual(viewModel.notes, ["Lowest median DNS latency.", "Connection path not measured."])
        XCTAssertEqual(viewModel.savedHistoryLabel, "Saved run: compare-run-1")
        XCTAssertEqual(viewModel.fullSavedHistoryID, "compare-run-1")
        XCTAssertEqual(
            viewModel.resultReport,
            """
            Benchmark result
            Health: Healthy
            Scope: DNS only
            Confidence: High confidence
            Recommendation: Recommended: Cloudflare
            Saved run: compare-run-1

            Candidates:
            Cloudflare | 127.0.0.1:53 | DNS median 4 ms | DNS P95 4 ms | Failure 0% failed | Diagnosis No issues
            Google Public DNS | 127.0.0.1:53 | DNS median 8 ms | DNS P95 8 ms | Failure 0% failed | Diagnosis No issues

            Notes:
            Lowest median DNS latency.
            Connection path not measured.

            Warning:
            DNS-only warning.
            """
        )
    }

    func testResultViewModelShortensLongSavedHistoryIDForResultPanel() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .healthy,
                primaryIssue: "none",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 4,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: "cloudflare"
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 20, failureRate: 0),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.9,
                confidence: .high,
                reasons: [],
                caveats: []
            ),
            savedHistoryID: "path-compare-bd1625f7-0f3f-47c8-b4f6-2ba43eeecf10",
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.savedHistoryLabel, "Saved run: path-compare-bd1625f7...")
        XCTAssertEqual(viewModel.fullSavedHistoryID, "path-compare-bd1625f7-0f3f-47c8-b4f6-2ba43eeecf10")
    }

    func testResultViewModelIncludesRecordFamilyInCopiedReportWhenAvailable() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsOnly,
                mode: .fastestRawDNS,
                health: .healthy,
                primaryIssue: "none",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: 500,
                dnsTimeoutMS: nil,
                connectTimeoutMS: nil,
                tlsHandshakeTimeoutMS: nil,
                connectPort: nil,
                maxConnectTargetsPerDomain: nil,
                tlsEnabled: nil,
                trustStore: nil,
                tlsSampleCount: nil,
                recommendedProfileID: "cloudflare",
                recordFamily: .ipv6Only
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 4, failureRate: 0),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.97,
                confidence: .high,
                reasons: [],
                caveats: []
            ),
            savedHistoryID: nil,
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.recordFamilyLabel, "AAAA only")
        XCTAssertTrue(viewModel.resultReport.contains("DNS records: AAAA only"))
    }

    func testResultViewModelCanIncludeElapsedTimeInCopiedReport() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsOnly,
                mode: .fastestRawDNS,
                health: .healthy,
                primaryIssue: "none",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: 500,
                dnsTimeoutMS: nil,
                connectTimeoutMS: nil,
                tlsHandshakeTimeoutMS: nil,
                connectPort: nil,
                maxConnectTargetsPerDomain: nil,
                tlsEnabled: nil,
                trustStore: nil,
                tlsSampleCount: nil,
                recommendedProfileID: "cloudflare"
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 4, failureRate: 0),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.97,
                confidence: .high,
                reasons: [],
                caveats: []
            ),
            savedHistoryID: nil,
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertTrue(viewModel.resultReportText(elapsedMS: 1_240).contains("Completed in: 1.2 s"))
    }

    func testResultViewModelKeepsCurrentDNSForDegradedInconclusiveRuns() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .degraded,
                primaryIssue: "reduced-reliability",
                canRecommend: true,
                safetyNotes: ["All candidates have reduced reliability; apply prompts should be conservative."],
                resolverCount: 2,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 4,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: "adguard-dns"
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 55, failureRate: 0.5),
                makeResultRun(profileID: "adguard-dns", medianDNS: 31, failureRate: 0.5),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "adguard-dns",
                score: 0.62,
                confidence: .inconclusive,
                reasons: [
                    "Best connection-path estimate for BestOverall mode.",
                    "Recommended profile: adguard-dns.",
                ],
                caveats: ["Timeout or failure rate reduces confidence."]
            ),
            savedHistoryID: nil,
            warning: "Path comparison warning."
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.recommendationLabel, "Keep current DNS")
        XCTAssertEqual(viewModel.confidenceLabel, "Inconclusive confidence")
        XCTAssertEqual(viewModel.rows.map(\.status), [.degraded, .degraded])
        XCTAssertEqual(viewModel.rows.map(\.statusDetail), ["50% failed", "50% failed"])
        XCTAssertTrue(viewModel.notes.contains("Best measured candidate during this run: AdGuard DNS."))
        XCTAssertTrue(viewModel.notes.contains("Many candidates failed at a similar partial rate; this can indicate current network, VPN, firewall, captive portal, or IPv6 reachability limits rather than one bad DNS provider."))
        XCTAssertFalse(viewModel.notes.contains("Recommended profile: adguard-dns."))
    }

    func testResultViewModelKeepsCurrentDNSWhenAllCandidatesHaveLowReliability() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .degraded,
                primaryIssue: "all-resolvers-low-reliability",
                canRecommend: false,
                safetyNotes: ["All candidates have reduced reliability; Keep current DNS and retest on a stable network."],
                resolverCount: 2,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 4,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: nil
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 55, failureRate: 0.5),
                makeResultRun(profileID: "adguard-dns", medianDNS: 31, failureRate: 0.5),
            ],
            recommendation: nil,
            savedHistoryID: nil,
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.recommendationLabel, "Keep current DNS")
        XCTAssertEqual(viewModel.confidenceLabel, "Inconclusive")
        XCTAssertTrue(viewModel.notes.contains("All candidates have reduced reliability; Keep current DNS and retest on a stable network."))
    }

    func testResultViewModelIncludesDedupedRunCaveats() {
        let tcpCaveat = "Some resolved endpoints failed TCP connect; DNS may be mapping to a poor, blocked, or unreachable path."
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .degraded,
                primaryIssue: "partial-failure",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 2,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 2,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: "cloudflare"
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 50, failureRate: 0.5, caveats: [tcpCaveat]),
                makeResultRun(profileID: "google-public-dns", medianDNS: 55, failureRate: 0.5, caveats: [tcpCaveat]),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.6,
                confidence: .inconclusive,
                reasons: [],
                caveats: []
            ),
            savedHistoryID: nil,
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.notes.filter { $0 == tcpCaveat }.count, 1)
    }

    func testResultViewModelLabelsWeakIPFamilyInFailureCell() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .degraded,
                primaryIssue: "partial-failure",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 2,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: "cloudflare"
            ),
            runs: [
                makeResultRun(
                    profileID: "cloudflare",
                    medianDNS: 50,
                    failureRate: 0.5,
                    timeoutRate: 0,
                    ipv4Health: 1,
                    ipv6Health: 0
                ),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.6,
                confidence: .inconclusive,
                reasons: [],
                caveats: []
            ),
            savedHistoryID: nil,
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.rows.first?.failureRateLabel, "50% failed (IPv6 weak)")
        XCTAssertEqual(viewModel.rows.first?.diagnosisLabel, "IPv6 weak")
    }

    func testResultViewModelSuggestsAOnlyWhenMostCandidatesHaveWeakIPv6() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsOnly,
                mode: .fastestRawDNS,
                health: .degraded,
                primaryIssue: "partial-failure",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 2,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: 800,
                dnsTimeoutMS: nil,
                connectTimeoutMS: nil,
                tlsHandshakeTimeoutMS: nil,
                connectPort: nil,
                maxConnectTargetsPerDomain: nil,
                tlsEnabled: nil,
                trustStore: nil,
                tlsSampleCount: nil,
                recommendedProfileID: "cloudflare"
            ),
            runs: [
                makeResultRun(profileID: "cloudflare", medianDNS: 50, failureRate: 0.5, ipv4Health: 1, ipv6Health: 0),
                makeResultRun(profileID: "quad9", medianDNS: 55, failureRate: 0.5, ipv4Health: 1, ipv6Health: 0),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.6,
                confidence: .inconclusive,
                reasons: [],
                caveats: []
            ),
            savedHistoryID: nil,
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertTrue(
            viewModel.notes.contains(
                "IPv6 looks weak across candidates; try DNS records: A only and retest before changing DNS."
            )
        )
    }

    func testResultViewModelDiagnosesTcpAndTimeoutFailures() {
        let tcpCaveat = "Some resolved endpoints failed TCP connect; DNS may be mapping to a poor, blocked, or unreachable path."
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .degraded,
                primaryIssue: "partial-failure",
                canRecommend: true,
                safetyNotes: [],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 800,
                connectTimeoutMS: 1_000,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 2,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: "cloudflare"
            ),
            runs: [
                makeResultRun(
                    profileID: "cloudflare",
                    medianDNS: 50,
                    failureRate: 0.5,
                    timeoutRate: 0.25,
                    caveats: [tcpCaveat],
                    ipv4Health: 1,
                    ipv6Health: 0
                ),
            ],
            recommendation: BenchmarkRecommendation(
                profileID: "cloudflare",
                score: 0.6,
                confidence: .inconclusive,
                reasons: [],
                caveats: []
            ),
            savedHistoryID: nil,
            warning: ""
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.rows.first?.diagnosisLabel, "TCP path failures, IPv6 weak, timeouts")
    }

    func testResultViewModelShowsNoRecommendationAndNAForAllFailedRuns() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsTCP,
                mode: .bestOverall,
                health: .failed,
                primaryIssue: "all-resolvers-failed",
                canRecommend: false,
                safetyNotes: ["No resolver completed enough checks."],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: nil,
                dnsTimeoutMS: 500,
                connectTimeoutMS: 500,
                tlsHandshakeTimeoutMS: nil,
                connectPort: 443,
                maxConnectTargetsPerDomain: 2,
                tlsEnabled: false,
                trustStore: nil,
                tlsSampleCount: 0,
                recommendedProfileID: nil
            ),
            runs: [
                makeResultRun(profileID: "dead", medianDNS: 0, failureRate: 1),
            ],
            recommendation: nil,
            savedHistoryID: nil,
            warning: "Path warning."
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: makeResultCatalog())

        XCTAssertEqual(viewModel.scopeLabel, "DNS + TCP")
        XCTAssertEqual(viewModel.healthLabel, "Failed")
        XCTAssertEqual(viewModel.recommendationLabel, "No recommendation")
        XCTAssertEqual(viewModel.confidenceLabel, "Inconclusive")
        XCTAssertTrue(viewModel.showsConnectionMetrics)
        XCTAssertEqual(viewModel.rows.first?.name, "dead")
        XCTAssertEqual(viewModel.rows.first?.medianDNSLatencyLabel, "n/a")
        XCTAssertEqual(viewModel.rows.first?.status, .failed)
        XCTAssertEqual(viewModel.rows.first?.statusDetail, "100% failed")
        XCTAssertEqual(viewModel.rows.first?.failureRateLabel, "100% failed")
        XCTAssertEqual(viewModel.notes, ["No resolver completed enough checks."])
        XCTAssertNil(viewModel.savedHistoryLabel)
    }

    func testResultViewModelShowsNAForNullDnsLatencyMetrics() {
        let result = BenchmarkResultPayload(
            summary: BenchmarkResultSummary(
                measurementScope: .dnsOnly,
                mode: .fastestRawDNS,
                health: .failed,
                primaryIssue: "all-resolvers-failed",
                canRecommend: false,
                safetyNotes: [],
                resolverCount: 1,
                domainCount: 1,
                attemptsPerRecord: 1,
                timeoutMS: 50,
                dnsTimeoutMS: nil,
                connectTimeoutMS: nil,
                tlsHandshakeTimeoutMS: nil,
                connectPort: nil,
                maxConnectTargetsPerDomain: nil,
                tlsEnabled: nil,
                trustStore: nil,
                tlsSampleCount: nil,
                recommendedProfileID: nil
            ),
            runs: [
                makeResultRun(profileID: "bad", medianDNS: nil, failureRate: 1),
            ],
            recommendation: nil,
            savedHistoryID: nil,
            warning: "DNS warning."
        )

        let viewModel = BenchmarkResultViewModel(result: result, catalog: nil)

        XCTAssertEqual(viewModel.rows.first?.medianDNSLatencyLabel, "n/a")
        XCTAssertEqual(viewModel.rows.first?.p95DNSLatencyLabel, "n/a")
        XCTAssertEqual(viewModel.rows.first?.status, .failed)
    }
}

private func makeResultRun(
    profileID: String,
    medianDNS: Double?,
    failureRate: Double,
    timeoutRate: Double? = nil,
    caveats: [String] = [],
    ipv4Health: Double = 1,
    ipv6Health: Double = 1
) -> BenchmarkResultRun {
    BenchmarkResultRun(
        profileID: profileID,
        resolver: "127.0.0.1:53",
        metrics: BenchmarkResultMetrics(
            profileID: profileID,
            medianDNSLatencyMS: medianDNS,
            p95DNSLatencyMS: medianDNS,
            failureRate: failureRate,
            timeoutRate: timeoutRate ?? failureRate,
            medianConnectLatencyMS: medianDNS,
            ipv4Health: ipv4Health,
            ipv6Health: ipv6Health,
            priorityFit: 1 - failureRate
        ),
        caveats: caveats
    )
}

private func makeResultCatalog() -> CatalogSnapshot {
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
                id: "adguard-dns",
                name: "AdGuard DNS",
                description: "AdGuard public DNS.",
                ipv4Servers: ["94.140.14.14"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: [],
                useCase: "filtering",
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
        ],
        testSuites: []
    )
}
