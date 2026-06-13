import Foundation

public struct BenchmarkSetupViewModel: Equatable {
    public let catalog: CatalogSnapshot
    public let executableAvailability: BenchmarkExecutableAvailability
    public let selectedProfileIDs: [String]
    public let selectedSuiteID: String?
    public let customDomainsText: String
    public let attempts: Int
    public let mode: BenchmarkPlanMode

    public var profileOptions: [BenchmarkProfileOption] {
        catalog.profiles.map(BenchmarkProfileOption.init(profile:))
    }

    public var runnableProfileIDs: [String] {
        profileOptions
            .filter(\.isRunnable)
            .map(\.id)
    }

    public var profileSelectionSummary: String {
        let runnableIDs = runnableProfileIDs
        guard !runnableIDs.isEmpty else {
            return "No runnable profiles available"
        }

        let selectedRunnableCount = runnableIDs.filter { selectedProfileIDs.contains($0) }.count
        return "\(selectedRunnableCount) of \(runnableIDs.count) runnable selected"
    }

    public var suiteOptions: [BenchmarkSuiteOption] {
        catalog.testSuites.map(BenchmarkSuiteOption.init(testSuite:))
    }

    public var plan: BenchmarkPlanViewModel {
        BenchmarkPlanViewModel(
            catalog: catalog,
            selectedProfileIDs: selectedProfileIDs,
            selectedSuiteID: selectedSuiteID,
            customDomains: Self.parseCustomDomains(customDomainsText),
            attempts: attempts,
            mode: mode
        )
    }

    public var readinessIssues: [String] {
        var issues: [String] = []
        if case .unavailable(let message) = executableAvailability {
            issues.append(message)
        }
        issues.append(contentsOf: plan.validation.issues)
        return issues
    }

    public var canRun: Bool {
        readinessIssues.isEmpty
    }

    public init(catalog: CatalogSnapshot, executableAvailability: BenchmarkExecutableAvailability) {
        self.init(
            catalog: catalog,
            executableAvailability: executableAvailability,
            selectedProfileIDs: Self.defaultProfileIDs(from: catalog),
            selectedSuiteID: catalog.testSuites.first?.id,
            customDomainsText: "",
            attempts: 1,
            mode: .dnsOnlyCompare
        )
    }

    public init(
        catalog: CatalogSnapshot,
        executableAvailability: BenchmarkExecutableAvailability,
        selectedProfileIDs: [String],
        selectedSuiteID: String?,
        customDomainsText: String,
        attempts: Int,
        mode: BenchmarkPlanMode
    ) {
        self.catalog = catalog
        self.executableAvailability = executableAvailability
        self.selectedProfileIDs = selectedProfileIDs
        self.selectedSuiteID = selectedSuiteID
        self.customDomainsText = customDomainsText
        self.attempts = attempts
        self.mode = mode
    }

    private static func defaultProfileIDs(from catalog: CatalogSnapshot) -> [String] {
        catalog.profiles
            .filter { BenchmarkProfileOption(profile: $0).isRunnable }
            .prefix(2)
            .map(\.id)
    }

    private static func parseCustomDomains(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n\r\t "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public struct BenchmarkProfileOption: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let detailLabel: String
    public let isRunnable: Bool

    public init(profile: CatalogProfile) {
        id = profile.id
        name = profile.name
        isRunnable = profile.protocol == .plain
            && (!profile.ipv4Servers.isEmpty || !profile.ipv6Servers.isEmpty)
        if isRunnable {
            detailLabel = "\(profile.ipv4Servers.count) IPv4 / \(profile.ipv6Servers.count) IPv6"
        } else {
            detailLabel = "Requires OS DNS profile flow"
        }
    }
}

public struct BenchmarkSuiteOption: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let domainCountLabel: String

    public init(testSuite: CatalogTestSuite) {
        id = testSuite.id
        name = testSuite.name
        domainCountLabel = testSuite.domains.count == 1
            ? "1 domain"
            : "\(testSuite.domains.count) domains"
    }
}
