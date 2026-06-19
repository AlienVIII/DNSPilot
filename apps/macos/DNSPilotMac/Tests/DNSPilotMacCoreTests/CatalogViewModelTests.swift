import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CatalogViewModelTests: XCTestCase {
    func testDefaultCatalogViewModelProvidesPreviewSummary() {
        let viewModel = CatalogViewModel()

        XCTAssertNil(viewModel.loadErrorMessage)
        XCTAssertEqual(viewModel.profileCount, 12)
        XCTAssertEqual(viewModel.testSuiteCount, 9)
        XCTAssertEqual(viewModel.filteredProfileCount, 6)
        XCTAssertTrue(viewModel.hasAzureSuite)
        XCTAssertEqual(viewModel.catalog?.profiles.map(\.id).suffix(3), ["fpt-telecom-dns", "vnpt-dns", "viettel-dns"])
        XCTAssertEqual(viewModel.catalog?.testSuites.map(\.id).suffix(4), [
            "gaming-steam-valve",
            "gaming-dota2-sea",
            "gaming-cs2",
            "gaming-riot-lol",
        ])
        XCTAssertEqual(
            viewModel.catalog?.testSuites.first { $0.id == "gaming-dota2-sea" }?.domains,
            ["dota2.com", "steamcommunity.com", "steampowered.com", "steamcontent.com", "api.steampowered.com"]
        )
        let cloudflare = viewModel.profileSummaries.first { $0.id == "cloudflare" }
        XCTAssertTrue(cloudflare?.canGuideApply == true)
        XCTAssertEqual(cloudflare?.guidedApplyButtonLabel, "Apply...")
        XCTAssertEqual(cloudflare?.dnsServerText, "1.1.1.1\n1.0.0.1\n2606:4700:4700::1111\n2606:4700:4700::1001")
    }

    func testCatalogViewModelBuildsDisplaySummaries() {
        let viewModel = CatalogViewModel(bridge: CatalogJSONBridge(data: Data(catalogFixtureJSON.utf8)))

        XCTAssertEqual(viewModel.profileSummaries.first?.name, "Cloudflare")
        XCTAssertEqual(viewModel.profileSummaries.first?.serverSummary, "2 IPv4 / 1 IPv6")
        XCTAssertEqual(viewModel.profileSummaries.first?.filteringLabel, "Unfiltered")
        XCTAssertEqual(viewModel.profileSummaries.last?.filteringLabel, "Malware")
        XCTAssertEqual(viewModel.testSuiteSummaries.first?.domainCountLabel, "2 domains")
    }

    func testCatalogProfileSummaryRejectsEncryptedOrEmptyProfilesForGuidedApply() {
        let doh = CatalogProfile(
            id: "secure",
            name: "Secure",
            description: "Encrypted DNS.",
            ipv4Servers: [],
            ipv6Servers: [],
            protocol: .doh,
            dohURL: "https://dns.example/dns-query",
            dotHostname: nil,
            filteringType: .none,
            tags: [],
            useCase: "privacy",
            securityNotes: []
        )
        let emptyPlain = CatalogProfile(
            id: "empty",
            name: "Empty",
            description: "No servers.",
            ipv4Servers: [],
            ipv6Servers: [],
            protocol: .plain,
            dohURL: nil,
            dotHostname: nil,
            filteringType: .none,
            tags: [],
            useCase: "custom",
            securityNotes: []
        )

        XCTAssertFalse(CatalogProfileSummary(profile: doh).canGuideApply)
        XCTAssertFalse(CatalogProfileSummary(profile: emptyPlain).canGuideApply)
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
