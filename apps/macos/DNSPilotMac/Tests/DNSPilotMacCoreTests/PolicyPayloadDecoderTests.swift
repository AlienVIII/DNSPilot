import Foundation
import XCTest
@testable import DNSPilotMacCore

final class PolicyPayloadDecoderTests: XCTestCase {
    func testPolicyGuidanceKeepsDirectBenchmarkFromFlushing() {
        let guidance = PolicyGuidanceViewModel(
            preflight: PreflightPolicy(
                platformID: "macos-store",
                scope: .directResolverBenchmark,
                flushCapability: .guidedUserAction,
                flushRequirement: .notNeeded,
                notes: ["Direct resolver benchmark bypasses the OS DNS cache."]
            ),
            applyPolicy: ApplyPolicy(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .allow,
                canPromptApply: true,
                notes: ["Explicit user-approved apply prompt."]
            )
        )

        XCTAssertEqual(guidance.flushStatusLabel, "No flush needed")
        XCTAssertEqual(guidance.applyActionLabel, "Enable profile")
        XCTAssertTrue(guidance.canPromptApply)
        XCTAssertEqual(guidance.notes.count, 2)
    }

    func testPolicyGuidanceProtectsCurrentDNSWhenNetworkIsManaged() {
        let guidance = PolicyGuidanceViewModel(
            preflight: PreflightPolicy(
                platformID: "macos-store",
                scope: .systemDNSValidation,
                flushCapability: .guidedUserAction,
                flushRequirement: .recommendedBeforeTest,
                notes: ["System DNS validation after apply can be stale."]
            ),
            applyPolicy: ApplyPolicy(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .protectCurrentDNS,
                canPromptApply: false,
                notes: ["VPN is active; protect current DNS."]
            )
        )

        XCTAssertEqual(guidance.flushStatusLabel, "Flush recommended")
        XCTAssertEqual(guidance.applyActionLabel, "Keep current DNS")
        XCTAssertFalse(guidance.canPromptApply)
    }

    func testPreflightDecoderMapsRustCliSchema() throws {
        let json = """
        {
          "schema_version": 1,
          "platform": "macos-store",
          "scope": "system-dns-validation",
          "flush_capability": "guided-user-action",
          "flush_requirement": "recommended-before-test",
          "notes": ["System DNS validation after apply can be polluted by stale OS resolver cache."]
        }
        """

        let preflight = try PreflightJSONDecoder().decode(Data(json.utf8))

        XCTAssertEqual(preflight.platformID, "macos-store")
        XCTAssertEqual(preflight.scope, .systemDNSValidation)
        XCTAssertEqual(preflight.flushCapability, .guidedUserAction)
        XCTAssertEqual(preflight.flushRequirement, .recommendedBeforeTest)
        XCTAssertEqual(preflight.notes.count, 1)
    }

    func testPreflightDecoderRejectsUnsupportedSchemaVersion() {
        let json = """
        {
          "schema_version": 2,
          "platform": "macos-store",
          "scope": "direct-resolver-benchmark",
          "flush_capability": "guided-user-action",
          "flush_requirement": "not-needed",
          "notes": []
        }
        """

        XCTAssertThrowsError(try PreflightJSONDecoder().decode(Data(json.utf8)))
    }

    func testApplyPolicyDecoderMapsRustCliSchema() throws {
        let json = """
        {
          "schema_version": 1,
          "platform": "macos-store",
          "apply_capability": "apple-network-extension-dns-settings",
          "disposition": "protect-current-dns",
          "can_prompt_apply": false,
          "notes": ["VPN is active; protect current DNS and avoid apply prompts."]
        }
        """

        let policy = try ApplyPolicyJSONDecoder().decode(Data(json.utf8))

        XCTAssertEqual(policy.platformID, "macos-store")
        XCTAssertEqual(policy.applyCapability, .appleNetworkExtensionDNSSettings)
        XCTAssertEqual(policy.disposition, .protectCurrentDNS)
        XCTAssertFalse(policy.canPromptApply)
        XCTAssertEqual(policy.notes.count, 1)
    }

    func testApplyPolicyDecoderRejectsUnsupportedSchemaVersion() {
        let json = """
        {
          "schema_version": 2,
          "platform": "windows-store",
          "apply_capability": "guided-settings",
          "disposition": "guide-only",
          "can_prompt_apply": true,
          "notes": []
        }
        """

        XCTAssertThrowsError(try ApplyPolicyJSONDecoder().decode(Data(json.utf8)))
    }
}
