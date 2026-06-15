import Foundation

public enum BenchmarkApplyPlanLoadOutcome: Equatable {
    case loaded(ApplyPlanViewModel)
    case failed(String)
}

public struct BenchmarkApplyPlanLoadCoordinator {
    private let loadPlan: (ApplyPlanRequest) throws -> ApplyPlan

    public init(_ loadPlan: @escaping (ApplyPlanRequest) throws -> ApplyPlan) {
        self.loadPlan = loadPlan
    }

    public init(runner: ApplyPlanRunner) {
        self.loadPlan = { request in
            try runner.load(request: request)
        }
    }

    public func load(
        for result: BenchmarkResultViewModel,
        platformID: String = "macos-store",
        profileDatabaseURL: URL? = nil,
        vpnActive: Bool = false,
        mdmProfileActive: Bool = false,
        corporateDNSDetected: Bool = false,
        captivePortalDetected: Bool = false
    ) -> BenchmarkApplyPlanLoadOutcome {
        let request = result.makeApplyPlanRequest(
            platformID: platformID,
            profileDatabaseURL: profileDatabaseURL,
            vpnActive: vpnActive,
            mdmProfileActive: mdmProfileActive,
            corporateDNSDetected: corporateDNSDetected,
            captivePortalDetected: captivePortalDetected
        )
        do {
            return .loaded(ApplyPlanViewModel(plan: try loadPlan(request)))
        } catch {
            return .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if case let ApplyPlanRunnerError.processFailed(message) = error {
            return message
        }
        return error.localizedDescription
    }
}
