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

    func testApplyPlanViewModelGuidesPlainDNSApply() {
        let viewModel = ApplyPlanViewModel(
            plan: ApplyPlan(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .guideOnly,
                profileID: "cloudflare",
                profileName: "Cloudflare",
                testedResolver: "1.1.1.1:53",
                dnsServers: ["1.1.1.1", "1.0.0.1"],
                canApply: false,
                notes: ["Store-safe build must guide plain DNS changes through OS settings."]
            )
        )

        XCTAssertEqual(viewModel.statusLabel, "Guided")
        XCTAssertEqual(viewModel.actionLabel, "Copy DNS + Open Settings")
        XCTAssertEqual(viewModel.recommendedProfileLabel, "Recommended: Cloudflare")
        XCTAssertTrue(viewModel.canOfferPrimaryAction)
        XCTAssertEqual(viewModel.dnsServerText, "1.1.1.1\n1.0.0.1")
        XCTAssertTrue(viewModel.copyText.contains("Profile: Cloudflare"))
        XCTAssertTrue(viewModel.copyText.contains("Tested resolver: 1.1.1.1:53"))
        XCTAssertEqual(viewModel.guidedPrimaryActionLabel, "Copy DNS + Open Settings")
        XCTAssertEqual(viewModel.guidedPrimaryActionCopyText, "1.1.1.1\n1.0.0.1")
        XCTAssertTrue(viewModel.opensNetworkSettingsAfterGuidedPrimaryAction)
        XCTAssertEqual(viewModel.guidedApplySteps.map(\.id), [
            "copy-dns",
            "open-network-settings",
            "paste-active-service",
            "flush-cache",
            "validate-system-dns",
        ])
        XCTAssertTrue(viewModel.guidedApplySteps.first?.detail.contains("1.1.1.1") == true)
        XCTAssertTrue(viewModel.guidedApplyChecklistText?.contains("DNS Pilot has not changed system DNS.") == true)
        XCTAssertTrue(viewModel.guidedApplyChecklistText?.contains("1.1.1.1\n1.0.0.1") == true)
        XCTAssertTrue(viewModel.guidedApplyChecklistText?.contains("sudo dscacheutil -flushcache") == true)
        XCTAssertTrue(viewModel.guidedApplyChecklistText?.contains("Run System DNS validation") == true)
        XCTAssertTrue(viewModel.guidedApplyChecklistText?.contains("Retest DNS Pilot after applying DNS.") == true)
    }

    func testApplyPlanViewModelProtectsCurrentDNS() {
        let viewModel = ApplyPlanViewModel(
            plan: ApplyPlan(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .protectCurrentDNS,
                profileID: "cloudflare",
                profileName: nil,
                dnsServers: [],
                canApply: false,
                notes: ["VPN is active; protect current DNS."]
            )
        )

        XCTAssertEqual(viewModel.statusLabel, "Protected")
        XCTAssertEqual(viewModel.actionLabel, "Keep current DNS")
        XCTAssertEqual(viewModel.recommendedProfileLabel, "Recommended: cloudflare")
        XCTAssertFalse(viewModel.canOfferPrimaryAction)
        XCTAssertNil(viewModel.guidedPrimaryActionLabel)
        XCTAssertNil(viewModel.guidedPrimaryActionCopyText)
        XCTAssertTrue(viewModel.guidedApplySteps.isEmpty)
        XCTAssertNil(viewModel.guidedApplyChecklistText)
        XCTAssertFalse(viewModel.opensNetworkSettingsAfterGuidedPrimaryAction)
        XCTAssertTrue(viewModel.copyText.contains("VPN is active"))
    }

    func testApplyPlanPresentationFallsBackToLocalNextStepWhenApplyPlanFails() {
        let failed = BenchmarkApplyPlanPresentation(
            outcome: .failed("apply plan failed"),
            isLoading: false
        )
        let loading = BenchmarkApplyPlanPresentation(
            outcome: nil,
            isLoading: true
        )
        let loaded = BenchmarkApplyPlanPresentation(
            outcome: .loaded(
                ApplyPlanViewModel(
                    plan: ApplyPlan(
                        platformID: "macos-store",
                        applyCapability: .appleNetworkExtensionDNSSettings,
                        disposition: .guideOnly,
                        profileID: "cloudflare",
                        profileName: "Cloudflare",
                        dnsServers: ["1.1.1.1"],
                        canApply: false,
                        notes: []
                    )
                )
            ),
            isLoading: false
        )
        let unavailable = BenchmarkApplyPlanPresentation(
            outcome: nil,
            isLoading: false
        )

        XCTAssertTrue(failed.showsApplyPlanState)
        XCTAssertTrue(failed.showsLocalNextStep)
        XCTAssertTrue(failed.reportIncludesLocalNextStep)
        XCTAssertTrue(loading.showsApplyPlanState)
        XCTAssertFalse(loading.showsLocalNextStep)
        XCTAssertFalse(loading.reportIncludesLocalNextStep)
        XCTAssertTrue(loaded.showsApplyPlanState)
        XCTAssertFalse(loaded.showsLocalNextStep)
        XCTAssertFalse(loaded.reportIncludesLocalNextStep)
        XCTAssertFalse(unavailable.showsApplyPlanState)
        XCTAssertTrue(unavailable.showsLocalNextStep)
        XCTAssertTrue(unavailable.reportIncludesLocalNextStep)
    }

    func testApplyPlanReportFormatterAppendsLoadedPlan() {
        let plan = ApplyPlanViewModel(
            plan: ApplyPlan(
                platformID: "macos-store",
                applyCapability: .appleNetworkExtensionDNSSettings,
                disposition: .guideOnly,
                profileID: "cloudflare",
                profileName: "Cloudflare",
                dnsServers: ["1.1.1.1"],
                canApply: false,
                notes: ["Store-safe build must guide plain DNS changes through OS settings."]
            )
        )

        let report = BenchmarkApplyPlanReportFormatter.appendApplyPlan(
            outcome: .loaded(plan),
            isLoading: false,
            to: "Benchmark result"
        )

        XCTAssertTrue(report.contains("Apply policy"))
        XCTAssertTrue(report.contains("Apply plan: Guided"))
        XCTAssertTrue(report.contains("DNS servers:\n1.1.1.1"))
    }

    func testApplyPlanReportFormatterAppendsFailureAndLoadingStates() {
        let failedReport = BenchmarkApplyPlanReportFormatter.appendApplyPlan(
            outcome: .failed("apply plan failed"),
            isLoading: false,
            to: "Benchmark result"
        )
        let loadingReport = BenchmarkApplyPlanReportFormatter.appendApplyPlan(
            outcome: nil,
            isLoading: true,
            to: "Benchmark result"
        )

        XCTAssertTrue(failedReport.contains("Apply policy unavailable"))
        XCTAssertTrue(failedReport.contains("apply plan failed"))
        XCTAssertTrue(loadingReport.contains("Apply policy: checking"))
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

    func testApplyPlanDecoderMapsRustCliSchema() throws {
        let json = """
        {
          "schema_version": 1,
          "platform": "macos-store",
          "apply_capability": "apple-network-extension-dns-settings",
          "disposition": "guide-only",
          "profile_id": "cloudflare",
          "profile_name": "Cloudflare",
          "tested_resolver": "1.0.0.1:53",
          "dns_servers": ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111"],
          "can_apply": false,
          "notes": ["Store-safe build must guide plain DNS changes through OS settings."]
        }
        """

        let plan = try ApplyPlanJSONDecoder().decode(Data(json.utf8))

        XCTAssertEqual(plan.platformID, "macos-store")
        XCTAssertEqual(plan.applyCapability, .appleNetworkExtensionDNSSettings)
        XCTAssertEqual(plan.disposition, .guideOnly)
        XCTAssertEqual(plan.profileID, "cloudflare")
        XCTAssertEqual(plan.profileName, "Cloudflare")
        XCTAssertEqual(plan.testedResolver, "1.0.0.1:53")
        XCTAssertEqual(plan.dnsServers, ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111"])
        XCTAssertFalse(plan.canApply)
        XCTAssertEqual(plan.notes.count, 1)
    }

    func testApplyPlanDecoderRejectsUnsupportedSchemaVersion() {
        let json = """
        {
          "schema_version": 2,
          "platform": "linux-native-power",
          "apply_capability": "linux-network-manager-polkit",
          "disposition": "apply-with-user-approval",
          "profile_id": "quad9",
          "profile_name": "Quad9",
          "dns_servers": ["9.9.9.9"],
          "can_apply": true,
          "notes": []
        }
        """

        XCTAssertThrowsError(try ApplyPlanJSONDecoder().decode(Data(json.utf8)))
    }
}
