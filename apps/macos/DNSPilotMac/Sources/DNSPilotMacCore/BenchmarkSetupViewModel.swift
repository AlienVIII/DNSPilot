import Foundation

public enum BenchmarkProfileSelectionState: Equatable, Sendable {
    case systemDNS
    case noRunnableProfiles
    case selectedRunnableProfiles(selected: Int, runnable: Int)
}

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
        switch profileSelectionState {
        case .systemDNS:
            return "System DNS uses the current macOS resolver; profile selection is ignored."
        case .noRunnableProfiles:
            return "No runnable profiles available"
        case .selectedRunnableProfiles(let selected, let runnable):
            return "\(selected) of \(runnable) runnable selected"
        }
    }

    public var profileSelectionState: BenchmarkProfileSelectionState {
        if mode == .systemDNSValidation {
            return .systemDNS
        }
        let runnableIDs = runnableProfileIDs
        guard !runnableIDs.isEmpty else {
            return .noRunnableProfiles
        }

        let selectedRunnableCount = runnableIDs.filter { selectedProfileIDs.contains($0) }.count
        return .selectedRunnableProfiles(
            selected: selectedRunnableCount,
            runnable: runnableIDs.count
        )
    }

    public var profileSelectionCaveat: String? {
        guard mode != .systemDNSValidation else {
            return nil
        }
        let selectedProfiles = catalog.profiles.filter { profile in
            selectedProfileIDs.contains(profile.id)
                && BenchmarkProfileOption(profile: profile, resolverTransport: resolverTransport).isRunnable
        }
        let includesUnfiltered = selectedProfiles.contains { $0.filteringType == .none }
        let includesFiltered = selectedProfiles.contains { $0.filteringType != .none }
        guard includesUnfiltered && includesFiltered else {
            return nil
        }
        return "Filtered DNS is selected with unfiltered resolvers; compare filtering goals separately."
    }

    public var runPlanSummary: String {
        let plan = plan
        var parts = [modeLabel]
        if mode != .systemDNSValidation, let resolverTransportLabel = resolverTransport.summaryLabel {
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
        if mode == .systemDNSValidation {
            return "System DNS validation should flush macOS DNS cache before testing."
        }
        return "Direct resolver test; system DNS flush is not required."
    }

    public var systemDNSFlushChecklistText: String? {
        guard mode == .systemDNSValidation else {
            return nil
        }
        return StoreSafeDNSFlushGuidanceViewModel().checklistText
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

    public var selectedSuiteIsGaming: Bool {
        guard let selectedSuiteID else {
            return false
        }
        return catalog.testSuites.contains { suite in
            suite.id == selectedSuiteID && suite.tags.contains("gaming")
        }
    }

    public var isGamingSuiteSelected: Bool {
        selectedSuiteIsGaming
    }

    public var gameCheckDisclaimer: String? {
        guard selectedSuiteIsGaming else {
            return nil
        }
        return "Game check estimates DNS and TCP connection timing. It is not ICMP ping or in-match UDP latency."
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

    public static func quickRunPreset(
        catalog: CatalogSnapshot,
        executableAvailability: BenchmarkExecutableAvailability
    ) -> BenchmarkSetupViewModel {
        let defaults = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: executableAvailability
        )
        return BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: executableAvailability,
            selectedProfileIDs: defaults.selectedProfileIDs,
            selectedSuiteID: nil,
            customDomainsText: [
                "github.com",
                "login.microsoftonline.com",
                "vnexpress.net",
            ].joined(separator: "\n"),
            attempts: 1,
            dnsTimeoutMS: 800,
            connectTimeoutMS: 800,
            maxConnectTargetsPerDomain: 2,
            recordFamily: defaults.recordFamily,
            resolverTransport: defaults.resolverTransport,
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
        let runnableProfiles = catalog.profiles
            .filter { BenchmarkProfileOption(profile: $0, resolverTransport: .automatic).isRunnable }

        let unfilteredProfiles = runnableProfiles
            .filter { $0.filteringType == .none }
        let filteredProfiles = runnableProfiles
            .filter { $0.filteringType != .none }
        return Array((unfilteredProfiles + filteredProfiles)
            .prefix(2)
            .map(\.id))
    }

    private static func parseCustomDomains(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n\r\t "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var modeLabel: String {
        mode.displayLabel
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
    private enum Availability: Equatable {
        case runnable
        case missingResolver(BenchmarkResolverTransport)
        case missingServer
        case requiresOSDNSProfile
    }

    public let id: String
    public let name: String
    public let isRunnable: Bool
    private let ipv4ServerCount: Int
    private let ipv6ServerCount: Int
    private let availability: Availability

    public init(profile: CatalogProfile, resolverTransport: BenchmarkResolverTransport = .automatic) {
        id = profile.id
        name = profile.name
        ipv4ServerCount = profile.ipv4Servers.count
        ipv6ServerCount = profile.ipv6Servers.count
        let socketAddress = resolverTransport.socketAddress(for: profile)
        isRunnable = profile.protocol == .plain
            && socketAddress != nil
        if isRunnable {
            availability = .runnable
        } else if profile.protocol == .plain {
            if resolverTransport.summaryLabel == nil {
                availability = .missingServer
            } else {
                availability = .missingResolver(resolverTransport)
            }
        } else {
            availability = .requiresOSDNSProfile
        }
    }

    public func detailLabel(localizer: DNSPilotLocalizer) -> String {
        switch availability {
        case .runnable:
            "\(ipv4ServerCount) IPv4 / \(ipv6ServerCount) IPv6"
        case .missingResolver(let transport):
            localizer.formatted(.missingDNSResolver, resolverLabel(transport, localizer: localizer))
        case .missingServer:
            localizer.text(.missingDNSServer)
        case .requiresOSDNSProfile:
            localizer.text(.requiresDNSProfileFlow)
        }
    }

    public func helpText(localizer: DNSPilotLocalizer) -> String {
        switch availability {
        case .runnable:
            localizer.text(.plainDNSProfileHelp)
        case .missingResolver(let transport):
            localizer.formatted(.missingDNSResolverHelp, resolverLabel(transport, localizer: localizer))
        case .missingServer:
            localizer.text(.missingDNSServerHelp)
        case .requiresOSDNSProfile:
            localizer.text(.requiresDNSProfileFlowHelp)
        }
    }

    private func resolverLabel(
        _ transport: BenchmarkResolverTransport,
        localizer: DNSPilotLocalizer
    ) -> String {
        switch transport {
        case .automatic:
            localizer.text(.recordAuto)
        case .ipv4Only:
            localizer.text(.recordIPv4)
        case .ipv6Only:
            localizer.text(.recordIPv6)
        }
    }
}

public struct BenchmarkSuiteOption: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let domainCount: Int

    public init(testSuite: CatalogTestSuite) {
        id = testSuite.id
        name = testSuite.name
        domainCount = testSuite.domains.count
    }

    public func domainCountLabel(localizer: DNSPilotLocalizer) -> String {
        localizer.formatted(.suiteDomainCount, domainCount)
    }

    public func helpText(localizer: DNSPilotLocalizer) -> String {
        localizer.text(.suiteDomainsHelp)
    }
}
