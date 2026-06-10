import Foundation

public enum CapabilityMatrixJSONDecoderError: Error, Equatable, LocalizedError {
    case unknownApply(String, platform: String)
    case unknownFlush(String, platform: String)

    public var errorDescription: String? {
        switch self {
        case let .unknownApply(value, platform):
            "Unknown apply capability '\(value)' for \(platform)."
        case let .unknownFlush(value, platform):
            "Unknown flush capability '\(value)' for \(platform)."
        }
    }
}

public struct CapabilityMatrixJSONDecoder {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func decode(_ data: Data) throws -> [CapabilityRow] {
        let payload = try decoder.decode(CapabilitiesPayload.self, from: data)
        try ShellPayloadSchema.validate(payload.schemaVersion)
        return try payload.capabilities.map(Self.map)
    }

    private static func map(_ entry: CapabilityEntry) throws -> CapabilityRow {
        CapabilityRow(
            platformID: entry.platform,
            platformName: platformName(for: entry.platform),
            canBenchmark: entry.canBenchmark,
            applyDisposition: try applyDisposition(for: entry.apply, platform: entry.platform),
            flush: try flushCapability(for: entry.flush, platform: entry.platform),
            storeSafe: entry.storeSafe,
            notes: entry.notes
        )
    }

    private static func applyDisposition(for value: String, platform: String) throws -> DNSPilotApplyDisposition {
        switch value {
        case "apple-network-extension-dns-settings",
             "desktop-admin-service",
             "linux-network-manager-polkit":
            .allow
        case "guided-settings":
            .guideOnly
        case "unsupported":
            .unsupported
        default:
            throw CapabilityMatrixJSONDecoderError.unknownApply(value, platform: platform)
        }
    }

    private static func flushCapability(for value: String, platform: String) throws -> DNSPilotFlushCapability {
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
            throw CapabilityMatrixJSONDecoderError.unknownFlush(value, platform: platform)
        }
    }

    private static func platformName(for platformID: String) -> String {
        let knownNames = [
            "macos-store": "macOS Store",
            "ios": "iOS / iPadOS",
            "android-play": "Android Play",
            "windows-store": "Windows Store",
            "linux-flatpak": "Linux Flatpak",
            "linux-snap": "Linux Snap",
            "linux-native-power": "Linux Native Power",
            "macos-power": "macOS Power",
            "windows-power": "Windows Power",
        ]
        if let knownName = knownNames[platformID] {
            return knownName
        }

        return platformID
            .split(separator: "-")
            .map { part in
                switch part {
                case "ios":
                    "iOS"
                case "macos":
                    "macOS"
                default:
                    part.capitalized
                }
            }
            .joined(separator: " ")
    }
}

public struct CapabilityMatrixJSONBridge: DNSPilotCoreBridge {
    private let loadData: () throws -> Data
    private let decoder: CapabilityMatrixJSONDecoder

    public init(data: Data, decoder: CapabilityMatrixJSONDecoder = CapabilityMatrixJSONDecoder()) {
        self.loadData = { data }
        self.decoder = decoder
    }

    public init(
        decoder: CapabilityMatrixJSONDecoder = CapabilityMatrixJSONDecoder(),
        loadData: @escaping () throws -> Data
    ) {
        self.loadData = loadData
        self.decoder = decoder
    }

    public func loadCapabilities() throws -> [CapabilityRow] {
        try decoder.decode(loadData())
    }
}

private struct CapabilitiesPayload: Decodable {
    let schemaVersion: Int
    let capabilities: [CapabilityEntry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case capabilities
    }
}

private struct CapabilityEntry: Decodable {
    let platform: String
    let apply: String
    let canBenchmark: Bool
    let flush: String
    let notes: [String]
    let storeSafe: Bool

    private enum CodingKeys: String, CodingKey {
        case platform
        case apply
        case canBenchmark = "can_benchmark"
        case flush
        case notes
        case storeSafe = "store_safe"
    }
}
