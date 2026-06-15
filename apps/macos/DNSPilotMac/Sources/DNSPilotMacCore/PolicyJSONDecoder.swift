import Foundation

public enum PolicyJSONDecoderError: Error, Equatable, LocalizedError {
    case unknownScope(String)
    case unknownFlushCapability(String)
    case unknownFlushRequirement(String)
    case unknownApplyCapability(String)
    case unknownApplyDisposition(String)
    case unknownApplyPlanDisposition(String)

    public var errorDescription: String? {
        switch self {
        case let .unknownScope(value):
            "Unknown preflight scope '\(value)'."
        case let .unknownFlushCapability(value):
            "Unknown flush capability '\(value)'."
        case let .unknownFlushRequirement(value):
            "Unknown flush requirement '\(value)'."
        case let .unknownApplyCapability(value):
            "Unknown apply capability '\(value)'."
        case let .unknownApplyDisposition(value):
            "Unknown apply disposition '\(value)'."
        case let .unknownApplyPlanDisposition(value):
            "Unknown apply-plan disposition '\(value)'."
        }
    }
}

public struct PreflightJSONDecoder {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func decode(_ data: Data) throws -> PreflightPolicy {
        let payload = try decoder.decode(PreflightPayload.self, from: data)
        try ShellPayloadSchema.validate(payload.schemaVersion)
        return try PreflightPolicy(
            platformID: payload.platform,
            scope: Self.scope(for: payload.scope),
            flushCapability: Self.flushCapability(for: payload.flushCapability),
            flushRequirement: Self.flushRequirement(for: payload.flushRequirement),
            notes: payload.notes
        )
    }

    private static func scope(for value: String) throws -> DNSPilotPreflightScope {
        switch value {
        case "direct-resolver-benchmark":
            .directResolverBenchmark
        case "system-dns-validation":
            .systemDNSValidation
        default:
            throw PolicyJSONDecoderError.unknownScope(value)
        }
    }

    private static func flushCapability(for value: String) throws -> DNSPilotFlushCapability {
        switch value {
        case "guided-user-action":
            .guidedUserAction
        case "desktop-admin-service":
            .desktopAdminService
        case "linux-system-resolver-polkit":
            .linuxSystemResolverPolkit
        case "unsupported":
            .unsupported
        default:
            throw PolicyJSONDecoderError.unknownFlushCapability(value)
        }
    }

    private static func flushRequirement(for value: String) throws -> DNSPilotFlushRequirement {
        switch value {
        case "not-needed":
            .notNeeded
        case "recommended-before-test":
            .recommendedBeforeTest
        case "recommended-but-unsupported":
            .recommendedButUnsupported
        default:
            throw PolicyJSONDecoderError.unknownFlushRequirement(value)
        }
    }
}

public struct ApplyPolicyJSONDecoder {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func decode(_ data: Data) throws -> ApplyPolicy {
        let payload = try decoder.decode(ApplyPolicyPayload.self, from: data)
        try ShellPayloadSchema.validate(payload.schemaVersion)
        return try ApplyPolicy(
            platformID: payload.platform,
            applyCapability: Self.applyCapability(for: payload.applyCapability),
            disposition: Self.disposition(for: payload.disposition),
            canPromptApply: payload.canPromptApply,
            notes: payload.notes
        )
    }

    private static func applyCapability(for value: String) throws -> DNSPilotApplyCapability {
        switch value {
        case "apple-network-extension-dns-settings":
            .appleNetworkExtensionDNSSettings
        case "guided-settings":
            .guidedSettings
        case "android-vpn-service":
            .androidVPNService
        case "linux-network-manager-polkit":
            .linuxNetworkManagerPolkit
        case "desktop-admin-service":
            .desktopAdminService
        case "unsupported":
            .unsupported
        default:
            throw PolicyJSONDecoderError.unknownApplyCapability(value)
        }
    }

    private static func disposition(for value: String) throws -> DNSPilotApplyDisposition {
        switch value {
        case "allow":
            .allow
        case "guide-only":
            .guideOnly
        case "protect-current-dns":
            .protectCurrentDNS
        case "unsupported":
            .unsupported
        default:
            throw PolicyJSONDecoderError.unknownApplyDisposition(value)
        }
    }
}

public struct ApplyPlanJSONDecoder {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func decode(_ data: Data) throws -> ApplyPlan {
        let payload = try decoder.decode(ApplyPlanPayload.self, from: data)
        try ShellPayloadSchema.validate(payload.schemaVersion)
        return try ApplyPlan(
            platformID: payload.platform,
            applyCapability: Self.applyCapability(for: payload.applyCapability),
            disposition: Self.disposition(for: payload.disposition),
            profileID: payload.profileID,
            profileName: payload.profileName,
            dnsServers: payload.dnsServers,
            canApply: payload.canApply,
            notes: payload.notes
        )
    }

    private static func applyCapability(for value: String) throws -> DNSPilotApplyCapability {
        switch value {
        case "apple-network-extension-dns-settings":
            .appleNetworkExtensionDNSSettings
        case "guided-settings":
            .guidedSettings
        case "android-vpn-service":
            .androidVPNService
        case "linux-network-manager-polkit":
            .linuxNetworkManagerPolkit
        case "desktop-admin-service":
            .desktopAdminService
        case "unsupported":
            .unsupported
        default:
            throw PolicyJSONDecoderError.unknownApplyCapability(value)
        }
    }

    private static func disposition(for value: String) throws -> DNSPilotApplyPlanDisposition {
        switch value {
        case "apply-with-user-approval":
            .applyWithUserApproval
        case "guide-only":
            .guideOnly
        case "protect-current-dns":
            .protectCurrentDNS
        case "unsupported":
            .unsupported
        case "not-recommended":
            .notRecommended
        default:
            throw PolicyJSONDecoderError.unknownApplyPlanDisposition(value)
        }
    }
}

private struct PreflightPayload: Decodable {
    let schemaVersion: Int
    let platform: String
    let scope: String
    let flushCapability: String
    let flushRequirement: String
    let notes: [String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case platform
        case scope
        case flushCapability = "flush_capability"
        case flushRequirement = "flush_requirement"
        case notes
    }
}

private struct ApplyPolicyPayload: Decodable {
    let schemaVersion: Int
    let platform: String
    let applyCapability: String
    let disposition: String
    let canPromptApply: Bool
    let notes: [String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case platform
        case applyCapability = "apply_capability"
        case disposition
        case canPromptApply = "can_prompt_apply"
        case notes
    }
}

private struct ApplyPlanPayload: Decodable {
    let schemaVersion: Int
    let platform: String
    let applyCapability: String
    let disposition: String
    let profileID: String?
    let profileName: String?
    let dnsServers: [String]
    let canApply: Bool
    let notes: [String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case platform
        case applyCapability = "apply_capability"
        case disposition
        case profileID = "profile_id"
        case profileName = "profile_name"
        case dnsServers = "dns_servers"
        case canApply = "can_apply"
        case notes
    }
}
