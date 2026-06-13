import Foundation

public protocol BenchmarkProcessRunning: AnyObject {
    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?
    ) throws -> BenchmarkProcessOutput

    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?,
        progressHandler: BenchmarkProgressEventHandler?
    ) throws -> BenchmarkProcessOutput
}

public extension BenchmarkProcessRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?,
        progressHandler: BenchmarkProgressEventHandler?
    ) throws -> BenchmarkProcessOutput {
        try run(
            executableURL: executableURL,
            arguments: arguments,
            cancellation: cancellation
        )
    }
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

public typealias BenchmarkProgressEventHandler = @Sendable (BenchmarkProgressEvent) -> Void

public enum BenchmarkProgressEventType: String, Decodable, Equatable, Sendable {
    case resolverStarted = "resolver_started"
    case resolverFinished = "resolver_finished"
}

public enum BenchmarkProgressEventStatus: String, Decodable, Equatable, Sendable {
    case success
    case degraded
    case failed
}

public struct BenchmarkProgressEvent: Decodable, Equatable, Sendable {
    public let type: BenchmarkProgressEventType
    public let measurementScope: BenchmarkMeasurementScope
    public let profileID: String
    public let resolver: String
    public let index: Int
    public let total: Int
    public let status: BenchmarkProgressEventStatus?
    public let failureRate: Double?
    public let timeoutRate: Double?
    public let elapsedMS: Double?

    private enum CodingKeys: String, CodingKey {
        case type
        case measurementScope = "measurement_scope"
        case profileID = "profile_id"
        case resolver
        case index
        case total
        case status
        case failureRate = "failure_rate"
        case timeoutRate = "timeout_rate"
        case elapsedMS = "elapsed_ms"
    }

    public init(
        type: BenchmarkProgressEventType,
        measurementScope: BenchmarkMeasurementScope,
        profileID: String,
        resolver: String,
        index: Int,
        total: Int,
        status: BenchmarkProgressEventStatus?,
        failureRate: Double?,
        timeoutRate: Double?,
        elapsedMS: Double? = nil
    ) {
        self.type = type
        self.measurementScope = measurementScope
        self.profileID = profileID
        self.resolver = resolver
        self.index = index
        self.total = total
        self.status = status
        self.failureRate = failureRate
        self.timeoutRate = timeoutRate
        self.elapsedMS = elapsedMS
    }
}

public enum BenchmarkProgressEventJSONDecoder {
    public static func decode(_ line: String) throws -> BenchmarkProgressEvent {
        let data = Data(line.utf8)
        return try JSONDecoder().decode(BenchmarkProgressEvent.self, from: data)
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

    public func run(
        plan: BenchmarkPlanViewModel,
        persistence: BenchmarkHistoryPersistence? = nil,
        cancellation: BenchmarkRunCancellation? = nil,
        progressHandler: BenchmarkProgressEventHandler? = nil
    ) throws -> BenchmarkRunResult {
        let validation = plan.validation
        guard validation.canRun else {
            throw BenchmarkRunnerError.invalidPlan(issues: validation.issues)
        }

        let progressArguments = progressHandler == nil ? [] : ["--progress-jsonl"]
        let arguments = plan.commandArguments + progressArguments + (persistence?.commandArguments ?? [])
        let output = try processRunner.run(
            executableURL: executableURL,
            arguments: arguments,
            cancellation: cancellation,
            progressHandler: progressHandler
        )
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

    public func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?
    ) throws -> BenchmarkProcessOutput {
        try run(
            executableURL: executableURL,
            arguments: arguments,
            cancellation: cancellation,
            progressHandler: nil
        )
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        cancellation: BenchmarkRunCancellation?,
        progressHandler: BenchmarkProgressEventHandler?
    ) throws -> BenchmarkProcessOutput {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        let processLock = NSLock()
        var hasStarted = false
        var shouldTerminateAfterStart = false
        let registration = cancellation?.register {
            processLock.lock()
            if hasStarted {
                if process.isRunning {
                    process.terminate()
                }
            } else {
                shouldTerminateAfterStart = true
            }
            processLock.unlock()
        }
        defer {
            registration?.cancel()
        }

        try process.run()
        processLock.lock()
        hasStarted = true
        let shouldTerminate = shouldTerminateAfterStart || (cancellation?.isCancelled == true)
        processLock.unlock()

        if shouldTerminate && process.isRunning {
            process.terminate()
        }

        let readGroup = DispatchGroup()
        let standardOutputBuffer = ProcessPipeBuffer()
        let standardErrorBuffer = ProcessPipeBuffer()
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            standardOutputBuffer.set(standardOutput.fileHandleForReading.readDataToEndOfFile())
            readGroup.leave()
        }
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            Self.drainStandardError(
                standardError.fileHandleForReading,
                into: standardErrorBuffer,
                progressHandler: progressHandler
            )
            readGroup.leave()
        }

        process.waitUntilExit()
        readGroup.wait()

        return BenchmarkProcessOutput(
            exitCode: process.terminationStatus,
            standardOutput: Self.string(from: standardOutputBuffer.data),
            standardError: Self.string(from: standardErrorBuffer.data)
        )
    }

    private static func string(from data: Data) -> String {
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func drainStandardError(
        _ fileHandle: FileHandle,
        into buffer: ProcessPipeBuffer,
        progressHandler: BenchmarkProgressEventHandler?
    ) {
        var lineBuffer = BenchmarkProgressLineBuffer(progressHandler: progressHandler)
        while true {
            let data = fileHandle.availableData
            if data.isEmpty {
                break
            }
            buffer.append(data)
            lineBuffer.append(data)
        }
        lineBuffer.flush()
    }
}

private final class ProcessPipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ data: Data) {
        lock.lock()
        value = data
        lock.unlock()
    }

    func append(_ data: Data) {
        lock.lock()
        value.append(data)
        lock.unlock()
    }
}

private struct BenchmarkProgressLineBuffer {
    private var pending = ""
    private let progressHandler: BenchmarkProgressEventHandler?

    init(progressHandler: BenchmarkProgressEventHandler?) {
        self.progressHandler = progressHandler
    }

    mutating func append(_ data: Data) {
        guard progressHandler != nil, let chunk = String(data: data, encoding: .utf8) else {
            return
        }
        pending.append(chunk)
        emitCompleteLines()
    }

    mutating func flush() {
        guard !pending.isEmpty else {
            return
        }
        emit(pending)
        pending.removeAll(keepingCapacity: true)
    }

    private mutating func emitCompleteLines() {
        while let newlineRange = pending.range(of: "\n") {
            let line = String(pending[..<newlineRange.lowerBound])
            pending.removeSubrange(pending.startIndex..<newlineRange.upperBound)
            emit(line)
        }
    }

    private func emit(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let event = try? BenchmarkProgressEventJSONDecoder.decode(trimmed) else {
            return
        }
        progressHandler?(event)
    }
}
