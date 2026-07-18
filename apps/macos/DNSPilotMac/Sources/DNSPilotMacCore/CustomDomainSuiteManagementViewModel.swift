public struct CustomDomainSuiteManagementViewModel: Equatable, Sendable {
    public let rows: [CustomDomainSuiteManagementRow]

    public init(testSuites: [CatalogTestSuite], reservedSuiteIDs: Set<String>? = nil) {
        var seenIDs = Set<String>()
        let reservedIDs = reservedSuiteIDs ?? Set(
            testSuites
                .filter { !Self.isEditableCustomSuite($0) }
                .map(\.id)
        )
        rows = testSuites
            .filter(Self.isEditableCustomSuite)
            .filter { suite in
                seenIDs.insert(suite.id).inserted
            }
            .map { suite in
                CustomDomainSuiteManagementRow(
                    testSuite: suite,
                    hasReservedIDCollision: reservedIDs.contains(suite.id)
                )
            }
    }

    private static func isEditableCustomSuite(_ suite: CatalogTestSuite) -> Bool {
        suite.description == "Custom domain test suite." || suite.tags.contains("custom")
    }
}

public struct CustomDomainSuiteManagementRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let domainCountLabel: String
    public let domainCount: Int
    public let domainsText: String
    public let opensAsNewSuite: Bool
    public let editHelpLabel: String
    public let warningLabel: String?
    public let hasReservedIDCollision: Bool

    public init(testSuite: CatalogTestSuite, hasReservedIDCollision: Bool = false) {
        id = testSuite.id
        name = testSuite.name
        domainCount = testSuite.domains.count
        domainCountLabel = testSuite.domains.count == 1
            ? "1 domain"
            : "\(testSuite.domains.count) domains"
        domainsText = testSuite.domains.joined(separator: "\n")
        opensAsNewSuite = hasReservedIDCollision
        self.hasReservedIDCollision = hasReservedIDCollision
        editHelpLabel = hasReservedIDCollision ? "Copy to new suite" : "Edit suite"
        warningLabel = hasReservedIDCollision
            ? "Built-in ID conflict. Edit creates a new custom-* copy; delete this legacy row after saving."
            : nil
    }
}
