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
            outputs: [
                rollbackCaptureOutput(),
                BenchmarkProcessOutput(exitCode: 0, standardOutput: "Applied DNS", standardError: ""),
            ]
        )
        let runner = MacOSPowerDNSActionRunner(
            isEnabled: true,
            osascriptURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            processRunner: processRunner
        )

        let snapshot = try runner.applyDNS(servers: ["1.1.1.1", "2606:4700:4700::1111"])

        XCTAssertEqual(snapshot.service, "Wi-Fi")
        XCTAssertEqual(snapshot.mode, .servers)
        XCTAssertEqual(snapshot.servers, ["192.168.1.1"])
        XCTAssertEqual(processRunner.invocations.count, 2)
        XCTAssertEqual(processRunner.invocations[0].executableURL.path, "/bin/sh")
        XCTAssertEqual(processRunner.invocations[1].executableURL.path, "/usr/bin/osascript")
        XCTAssertEqual(processRunner.invocations[1].arguments.first, "-e")
        let script = try XCTUnwrap(processRunner.invocations[1].arguments.last)
        XCTAssertTrue(script.contains("with administrator privileges"))
        XCTAssertTrue(script.contains("/usr/sbin/networksetup -listnetworkserviceorder"))
        XCTAssertTrue(script.contains("/usr/sbin/networksetup -setdnsservers"))
        XCTAssertTrue(script.contains("'1.1.1.1' '2606:4700:4700::1111'"))
        XCTAssertTrue(script.contains("DNS configuration changed"))
        XCTAssertTrue(script.contains("/usr/bin/dscacheutil -flushcache"))
        XCTAssertTrue(script.contains("mDNSResponder"))
    }

    func testInvalidRollbackCaptureStopsBeforeAdministratorPrompt() {
        let processRunner = RecordingPowerActionProcessRunner(
            outputs: [
                BenchmarkProcessOutput(
                    exitCode: 0,
                    standardOutput: """
                    DNSPILOT_ROLLBACK_V1
                    service_b64=not-base64
                    mode=servers
                    server=192.168.1.1
                    DNSPILOT_ROLLBACK_END
                    """,
                    standardError: ""
                ),
            ]
        )
        let runner = MacOSPowerDNSActionRunner(isEnabled: true, processRunner: processRunner)

        XCTAssertThrowsError(try runner.applyDNS(servers: ["1.1.1.1"]))
        XCTAssertEqual(processRunner.invocations.count, 1)
        XCTAssertEqual(processRunner.invocations.first?.executableURL.path, "/bin/sh")
    }

    func testMalformedRollbackServerStopsBeforeAdministratorPrompt() {
        let processRunner = RecordingPowerActionProcessRunner(
            outputs: [
                BenchmarkProcessOutput(
                    exitCode: 0,
                    standardOutput: """
                    DNSPILOT_ROLLBACK_V1
                    service_b64=V2ktRmk=
                    mode=servers
                    server=resolver.example.com
                    DNSPILOT_ROLLBACK_END
                    """,
                    standardError: ""
                ),
            ]
        )
        let runner = MacOSPowerDNSActionRunner(isEnabled: true, processRunner: processRunner)

        XCTAssertThrowsError(try runner.applyDNS(servers: ["1.1.1.1"]))
        XCTAssertEqual(processRunner.invocations.count, 1)
        XCTAssertEqual(processRunner.invocations.first?.executableURL.path, "/bin/sh")
    }

    func testRestoreAutomaticDNSUsesEmptyAndChecksActiveService() throws {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "Restored DNS", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(
            isEnabled: true,
            processRunner: processRunner,
            now: { Date(timeIntervalSince1970: 1_100) }
        )
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .automatic,
            servers: [],
            appliedMode: .servers,
            appliedServers: ["1.1.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try runner.restoreDNS(snapshot: snapshot)

        let script = try XCTUnwrap(processRunner.invocations.first?.arguments.last)
        XCTAssertTrue(script.contains("networksetup -setdnsservers 'Wi-Fi' Empty"))
        XCTAssertTrue(script.contains("Active network service changed"))
        XCTAssertTrue(script.contains("/usr/bin/dscacheutil -flushcache"))
    }

    func testRestoreRequiresCurrentDNSToMatchTheStateAppliedByDNSPilot() throws {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "Restored DNS", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(
            isEnabled: true,
            processRunner: processRunner,
            now: { Date(timeIntervalSince1970: 1_100) }
        )
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["192.168.1.1"],
            appliedMode: .servers,
            appliedServers: ["1.1.1.1", "1.0.0.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try runner.restoreDNS(snapshot: snapshot)

        let script = try XCTUnwrap(processRunner.invocations.first?.arguments.last)
        XCTAssertTrue(script.contains("DNS configuration changed after apply"))
        XCTAssertTrue(script.contains("'1.1.1.1' '1.0.0.1'"))
    }

    func testRestoreRejectsLegacySnapshotWithoutAppliedStateBeforeAdministratorPrompt() {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(
            isEnabled: true,
            processRunner: processRunner,
            now: { Date(timeIntervalSince1970: 1_100) }
        )
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["192.168.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertThrowsError(try runner.restoreDNS(snapshot: snapshot)) { error in
            XCTAssertEqual(error as? MacOSPowerDNSActionRunnerError, .missingAppliedDNSState)
        }
        XCTAssertTrue(processRunner.invocations.isEmpty)
    }

    func testRestoreRejectsStaleSnapshotBeforeAdministratorPrompt() {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(
            isEnabled: true,
            processRunner: processRunner,
            now: { Date(timeIntervalSince1970: 100_000) }
        )
        let snapshot = PowerDNSRollbackSnapshot(
            service: "Wi-Fi",
            mode: .servers,
            servers: ["192.168.1.1"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertThrowsError(try runner.restoreDNS(snapshot: snapshot)) { error in
            XCTAssertEqual(error as? MacOSPowerDNSActionRunnerError, .staleRollbackSnapshot)
        }
        XCTAssertTrue(processRunner.invocations.isEmpty)
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

    func testApplyRejectsHostnamesBeforePromptingForAdmin() {
        let processRunner = RecordingPowerActionProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = MacOSPowerDNSActionRunner(isEnabled: true, processRunner: processRunner)

        XCTAssertThrowsError(try runner.applyDNS(servers: ["resolver.example.com"])) { error in
            XCTAssertEqual(
                error as? MacOSPowerDNSActionRunnerError,
                .unsafeDNSServer("resolver.example.com")
            )
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
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isEnabled(environment: [:], userDefaultValue: false))
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isEnabled(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "0"], userDefaultValue: true))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isEnabled(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "1"], userDefaultValue: false))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isEnabled(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "true"], userDefaultValue: false))
    }

    func testBundleInfoCanEnablePowerEditionWithoutTerminalEnvironment() {
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isEnabled(environment: [:], bundleInfoValue: true, userDefaultValue: false))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isEnabled(environment: [:], bundleInfoValue: true, userDefaultValue: true))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isEnabled(environment: [:], bundleInfoValue: "yes", userDefaultValue: true))
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isEnabled(environment: [:], bundleInfoValue: false, userDefaultValue: false))
    }

    func testUserOptInCannotEnableDirectAdminActionsWithoutPowerBundle() {
        XCTAssertFalse(
            MacOSPowerDNSActionConfiguration.isEnabled(
                environment: [:],
                bundleInfoValue: nil,
                userDefaultValue: true
            )
        )
    }

    func testBuildCapabilityRequiresPowerBundleOrLaunchFlag() {
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isBuildCapable(environment: [:], bundleInfoValue: nil))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isBuildCapable(environment: [:], bundleInfoValue: true))
        XCTAssertTrue(MacOSPowerDNSActionConfiguration.isBuildCapable(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "1"], bundleInfoValue: nil))
        XCTAssertFalse(MacOSPowerDNSActionConfiguration.isBuildCapable(environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "0"], bundleInfoValue: true))
    }

    func testEnvironmentFlagOverridesBundlePowerEditionSwitch() {
        XCTAssertFalse(
            MacOSPowerDNSActionConfiguration.isEnabled(
                environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "0"],
                bundleInfoValue: true,
                userDefaultValue: true
            )
        )
        XCTAssertTrue(
            MacOSPowerDNSActionConfiguration.isEnabled(
                environment: ["DNSPILOT_ENABLE_POWER_ACTIONS": "1"],
                bundleInfoValue: false,
                userDefaultValue: false
            )
        )
    }
}

private final class RecordingPowerActionProcessRunner: BenchmarkProcessRunning {
    struct Invocation: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    private var outputs: [BenchmarkProcessOutput]
    private(set) var invocations: [Invocation] = []

    init(output: BenchmarkProcessOutput) {
        outputs = [output]
    }

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
            ? BenchmarkProcessOutput(exitCode: 1, standardOutput: "", standardError: "Missing test output")
            : outputs.removeFirst()
    }
}

private func rollbackCaptureOutput() -> BenchmarkProcessOutput {
    BenchmarkProcessOutput(
        exitCode: 0,
        standardOutput: """
        DNSPILOT_ROLLBACK_V1
        service_b64=V2ktRmk=
        mode=servers
        server=192.168.1.1
        DNSPILOT_ROLLBACK_END
        """,
        standardError: ""
    )
}
