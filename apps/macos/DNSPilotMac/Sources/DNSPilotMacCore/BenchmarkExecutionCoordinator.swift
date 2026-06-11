import Foundation

public enum BenchmarkExecutionOutcome: Equatable {
    case completed(BenchmarkResultViewModel)
    case failed(String)
}

public struct BenchmarkExecutionCoordinator {
    private let runner: BenchmarkRunner
    private let catalog: CatalogSnapshot

    public init(runner: BenchmarkRunner, catalog: CatalogSnapshot) {
        self.runner = runner
        self.catalog = catalog
    }

    public func execute(plan: BenchmarkPlanViewModel) -> BenchmarkExecutionOutcome {
        do {
            let runResult = try runner.run(plan: plan)
            guard runResult.succeeded else {
                return .failed(Self.processFailureMessage(from: runResult))
            }

            let payload = try BenchmarkResultJSONDecoder.decode(runResult.standardOutput)
            return .completed(BenchmarkResultViewModel(result: payload, catalog: catalog))
        } catch BenchmarkRunnerError.invalidPlan(let issues) {
            return .failed(issues.joined(separator: "\n"))
        } catch is DecodingError {
            return .failed("Could not parse benchmark result.")
        } catch {
            return .failed(error.localizedDescription)
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
}
