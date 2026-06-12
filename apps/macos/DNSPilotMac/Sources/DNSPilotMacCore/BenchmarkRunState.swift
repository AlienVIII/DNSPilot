public struct BenchmarkRunID: Equatable, Hashable, Sendable {
    private let value: Int

    public init(_ value: Int) {
        self.value = value
    }
}

public enum BenchmarkRunState: Equatable, Sendable {
    case idle
    case running(runID: BenchmarkRunID)
    case cancelling(runID: BenchmarkRunID)
    case completed
    case cancelled
    case failed(String)
}

public struct BenchmarkRunStateMachine: Equatable, Sendable {
    public private(set) var state: BenchmarkRunState
    private var nextID: Int

    public init(state: BenchmarkRunState = .idle, nextID: Int = 1) {
        self.state = state
        self.nextID = nextID
    }

    @discardableResult
    public mutating func start() -> BenchmarkRunID {
        let runID = BenchmarkRunID(nextID)
        nextID += 1
        state = .running(runID: runID)
        return runID
    }

    public mutating func requestCancel(runID: BenchmarkRunID) {
        guard state == .running(runID: runID) else {
            return
        }
        state = .cancelling(runID: runID)
    }

    public mutating func finishCompleted(runID: BenchmarkRunID) {
        guard state == .running(runID: runID) else {
            return
        }
        state = .completed
    }

    public mutating func finishCancelled(runID: BenchmarkRunID) {
        guard state == .running(runID: runID) || state == .cancelling(runID: runID) else {
            return
        }
        state = .cancelled
    }

    public mutating func finishFailed(runID: BenchmarkRunID, message: String) {
        guard state == .running(runID: runID) else {
            return
        }
        state = .failed(message)
    }
}
