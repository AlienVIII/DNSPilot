import XCTest
@testable import DNSPilotMacCore

final class BenchmarkResultDecoderTests: XCTestCase {
    func testDecoderMapsDnsOnlyCompareResult() throws {
        let result = try BenchmarkResultJSONDecoder.decode(dnsOnlyCompareJSON)

        XCTAssertEqual(result.summary.measurementScope, .dnsOnly)
        XCTAssertEqual(result.summary.mode, .fastestRawDNS)
        XCTAssertEqual(result.summary.health, .healthy)
        XCTAssertEqual(result.summary.primaryIssue, "none")
        XCTAssertTrue(result.summary.canRecommend)
        XCTAssertEqual(result.summary.recommendedProfileID, "fast")
        XCTAssertEqual(result.summary.resolverCount, 2)
        XCTAssertEqual(result.summary.domainCount, 1)
        XCTAssertEqual(result.runs.map(\.profileID), ["slow", "fast"])
        XCTAssertEqual(result.runs[0].caveats, [])
        XCTAssertEqual(result.runs[1].metrics.medianDNSLatencyMS, 4.0)
        XCTAssertNil(result.runs[1].metrics.medianConnectLatencyMS)
        XCTAssertEqual(result.recommendation?.profileID, "fast")
        XCTAssertEqual(result.recommendation?.confidence, .high)
        XCTAssertTrue(result.warning.contains("DNS-only"))
    }

    func testDecoderMapsPathCompareResultWithoutRecommendation() throws {
        let result = try BenchmarkResultJSONDecoder.decode(pathCompareNoRecommendationJSON)

        XCTAssertEqual(result.summary.measurementScope, .dnsTCP)
        XCTAssertEqual(result.summary.mode, .bestOverall)
        XCTAssertEqual(result.summary.health, .failed)
        XCTAssertEqual(result.summary.primaryIssue, "all-resolvers-failed")
        XCTAssertFalse(result.summary.canRecommend)
        XCTAssertNil(result.summary.recommendedProfileID)
        XCTAssertEqual(result.summary.tlsEnabled, false)
        XCTAssertNil(result.summary.trustStore)
        XCTAssertEqual(result.summary.connectPort, 443)
        XCTAssertEqual(result.summary.maxConnectTargetsPerDomain, 2)
        XCTAssertEqual(result.runs.count, 1)
        XCTAssertEqual(result.runs[0].caveats, ["No usable A/AAAA answers were returned, so TCP connect probes were skipped."])
        XCTAssertNil(result.recommendation)
        XCTAssertTrue(result.warning.contains("Path comparison"))
    }

    func testDecoderMapsAllFailedDnsOnlyNullLatencyMetrics() throws {
        let result = try BenchmarkResultJSONDecoder.decode(allFailedDnsOnlyJSON)

        XCTAssertEqual(result.summary.health, .failed)
        XCTAssertEqual(result.summary.primaryIssue, "all-resolvers-failed")
        XCTAssertNil(result.runs[0].metrics.medianDNSLatencyMS)
        XCTAssertNil(result.runs[0].metrics.p95DNSLatencyMS)
        XCTAssertNil(result.runs[0].metrics.medianConnectLatencyMS)
        XCTAssertEqual(result.runs[0].metrics.failureRate, 1.0)
    }
}

