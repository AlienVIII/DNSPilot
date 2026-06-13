import Foundation

public struct BenchmarkSetupViewModel: Equatable {
    public let catalog: CatalogSnapshot
    public let executableAvailability: BenchmarkExecutableAvailability
    public let selectedProfileIDs: [String]
    public let selectedSuiteID: String?
    public let customDomainsText: String
    public let attempts: Int
    public let dnsTimeoutMS: Int
    public let connectTimeoutMS: Int
    public let maxConnectTargetsPerDomain: Int
    public let recordFamily: BenchmarkRecordFamily
    public let resolverTransport: BenchmarkResolverTransport
    public let mode: BenchmarkPlanMode

    public var profileOptions: [BenchmarkProfileOption] {
        catalog.profiles.map { profile in
            BenchmarkProfileOption(profile: profile, resolverTransport: resolverTransport)
        }
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

    public var runPlanSummary: String {
        let plan = plan
        var parts = [modeLabel]
        if let resolverTransportLabel = resolverTransport.summaryLabel {
            parts.append(resolverTransportLabel)
        }
        parts += [
            recordFamily.displayLabel,
            Self.countLabel(plan.resolverCount, singular: "resolver", plural: "resolvers"),
            Self.countLabel(plan.domains.count, singular: "domain", plural: "domains"),
            Self.countLabel(attempts, singular: "attempt", plural: "attempts"),
        ]
        if mode == .connectionPathCompare {
            parts.append("\(maxConnectTargetsPerDomain) TCP targets/domain")
        }
        return parts.joined(separator: ", ")
    }

    public var flushPolicySummary: String {
        "Direct resolver test; system DNS flush is not required."
    }

    public var estimatedDurationWarning: String? {
        let plan = plan
        guard plan.validation.canRun else {
            return nil
        }
        let worstCaseMilliseconds = Self.worstCaseMilliseconds(
            resolverCount: plan.resolverCount,
            domainCount: plan.domains.count,
            attempts: attempts,
            dnsTimeoutMS: dnsTimeoutMS,
            connectTimeoutMS: connectTimeoutMS,
            maxConnectTargetsPerDomain: maxConnectTargetsPerDomain,
            recordFamilyCount: recordFamily.recordTypeCount,
            mode: mode
        )
        guard worstCaseMilliseconds >= Self.longBenchmarkWarningThresholdMS else {
            return nil
        }
        return "Estimated worst-case wait: about \(BenchmarkElapsedTimeFormatter.label(milliseconds: worstCaseMilliseconds)). Reduce profiles, domains, or attempts if this looks too long."
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
            dnsTimeoutMS: dnsTimeoutMS,
            connectTimeoutMS: connectTimeoutMS,
            maxConnectTargetsPerDomain: maxConnectTargetsPerDomain,
            recordFamily: recordFamily,
            resolverTransport: resolverTransport,
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
            dnsTimeoutMS: 800,
            connectTimeoutMS: 1_000,
            maxConnectTargetsPerDomain: 4,
            recordFamily: .both,
            resolverTransport: .automatic,
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
        dnsTimeoutMS: Int = 800,
        connectTimeoutMS: Int = 1_000,
        maxConnectTargetsPerDomain: Int = 4,
        recordFamily: BenchmarkRecordFamily = .both,
        resolverTransport: BenchmarkResolverTransport = .automatic,
        mode: BenchmarkPlanMode
    ) {
        self.catalog = catalog
        self.executableAvailability = executableAvailability
        self.selectedProfileIDs = selectedProfileIDs
        self.selectedSuiteID = selectedSuiteID
        self.customDomainsText = customDomainsText
        self.attempts = attempts
        self.dnsTimeoutMS = dnsTimeoutMS
        self.connectTimeoutMS = connectTimeoutMS
        self.maxConnectTargetsPerDomain = maxConnectTargetsPerDomain
        self.recordFamily = recordFamily
        self.resolverTransport = resolverTransport
        self.mode = mode
    }

    private static func defaultProfileIDs(from catalog: CatalogSnapshot) -> [String] {
        catalog.profiles
            .filter { BenchmarkProfileOption(profile: $0, resolverTransport: .automatic).isRunnable }
            .prefix(2)
            .map(\.id)
    }

    private static func parseCustomDomains(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n\r\t "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var modeLabel: String {
        switch mode {
        case .dnsOnlyCompare:
            "DNS only"
        case .connectionPathCompare:
            "DNS + TCP"
        }
    }

    private static func countLabel(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    private static let longBenchmarkWarningThresholdMS = 30_000

    private static func worstCaseMilliseconds(
        resolverCount: Int,
        domainCount: Int,
        attempts: Int,
        dnsTimeoutMS: Int,
        connectTimeoutMS: Int,
        maxConnectTargetsPerDomain: Int,
        recordFamilyCount: Int,
        mode: BenchmarkPlanMode
    ) -> Int {
        let dnsMilliseconds = resolverCount
            * domainCount
            * recordFamilyCount
            * attempts
            * dnsTimeoutMS
        guard mode == .connectionPathCompare else {
            return dnsMilliseconds
        }
        let tcpMilliseconds = resolverCount
            * domainCount
            * maxConnectTargetsPerDomain
            * attempts
            * connectTimeoutMS
        return dnsMilliseconds + tcpMilliseconds
    }
}

public struct BenchmarkProfileOption: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let detailLabel: String
    public let isRunnable: Bool

    public init(profile: CatalogProfile, resolverTransport: BenchmarkResolverTransport = .automatic) {
        id = profile.id
        name = profile.name
        isRunnable = profile.protocol == .plain
            && resolverTransport.socketAddress(for: profile) != nil
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
