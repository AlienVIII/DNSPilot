import Foundation

public enum CustomDomainSuiteSaveRunnerError: Error, Equatable {
    case invalidForm(issues: [String])
    case processFailed(String)
}

extension CustomDomainSuiteSaveRunnerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidForm(let issues):
            issues.joined(separator: "\n")
        case .processFailed(let message):
            message
        }
    }
}

public struct CustomDomainSuiteSaveResult: Equatable {
    public let suiteID: String
    public let name: String
    public let commandArguments: [String]

    public init(suiteID: String, name: String, commandArguments: [String]) {
        self.suiteID = suiteID
        self.name = name
        self.commandArguments = commandArguments
    }
}

public struct CustomDomainSuiteSaveRunner {
    private let executableURL: URL
    private let processRunner: any BenchmarkProcessRunning

    public init(
        executableURL: URL,
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
    }

    public func save(
        form: CustomDomainSuiteFormViewModel,
        databaseURL: URL
    ) throws -> CustomDomainSuiteSaveResult {
        guard form.canSave else {
            throw CustomDomainSuiteSaveRunnerError.invalidForm(issues: form.issues)
        }

        let arguments = form.suiteAddArguments(databaseURL: databaseURL)
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: arguments,
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw CustomDomainSuiteSaveRunnerError.processFailed(Self.failureMessage(from: output))
        }

        return CustomDomainSuiteSaveResult(
            suiteID: form.suiteID,
            name: form.name,
            commandArguments: arguments
        )
    }

    private static func failureMessage(from output: BenchmarkProcessOutput) -> String {
        let standardError = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardError.isEmpty {
            return standardError
        }

        let standardOutput = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardOutput.isEmpty {
            return standardOutput
        }

        return "Suite save command exited with code \(output.exitCode)."
    }
}

public enum CustomDomainSuiteSaveOutcome: Equatable {
    case saved(suiteID: String, name: String)
    case failed(String)
}

public struct CustomDomainSuiteSaveCoordinator {
    private let runner: CustomDomainSuiteSaveRunner

    public init(runner: CustomDomainSuiteSaveRunner) {
        self.runner = runner
    }

    public func save(
        form: CustomDomainSuiteFormViewModel,
        databaseURL: URL
    ) -> CustomDomainSuiteSaveOutcome {
        do {
            let result = try runner.save(form: form, databaseURL: databaseURL)
            return .saved(suiteID: result.suiteID, name: result.name)
        } catch CustomDomainSuiteSaveRunnerError.invalidForm(let issues) {
            return .failed(issues.joined(separator: "\n"))
        } catch CustomDomainSuiteSaveRunnerError.processFailed(let message) {
            return .failed(message)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
