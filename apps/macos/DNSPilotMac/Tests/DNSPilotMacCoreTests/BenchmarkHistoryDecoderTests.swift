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
    }
}

private let historyListJSON = """
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

private func makeHistoryCatalog() -> CatalogSnapshot {
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
