import Foundation

public enum BenchmarkHistoryLoadOutcome: Equatable {
    case loaded(BenchmarkHistoryViewModel)
    case failed(String)
}

public struct BenchmarkHistoryLoadCoordinator {
    private let runner: BenchmarkHistoryRunner
    private let catalog: CatalogSnapshot

    public init(runner: BenchmarkHistoryRunner, catalog: CatalogSnapshot) {
        self.runner = runner
        self.catalog = catalog
    }

    public func load(databaseURL: URL) -> BenchmarkHistoryLoadOutcome {
        do {
            let payload = try runner.load(databaseURL: databaseURL)
            return .loaded(BenchmarkHistoryViewModel(payload: payload, catalog: catalog))
        } catch BenchmarkHistoryRunnerError.processFailed(let message) {
            return .failed(message)
        } catch is DecodingError {
            return .failed("Could not parse benchmark history.")
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
