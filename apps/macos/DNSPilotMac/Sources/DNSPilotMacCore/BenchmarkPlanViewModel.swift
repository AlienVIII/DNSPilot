public enum BenchmarkPlanMode: Equatable, Hashable, Sendable {
    case dnsOnlyCompare
    case connectionPathCompare
    case systemDNSValidation

    public var displayLabel: String {
        switch self {
        case .dnsOnlyCompare:
            "DNS only"
        case .connectionPathCompare:
            "DNS + TCP"
        case .systemDNSValidation:
            "System DNS"
        }
    }

    public var helpText: String {
        switch self {
        case .dnsOnlyCompare:
            """
            EN: Measures DNS lookup latency and reliability only.
            VI: Chỉ đo tốc độ và độ ổn định khi phân giải DNS; chưa đo kết nối web/app.
            """
        case .connectionPathCompare:
            """
            EN: Measures DNS lookup, then TCP connect to resolved endpoints.
            VI: Đo DNS rồi thử kết nối TCP tới IP trả về; sát trải nghiệm hơn DNS only nhưng chưa đo TLS/HTTP/QUIC.
            """
        case .systemDNSValidation:
            """
            EN: Validates the current macOS system DNS resolver path after a manual DNS change.
            VI: Kiểm tra DNS hệ thống hiện tại của macOS sau khi bạn đổi DNS thủ công; nên flush cache trước khi test.
            """
        }
    }
}

public enum BenchmarkRecordFamily: String, Equatable, Hashable, CaseIterable, Decodable, Sendable {
    case both
    case ipv4Only = "ipv4-only"
    case ipv6Only = "ipv6-only"

    public var cliValue: String {
        rawValue
    }

    public var displayLabel: String {
        switch self {
        case .both:
            "A + AAAA"
        case .ipv4Only:
            "A only"
        case .ipv6Only:
            "AAAA only"
        }
    }

    public var helpText: String {
        switch self {
        case .both:
            """
            EN: Query both A and AAAA records. A returns IPv4 addresses; AAAA returns IPv6 addresses.
            VI: Hỏi cả bản ghi A và AAAA. A là địa chỉ IPv4; AAAA là địa chỉ IPv6.
            """
        case .ipv4Only:
            """
            EN: Query A records only, so the run tests IPv4 answers without IPv6 noise.
            VI: Chỉ hỏi bản ghi A để test IPv4, hữu ích khi mạng IPv6 yếu hoặc bị chặn.
            """
        case .ipv6Only:
            """
            EN: Query AAAA records only, so the run tests IPv6 answers and IPv6 reachability.
            VI: Chỉ hỏi bản ghi AAAA để test IPv6; dùng khi muốn kiểm tra đường IPv6 riêng.
            """
        }
    }

    public var recordTypeCount: Int {
        switch self {
        case .both:
            2
        case .ipv4Only, .ipv6Only:
            1
        }
    }
}

public enum BenchmarkResolverTransport: Equatable, Hashable, CaseIterable, Sendable {
    case automatic
    case ipv4Only
    case ipv6Only

    public var displayLabel: String {
        switch self {
        case .automatic:
            "Auto"
        case .ipv4Only:
            "IPv4"
        case .ipv6Only:
            "IPv6"
        }
    }

    public var helpText: String {
        switch self {
        case .automatic:
            """
            EN: Use each profile's IPv4 DNS server first, then fall back to IPv6 if needed.
            VI: Ưu tiên DNS server IPv4 của từng profile, nếu không có thì dùng IPv6.
            """
        case .ipv4Only:
            """
            EN: Benchmark only IPv4 DNS server addresses, such as 1.1.1.1.
            VI: Chỉ benchmark địa chỉ DNS server IPv4, ví dụ 1.1.1.1.
            """
        case .ipv6Only:
            """
            EN: Benchmark only IPv6 DNS server addresses, such as 2606:4700:4700::1111.
            VI: Chỉ benchmark địa chỉ DNS server IPv6, ví dụ 2606:4700:4700::1111.
            """
        }
    }

    public var summaryLabel: String? {
        switch self {
        case .automatic:
            nil
        case .ipv4Only:
            "IPv4 resolver"
        case .ipv6Only:
            "IPv6 resolver"
        }
    }

    func socketAddress(for profile: CatalogProfile) -> String? {
        switch self {
        case .automatic:
            if let ipv4 = profile.ipv4Servers.first {
                return "\(ipv4):53"
            }
            if let ipv6 = profile.ipv6Servers.first {
                return "[\(ipv6)]:53"
            }
            return nil
        case .ipv4Only:
            guard let ipv4 = profile.ipv4Servers.first else {
                return nil
            }
            return "\(ipv4):53"
        case .ipv6Only:
            guard let ipv6 = profile.ipv6Servers.first else {
                return nil
            }
            return "[\(ipv6)]:53"
        }
    }
}

public struct BenchmarkPlanValidation: Equatable, Sendable {
    public let canRun: Bool
    public let issues: [String]

    public init(issues: [String]) {
        self.issues = issues
        canRun = issues.isEmpty
    }
}

public struct BenchmarkPlanViewModel: Equatable, Sendable {
    public let catalog: CatalogSnapshot
    public let selectedProfileIDs: [String]
    public let selectedSuiteID: String?
    public let customDomains: [String]
    public let attempts: Int
    public let dnsTimeoutMS: Int
    public let connectTimeoutMS: Int
    public let maxConnectTargetsPerDomain: Int
    public let recordFamily: BenchmarkRecordFamily
    public let resolverTransport: BenchmarkResolverTransport
    public let mode: BenchmarkPlanMode

