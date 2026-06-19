import Foundation
import XCTest
@testable import DNSPilotMacCore

final class MacOSPowerDNSActionRunnerTests: XCTestCase {
    func testPowerActionsAreDisabledByDefault() {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(processRunner: processRunner)

        XCTAssertThrowsError(try runner.applyDNS(servers: ["1.1.1.1", "1.0.0.1"])) { error in
            XCTAssertEqual(error as? MacOSPowerDNSActionRunnerError, .disabled)
        }
        XCTAssertTrue(processRunner.invocations.isEmpty)
    }

    func testEnabledApplyBuildsAdminAppleScriptForActiveNetworkService() throws {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "Applied DNS", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(
            isEnabled: true,
            osascriptURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            processRunner: processRunner
        )

        try runner.applyDNS(servers: ["1.1.1.1", "2606:4700:4700::1111"])

        XCTAssertEqual(processRunner.invocations.count, 1)
        XCTAssertEqual(processRunner.invocations[0].executableURL.path, "/usr/bin/osascript")
        XCTAssertEqual(processRunner.invocations[0].arguments.first, "-e")
        let script = try XCTUnwrap(processRunner.invocations[0].arguments.last)
        XCTAssertTrue(script.contains("with administrator privileges"))
        XCTAssertTrue(script.contains("/usr/sbin/networksetup -setdnsservers"))
        XCTAssertTrue(script.contains("'1.1.1.1' '2606:4700:4700::1111'"))
        XCTAssertTrue(script.contains("/usr/bin/dscacheutil -flushcache"))
        XCTAssertTrue(script.contains("mDNSResponder"))
    }

    func testEnabledFlushBuildsAdminAppleScript() throws {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(isEnabled: true, processRunner: processRunner)

        try runner.flushDNS()

        let script = try XCTUnwrap(processRunner.invocations.first?.arguments.last)
        XCTAssertTrue(script.contains("with administrator privileges"))
        XCTAssertTrue(script.contains("/usr/bin/dscacheutil -flushcache"))
        XCTAssertTrue(script.contains("/usr/bin/killall -HUP mDNSResponder"))
    }

    func testApplyRejectsEmptyOrUnsafeServerListBeforePromptingForAdmin() {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(isEnabled: true, processRunner: processRunner)

        XCTAssertThrowsError(try runner.applyDNS(servers: [])) { error in
            XCTAssertEqual(error as? MacOSPowerDNSActionRunnerError, .emptyDNSServers)
        }
        XCTAssertThrowsError(try runner.applyDNS(servers: ["1.1.1.1; rm -rf /"])) { error in
            XCTAssertEqual(error as? MacOSPowerDNSActionRunnerError, .unsafeDNSServer("1.1.1.1; rm -rf /"))
        }
        XCTAssertTrue(processRunner.invocations.isEmpty)
    }

    func testRunnerMapsProcessFailureToUsefulMessage() {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 1, standardOutput: "", standardError: "User canceled.")
        )
        let runner = MacOSPowerDNSActionRunner(isEnabled: true, processRunner: processRunner)

        XCTAssertThrowsError(try runner.flushDNS()) { error in
            XCTAssertEqual(error as? MacOSPowerDNSActionRunnerError, .processFailed("User canceled."))
        }
    }

    func testEnvironmentFlagEnablesPowerActionsOnlyWhenExplicit() {
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isEnabled(environment: [:]))
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isEnabled(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "0"]))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isEnabled(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "1"]))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isEnabled(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "true"]))
    }
}

private final class RecordingPowerActionProcessRunner: BenchmarkProcessRunning {
    struct Invocation: Equatable {
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
