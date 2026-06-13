public struct CustomDomainSuiteManagementViewModel: Equatable, Sendable {
    public let rows: [CustomDomainSuiteManagementRow]

    public init(testSuites: [CatalogTestSuite]) {
        var seenIDs = Set<String>()
        rows = testSuites
            .filter(Self.isEditableCustomSuite)
            .filter { suite in
                seenIDs.insert(suite.id).inserted
            }
            .map(CustomDomainSuiteManagementRow.init(testSuite:))
    }

    private static func isEditableCustomSuite(_ suite: CatalogTestSuite) -> Bool {
        suite.description == "Custom domain test suite." || suite.tags.contains("custom")
    }
}

public struct CustomDomainSuiteManagementRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let domainCountLabel: String
    public let domainsText: String

    public init(testSuite: CatalogTestSuite) {
        id = testSuite.id
        name = testSuite.name
        domainCountLabel = testSuite.domains.count == 1
            ? "1 domain"
            : "\(testSuite.domains.count) domains"
        domainsText = testSuite.domains.joined(separator: "\n")
    }
}
