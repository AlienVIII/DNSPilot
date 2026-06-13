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
        cancellation: BenchmarkRunCancellation? = nil,
        progressHandler: BenchmarkProgressEventHandler? = nil
    ) -> BenchmarkExecutionOutcome {
        do {
            let runResult = try runner.run(
                plan: plan,
                persistence: persistence,
                cancellation: cancellation,
                progressHandler: progressHandler
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
                if let failure = Self.benchmarkPayloadFailure(from: payload, result: runResult) {
                    Self.logger.error(
                        "Benchmark payload reported failed health primary_issue=\(payload.summary.primaryIssue, privacy: .public)"
                    )
                    return .failed(failure)
                }
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

    private static func benchmarkPayloadFailure(
        from payload: BenchmarkResultPayload,
        result: BenchmarkRunResult
    ) -> BenchmarkExecutionFailure? {
        guard payload.summary.health == .failed else {
            return nil
        }

        return BenchmarkExecutionFailure(
            message: failedPayloadMessage(for: payload.summary),
            failedStep: failedPayloadStep(for: payload.summary),
            debugLog: debugLog(from: result)
        )
    }

    private static func failedPayloadMessage(for summary: BenchmarkResultSummary) -> String {
        switch (summary.measurementScope, summary.primaryIssue) {
        case (.dnsOnly, "all-resolvers-failed"):
            "DNS lookup failed for all selected resolvers."
        case (_, "all-resolvers-failed"):
            "Benchmark failed for all selected resolvers."
        default:
            summary.safetyNotes.first ?? "Benchmark failed: \(summary.primaryIssue)."
        }
    }

    private static func failedPayloadStep(for summary: BenchmarkResultSummary) -> BenchmarkFailureStep {
        switch summary.measurementScope {
        case .dnsOnly:
            return .resolvingDNS
        case .dnsTCP, .dnsTCPTLS:
            if summary.primaryIssue.contains("dns") {
                return .resolvingDNS
            }
            return .measuringConnection
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
        let standardError = userFacingProcessText(result.standardError)
        if !standardError.isEmpty {
            return standardError
        }

        let standardOutput = userFacingProcessText(result.standardOutput)
        if !standardOutput.isEmpty {
            return standardOutput
        }

        return "Benchmark command exited with code \(result.exitCode)."
    }

    private static func userFacingProcessText(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !isProgressEventJSONLine($0) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isProgressEventJSONLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.hasPrefix("{"), trimmedLine.contains("\"type\"") else {
            return false
        }
        return (try? BenchmarkProgressEventJSONDecoder.decode(trimmedLine)) != nil
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
