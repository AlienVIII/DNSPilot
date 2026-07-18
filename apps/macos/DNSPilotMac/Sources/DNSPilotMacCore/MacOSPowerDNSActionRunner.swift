import Foundation
import Network

public enum MacOSPowerDNSActionRunnerError: Error, Equatable {
    case disabled
    case emptyDNSServers
    case unsafeDNSServer(String)
    case invalidRollbackCapture(String)
    case staleRollbackSnapshot
    case missingAppliedDNSState
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
        case .invalidRollbackCapture(let reason):
            "Could not safely capture current DNS for rollback: \(reason)"
        case .staleRollbackSnapshot:
            "The previous DNS snapshot is stale. Capture current DNS again before applying a resolver."
        case .missingAppliedDNSState:
            "The previous DNS snapshot cannot prove which DNS state DNS Pilot applied. Apply again before restoring."
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
    private let shellURL: URL
    private let processRunner: any BenchmarkProcessRunning
    private let maxRollbackAge: TimeInterval
    private let now: () -> Date

    public init(
        isEnabled: Bool = false,
        osascriptURL: URL = URL(fileURLWithPath: "/usr/bin/osascript"),
        shellURL: URL = URL(fileURLWithPath: "/bin/sh"),
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner(),
        maxRollbackAge: TimeInterval = 86_400,
        now: @escaping () -> Date = Date.init
    ) {
        self.isEnabled = isEnabled
        self.osascriptURL = osascriptURL
        self.shellURL = shellURL
        self.processRunner = processRunner
        self.maxRollbackAge = maxRollbackAge
        self.now = now
    }

    public static func fromEnvironment(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        osascriptURL: URL = URL(fileURLWithPath: "/usr/bin/osascript"),
        shellURL: URL = URL(fileURLWithPath: "/bin/sh"),
        processRunner: any BenchmarkProcessRunning = FoundationBenchmarkProcessRunner()
    ) -> MacOSPowerDNSActionRunner {
        MacOSPowerDNSActionRunner(
            isEnabled: MacOSPowerDNSActionConfiguration.isEnabled(environment: environment),
            osascriptURL: osascriptURL,
            shellURL: shellURL,
            processRunner: processRunner
        )
    }

    public func applyDNS(servers: [String]) throws -> PowerDNSRollbackSnapshot {
        try ensureEnabled()
        let sanitizedServers = try sanitizedDNSServers(servers)
        let rollbackSnapshot = try captureRollbackSnapshot()
        try runAdminShellScript(
            Self.applyShellScript(servers: sanitizedServers, rollbackSnapshot: rollbackSnapshot)
        )
        return PowerDNSRollbackSnapshot(
            service: rollbackSnapshot.service,
            mode: rollbackSnapshot.mode,
            servers: rollbackSnapshot.servers,
            appliedMode: .servers,
            appliedServers: sanitizedServers,
            createdAt: rollbackSnapshot.createdAt
        )
    }

