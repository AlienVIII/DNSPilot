public struct GamePingPlanViewModel: Equatable, Sendable {
    public let catalog: CatalogSnapshot
    public let selectedPresetID: String?
    public let selectedProfileIDs: [String]
    public let attempts: Int
    public let dnsTimeoutMS: Int
    public let connectTimeoutMS: Int

    public init(
        catalog: CatalogSnapshot,
        selectedPresetID: String? = nil,
        selectedProfileIDs: [String]? = nil,
        attempts: Int = 1,
        dnsTimeoutMS: Int = 800,
        connectTimeoutMS: Int = 1_000
    ) {
        self.catalog = catalog
        self.selectedPresetID = selectedPresetID ?? catalog.testSuites.first { $0.tags.contains("gaming") }?.id
        self.selectedProfileIDs = selectedProfileIDs ?? Self.defaultProfileIDs(from: catalog)
        self.attempts = attempts
        self.dnsTimeoutMS = dnsTimeoutMS
        self.connectTimeoutMS = connectTimeoutMS
    }

    public var presetOptions: [GamePingPresetOption] {
        catalog.testSuites
            .filter { $0.tags.contains("gaming") }
            .map(GamePingPresetOption.init)
    }

    public var selectedPreset: CatalogTestSuite? {
        guard let selectedPresetID else {
            return nil
        }
        return catalog.testSuites.first { $0.id == selectedPresetID && $0.tags.contains("gaming") }
    }

    public var warningText: String {
        "Game Ping estimates DNS and TCP connect latency to game-related domains. It is not ICMP ping and not in-match UDP latency."
    }

    public var issues: [String] {
        var issues: [String] = []
        if selectedPreset == nil {
            issues.append("Select a game preset.")
        }
        if selectedProfileIDs.isEmpty {
            issues.append("Select at least one DNS profile.")
        }
        issues += plan.validation.issues.filter { issue in
            issue != "Select a test suite or add custom domains."
        }
        return Self.uniquePreservingOrder(issues)
    }

    public var canRun: Bool {
        issues.isEmpty
    }

    public var plan: BenchmarkPlanViewModel {
        BenchmarkPlanViewModel(
            catalog: catalog,
            selectedProfileIDs: selectedProfileIDs,
            selectedSuiteID: selectedPreset?.id,
            customDomains: [],
            attempts: attempts,
            dnsTimeoutMS: dnsTimeoutMS,
            connectTimeoutMS: connectTimeoutMS,
            maxConnectTargetsPerDomain: 4,
            recordFamily: .both,
            resolverTransport: .automatic,
            mode: .connectionPathCompare
        )
    }

    public var copyText: String {
        var lines = [
            "DNS Pilot Game Ping",
            warningText,
        ]
        if let selectedPreset {
            lines.append("Preset: \(selectedPreset.name)")
            lines.append("Domains:")
            lines.append(contentsOf: selectedPreset.domains)
        }
        lines.append("DNS profiles:")
        lines.append(contentsOf: selectedProfileIDs)
        lines.append("Attempts: \(attempts)")
        lines.append("DNS timeout: \(dnsTimeoutMS) ms")
        lines.append("TCP timeout: \(connectTimeoutMS) ms")
        return lines.joined(separator: "\n")
    }

    private static func defaultProfileIDs(from catalog: CatalogSnapshot) -> [String] {
        let preferred = [
            "cloudflare",
            "google-public-dns",
            "quad9",
            "fpt-telecom-dns",
            "vnpt-dns",
            "viettel-dns",
        ]
        let available = Set(catalog.profiles.filter { $0.protocol == .plain }.map(\.id))
        return preferred.filter { available.contains($0) }
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

public struct GamePingPresetOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let detail: String

    public init(testSuite: CatalogTestSuite) {
        id = testSuite.id
        name = testSuite.name
        detail = "\(testSuite.domains.count) domains"
    }
}
