import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BenchmarkApplyPlanRequestFactoryTests: XCTestCase {
    func testFactoryBuildsRequestFromHealthyRecommendedBenchmark() {
        let databaseURL = URL(fileURLWithPath: "/tmp/dnspilot.sqlite")
        let result = makeApplyPlanBenchmarkResult(
            health: .healthy,
            canRecommend: true,
            recommendedProfileID: "cloudflare",
            confidence: .medium
        )

        let request = BenchmarkApplyPlanRequestFactory.makeRequest(
            for: result,
            platformID: "macos-store",
            profileDatabaseURL: databaseURL,
            vpnActive: true,
            mdmProfileActive: true,
            corporateDNSDetected: true,
            captivePortalDetected: true
        )

        XCTAssertEqual(request.platformID, "macos-store")
        XCTAssertEqual(request.profileDatabaseURL, databaseURL)
        XCTAssertEqual(request.profileID, "cloudflare")
        XCTAssertEqual(request.testedResolver, "127.0.0.1:53")
        XCTAssertEqual(request.confidence, .medium)
        XCTAssertEqual(request.gateHealth, .healthy)
        XCTAssertTrue(request.vpnActive)
        XCTAssertTrue(request.mdmProfileActive)
        XCTAssertTrue(request.corporateDNSDetected)
        XCTAssertTrue(request.captivePortalDetected)
    }

    func testFactoryPreservesLowConfidenceCandidateForApplyPlanGate() {
        let result = makeApplyPlanBenchmarkResult(
            health: .healthy,
            canRecommend: true,
            recommendedProfileID: "adguard-dns",
            confidence: .low
        )

        let request = BenchmarkApplyPlanRequestFactory.makeRequest(for: result)

        XCTAssertEqual(request.profileID, "adguard-dns")
        XCTAssertEqual(request.confidence, .low)
        XCTAssertEqual(request.gateHealth, .healthy)
    }

    func testFactorySuppressesProfileWhenBenchmarkCannotRecommend() {
        let result = makeApplyPlanBenchmarkResult(
            health: .healthy,
            canRecommend: false,
            recommendedProfileID: "cloudflare",
            confidence: .high
        )

        let request = BenchmarkApplyPlanRequestFactory.makeRequest(for: result)

        XCTAssertNil(request.profileID)
        XCTAssertEqual(request.confidence, .high)
        XCTAssertEqual(request.gateHealth, .healthy)
    }

    func testFactoryMapsMissingRecommendationToInconclusiveRequest() {
        let result = makeApplyPlanBenchmarkResult(
            health: .failed,
            canRecommend: false,
            recommendedProfileID: nil,
            confidence: nil
        )

        let request = BenchmarkApplyPlanRequestFactory.makeRequest(for: result)

        XCTAssertNil(request.profileID)
        XCTAssertEqual(request.confidence, .inconclusive)
        XCTAssertEqual(request.gateHealth, .failed)
    }

    func testResultViewModelBuildsApplyPlanRequestFromSourcePayload() {
        let databaseURL = URL(fileURLWithPath: "/tmp/custom.sqlite")
        let result = makeApplyPlanBenchmarkResult(
            health: .healthy,
            canRecommend: true,
            recommendedProfileID: "cloudflare",
            confidence: .high
        )
        let viewModel = BenchmarkResultViewModel(result: result, catalog: nil)

        let request = viewModel.makeApplyPlanRequest(
            profileDatabaseURL: databaseURL,
            vpnActive: true
        )

        XCTAssertEqual(request.profileDatabaseURL, databaseURL)
        XCTAssertEqual(request.profileID, "cloudflare")
        XCTAssertEqual(request.testedResolver, "127.0.0.1:53")
        XCTAssertEqual(request.confidence, .high)
        XCTAssertEqual(request.gateHealth, .healthy)
        XCTAssertTrue(request.vpnActive)
    }

    func testLoadCoordinatorLoadsApplyPlanForBenchmarkResult() {
        let databaseURL = URL(fileURLWithPath: "/tmp/custom.sqlite")
        let result = makeApplyPlanBenchmarkResult(
            health: .healthy,
            canRecommend: true,
            recommendedProfileID: "cloudflare",
            confidence: .high
        )
        let viewModel = BenchmarkResultViewModel(result: result, catalog: nil)
        let coordinator = BenchmarkApplyPlanLoadCoordinator { request in
            XCTAssertEqual(request.profileDatabaseURL, databaseURL)
            XCTAssertEqual(request.profileID, "cloudflare")
            return ApplyPlan(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .guideOnly,
                profileID: "cloudflare",
                profileName: "Cloudflare",
                testedResolver: "127.0.0.1:53",
                dnsServers: ["1.1.1.1", "1.0.0.1"],
                canApply: false,
                notes: ["Store-safe build must guide plain DNS changes through OS settings."]
            )
        }

        let outcome = coordinator.load(for: viewModel, profileDatabaseURL: databaseURL)

        XCTAssertEqual(
            outcome,
            .loaded(
                ApplyPlanViewModel(
                    plan: ApplyPlan(
                        platformID: "macos-store",
                        applyCapability: .appleNetworkExtensionDNSSettings,
                        disposition: .guideOnly,
                        profileID: "cloudflare",
                        profileName: "Cloudflare",
                        testedResolver: "127.0.0.1:53",
                        dnsServers: ["1.1.1.1", "1.0.0.1"],
                        canApply: false,
                        notes: ["Store-safe build must guide plain DNS changes through OS settings."]
                    )
                )
            )
        )
    }

    func testLoadCoordinatorMapsApplyPlanFailuresToMessage() {
        let result = makeApplyPlanBenchmarkResult(
            health: .healthy,
            canRecommend: true,
            recommendedProfileID: "cloudflare",
            confidence: .high
        )
        let viewModel = BenchmarkResultViewModel(result: result, catalog: nil)
        let coordinator = BenchmarkApplyPlanLoadCoordinator { _ in
            throw ApplyPlanRunnerError.processFailed("apply plan failed")
        }

        let outcome = coordinator.load(for: viewModel)

        XCTAssertEqual(outcome, .failed("apply plan failed"))
    }
}

