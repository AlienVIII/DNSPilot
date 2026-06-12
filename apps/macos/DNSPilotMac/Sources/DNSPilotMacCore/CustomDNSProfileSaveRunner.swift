import Foundation

public enum CustomDNSProfileSaveRunnerError: Error, Equatable {
    case invalidForm(issues: [String])
    case processFailed(String)
}

public struct CustomDNSProfileSaveResult: Equatable {
    public let profileID: String
    public let name: String
    public let commandArguments: [String]

    public init(profileID: String, name: String, commandArguments: [String]) {
        self.profileID = profileID
        self.name = name
        self.commandArguments = commandArguments
    }
}

public struct CustomDNSProfileSaveRunner {
    private let executableURL: URL
    private let processRunner: any BenchmarkProcessRunning

    public init(
        executableURL: URL,
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
    }

    public func save(form: CustomDNSProfileFormViewModel, databaseURL: URL) throws -> CustomDNSProfileSaveResult {
        guard form.canSave else {
            throw CustomDNSProfileSaveRunnerError.invalidForm(issues: form.issues)
        }

        let arguments = form.profileAddArguments(databaseURL: databaseURL)
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: arguments,
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw CustomDNSProfileSaveRunnerError.processFailed(Self.failureMessage(from: output))
        }

        return CustomDNSProfileSaveResult(
            profileID: form.profileID,
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

        return "Profile save command exited with code \(output.exitCode)."
    }
}

public enum CustomDNSProfileSaveOutcome: Equatable {
    case saved(profileID: String, name: String)
    case failed(String)
}

public struct CustomDNSProfileSaveCoordinator {
    private let runner: CustomDNSProfileSaveRunner

    public init(runner: CustomDNSProfileSaveRunner) {
        self.runner = runner
    }

    public func save(form: CustomDNSProfileFormViewModel, databaseURL: URL) -> CustomDNSProfileSaveOutcome {
        do {
            let result = try runner.save(form: form, databaseURL: databaseURL)
            return .saved(profileID: result.profileID, name: result.name)
        } catch CustomDNSProfileSaveRunnerError.invalidForm(let issues) {
            return .failed(issues.joined(separator: "\n"))
        } catch CustomDNSProfileSaveRunnerError.processFailed(let message) {
            return .failed(message)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
