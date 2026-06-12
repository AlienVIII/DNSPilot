import Foundation

public enum BenchmarkExecutionOutcome: Equatable {
    case completed(BenchmarkResultViewModel)
    case failed(BenchmarkExecutionFailure)
}

public struct BenchmarkExecutionCoordinator {
    private let runner: BenchmarkRunner
    private let catalog: CatalogSnapshot

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
            guard runResult.succeeded else {
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
            } catch is DecodingError {
                return .failed(
                    BenchmarkExecutionFailure(
                        message: "Could not parse benchmark result.",
                        failedStep: .parsingResult,
                        debugLog: Self.debugLog(from: runResult)
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

    private static func debugLog(from result: BenchmarkRunResult) -> String {
        var sections = ["exit code: \(result.exitCode)"]
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
}
