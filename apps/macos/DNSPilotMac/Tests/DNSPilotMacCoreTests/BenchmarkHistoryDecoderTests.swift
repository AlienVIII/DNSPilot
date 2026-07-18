import XCTest
@testable import DNSPilotMacCore

final class BenchmarkHistoryDecoderTests: XCTestCase {
    func testDecoderMapsHistoryListPayload() throws {
        let payload = try BenchmarkHistoryJSONDecoder.decode(historyListJSON)

        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.benchmarkHistoryCount, 1)
        XCTAssertEqual(payload.records[0].id, "compare-run-1")
        XCTAssertEqual(payload.records[0].scope, .dnsOnly)
        XCTAssertEqual(payload.records[0].mode, .fastestRawDNS)
        XCTAssertEqual(payload.records[0].domains, ["github.com", "azure.microsoft.com"])
        XCTAssertEqual(payload.records[0].resolverProfileIDs, ["cloudflare", "google"])
        XCTAssertEqual(payload.records[0].metrics[0].medianDNSLatencyMS, 12.0)
        XCTAssertEqual(payload.records[0].gate.health, .healthy)
        XCTAssertEqual(payload.records[0].gate.primaryIssue, "none")
        XCTAssertEqual(payload.records[0].recommendationProfileID, "cloudflare")
    }

    func testDecoderRejectsUnsupportedSchemaVersion() {
        let json = historyListJSON.replacingOccurrences(of: "\"schema_version\": 1", with: "\"schema_version\": 2")

        XCTAssertThrowsError(try BenchmarkHistoryJSONDecoder.decode(json)) { error in
            XCTAssertEqual(
                error as? ShellPayloadSchemaError,
                .unsupportedVersion(2, supported: 1)
            )
        }
    }
}

final class BenchmarkHistoryViewModelTests: XCTestCase {
    func testViewModelBuildsDisplayRows() throws {
        let payload = try BenchmarkHistoryJSONDecoder.decode(historyListJSON)
        let viewModel = BenchmarkHistoryViewModel(
            payload: payload,
            catalog: makeHistoryCatalog()
        )

        XCTAssertEqual(viewModel.rows.count, 1)
        XCTAssertEqual(viewModel.rows[0].title, "DNS only")
        XCTAssertEqual(viewModel.rows[0].domainSummary, "github.com + 1 more")
        XCTAssertEqual(viewModel.rows[0].resolverSummary, "2 resolvers")
        XCTAssertEqual(viewModel.rows[0].healthLabel, "Healthy")
        XCTAssertEqual(viewModel.rows[0].recommendationLabel, "Recommended: Cloudflare")
        XCTAssertEqual(viewModel.rows[0].applyGuidanceLabel, "Retest before applying saved recommendation")
        let vietnamese = DNSPilotLocalizer(language: .vietnamese)
        XCTAssertEqual(viewModel.rows[0].localizedTitle(localizer: vietnamese), "Chỉ DNS")
        XCTAssertEqual(viewModel.rows[0].localizedDomainSummary(localizer: vietnamese), "github.com + 1 domain khác")
        XCTAssertEqual(viewModel.rows[0].localizedResolverSummary(localizer: vietnamese), "2 máy chủ DNS")
        XCTAssertEqual(viewModel.rows[0].localizedHealthLabel(localizer: vietnamese), "Ổn định")
        XCTAssertEqual(viewModel.rows[0].localizedRecommendationLabel(localizer: vietnamese), "Khuyến nghị: Cloudflare")
        XCTAssertEqual(
            viewModel.rows[0].localizedApplyGuidanceLabel(localizer: vietnamese),
            "Kiểm tra lại trước khi áp dụng khuyến nghị đã lưu"
        )
    }

    func testViewModelShowsNewestSavedRunFirst() throws {
        let payload = try BenchmarkHistoryJSONDecoder.decode(twoRunHistoryListJSON)
        let viewModel = BenchmarkHistoryViewModel(
            payload: payload,
            catalog: makeHistoryCatalog()
        )

        XCTAssertEqual(viewModel.rows.map(\.id), ["run-new", "run-old"])
    }

    func testViewModelKeepsCurrentDNSForLowReliabilityHistoryRun() {
        let payload = BenchmarkHistoryPayload(
            db: "/tmp/dnspilot.sqlite",
            schemaVersion: 1,
            benchmarkHistoryCount: 1,
            records: [
                makeHistoryRecord(
                    id: "degraded-run",
                    gate: BenchmarkHistoryGate(
                        canRecommend: true,
                        health: .degraded,
                        primaryIssue: "partial-failure",
                        notes: []
                    ),
                    recommendationProfileID: "cloudflare",
                    metrics: [
                        makeHistoryMetric(profileID: "cloudflare", failureRate: 0.5),
                        makeHistoryMetric(profileID: "google", failureRate: 0.5),
                    ]
                ),
            ]
        )

        let viewModel = BenchmarkHistoryViewModel(payload: payload, catalog: makeHistoryCatalog())

        XCTAssertEqual(viewModel.rows.first?.recommendationLabel, "Keep current DNS")
        XCTAssertEqual(viewModel.rows.first?.applyGuidanceLabel, "Do not apply from this saved run")
    }

