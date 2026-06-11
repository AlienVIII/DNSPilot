import Foundation

public protocol BenchmarkProcessRunning: AnyObject {
    func run(executableURL: URL, arguments: [String]) throws -> BenchmarkProcessOutput
}

public struct BenchmarkProcessOutput: Equatable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public struct BenchmarkRunResult: Equatable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String
    public let commandArguments: [String]

    public var succeeded: Bool {
        exitCode == 0
    }

    public init(
        exitCode: Int32,
        standardOutput: String,
        standardError: String,
        commandArguments: [String]
    ) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.commandArguments = commandArguments
    }
}

public enum BenchmarkRunnerError: Error, Equatable {
    case invalidPlan(issues: [String])
}

public struct BenchmarkRunner {
    private let executableURL: URL
    private let processRunner: any BenchmarkProcessRunning

    public init(
        executableURL: URL,
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
    }

    public func run(plan: BenchmarkPlanViewModel) throws -> BenchmarkRunResult {
        let validation = plan.validation
        guard validation.canRun else {
            throw BenchmarkRunnerError.invalidPlan(issues: validation.issues)
        }

        let arguments = plan.commandArguments
        let output = try processRunner.run(executableURL: executableURL, arguments: arguments)
        return BenchmarkRunResult(
            exitCode: output.exitCode,
            standardOutput: output.standardOutput,
            standardError: output.standardError,
            commandArguments: arguments
        )
    }
}

public final class FoundationBenchmarkProcessRunner: BenchmarkProcessRunning {
    public init() {}

    public func run(executableURL: URL, arguments: [String]) throws -> BenchmarkProcessOutput {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        return BenchmarkProcessOutput(
            exitCode: process.terminationStatus,
            standardOutput: Self.readString(from: standardOutput),
            standardError: Self.readString(from: standardError)
        )
    }

    private static func readString(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
