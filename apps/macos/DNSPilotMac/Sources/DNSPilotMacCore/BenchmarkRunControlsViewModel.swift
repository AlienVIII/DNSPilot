public struct BenchmarkRunControlsViewModel: Equatable, Sendable {
    public let primaryLabel: String
    public let isPrimaryEnabled: Bool
    public let showsCancel: Bool
    public let isCancelEnabled: Bool

    public init(state: BenchmarkRunState, setupCanRun: Bool) {
        switch state {
        case .idle, .completed, .cancelled, .failed:
            primaryLabel = "Run"
            isPrimaryEnabled = setupCanRun
            showsCancel = false
            isCancelEnabled = false
        case .running:
            primaryLabel = "Running"
            isPrimaryEnabled = false
            showsCancel = true
            isCancelEnabled = true
        case .cancelling:
            primaryLabel = "Cancelling"
            isPrimaryEnabled = false
            showsCancel = true
            isCancelEnabled = false
        }
    }
}
