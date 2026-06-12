import Foundation
import Network

public struct CustomDNSProfileFormViewModel: Equatable, Sendable {
    public let name: String
    public let ipv4ServersText: String
    public let ipv6ServersText: String
    public let profileID: String
    public let ipv4Servers: [String]
    public let ipv6Servers: [String]
    public let issues: [String]

    public var canSave: Bool {
        issues.isEmpty
    }

    public init(
        name: String,
        ipv4ServersText: String,
        ipv6ServersText: String
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ipv4ServersText = ipv4ServersText
        self.ipv6ServersText = ipv6ServersText
        profileID = Self.makeProfileID(from: name)

        let ipv4Tokens = Self.tokens(from: ipv4ServersText)
        let ipv6Tokens = Self.tokens(from: ipv6ServersText)
        let ipv4Result = Self.validate(tokens: ipv4Tokens, family: .ipv4)
        let ipv6Result = Self.validate(tokens: ipv6Tokens, family: .ipv6)
        ipv4Servers = ipv4Result.servers
        ipv6Servers = ipv6Result.servers

        var nextIssues: [String] = []
        if self.name.isEmpty {
            nextIssues.append("Name is required.")
        }
        nextIssues += ipv4Result.issues
        nextIssues += ipv6Result.issues
        if ipv4Tokens.isEmpty, ipv6Tokens.isEmpty {
            nextIssues.append("Add at least one IPv4 or IPv6 DNS server.")
        }
        issues = nextIssues
    }

    public func profileAddArguments(databaseURL: URL) -> [String] {
        var args = [
            "profile-add",
            "--db", databaseURL.path,
            "--id", profileID,
            "--name", name,
        ]
        for server in ipv4Servers {
            args += ["--ipv4", server]
        }
        for server in ipv6Servers {
            args += ["--ipv6", server]
        }
        args += ["--tag", "custom"]
        return args
    }

    private enum AddressFamily {
        case ipv4
        case ipv6

        var label: String {
            switch self {
            case .ipv4:
                "IPv4"
            case .ipv6:
                "IPv6"
            }
        }
    }

    private struct ValidationResult {
        let servers: [String]
        let issues: [String]
    }

    private static func tokens(from text: String) -> [String] {
        text.split { character in
            character.isWhitespace || character == ","
        }
        .map(String.init)
    }

    private static func validate(tokens: [String], family: AddressFamily) -> ValidationResult {
        var servers: [String] = []
        var issues: [String] = []
        var seen: Set<String> = []

        for token in tokens {
            guard isValid(token, family: family) else {
                issues.append("Invalid \(family.label) DNS server: \(token)")
                continue
            }
            guard seen.insert(token).inserted else {
                issues.append("Duplicate \(family.label) DNS server: \(token)")
                continue
            }
            servers.append(token)
        }

        return ValidationResult(servers: servers, issues: issues)
    }

    private static func isValid(_ server: String, family: AddressFamily) -> Bool {
        switch family {
        case .ipv4:
            IPv4Address(server) != nil
        case .ipv6:
            IPv6Address(server) != nil
        }
    }

    private static func makeProfileID(from name: String) -> String {
        let lowercased = name.lowercased()
        var result = ""
        var previousWasDash = false

        for scalar in lowercased.unicodeScalars {
            let isLetter = scalar.value >= 97 && scalar.value <= 122
            let isNumber = scalar.value >= 48 && scalar.value <= 57
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || scalar == "-"
                || scalar == "_"

            if isLetter || isNumber {
                result.unicodeScalars.append(scalar)
                previousWasDash = false
            } else if isSeparator, !previousWasDash, !result.isEmpty {
                result.append("-")
                previousWasDash = true
            }
        }

        while result.last == "-" {
            result.removeLast()
        }
        return result.isEmpty ? "custom-dns" : result
    }
}
