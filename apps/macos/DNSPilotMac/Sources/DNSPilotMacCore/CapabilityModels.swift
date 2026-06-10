public enum DNSPilotFlushCapability: Equatable {
    case guidedUserAction
    case desktopAdminService
    case linuxSystemResolverPolkit
    case unsupported
}

public enum DNSPilotApplyDisposition: Equatable {
    case allow
    case guideOnly
    case protectCurrentDNS
    case unsupported
}

public struct CapabilityRow: Equatable, Identifiable {
    public let platformID: String
    public let platformName: String
    public let canBenchmark: Bool
    public let applyDisposition: DNSPilotApplyDisposition
    public let flush: DNSPilotFlushCapability
    public let storeSafe: Bool
    public let notes: [String]

    public var id: String { platformID }

    public init(
        platformID: String,
        platformName: String,
        canBenchmark: Bool,
        applyDisposition: DNSPilotApplyDisposition,
        flush: DNSPilotFlushCapability,
        storeSafe: Bool,
        notes: [String]
    ) {
        self.platformID = platformID
        self.platformName = platformName
        self.canBenchmark = canBenchmark
        self.applyDisposition = applyDisposition
        self.flush = flush
        self.storeSafe = storeSafe
        self.notes = notes
    }
}
