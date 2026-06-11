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
            savedHistoryID: nil,
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
        XCTAssertEqual(viewModel.rows.first?.failureRateLabel, "100% failed")
        XCTAssertEqual(viewModel.notes, ["No resolver completed enough checks."])
    }
}

private func makeResultRun(
    profileID: String,
    medianDNS: Double,
    failureRate: Double
) -> BenchmarkResultRun {
    BenchmarkResultRun(
        profileID: profileID,
        resolver: "127.0.0.1:53",
        metrics: BenchmarkResultMetrics(
            profileID: profileID,
            medianDNSLatencyMS: medianDNS,
            p95DNSLatencyMS: medianDNS,
            failureRate: failureRate,
            timeoutRate: failureRate,
            medianConnectLatencyMS: medianDNS,
            ipv4Health: 1 - failureRate,
            ipv6Health: 0,
            priorityFit: 1 - failureRate
        )
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
