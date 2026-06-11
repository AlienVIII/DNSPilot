public enum DNSPilotPreflightScope: Equatable {
    case directResolverBenchmark
    case systemDNSValidation
}

public enum DNSPilotFlushRequirement: Equatable {
    case notNeeded
    case recommendedBeforeTest
    case recommendedButUnsupported
}

public enum DNSPilotApplyCapability: Equatable {
    case appleNetworkExtensionDNSSettings
    case guidedSettings
    case androidVPNService
    case linuxNetworkManagerPolkit
    case desktopAdminService
    case unsupported
}

public struct PreflightPolicy: Equatable {
    public let platformID: String
    public let scope: DNSPilotPreflightScope
    public let flushCapability: DNSPilotFlushCapability
    public let flushRequirement: DNSPilotFlushRequirement
    public let notes: [String]

    public init(
        platformID: String,
        scope: DNSPilotPreflightScope,
        flushCapability: DNSPilotFlushCapability,
        flushRequirement: DNSPilotFlushRequirement,
        notes: [String]
    ) {
        self.platformID = platformID
        self.scope = scope
        self.flushCapability = flushCapability
        self.flushRequirement = flushRequirement
        self.notes = notes
    }
}

public struct ApplyPolicy: Equatable {
    public let platformID: String
    public let applyCapability: DNSPilotApplyCapability
    public let disposition: DNSPilotApplyDisposition
    public let canPromptApply: Bool
    public let notes: [String]

    public init(
        platformID: String,
        applyCapability: DNSPilotApplyCapability,
        disposition: DNSPilotApplyDisposition,
        canPromptApply: Bool,
        notes: [String]
    ) {
        self.platformID = platformID
        self.applyCapability = applyCapability
        self.disposition = disposition
        self.canPromptApply = canPromptApply
        self.notes = notes
    }
}