private let dnsOnlyCompareJSON = """
{
  "summary": {
    "measurement_scope": "dns-only",
    "mode": "fastest-raw-dns",
    "health": "healthy",
    "primary_issue": "none",
    "can_recommend": true,
    "safety_notes": [],
    "resolver_count": 2,
    "domain_count": 1,
    "attempts_per_record": 1,
    "timeout_ms": 500,
    "recommended_profile_id": "fast"
  },
  "runs": [
    {
      "profile_id": "slow",
      "resolver": "127.0.0.1:5301",
      "metrics": {
        "profile_id": "slow",
        "median_dns_latency_ms": 80.0,
        "p95_dns_latency_ms": 80.0,
        "failure_rate": 0.0,
        "timeout_rate": 0.0,
        "median_connect_latency_ms": null,
        "ipv4_health": 1.0,
        "ipv6_health": 0.0,
        "priority_fit": 1.0
      }
    },
    {
      "profile_id": "fast",
      "resolver": "127.0.0.1:5302",
      "metrics": {
        "profile_id": "fast",
        "median_dns_latency_ms": 4.0,
        "p95_dns_latency_ms": 4.0,
        "failure_rate": 0.0,
        "timeout_rate": 0.0,
        "median_connect_latency_ms": null,
        "ipv4_health": 1.0,
        "ipv6_health": 0.0,
        "priority_fit": 1.0
      }
    }
  ],
  "recommendation": {
    "decision": { "apply-profile": "fast" },
    "profile_id": "fast",
    "score": 0.98,
    "confidence": "high",
    "reasons": ["Lowest median DNS latency."],
    "caveats": ["Connection path not measured."]
  },
  "saved_history_id": null,
  "warning": "DNS-only comparison estimates resolver lookup latency and reliability."
}
"""

private let allFailedDnsOnlyJSON = """
{
  "summary": {
    "measurement_scope": "dns-only",
    "mode": "fastest-raw-dns",
    "health": "failed",
    "primary_issue": "all-resolvers-failed",
    "can_recommend": false,
    "safety_notes": ["Every candidate failed the measured scope."],
    "resolver_count": 1,
    "domain_count": 1,
    "attempts_per_record": 1,
    "timeout_ms": 50,
    "recommended_profile_id": null
  },
  "runs": [
    {
      "profile_id": "bad",
      "resolver": "127.0.0.1:9",
      "metrics": {
        "profile_id": "bad",
        "median_dns_latency_ms": null,
        "p95_dns_latency_ms": null,
        "failure_rate": 1.0,
        "timeout_rate": 1.0,
        "median_connect_latency_ms": null,
        "ipv4_health": 0.0,
        "ipv6_health": 0.0,
        "priority_fit": 1.0
      }
    }
  ],
  "recommendation": null,
  "saved_history_id": null,
  "warning": "DNS-only comparison estimates resolver lookup latency and reliability."
}
"""

private let pathCompareNoRecommendationJSON = """
{
  "summary": {
    "measurement_scope": "dns-tcp",
    "mode": "best-overall",
    "health": "failed",
    "primary_issue": "all-resolvers-failed",
    "can_recommend": false,
    "safety_notes": ["No resolver completed enough checks."],
    "tls_enabled": false,
    "trust_store": null,
    "resolver_count": 1,
    "domain_count": 1,
    "attempts_per_record": 1,
    "dns_timeout_ms": 500,
    "connect_timeout_ms": 500,
    "tls_handshake_timeout_ms": null,
    "connect_port": 443,
    "max_connect_targets_per_domain": 2,
    "tls_sample_count": 0,
    "recommended_profile_id": null
  },
  "runs": [
    {
      "profile_id": "dead",
      "resolver": "127.0.0.1:5303",
      "metrics": {
        "profile_id": "dead",
        "median_dns_latency_ms": 0.0,
        "p95_dns_latency_ms": 0.0,
        "failure_rate": 1.0,
        "timeout_rate": 1.0,
        "median_connect_latency_ms": 0.0,
        "ipv4_health": 0.0,
        "ipv6_health": 0.0,
        "priority_fit": 0.0
      },
      "caveats": ["No usable A/AAAA answers were returned, so TCP connect probes were skipped."],
      "summary": {
        "measurement_scope": "dns-tcp",
        "health": "failed",
        "primary_issue": "dns-failure",
        "tls_enabled": false,
        "trust_store": null,
        "domain_count": 1,
        "dns_sample_count": 1,
        "connect_target_count": 0,
        "connect_sample_count": 0,
        "tls_sample_count": 0,
        "caveat_count": 1
      }
    }
  ],
  "recommendation": null,
  "saved_history_id": null,
  "warning": "Path comparison estimates DNS plus TCP connect timing only."
}
"""
