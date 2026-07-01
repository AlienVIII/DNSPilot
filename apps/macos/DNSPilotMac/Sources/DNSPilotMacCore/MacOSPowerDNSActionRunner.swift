import Foundation

public enum MacOSPowerDNSActionRunnerError: Error, Equatable {
    case disabled
    case emptyDNSServers
    case unsafeDNSServer(String)
    case processFailed(String)
}

extension MacOSPowerDNSActionRunnerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .disabled:
            "Power DNS actions are disabled for this build."
        case .emptyDNSServers:
            "No DNS servers were provided."
        case .unsafeDNSServer(let server):
            "Unsafe DNS server value: \(server)"
        case .processFailed(let message):
            message
        }
    }
}

public enum MacOSPowerDNSActionConfiguration {
    public static let environmentFlag = "DNSPILOT_ENABLE_POWER_ACTIONS"
    public static let bundleInfoKey = "DNSPilotPowerActionsEnabled"
    public static let userDefaultsKey = "DNSPilotDirectAdminActionsEnabled"

    public static func isBuildCapable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfoValue: Any? = Bundle.main.object(forInfoDictionaryKey: bundleInfoKey)
    ) -> Bool {
        if let environmentValue = environment[environmentFlag] {
            return isTruthy(environmentValue)
        }
        return isTruthy(bundleInfoValue)
    }

    public static func isForcedEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let environmentValue = environment[environmentFlag] else {
            return false
        }
        return isTruthy(environmentValue)
    }

    public static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfoValue: Any? = Bundle.main.object(forInfoDictionaryKey: bundleInfoKey),
        userDefaultValue: Bool = UserDefaults.standard.bool(forKey: userDefaultsKey)
    ) -> Bool {
        if let environmentValue = environment[environmentFlag] {
            return isTruthy(environmentValue)
        }
        guard isBuildCapable(environment: environment, bundleInfoValue: bundleInfoValue) else {
            return false
        }
        return userDefaultValue
    }

    private static func isTruthy(_ value: Any?) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }
        guard let stringValue = value as? String else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(
            stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }
}

public struct MacOSPowerDNSActionRunner {
    private let isEnabled: Bool
    private let osascriptURL: URL
    private let processRunner: any BenchmarkProcessRunning

    public init(
        isEnabled: Bool = false,
        osascriptURL: URL = URL(fileURLWithPath: "/usr/bin/osascript"),
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) {
        self.isEnabled = isEnabled
        self.osascriptURL = osascriptURL
        self.processRunner = processRunner
    }

    public static func fromEnvironment(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        osascriptURL: URL = URL(fileURLWithPath: "/usr/bin/osascript"),
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) -> MacOSPowerDNSActionRunner {
        MacOSPowerDNSActionRunner(
            isEnabled: MacOSPowerDNSActionConfiguration.isEnabled(environment: environment),
            osascriptURL: osascriptURL,
            processRunner: processRunner
        )
    }

    public func applyDNS(servers: [String]) throws {
        try ensureEnabled()
        let sanitizedServers = try sanitizedDNSServers(servers)
        try runAdminShellScript(Self.applyShellScript(servers: sanitizedServers))
    }

    public func flushDNS() throws {
        try ensureEnabled()
        try runAdminShellScript(Self.flushShellScript)
    }

    private func ensureEnabled() throws {
        guard isEnabled else {
            throw MacOSPowerDNSActionRunnerError.disabled
        }
    }

    private func sanitizedDNSServers(_ servers: [String]) throws -> [String] {
        let sanitized = servers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !sanitized.isEmpty else {
            throw MacOSPowerDNSActionRunnerError.emptyDNSServers
        }

        for server in sanitized where !Self.isSafeDNSServer(server) {
            throw MacOSPowerDNSActionRunnerError.unsafeDNSServer(server)
        }
        return sanitized
    }

    private func runAdminShellScript(_ shellScript: String) throws {
        let output = try processRunner.run(
            executableURL: osascriptURL,
            arguments: ["-e", Self.appleScript(shellScript: shellScript)],
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw MacOSPowerDNSActionRunnerError.processFailed(Self.failureMessage(from: output))
        }
    }

    private static func isSafeDNSServer(_ server: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789:.%-")
        return server.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func appleScript(shellScript: String) -> String {
        "do shell script \"\(appleScriptEscaped(shellScript))\" with administrator privileges"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func applyShellScript(servers: [String]) -> String {
        let serverArguments = servers.map(shellQuoted).joined(separator: " ")
        return """
        set -e
        device="$(/sbin/route -n get default 2>/dev/null | /usr/bin/awk '/interface:/{print $2; exit}')"
        if [ -z "$device" ]; then echo "No default network interface found." >&2; exit 2; fi
        service="$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk -v dev="$device" '/^Hardware Port: / { port=substr($0, 16) } /^Device: / && substr($0, 9) == dev { print port; exit }')"
        if [ -z "$service" ]; then echo "No macOS network service found for interface $device." >&2; exit 3; fi
        /usr/sbin/networksetup -setdnsservers "$service" \(serverArguments)
        \(flushShellScript)
        echo "Applied DNS to $service."
        """
    }

    private static let flushShellScript = """
    set -e
    /usr/bin/dscacheutil -flushcache
    /usr/bin/killall -HUP mDNSResponder
    echo "Flushed macOS DNS cache."
    """

    private static func failureMessage(from output: BenchmarkProcessOutput) -> String {
        let standardError = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardError.isEmpty {
            return standardError
        }

        let standardOutput = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !standardOutput.isEmpty {
            return standardOutput
        }

        return "Power DNS action exited with code \(output.exitCode)."
    }
}