    func testViewModelShowsBestMeasuredForDegradedButUsableHistoryRun() {
        let payload = BenchmarkHistoryPayload(
            db: "/tmp/dnspilot.sqlite",
            schemaVersion: 1,
            benchmarkHistoryCount: 1,
            records: [
                makeHistoryRecord(
                    id: "partial-run",
                    gate: BenchmarkHistoryGate(
                        canRecommend: true,
                        health: .degraded,
                        primaryIssue: "partial-failure",
                        notes: []
                    ),
                    recommendationProfileID: "cloudflare",
                    metrics: [
                        makeHistoryMetric(profileID: "cloudflare", failureRate: 0.2),
                        makeHistoryMetric(profileID: "google", failureRate: 0.0),
                    ]
                ),
            ]
        )

        let viewModel = BenchmarkHistoryViewModel(payload: payload, catalog: makeHistoryCatalog())

        XCTAssertEqual(viewModel.rows.first?.recommendationLabel, "Best measured: Cloudflare")
    }
}

let historyListJSON = """
{
  "db": "/tmp/dnspilot.sqlite",
  "schema_version": 1,
  "benchmark_history_count": 1,
  "benchmark_history": [
    {
      "id": "compare-run-1",
      "started_at": "started-1",
      "scope": "dns-only",
      "mode": "fastest-raw-dns",
      "domains": ["github.com", "azure.microsoft.com"],
      "resolver_profile_ids": ["cloudflare", "google"],
      "metrics": [
        {
          "profile_id": "cloudflare",
          "median_dns_latency_ms": 12.0,
          "p95_dns_latency_ms": 20.0,
          "failure_rate": 0.0,
          "timeout_rate": 0.0,
          "median_connect_latency_ms": 0.0,
          "ipv4_health": 1.0,
          "ipv6_health": 1.0,
          "priority_fit": 1.0
        }
      ],
      "gate": {
        "can_recommend": true,
        "health": "healthy",
        "primary_issue": "none",
        "notes": []
      },
      "recommendation_profile_id": "cloudflare",
      "notes": ["Saved by compare CLI."]
    }
  ]
}
"""

let twoRunHistoryListJSON = """
{
  "db": "/tmp/dnspilot.sqlite",
  "schema_version": 1,
  "benchmark_history_count": 2,
  "benchmark_history": [
    {
      "id": "run-old",
      "started_at": "started-1",
      "scope": "dns-only",
      "mode": "fastest-raw-dns",
      "domains": ["github.com"],
      "resolver_profile_ids": ["cloudflare"],
      "metrics": [
        {
          "profile_id": "cloudflare",
          "median_dns_latency_ms": 12.0,
          "p95_dns_latency_ms": 20.0,
          "failure_rate": 0.0,
          "timeout_rate": 0.0,
          "median_connect_latency_ms": 0.0,
          "ipv4_health": 1.0,
          "ipv6_health": 1.0,
          "priority_fit": 1.0
        }
      ],
      "gate": {
        "can_recommend": true,
        "health": "healthy",
        "primary_issue": "none",
        "notes": []
      },
      "recommendation_profile_id": "cloudflare",
      "notes": []
    },
    {
      "id": "run-new",
      "started_at": "started-2",
      "scope": "dns-tcp",
      "mode": "best-overall",
      "domains": ["github.com"],
      "resolver_profile_ids": ["google"],
      "metrics": [
        {
          "profile_id": "google",
          "median_dns_latency_ms": 10.0,
          "p95_dns_latency_ms": 18.0,
          "failure_rate": 0.0,
          "timeout_rate": 0.0,
          "median_connect_latency_ms": 22.0,
          "ipv4_health": 1.0,
          "ipv6_health": 1.0,
          "priority_fit": 1.0
        }
      ],
      "gate": {
        "can_recommend": true,
        "health": "healthy",
        "primary_issue": "none",
        "notes": []
      },
      "recommendation_profile_id": "google",
      "notes": []
    }
  ]
}
"""

func makeHistoryCatalog() -> CatalogSnapshot {
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
        ],
        testSuites: []
    )
}

func makeHistoryRecord(
    id: String,
    gate: BenchmarkHistoryGate,
    recommendationProfileID: String?,
    metrics: [BenchmarkResultMetrics]
) -> BenchmarkHistoryRecord {
    BenchmarkHistoryRecord(
        id: id,
        startedAt: "started",
        scope: .dnsTCP,
        mode: .bestOverall,
        domains: ["github.com"],
        resolverProfileIDs: metrics.map(\.profileID),
        metrics: metrics,
        gate: gate,
        recommendationProfileID: recommendationProfileID,
        notes: []
    )
}

func makeHistoryMetric(profileID: String, failureRate: Double) -> BenchmarkResultMetrics {
    BenchmarkResultMetrics(
        profileID: profileID,
        medianDNSLatencyMS: 10,
        p95DNSLatencyMS: 20,
        failureRate: failureRate,
        timeoutRate: failureRate,
        medianConnectLatencyMS: 30,
        ipv4Health: 1,
        ipv6Health: failureRate >= 0.5 ? 0 : 1,
        priorityFit: 1 - failureRate
    )
}
