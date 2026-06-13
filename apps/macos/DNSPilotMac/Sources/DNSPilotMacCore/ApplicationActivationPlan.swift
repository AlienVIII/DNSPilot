public enum DNSPilotApplicationActivationAction: Equatable, Sendable {
    case setRegularActivationPolicy
    case activateIgnoringOtherApps
    case ensureMainWindowVisible(delayMilliseconds: Int)
}

public struct DNSPilotApplicationActivationPlan: Equatable, Sendable {
    public let actions: [DNSPilotApplicationActivationAction]

    public init(actions: [DNSPilotApplicationActivationAction]) {
        self.actions = actions
    }

    public static let launch = DNSPilotApplicationActivationPlan(
        actions: [
            .setRegularActivationPolicy,
            .activateIgnoringOtherApps,
            .ensureMainWindowVisible(delayMilliseconds: 200),
        ]
    )
}
