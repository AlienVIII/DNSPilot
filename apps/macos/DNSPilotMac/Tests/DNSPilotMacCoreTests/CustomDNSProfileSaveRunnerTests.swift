import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CustomDNSProfileSaveRunnerTests: XCTestCase {
    func testRunnerPassesProfileAddArgumentsToProcessRunner() throws {
        let processRunner = RecordingCustomDNSProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDNSProfileSaveRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let form = CustomDNSProfileFormViewModel(
            name: "Office DNS",
            ipv4ServersText: "1.1.1.1 8.8.8.8",
            ipv6ServersText: "2606:4700:4700::1111"
        )

        let result = try runner.save(
            form: form,
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite")
        )

        XCTAssertEqual(processRunner.invocations.count, 1)
        XCTAssertEqual(processRunner.invocations[0].executableURL.path, "/usr/local/bin/dnspilot")
        XCTAssertEqual(
            processRunner.invocations[0].arguments,
            [
                "profile-add",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "custom-office-dns",
                "--name", "Office DNS",
                "--ipv4", "1.1.1.1",
                "--ipv4", "8.8.8.8",
                "--ipv6", "2606:4700:4700::1111",
                "--tag", "custom",
            ]
        )
        XCTAssertEqual(result.profileID, "custom-office-dns")
        XCTAssertEqual(result.name, "Office DNS")
    }

    func testRunnerPassesProfileUpdateArgumentsToProcessRunner() throws {
        let processRunner = RecordingCustomDNSProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDNSProfileSaveRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let form = CustomDNSProfileFormViewModel(
            name: "Office DNS Updated",
            ipv4ServersText: "8.8.8.8",
            ipv6ServersText: "",
            profileID: "office-dns"
        )

        let result = try runner.save(
            form: form,
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            mode: .update
        )

        XCTAssertEqual(
            processRunner.invocations[0].arguments,
            [
                "profile-update",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "office-dns",
                "--name", "Office DNS Updated",
                "--ipv4", "8.8.8.8",
                "--tag", "custom",
            ]
        )
        XCTAssertEqual(result.profileID, "office-dns")
    }

    func testDeleteRunnerPassesProfileDeleteArgumentsToProcessRunner() throws {
        let processRunner = RecordingCustomDNSProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDNSProfileDeleteRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        try runner.delete(profileID: "office-dns", databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(
            processRunner.invocations[0].arguments,
            [
                "profile-delete",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "office-dns",
            ]
        )
    }

    func testRunnerRejectsInvalidFormWithoutStartingProcess() throws {
        let processRunner = RecordingCustomDNSProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDNSProfileSaveRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let form = CustomDNSProfileFormViewModel(
            name: "",
            ipv4ServersText: "",
            ipv6ServersText: ""
        )

        XCTAssertThrowsError(
            try runner.save(form: form, databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))
        ) { error in
            XCTAssertEqual(
                error as? CustomDNSProfileSaveRunnerError,
                .invalidForm(issues: [
                    "Name is required.",
                    "Add at least one IPv4 or IPv6 DNS server.",
                ])
            )
        }
        XCTAssertTrue(processRunner.invocations.isEmpty)
    }

    func testRunnerThrowsProcessFailureForNonZeroExit() throws {
        let processRunner = RecordingCustomDNSProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 2, standardOutput: "", standardError: "profile already exists")
        )
        let runner = CustomDNSProfileSaveRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let form = CustomDNSProfileFormViewModel(
            name: "Office DNS",
            ipv4ServersText: "1.1.1.1",
            ipv6ServersText: ""
        )

        XCTAssertThrowsError(
            try runner.save(form: form, databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))
        ) { error in
            XCTAssertEqual(
                error as? CustomDNSProfileSaveRunnerError,
                .processFailed("profile already exists")
            )
        }
    }

    func testCoordinatorMapsRunnerErrorsToUserMessage() throws {
        let processRunner = RecordingCustomDNSProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 2, standardOutput: "", standardError: "profile already exists")
        )
        let coordinator = CustomDNSProfileSaveCoordinator(
            runner: CustomDNSProfileSaveRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: processRunner
            )
        )
        let form = CustomDNSProfileFormViewModel(
            name: "Office DNS",
            ipv4ServersText: "1.1.1.1",
            ipv6ServersText: ""
        )

        let outcome = coordinator.save(
            form: form,
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite")
        )

        XCTAssertEqual(outcome, .failed("profile already exists"))
    }

    func testCoordinatorPassesUpdateModeToRunner() throws {
        let processRunner = RecordingCustomDNSProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let coordinator = CustomDNSProfileSaveCoordinator(
            runner: CustomDNSProfileSaveRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: processRunner
            )
        )
        let form = CustomDNSProfileFormViewModel(
            name: "Renamed DNS",
            ipv4ServersText: "8.8.8.8",
            ipv6ServersText: "",
            profileID: "office-dns"
        )

        let outcome = coordinator.save(
            form: form,
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            mode: .update
        )

        XCTAssertEqual(outcome, .saved(profileID: "office-dns", name: "Renamed DNS"))
        XCTAssertEqual(processRunner.invocations[0].arguments[0], "profile-update")
    }
}

private final class RecordingCustomDNSProcessRunner: BenchmarkProcessRunning {
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
