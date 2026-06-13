import Foundation

public struct CustomDomainSuiteFormViewModel: Equatable, Sendable {
    public let name: String
    public let domainsText: String
    public let suiteID: String
    public let domains: [String]
    public let issues: [String]

    public var canSave: Bool {
        issues.isEmpty
    }

    public init(name: String, domainsText: String, suiteID: String? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.domainsText = domainsText
        self.suiteID = suiteID ?? Self.makeSuiteID(from: name)

        let tokens = Self.tokens(from: domainsText)
        let validation = Self.validate(domains: tokens)
        domains = validation.domains

        var nextIssues: [String] = []
        if self.name.isEmpty {
            nextIssues.append("Suite name is required.")
        }
        if tokens.isEmpty {
            nextIssues.append("Add at least one domain.")
        }
        nextIssues += validation.issues
        issues = nextIssues
    }

    public func suiteAddArguments(databaseURL: URL) -> [String] {
        var args = [
            "suite-add",
            "--db", databaseURL.path,
            "--id", suiteID,
            "--name", name,
        ]
        for domain in domains {
            args += ["--domain", domain]
        }
        args += ["--tag", "custom"]
        return args
    }

    private struct ValidationResult {
        let domains: [String]
        let issues: [String]
    }

    private static func tokens(from text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n\r\t "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func validate(domains tokens: [String]) -> ValidationResult {
        var domains: [String] = []
        var issues: [String] = []
        var seen: Set<String> = []

        for token in tokens {
            let normalized = token.lowercased()
            guard isValidDomainName(token) else {
                issues.append("Invalid domain: \(token)")
                continue
            }
            guard seen.insert(normalized).inserted else {
                issues.append("Duplicate domain: \(token)")
                continue
            }
            domains.append(token)
        }

        return ValidationResult(domains: domains, issues: issues)
    }

    private static func isValidDomainName(_ domain: String) -> Bool {
        var trimmed = domain
        while trimmed.hasSuffix(".") {
            trimmed.removeLast()
        }

        guard !trimmed.isEmpty else {
            return false
        }

        return trimmed.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            isValidDomainLabel(label)
        }
    }

    private static func isValidDomainLabel(_ label: Substring) -> Bool {
        guard !label.isEmpty,
              label.utf8.count <= 63,
              label.first != "-",
              label.last != "-"
        else {
            return false
        }

        return label.utf8.allSatisfy { byte in
            (byte >= 48 && byte <= 57)
                || (byte >= 65 && byte <= 90)
                || (byte >= 97 && byte <= 122)
                || byte == 45
        }
    }

    private static func makeSuiteID(from name: String) -> String {
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
        return result.isEmpty ? "custom-suite" : result
    }
}