    public var domains: [String] {
        let suiteDomains = selectedSuiteID.flatMap { id in
            catalog.testSuites.first { $0.id == id }?.domains
        } ?? []
        return Self.uniquePreservingOrder(suiteDomains + sanitizedCustomDomains)
    }

    public var resolverCount: Int {
        if mode == .systemDNSValidation {
            return 1
        }
        return plainResolvers.count
    }

    public var resolverTargets: [BenchmarkProgressResolverTarget] {
        if mode == .systemDNSValidation {
            return [
                BenchmarkProgressResolverTarget(
                    id: Self.systemDNSResolverID,
                    name: "System DNS",
                    resolver: Self.systemDNSResolverLabel
                ),
            ]
        }
        return plainResolvers.map { resolver in
            BenchmarkProgressResolverTarget(
                id: resolver.id,
                name: resolver.name,
                resolver: resolver.socketAddress
            )
        }
    }

    public var validation: BenchmarkPlanValidation {
        var issues: [String] = []
        if mode != .systemDNSValidation, plainResolvers.isEmpty {
            if let summaryLabel = resolverTransport.summaryLabel {
                issues.append("Select at least one plain DNS profile with \(summaryLabel).")
            } else {
                issues.append("Select at least one plain DNS profile.")
            }
        }
        if domains.isEmpty {
            issues.append("Select a test suite or add custom domains.")
        }
        if attempts < 1 {
            issues.append("Attempts must be at least 1.")
        }
        if dnsTimeoutMS < 1 {
            issues.append("DNS timeout must be at least 1 ms.")
        }
        if mode == .connectionPathCompare, connectTimeoutMS < 1 {
            issues.append("TCP timeout must be at least 1 ms.")
        }
        if mode == .connectionPathCompare, maxConnectTargetsPerDomain < 1 {
            issues.append("Max TCP targets per domain must be at least 1.")
        }
        for domain in sanitizedCustomDomains where !Self.isValidDomainName(domain) {
            issues.append("Invalid custom domain: \(domain)")
        }
        return BenchmarkPlanValidation(issues: issues)
    }

    public var commandArguments: [String] {
        var args: [String]
        switch mode {
        case .dnsOnlyCompare:
            args = ["compare"]
            for resolver in plainResolvers {
                args.append("--resolver")
                args.append("\(resolver.id)=\(resolver.socketAddress)")
            }
        case .connectionPathCompare:
            args = ["path-compare"]
            for resolver in plainResolvers {
                args.append("--resolver")
                args.append("\(resolver.id)=\(resolver.socketAddress)")
            }
        case .systemDNSValidation:
            args = ["system-benchmark", "--platform", "macos-store"]
        }
        for domain in domains {
            args.append("--domain")
            args.append(domain)
        }
        args.append("--attempts")
        args.append(String(attempts))
        args.append("--ip-family")
        args.append(recordFamily.cliValue)
        switch mode {
        case .connectionPathCompare:
            args.append("--dns-timeout-ms")
            args.append(String(dnsTimeoutMS))
            args.append("--connect-timeout-ms")
            args.append(String(connectTimeoutMS))
            args.append("--max-connect-targets-per-domain")
            args.append(String(maxConnectTargetsPerDomain))
        case .dnsOnlyCompare, .systemDNSValidation:
            args.append("--timeout-ms")
            args.append(String(dnsTimeoutMS))
        }
        return args
    }

    public var supportsProgressEvents: Bool {
        true
    }

    public var supportsHistoryPersistence: Bool {
        true
    }

    private var plainResolvers: [PlainResolver] {
        selectedProfileIDs.compactMap { id in
            guard let profile = catalog.profiles.first(where: { $0.id == id }),
                  profile.protocol == .plain
            else {
                return nil
            }
            if let socketAddress = resolverTransport.socketAddress(for: profile) {
                return PlainResolver(id: profile.id, name: profile.name, socketAddress: socketAddress)
            }
            return nil
        }
    }

    private var sanitizedCustomDomains: [String] {
        customDomains
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public init(
        catalog: CatalogSnapshot,
        selectedProfileIDs: [String],
        selectedSuiteID: String?,
        customDomains: [String],
        attempts: Int,
        dnsTimeoutMS: Int = 800,
        connectTimeoutMS: Int = 1_000,
        maxConnectTargetsPerDomain: Int = 4,
        recordFamily: BenchmarkRecordFamily = .both,
        resolverTransport: BenchmarkResolverTransport = .automatic,
        mode: BenchmarkPlanMode
    ) {
        self.catalog = catalog
        self.selectedProfileIDs = selectedProfileIDs
        self.selectedSuiteID = selectedSuiteID
        self.customDomains = customDomains
        self.attempts = attempts
        self.dnsTimeoutMS = dnsTimeoutMS
        self.connectTimeoutMS = connectTimeoutMS
        self.maxConnectTargetsPerDomain = maxConnectTargetsPerDomain
        self.recordFamily = recordFamily
        self.resolverTransport = resolverTransport
        self.mode = mode
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let normalized = value.lowercased()
            guard seen.insert(normalized).inserted else {
                continue
            }
            result.append(value)
        }
        return result
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

    private static let systemDNSResolverID = "system-dns"
    private static let systemDNSResolverLabel = "macOS system resolver"
}

private struct PlainResolver: Equatable, Sendable {
    let id: String
    let name: String
    let socketAddress: String
}