private func makeApplyPlanBenchmarkResult(
    health: BenchmarkHealth,
    canRecommend: Bool,
    recommendedProfileID: String?,
    confidence: BenchmarkConfidence?
) -> BenchmarkResultPayload {
    BenchmarkResultPayload(
        summary: BenchmarkResultSummary(
            measurementScope: .dnsTCP,
            mode: .bestOverall,
            health: health,
            primaryIssue: "none",
            canRecommend: canRecommend,
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
            recommendedProfileID: recommendedProfileID
        ),
        runs: [
            BenchmarkResultRun(
                profileID: recommendedProfileID ?? "none",
                resolver: "127.0.0.1:53",
                metrics: BenchmarkResultMetrics(
                    profileID: recommendedProfileID ?? "none",
                    medianDNSLatencyMS: nil,
                    p95DNSLatencyMS: nil,
                    failureRate: health == .healthy ? 0 : 1,
                    timeoutRate: health == .healthy ? 0 : 1,
                    medianConnectLatencyMS: nil,
                    ipv4Health: health == .healthy ? 1 : 0,
                    ipv6Health: health == .healthy ? 1 : 0,
                    priorityFit: health == .healthy ? 1 : 0
                )
            ),
        ],
        recommendation: recommendedProfileID.flatMap { profileID in
            confidence.map { confidence in
                BenchmarkRecommendation(
                    profileID: profileID,
                    score: 0.9,
                    confidence: confidence,
                    reasons: [],
                    caveats: []
                )
            }
        },
        savedHistoryID: nil,
        warning: ""
    )
}
