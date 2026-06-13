import Foundation
import XCTest
@testable import DNSPilotMacCore

final class CustomDomainSuiteSaveRunnerTests: XCTestCase {
    func testRunnerPassesSuiteAddArgumentsToProcessRunner() throws {
        let processRunner = RecordingSuiteProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDomainSuiteSaveRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let form = CustomDomainSuiteFormViewModel(
            name: "Azure Lab",
            domainsText: "portal.azure.com login.microsoftonline.com"
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
                "suite-add",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "custom-azure-lab",
                "--name", "Azure Lab",
                "--domain", "portal.azure.com",
                "--domain", "login.microsoftonline.com",
                "--tag", "custom",
            ]
        )
        XCTAssertEqual(result.suiteID, "custom-azure-lab")
        XCTAssertEqual(result.name, "Azure Lab")
    }

    func testRunnerPassesSuiteUpdateArgumentsToProcessRunner() throws {
        let processRunner = RecordingSuiteProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDomainSuiteSaveRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let form = CustomDomainSuiteFormViewModel(
            name: "Azure Lab Updated",
            domainsText: "management.azure.com",
            suiteID: "azure-lab"
        )

        let result = try runner.save(
            form: form,
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            mode: .update
        )

        XCTAssertEqual(
            processRunner.invocations[0].arguments,
            [
                "suite-update",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "azure-lab",
                "--name", "Azure Lab Updated",
                "--domain", "management.azure.com",
                "--tag", "custom",
            ]
        )
        XCTAssertEqual(result.suiteID, "azure-lab")
    }

    func testDeleteRunnerPassesSuiteDeleteArgumentsToProcessRunner() throws {
        let processRunner = RecordingSuiteProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDomainSuiteDeleteRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )

        try runner.delete(suiteID: "azure-lab", databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))

        XCTAssertEqual(
            processRunner.invocations[0].arguments,
            [
                "suite-delete",
                "--db", "/tmp/dnspilot.sqlite",
                "--id", "azure-lab",
            ]
        )
    }

    func testRunnerRejectsInvalidFormWithoutStartingProcess() throws {
        let processRunner = RecordingSuiteProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let runner = CustomDomainSuiteSaveRunner(
            executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
            processRunner: processRunner
        )
        let form = CustomDomainSuiteFormViewModel(name: "", domainsText: "")

        XCTAssertThrowsError(
            try runner.save(form: form, databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"))
        ) { error in
            XCTAssertEqual(
                error as? CustomDomainSuiteSaveRunnerError,
                .invalidForm(issues: [
                    "Suite name is required.",
                    "Add at least one domain.",
                ])
            )
        }
        XCTAssertTrue(processRunner.invocations.isEmpty)
    }

    func testCoordinatorMapsRunnerErrorsToUserMessage() throws {
        let processRunner = RecordingSuiteProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 2, standardOutput: "", standardError: "suite already exists")
        )
        let coordinator = CustomDomainSuiteSaveCoordinator(
            runner: CustomDomainSuiteSaveRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: processRunner
            )
        )
        let form = CustomDomainSuiteFormViewModel(name: "Azure Lab", domainsText: "portal.azure.com")

        let outcome = coordinator.save(
            form: form,
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite")
        )

        XCTAssertEqual(outcome, .failed("suite already exists"))
    }

    func testCoordinatorPassesUpdateModeToRunner() throws {
        let processRunner = RecordingSuiteProcessRunner(
            output: BenchmarkProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        )
        let coordinator = CustomDomainSuiteSaveCoordinator(
            runner: CustomDomainSuiteSaveRunner(
                executableURL: URL(fileURLWithPath: "/usr/local/bin/dnspilot"),
                processRunner: processRunner
            )
        )
        let form = CustomDomainSuiteFormViewModel(
            name: "Azure Lab Updated",
            domainsText: "management.azure.com",
            suiteID: "azure-lab"
        )

        let outcome = coordinator.save(
            form: form,
            databaseURL: URL(fileURLWithPath: "/tmp/dnspilot.sqlite"),
            mode: .update
        )

        XCTAssertEqual(outcome, .saved(suiteID: "azure-lab", name: "Azure Lab Updated"))
        XCTAssertEqual(processRunner.invocations[0].arguments[0], "suite-update")
    }
}

private final class RecordingSuiteProcessRunner: BenchmarkProcessRunning {
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
