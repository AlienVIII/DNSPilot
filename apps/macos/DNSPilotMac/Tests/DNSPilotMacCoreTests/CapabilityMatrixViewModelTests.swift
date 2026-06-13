import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CapabilityMatrixViewModelTests: XCTestCase {
    func testDefaultMatrixIncludesPlatformFlushAndApplyPolicy() {
        let viewModel = CapabilityMatrixViewModel()

        XCTAssertEqual(viewModel.rows.first?.platformName, "macOS Store")
        XCTAssertEqual(viewModel.rows.first?.applyLabel, "User-approved")
        XCTAssertEqual(viewModel.rows.first?.flushLabel, "Guided")
        XCTAssertTrue(viewModel.rows.contains { row in
            row.platformID == "macos-store"
                && row.flush == .guidedUserAction
                && row.applyDisposition == .allow
        })
        XCTAssertTrue(viewModel.rows.contains { row in
            row.platformID == "windows-store"
                && row.applyDisposition == .guideOnly
        })
        XCTAssertTrue(viewModel.rows.contains { row in
            row.platformID == "ios"
                && row.flush == .unsupported
        })
    }

    func testDesignTokensStayWithinCompactControlRules() {
        XCTAssertLessThanOrEqual(DNSPilotDesign.Radius.card, 8)
        XCTAssertLessThanOrEqual(DNSPilotDesign.Radius.control, 8)
        XCTAssertGreaterThan(DNSPilotDesign.Spacing.panel, DNSPilotDesign.Spacing.controlGap)
    }

    func testCapabilitiesDecoderMapsRustCliSchema() throws {
        let json = """
        {
          "schema_version": 1,
          "capabilities": [
            {
              "apply": "apple-network-extension-dns-settings",
              "can_benchmark": true,
              "flush": "guided-user-action",
              "notes": ["DoH/DoT DNS Settings require explicit user enablement."],
              "platform": "macos-store",
              "store_safe": true
            },
            {
              "apply": "linux-network-manager-polkit",
              "can_benchmark": true,
              "flush": "linux-system-resolver-polkit",
              "notes": ["Native packages can use NetworkManager/systemd-resolved with polkit."],
              "platform": "linux-native-power",
              "store_safe": false
            }
          ]
        }
        """

        let rows = try CapabilityMatrixJSONDecoder().decode(Data(json.utf8))

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first?.platformName, "macOS Store")
        XCTAssertEqual(rows.first?.applyDisposition, .allow)
        XCTAssertEqual(rows.first?.flush, .guidedUserAction)
        XCTAssertEqual(rows.last?.platformName, "Linux Native Power")
        XCTAssertEqual(rows.last?.applyDisposition, .allow)
        XCTAssertEqual(rows.last?.flush, .linuxSystemResolverPolkit)
        XCTAssertEqual(rows.last?.storeSafe, false)
    }

    func testCapabilitiesDecoderRejectsUnknownCapabilityValues() {
        let json = """
        {
          "schema_version": 1,
          "capabilities": [
            {
              "apply": "new-system-api",
              "can_benchmark": true,
              "flush": "guided-user-action",
              "notes": [],
              "platform": "macos-store",
              "store_safe": true
            }
          ]
        }
        """

        XCTAssertThrowsError(try CapabilityMatrixJSONDecoder().decode(Data(json.utf8)))
    }

    func testCapabilitiesDecoderRejectsUnsupportedSchemaVersion() {
        let json = """
        {
          "schema_version": 2,
          "capabilities": []
        }
        """

        XCTAssertThrowsError(try CapabilityMatrixJSONDecoder().decode(Data(json.utf8)))
    }

    func testViewModelLoadsRowsFromJSONBridge() {
        let viewModel = CapabilityMatrixViewModel(
            bridge: CapabilityMatrixJSONBridge(data: Data(capabilitiesFixtureJSON.utf8))
        )

        XCTAssertNil(viewModel.loadErrorMessage)
        XCTAssertEqual(viewModel.rows.count, 2)
        XCTAssertEqual(viewModel.rows.first?.platformID, "macos-store")
    }

    func testViewModelCapturesBridgeLoadFailure() {
        let viewModel = CapabilityMatrixViewModel(bridge: FailingCapabilityBridge())

        XCTAssertTrue(viewModel.rows.isEmpty)
        XCTAssertNotNil(viewModel.loadErrorMessage)
    }
}

private struct FailingCapabilityBridge: DNSPilotCoreBridge {
    func loadCapabilities() throws -> [CapabilityRow] {
        throw NSError(domain: "DNSPilotMacCoreTests", code: 1)
    }
}

private let capabilitiesFixtureJSON = """
{
  "schema_version": 1,
  "capabilities": [
    {
      "apply": "apple-network-extension-dns-settings",
      "can_benchmark": true,
      "flush": "guided-user-action",
      "notes": ["DoH/DoT DNS Settings require explicit user enablement."],
      "platform": "macos-store",
      "store_safe": true
    },
    {
      "apply": "guided-settings",
      "can_benchmark": true,
      "flush": "guided-user-action",
      "notes": ["Store builds must not depend on administrator elevation."],
      "platform": "windows-store",
      "store_safe": true
    }
  ]
}
"""