    public func restoreDNS(snapshot: PowerDNSRollbackSnapshot) throws {
        try ensureEnabled()
        let sanitizedSnapshot = try sanitizedRollbackSnapshot(snapshot)
        try runAdminShellScript(Self.restoreShellScript(snapshot: sanitizedSnapshot))
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

    private func sanitizedRollbackSnapshot(
        _ snapshot: PowerDNSRollbackSnapshot
    ) throws -> PowerDNSRollbackSnapshot {
        guard snapshot.isFresh(now: now(), maxAge: maxRollbackAge) else {
            throw MacOSPowerDNSActionRunnerError.staleRollbackSnapshot
        }
        guard Self.isSafeServiceName(snapshot.service) else {
            throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("invalid network service")
        }
        guard let appliedMode = snapshot.appliedMode else {
            throw MacOSPowerDNSActionRunnerError.missingAppliedDNSState
        }

        switch snapshot.mode {
        case .automatic:
            guard snapshot.servers.isEmpty else {
                throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture(
                    "automatic DNS cannot include server addresses"
                )
            }
        case .servers:
            let servers = try sanitizedDNSServers(snapshot.servers)
            guard servers.count == snapshot.servers.count else {
                throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("empty DNS server")
            }
        }
        switch appliedMode {
        case .automatic:
            guard snapshot.appliedServers.isEmpty else {
                throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("automatic applied DNS cannot include server addresses")
            }
        case .servers:
            let servers = try sanitizedDNSServers(snapshot.appliedServers)
            guard servers.count == snapshot.appliedServers.count else {
                throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("empty applied DNS server")
            }
        }
        return snapshot
    }

    private func captureRollbackSnapshot() throws -> PowerDNSRollbackSnapshot {
        let output = try processRunner.run(
            executableURL: shellURL,
            arguments: ["-c", Self.captureRollbackShellScript],
            cancellation: nil
        )
        guard output.exitCode == 0 else {
            throw MacOSPowerDNSActionRunnerError.processFailed(Self.failureMessage(from: output))
        }
        return try Self.parseRollbackSnapshot(output.standardOutput, createdAt: now())
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
        IPv4Address(server) != nil || IPv6Address(server) != nil
    }

    private static func isSafeServiceName(_ service: String) -> Bool {
        !service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !service.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
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

    private static let rollbackProtocolStart = "DNSPILOT_ROLLBACK_V1"
    private static let rollbackProtocolEnd = "DNSPILOT_ROLLBACK_END"

    private static let activeServiceLookupShell = """
    export LC_ALL=C
    device="$(/sbin/route -n get default 2>/dev/null | /usr/bin/awk '/interface:/{print $2; exit}')"
    if [ -z "$device" ]; then echo "No default network interface found." >&2; exit 2; fi
    service="$(/usr/sbin/networksetup -listnetworkserviceorder | /usr/bin/awk -v dev="$device" '/^\\([0-9*]+\\) / { service=$0; sub(/^\\([0-9*]+\\) /, "", service) } /^\\(Hardware Port: / && index($0, "Device: " dev ")") { print service; exit }')"
    if [ -z "$service" ]; then echo "No macOS network service found for interface $device." >&2; exit 3; fi
    """

    private static let captureRollbackShellScript = """
    set -e
    \(activeServiceLookupShell)
    current_dns="$(/usr/sbin/networksetup -getdnsservers "$service")"
    printf '%s\\n' \(rollbackProtocolStart)
    printf 'service_b64=%s\\n' "$(printf '%s' "$service" | /usr/bin/base64 | /usr/bin/tr -d '\\n')"
    case "$current_dns" in
      "There aren't any DNS Servers set on "*)
        printf '%s\\n' 'mode=automatic'
        ;;
      *)
        if [ -z "$current_dns" ]; then echo "Current DNS server list is empty." >&2; exit 4; fi
        printf '%s\\n' 'mode=servers'
        printf '%s\\n' "$current_dns" | while IFS= read -r server; do
          if [ -z "$server" ]; then echo "Current DNS server list contains an empty entry." >&2; exit 5; fi
          printf 'server=%s\\n' "$server"
        done
        ;;
    esac
    printf '%s\\n' \(rollbackProtocolEnd)
    """

    private static func parseRollbackSnapshot(
        _ output: String,
        createdAt: Date
    ) throws -> PowerDNSRollbackSnapshot {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmedOutput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == rollbackProtocolStart, lines.last == rollbackProtocolEnd, lines.count >= 4 else {
            throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("missing protocol markers")
        }

        var encodedService: String?
        var mode: PowerDNSRollbackMode?
        var servers = [String]()

        for line in lines.dropFirst().dropLast() {
            if line.hasPrefix("service_b64=") {
                guard encodedService == nil else {
                    throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("duplicate network service")
                }
                encodedService = String(line.dropFirst("service_b64=".count))
            } else if line.hasPrefix("mode=") {
                guard mode == nil, let parsedMode = PowerDNSRollbackMode(rawValue: String(line.dropFirst("mode=".count))) else {
                    throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("invalid DNS mode")
                }
                mode = parsedMode
            } else if line.hasPrefix("server=") {
                let server = String(line.dropFirst("server=".count))
                guard isSafeDNSServer(server), !servers.contains(server) else {
                    throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("invalid DNS server")
                }
                servers.append(server)
            } else {
                throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("unknown capture field")
            }
        }

        guard let encodedService,
              let serviceData = Data(base64Encoded: encodedService),
              serviceData.base64EncodedString() == encodedService,
              let service = String(data: serviceData, encoding: .utf8),
              isSafeServiceName(service),
              let mode else {
            throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("invalid network service")
        }

        switch mode {
        case .automatic where !servers.isEmpty:
            throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("automatic DNS included server addresses")
        case .servers where servers.isEmpty:
            throw MacOSPowerDNSActionRunnerError.invalidRollbackCapture("manual DNS did not include server addresses")
        default:
            break
        }

        return PowerDNSRollbackSnapshot(
            service: service,
            mode: mode,
            servers: servers,
            createdAt: createdAt
        )
    }

    private static func applyShellScript(
        servers: [String],
        rollbackSnapshot: PowerDNSRollbackSnapshot
    ) -> String {
        let serverArguments = servers.map(shellQuoted).joined(separator: " ")
        let expectedConfigurationGuard: String
        switch rollbackSnapshot.mode {
        case .automatic:
            expectedConfigurationGuard = """
            current_dns="$(/usr/sbin/networksetup -getdnsservers "$service")"
            case "$current_dns" in
              "There aren't any DNS Servers set on "*) ;;
              *) echo "DNS configuration changed before apply." >&2; exit 5 ;;
            esac
            """
        case .servers:
            let expectedServerArguments = rollbackSnapshot.servers.map(shellQuoted).joined(separator: " ")
            expectedConfigurationGuard = """
            current_dns="$(/usr/sbin/networksetup -getdnsservers "$service")"
            expected_dns="$(/usr/bin/printf '%s\\n' \(expectedServerArguments))"
            if [ "$current_dns" != "$expected_dns" ]; then echo "DNS configuration changed before apply." >&2; exit 5; fi
            """
        }
        return """
        set -e
        \(activeServiceLookupShell)
        if [ "$service" != \(shellQuoted(rollbackSnapshot.service)) ]; then echo "Active network service changed before apply." >&2; exit 4; fi
        \(expectedConfigurationGuard)
        /usr/sbin/networksetup -setdnsservers "$service" \(serverArguments)
        \(flushShellScript)
        echo "Applied DNS to $service."
        """
    }

    private static func restoreShellScript(snapshot: PowerDNSRollbackSnapshot) -> String {
        let appliedConfigurationGuard: String
        switch snapshot.appliedMode {
        case .automatic:
            appliedConfigurationGuard = """
            current_dns="$(/usr/sbin/networksetup -getdnsservers "$service")"
            case "$current_dns" in
              "There aren't any DNS Servers set on "*) ;;
              *) echo "DNS configuration changed after apply; restore cancelled." >&2; exit 5 ;;
            esac
            """
        case .servers:
            let appliedServerArguments = snapshot.appliedServers.map(shellQuoted).joined(separator: " ")
            appliedConfigurationGuard = """
            current_dns="$(/usr/sbin/networksetup -getdnsservers "$service")"
            expected_dns="$(/usr/bin/printf '%s\\n' \(appliedServerArguments))"
            if [ "$current_dns" != "$expected_dns" ]; then echo "DNS configuration changed after apply; restore cancelled." >&2; exit 5; fi
            """
        case nil:
            return "exit 1"
        }
        let restoreCommand: String
        switch snapshot.mode {
        case .automatic:
            restoreCommand = "/usr/sbin/networksetup -setdnsservers \(shellQuoted(snapshot.service)) Empty"
        case .servers:
            let serverArguments = snapshot.servers.map(shellQuoted).joined(separator: " ")
            restoreCommand = "/usr/sbin/networksetup -setdnsservers \(shellQuoted(snapshot.service)) \(serverArguments)"
        }
        return """
        set -e
        \(activeServiceLookupShell)
        if [ "$service" != \(shellQuoted(snapshot.service)) ]; then echo "Active network service changed before restore." >&2; exit 4; fi
        \(appliedConfigurationGuard)
        \(restoreCommand)
        \(flushShellScript)
        echo "Restored DNS on $service."
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
