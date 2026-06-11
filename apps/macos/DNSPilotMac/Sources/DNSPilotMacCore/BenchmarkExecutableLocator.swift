import Foundation

public enum BenchmarkExecutableSource: Equatable {
    case environmentOverride
    case bundleResource
}

public enum BenchmarkExecutableLocation: Equatable {
    case found(URL, source: BenchmarkExecutableSource)
    case missing(String)
}

public struct BenchmarkExecutableLocator {
    private let environment: [String: String]
    private let bundledExecutablePath: String?

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundledExecutablePath: String? = Bundle.main.path(forResource: "dnspilot-cli", ofType: nil)
    ) {
        self.environment = environment
        self.bundledExecutablePath = bundledExecutablePath
    }

    public func locate() -> BenchmarkExecutableLocation {
        if let override = nonEmptyPath(environment["DNSPILOT_CLI_PATH"]) {
            return .found(URL(fileURLWithPath: override), source: .environmentOverride)
        }

        if let bundledExecutablePath = nonEmptyPath(bundledExecutablePath) {
            return .found(URL(fileURLWithPath: bundledExecutablePath), source: .bundleResource)
        }

        return .missing(
            "DNS Pilot CLI executable is not bundled. Set DNSPILOT_CLI_PATH for development builds."
        )
    }

    private func nonEmptyPath(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
