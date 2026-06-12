import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CatalogStorageBridgeTests: XCTestCase {
    func testProfileListDecoderMapsPayload() throws {
        let payload = try CatalogProfileListJSONDecoder.decode(Data(profileListJSON.utf8))

        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.profiles.count, 2)
        XCTAssertEqual(payload.profiles.last?.id, "custom-lab")
        XCTAssertEqual(payload.profiles.last?.ipv4Servers, ["4.4.4.4"])
    }

    func testSuiteListDecoderMapsPayload() throws {
        let payload = try CatalogSuiteListJSONDecoder.decode(Data(suiteListJSON.utf8))

        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.testSuites.count, 1)
        XCTAssertEqual(payload.testSuites.first?.id, "azure-lab")
    }

    func testStorageRunnerLoadsProfilesAndSuitesThroughProcessBoundary() throws {
        let processRunner = RecordingCatalogStorageProcessRunner(outputs: [
            BenchmarkProcessOutput(exitCode: 0, standardOutput: profileListJSON, standardError: ""),
            BenchmarkProcessOutput(exitCode: 0, standardOutput: suiteListJSON, standardError: ""),
        ])
        let runner = CatalogStorageRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        let snapshot = try runner.loadSnapshot(databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(snapshot.profiles.map(\.id), ["cloudflare", "custom-lab"])
        XCTAssertEqual(snapshot.testSuites.map(\.id), ["azure-lab"])
        XCTAssertEqual(processRunner.invocations.map(\.arguments), [
            ["profile-list", "--db", "/tmp/dnspilot.sqlite"],
            ["suite-list", "--db", "/tmp/dnspilot.sqlite"],
        ])
    }

    func testStorageBackedBridgeMergesProfilesAndDeduplicatesBuiltIns() throws {
        let bridge = StorageBackedCatalogBridge(
            baseBridge: FixedCatalogBridge(snapshot: baseCatalog()),
            storageRunner: CatalogStorageRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: RecordingCatalogStorageProcessRunner(outputs: [
                    BenchmarkProcessOutput(exitCode: 0, standardOutput: profileListJSON, standardError: ""),
                    BenchmarkProcessOutput(exitCode: 0, standardOutput: suiteListJSON, standardError: ""),
                ])
            ),
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite")
        )

        let catalog = try bridge.loadCatalog()

        XCTAssertEqual(catalog.profiles.map(\.id), ["cloudflare", "custom-lab"])
        XCTAssertEqual(catalog.profiles.first?.name, "Cloudflare Stored")
        XCTAssertEqual(catalog.testSuites.map(\.id), ["developer", "azure-lab"])
    }

    func testStorageBackedBridgeFallsBackToBaseCatalogWhenStorageFails() throws {
        let bridge = StorageBackedCatalogBridge(
            baseBridge: FixedCatalogBridge(snapshot: baseCatalog()),
            storageRunner: CatalogStorageRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: RecordingCatalogStorageProcessRunner(outputs: [
                    BenchmarkProcessOutput(exitCode: 2, standardOutput: "", standardError: "storage corrupt"),
                ])
            ),
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite")
        )

        let catalog = try bridge.loadCatalog()

        XCTAssertEqual(catalog, baseCatalog())
    }
}

private struct FixedCatalogBridge: DNSPilotCatalogBridge {
    let snapshot: CatalogSnapshot

    func loadCatalog() throws -> CatalogSnapshot {
        snapshot
    }
}

private final class RecordingCatalogStorageProcessRunner: BenchmarkProcessRunning {
    struct Invocation {
        let executableURL: URL
        let arguments: [String]
    }

    private var outputs: [BenchmarkProcessOutput]
    private(set) var invocations: [Invocation] = []

    init(outputs: [BenchmarkProcessOutput]) {
        self.outputs = outputs
    }

    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?
    ) throws -> BenchmarkProcessOutput {
        invocations.append(Invocation(executableURL: executableURL, arguments: arguments))
        return outputs.isEmpty
            ? BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
            : outputs.removeFirst()
    }
}

private func baseCatalog() -> CatalogSnapshot {
    CatalogSnapshot(
        profiles: [
            CatalogProfile(
                id: "cloudflare",
                name: "Cloudflare",
                description: "Built-in Cloudflare.",
                ipv4Servers: ["1.1.1.1"],
                ipv6Servers: [],
                protocol: .plain,
                dohURL: nil,
                dotHostname: nil,
                filteringType: .none,
                tags: ["general"],
                useCase: "performance",
                securityNotes: []
            ),
        ],
        testSuites: [
            CatalogTestSuite(
                id: "developer",
                name: "Developer",
                description: "Developer checks.",
                domains: ["github.com"],
                tags: ["developer"]
            ),
        ]
    )
}

private let profileListJSON = """
{
  "db": "/tmp/dnspilot.sqlite",
  "schema_version": 1,
  "profile_count": 2,
  "profiles": [
    {
      "description": "Stored Cloudflare.",
      "doh_url": null,
      "dot_hostname": null,
      "filtering_type": "none",
      "id": "cloudflare",
      "ipv4_servers": ["1.1.1.1"],
      "ipv6_servers": [],
      "name": "Cloudflare Stored",
      "protocol": "plain",
      "security_notes": [],
      "tags": ["general"],
      "use_case": "performance"
    },
    {
      "description": "Custom DNS profile.",
      "doh_url": null,
      "dot_hostname": null,
      "filtering_type": "none",
      "id": "custom-lab",
      "ipv4_servers": ["4.4.4.4"],
      "ipv6_servers": [],
      "name": "Custom Lab",
      "protocol": "plain",
      "security_notes": [],
      "tags": ["custom"],
      "use_case": "custom"
    }
  ]
}
"""

private let suiteListJSON = """
{
  "db": "/tmp/dnspilot.sqlite",
  "schema_version": 1,
  "test_suite_count": 1,
  "test_suites": [
    {
      "description": "Custom domain test suite.",
      "domains": ["portal.azure.com"],
      "id": "azure-lab",
      "name": "Azure Lab",
      "tags": ["azure"]
    }
  ]
}
"""
