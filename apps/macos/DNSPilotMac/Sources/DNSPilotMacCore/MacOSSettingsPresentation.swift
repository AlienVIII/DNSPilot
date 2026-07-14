public struct MacOSSettingsPresentation: Equatable, Sendable {
    public let isPowerBuild: Bool

    public init(isPowerBuild: Bool) {
        self.isPowerBuild = isPowerBuild
    }

    public var showsPowerActions: Bool {
        isPowerBuild
    }
}
