import Foundation
import XCTest
@testable import DNSPilotMacCore

final class ApplyPlanRunnerTests: XCTestCase {
    func testRequestBuildsApplyPlanArguments() {
        let request = ApplyPlanRequest(
            platformID: "linux-native-power",
            profileDatabaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            profileID: "cloudflare",
            testedResolver: "1.0.0.1:53",
            confidence: .medium,
            gateHealth: .healthy,
            vpnActive: true,
            mdmProfileActive: true,
            corporateDNSDetected: true,
            captivePortalDetected: true
        )

        XCTAssertEqual(
            request.commandArguments,
            [
                "apply-plan",
                "linux-native-power",
                "--confidence", "medium",
                "--gate-health", "healthy",
                "--profile-db", "/tmp/dnspilot.sqlite",
                "--profile-id", "cloudflare",
                "--tested-resolver", "1.0.0.1:53",
                "--vpn-active",
                "--mdm-profile-active",
                "--corporate-dns-detected",
                "--captive-portal-detected",
            ]
        )
    }

    func testRunnerPassesArgumentsAndDecodesApplyPlan() throws {
        let processRunner = RecordingApplyPlanProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: applyPlanJSON, standardError: "")
        )
        let runner = ApplyPlanRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        let plan = try runner.load(
            request: ApplyPlanRequest(profileID: "cloudflare", confidence: .high)
        )

        XCTAssertEqual(processRunner.invocations.count, 1)
        XCTAssertEqual(processRunner.invocations[0].executableURL.path, "/usr/local/bin/dnspilot")
        XCTAssertEqual(
            processRunner.invocations[0].arguments,
            [
                "apply-plan",
                "macos-store",
                "--confidence", "high",
                "--gate-health", "healthy",
                "--profile-id", "cloudflare",
            ]
        )
        XCTAssertEqual(plan.profileID, "cloudflare")
        XCTAssertEqual(plan.testedResolver, "1.1.1.1:53")
        XCTAssertEqual(plan.disposition, .guideOnly)
        XCTAssertEqual(plan.dnsServers.first, "1.1.1.1")
    }

    func testRunnerThrowsProcessFailureForNonZeroExit() {
        let processRunner = RecordingApplyPlanProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 2, standardOutput: "", standardError: "apply plan failed")
        )
        let runner = ApplyPlanRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        XCTAssertThrowsError(try runner.load(request: ApplyPlanRequest(profileID: "cloudflare"))) { error in
            XCTAssertEqual(error as? ApplyPlanRunnerError, .processFailed("apply plan failed"))
        }
    }
}

private final class RecordingApplyPlanProcessRunner: BenchmarkProcessRunning {
    struct Invocation {
        let executableURL: URL
        let arguments: [String]
    }

    private let output: BenchmarkProcessOutput
    private(set) var invocations: [Invocation] = []

    init(output: BenchmarkProcessOutput) {
        self.output = output
    }

    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?
    ) throws -> BenchmarkProcessOutput {
        invocations.append(Invocation(executableURL: executableURL, arguments: arguments))
        return output
    }
}

private let applyPlanJSON = """
{
  "schema_version": 1,
  "platform": "macos-store",
  "apply_capability": "apple-network-extension-dns-settings",
  "disposition": "guide-only",
  "profile_id": "cloudflare",
  "profile_name": "Cloudflare",
  "tested_resolver": "1.1.1.1:53",
  "dns_servers": ["1.1.1.1", "1.0.0.1"],
  "can_apply": false,
  "notes": ["Store-safe build must guide plain DNS changes through OS settings."]
}
"""
