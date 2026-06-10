import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CatalogViewModelTests: XCTestCase {
    func testDefaultCatalogViewModelProvidesPreviewSummary() {
        let viewModel = CatalogViewModel()

        XCTAssertNil(viewModel.loadErrorMessage)
        XCTAssertGreaterThanOrEqual(viewModel.profileCount, 2)
        XCTAssertGreaterThanOrEqual(viewModel.testSuiteCount, 1)
        XCTAssertGreaterThanOrEqual(viewModel.filteredProfileCount, 1)
        XCTAssertTrue(viewModel.hasAzureSuite)
    }

    func testCatalogDecoderMapsRustCliSchema() throws {
        let catalog = try CatalogJSONDecoder().decode(Data(catalogFixtureJSON.utf8))

        XCTAssertEqual(catalog.profiles.count, 2)
        XCTAssertEqual(catalog.profiles.first?.id, "cloudflare")
        XCTAssertEqual(catalog.profiles.first?.protocol, .plain)
        XCTAssertEqual(catalog.profiles.first?.filteringType, CatalogFilteringType.none)
        XCTAssertEqual(catalog.profiles.first?.ipv4Servers, ["1.1.1.1", "1.0.0.1"])
        XCTAssertEqual(catalog.profiles.last?.filteringType, .malware)
        XCTAssertEqual(catalog.testSuites.first?.id, "azure-microsoft")
        XCTAssertEqual(catalog.testSuites.first?.domains, ["portal.azure.com", "login.microsoftonline.com"])
    }

    func testCatalogDecoderRejectsUnknownProtocolValues() {
        let json = """
        {
          "schema_version": 1,
          "profiles": [
            {
              "description": "Unsupported protocol.",
              "doh_url": null,
              "dot_hostname": null,
              "filtering_type": "none",
              "id": "unknown",
              "ipv4_servers": [],
              "ipv6_servers": [],
              "name": "Unknown",
              "protocol": "dnscrypt",
              "security_notes": [],
              "tags": [],
              "use_case": "test"
            }
          ],
          "testSuites": []
        }
        """

        XCTAssertThrowsError(try CatalogJSONDecoder().decode(Data(json.utf8)))
    }

    func testCatalogDecoderRejectsUnsupportedSchemaVersion() {
        let json = """
        {
          "schema_version": 2,
          "profiles": [],
          "testSuites": []
        }
        """

        XCTAssertThrowsError(try CatalogJSONDecoder().decode(Data(json.utf8)))
    }

    func testCatalogViewModelLoadsSnapshotFromJSONBridge() {
        let viewModel = CatalogViewModel(bridge: CatalogJSONBridge(data: Data(catalogFixtureJSON.utf8)))

        XCTAssertNil(viewModel.loadErrorMessage)
        XCTAssertEqual(viewModel.catalog?.profiles.first?.name, "Cloudflare")
        XCTAssertEqual(viewModel.catalog?.testSuites.first?.name, "Azure / Microsoft")
    }

    func testCatalogViewModelCapturesBridgeLoadFailure() {
        let viewModel = CatalogViewModel(bridge: FailingCatalogBridge())

        XCTAssertNil(viewModel.catalog)
        XCTAssertNotNil(viewModel.loadErrorMessage)
    }
}

private struct FailingCatalogBridge: DNSPilotCatalogBridge {
    func loadCatalog() throws -> CatalogSnapshot {
        throw NSError(domain: "DNSPilotMacCoreTests", code: 2)
    }
}

private let catalogFixtureJSON = """
{
  "schema_version": 1,
  "profiles": [
    {
      "description": "Fast unfiltered public DNS.",
      "doh_url": null,
      "dot_hostname": null,
      "filtering_type": "none",
      "id": "cloudflare",
      "ipv4_servers": ["1.1.1.1", "1.0.0.1"],
      "ipv6_servers": ["2606:4700:4700::1111"],
      "name": "Cloudflare",
      "protocol": "plain",
      "security_notes": [],
      "tags": ["general", "unfiltered"],
      "use_case": "performance"
    },
    {
      "description": "Cloudflare DNS with malware blocking.",
      "doh_url": null,
      "dot_hostname": null,
      "filtering_type": "malware",
      "id": "cloudflare-malware",
      "ipv4_servers": ["1.1.1.2"],
      "ipv6_servers": [],
      "name": "Cloudflare Malware Blocking",
      "protocol": "plain",
      "security_notes": ["Filtered DNS may intentionally block some domains."],
      "tags": ["security", "filtered"],
      "use_case": "filtering"
    }
  ],
  "testSuites": [
    {
      "description": "Microsoft login and Azure portal checks.",
      "domains": ["portal.azure.com", "login.microsoftonline.com"],
      "id": "azure-microsoft",
      "name": "Azure / Microsoft",
      "tags": ["developer", "cloud", "microsoft"]
    }
  ]
}
"""
