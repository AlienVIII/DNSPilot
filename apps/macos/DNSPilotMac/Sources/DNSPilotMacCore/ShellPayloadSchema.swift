import Foundation

public enum ShellPayloadSchema {
    public static let supportedVersion = 1

    public static func validate(_ version: Int) throws {
        guard version == supportedVersion else {
            throw ShellPayloadSchemaError.unsupportedVersion(version, supported: supportedVersion)
        }
    }
}

public enum ShellPayloadSchemaError: Error, Equatable, LocalizedError {
    case unsupportedVersion(Int, supported: Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version, supported):
            "Unsupported shell payload schema version \(version); expected \(supported)."
        }
    }
}
