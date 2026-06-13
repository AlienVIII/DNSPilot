import Foundation
import OSLog

public enum BenchmarkExecutionOutcome: Equatable {
    case completed(BenchmarkResultViewModel)
    case failed(BenchmarkExecutionFailure)
}

public struct BenchmarkExecutionCoordinator {
    private let runner: BenchmarkRunner
    private let catalog: CatalogSnapshot
    private static let logger = Logger(subsystem: "com.dnspilot.mac", category: "benchmark")

    public init(runner: BenchmarkRunner, catalog: CatalogSnapshot) {
        self.runner = runner
        self.catalog = catalog
    }

    public func execute(
        plan: BenchmarkPlanViewModel,
        persistence: BenchmarkHistoryPersistence? = nil,
        cancellation: BenchmarkRunCancellation? = nil
    ) -> BenchmarkExecutionOutcome {
        do {
            let runResult = try runner.run(
                plan: plan,
                persistence: persistence,
                cancellation: cancellation
            )
            Self.logger.info(
                "Benchmark process finished exit=\(runResult.exitCode, privacy: .public) stdout_bytes=\(runResult.standardOutput.utf8.count, privacy: .public) stderr_bytes=\(runResult.standardError.utf8.count, privacy: .public) args=\(runResult.commandArguments.joined(separator: " "), privacy: .private)"
            )
            guard runResult.succeeded else {
                Self.logger.error("Benchmark process failed exit=\(runResult.exitCode, privacy: .public)")
                return .failed(
                    BenchmarkExecutionFailure(
                        message: Self.processFailureMessage(from: runResult),
                        failedStep: Self.processFailureStep(for: plan.mode),
                        debugLog: Self.debugLog(from: runResult)
                    )
                )
            }

            do {
                let payload = try BenchmarkResultJSONDecoder.decode(runResult.standardOutput)
                return .completed(BenchmarkResultViewModel(result: payload, catalog: catalog))
            } catch {
                let parseError = Self.parseErrorDescription(error)
                Self.logger.error("Benchmark result parse failed: \(parseError, privacy: .public)")
                return .failed(
                    BenchmarkExecutionFailure(
                        message: "Could not parse benchmark result: \(parseError)",
                        failedStep: .parsingResult,
                        debugLog: Self.debugLog(from: runResult, parseError: parseError)
                    )
                )
            }
        } catch BenchmarkRunnerError.invalidPlan(let issues) {
            let message = issues.joined(separator: "\n")
            return .failed(
                BenchmarkExecutionFailure(
                    message: message,
                    failedStep: .preparingBenchmark,
                    debugLog: message
                )
            )
        } catch {
            return .failed(
                BenchmarkExecutionFailure(
                    message: error.localizedDescription,
                    failedStep: .preparingBenchmark,
                    debugLog: error.localizedDescription
                )
            )
        }
    }

    private static func processFailureStep(for mode: BenchmarkPlanMode) -> BenchmarkFailureStep {
        switch mode {
        case .dnsOnlyCompare:
            .resolvingDNS
        case .connectionPathCompare:
            .measuringConnection
        }
    }

    private static func processFailureMessage(from result: BenchmarkRunResult) -> String {
        let standardError = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardError.isEmpty {
            return standardError
        }

        let standardOutput = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardOutput.isEmpty {
            return standardOutput
        }

        return "Benchmark command exited with code \(result.exitCode)."
    }

    private static func debugLog(from result: BenchmarkRunResult, parseError: String? = nil) -> String {
        var sections: [String] = []
        if let parseError {
            sections.append("parse_error:\n\(parseError)")
        }
        sections.append("exit code: \(result.exitCode)")
        let standardError = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardError.isEmpty {
            sections.append("stderr:\n\(standardError)")
        }
        let standardOutput = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardOutput.isEmpty {
            sections.append("stdout:\n\(standardOutput)")
        }
        sections.append("arguments:\n\(result.commandArguments.joined(separator: " "))")
        return sections.joined(separator: "\n\n")
    }

    private static func parseErrorDescription(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case .dataCorrupted(let context):
            return "data corrupted at \(codingPathDescription(context.codingPath)) - \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at \(codingPathDescription(context.codingPath)) - \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "type mismatch at \(codingPathDescription(context.codingPath)) - expected \(type) - \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "missing value at \(codingPathDescription(context.codingPath)) - expected \(type) - \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private static func codingPathDescription(_ codingPath: [any CodingKey]) -> String {
        guard !codingPath.isEmpty else {
            return "root"
        }
        return codingPath.map(\.stringValue).joined(separator: ".")
    }
}
