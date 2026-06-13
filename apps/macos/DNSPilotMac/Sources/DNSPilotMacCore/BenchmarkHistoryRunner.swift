import Foundation

public enum BenchmarkHistoryRunnerError: Error, Equatable {
    case processFailed(String)
}

public struct BenchmarkHistoryRunner {
    private let executableURL: URL
    private let processRunner: any BenchmarkProcessRunning

    public init(
        executableURL: URL,
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
    }

    public func load(databaseURL: URL) throws -> BenchmarkHistoryPayload {
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: ["history-list", "--db", databaseURL.path],
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw BenchmarkHistoryRunnerError.processFailed(Self.failureMessage(from: output))
        }
        return try BenchmarkHistoryJSONDecoder.decode(output.standardOutput)
    }

    public func delete(historyID: String, databaseURL: URL) throws {
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: [
                "history-delete",
                "--db", databaseURL.path,
                "--id", historyID,
            ],
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw BenchmarkHistoryRunnerError.processFailed(Self.failureMessage(from: output))
        }
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

        return "History command exited with code \(output.exitCode)."
    }
}
