public enum ProductGoalReadinessStatus: String, Equatable, Sendable {
    case supported
    case storeSafeGuided
    case estimated

    public var label: String {
        switch self {
        case .supported:
            "Supported"
        case .storeSafeGuided:
            "Store-safe guided"
        case .estimated:
            "Estimate"
        }
    }

    public func localizedLabel(localizer: DNSPilotLocalizer) -> String {
        switch localizer.language {
        case .vietnamese:
            switch self {
            case .supported:
                "Đã hỗ trợ"
            case .storeSafeGuided:
                "Store-safe có hướng dẫn"
            case .estimated:
                "Ước tính"
            }
        case .system, .english:
            label
        }
    }

    public var systemImage: String {
        switch self {
        case .supported:
            "checkmark.circle"
        case .storeSafeGuided:
            "hand.raised"
        case .estimated:
            "gauge.with.dots.needle.bottom.50percent"
        }
    }
}

public struct ProductGoalReadinessRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: ProductGoalReadinessStatus
    public let summary: String
    public let caveat: String
    public let entryPoint: String
    public let validationEvidence: String

    public init(
        id: String,
        title: String,
        status: ProductGoalReadinessStatus,
        summary: String,
        caveat: String,
        entryPoint: String,
        validationEvidence: String
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.summary = summary
        self.caveat = caveat
        self.entryPoint = entryPoint
        self.validationEvidence = validationEvidence
    }

    public var statusLabel: String {
        status.label
    }

    public var systemImage: String {
        status.systemImage
    }
}

public struct ProductGoalReadinessViewModel: Equatable, Sendable {
    public let rows: [ProductGoalReadinessRow]

    public init(rows: [ProductGoalReadinessRow] = Self.defaultRows) {
        self.rows = rows
    }

    public init(localizer: DNSPilotLocalizer) {
        self.rows = Self.rows(language: localizer.language)
    }

    public static var defaultRows: [ProductGoalReadinessRow] {
        rows(language: .english)
    }

    public static func rows(language: DNSPilotLanguage) -> [ProductGoalReadinessRow] {
        switch language {
        case .vietnamese:
            vietnameseRows
        case .system, .english:
            englishRows
        }
    }

    private static let englishRows: [ProductGoalReadinessRow] = [
        ProductGoalReadinessRow(
            id: "fastest-dns",
            title: "Fastest DNS check",
            status: .supported,
            summary: "Benchmark ranks observed DNS latency and reports the fastest observed candidate.",
            caveat: "Fastest DNS is a connection-path estimate, not a full browser or app speed claim.",
            entryPoint: "Benchmark > DNS only or DNS + TCP; Result shows Fastest observed DNS.",
            validationEvidence: "BenchmarkResultViewModelTests cover fastest-vs-balanced labels and degraded trust states."
        ),
        ProductGoalReadinessRow(
            id: "balanced-dns",
            title: "Balanced DNS recommendation",
            status: .supported,
            summary: "Recommendation favors reliability, confidence, and safe keep-current decisions over raw speed.",
            caveat: "VPN, MDM, captive portal, IPv6 reachability, and Secure DNS can reduce confidence.",
            entryPoint: "Benchmark result recommendation and next-step panel.",
            validationEvidence: "Core recommendation safety gates and macOS result trust-state tests."
        ),
        ProductGoalReadinessRow(
            id: "apply-selected-dns",
            title: "Apply selected DNS",
            status: .storeSafeGuided,
            summary: "Selected plain DNS profiles can be copied and opened in macOS Network Settings after confirmation.",
            caveat: "True one-click system mutation is available only in Power edition paths such as DNSPilotPowerActionsEnabled=true, DNSPILOT_ENABLE_POWER_ACTIONS=1, or a future privileged helper.",
            entryPoint: "Catalog > selected plain DNS profile > Apply, or Power Apply when explicitly enabled.",
            validationEvidence: "Guided apply policy tests plus MacOSPowerDNSActionRunnerTests for disabled-by-default admin apply."
        ),
        ProductGoalReadinessRow(
            id: "flush-dns",
            title: "Flush DNS",
            status: .storeSafeGuided,
            summary: "DNS Pilot provides a confirmed, copyable flush checklist for the current macOS build.",
            caveat: "Real cache flush requires admin authorization through DNSPilotPowerActionsEnabled=true, DNSPILOT_ENABLE_POWER_ACTIONS=1, or a trusted helper outside the store-safe app.",
            entryPoint: "Menu Bar > Flush DNS, Benchmark System DNS validation, or Power Flush when explicitly enabled.",
            validationEvidence: "StoreSafeDNSActionViewModel and MacOSPowerDNSActionRunnerTests cover guided and admin paths."
        ),
        ProductGoalReadinessRow(
            id: "saved-domains",
            title: "Saved domain suites",
            status: .supported,
            summary: "Built-in Azure, YouTube, GitHub, ChatGPT, and custom domain suites are available.",
            caveat: "Domains should be edited when a company, game, or SaaS vendor changes hostnames.",
            entryPoint: "Custom DNS > Saved suites, Azure Example, and Benchmark suite picker.",
            validationEvidence: "CustomDomainSuiteSaveRunnerTests and CatalogViewModelTests cover custom and built-in suites."
        ),
        ProductGoalReadinessRow(
            id: "game-server-checks",
            title: "Game server checks",
            status: .estimated,
            summary: "Game Ping covers Dota 2 SEA, CS2, and Riot/League endpoints with DNS + TCP probes.",
            caveat: "This is not ICMP ping or in-match UDP latency; some game traffic uses private routing.",
            entryPoint: "Game Ping > choose Dota 2 SEA, CS2, Riot, or League preset > Run.",
            validationEvidence: "GamePingPlanViewModelTests cover preset availability and DNS + TCP plan construction."
        ),
    ]

    private static let vietnameseRows: [ProductGoalReadinessRow] = [
        ProductGoalReadinessRow(
            id: "fastest-dns",
            title: "Kiểm tra DNS nhanh nhất",
            status: .supported,
            summary: "Benchmark xếp hạng độ trễ DNS quan sát được và báo ứng viên nhanh nhất.",
            caveat: "DNS nhanh nhất chỉ là ước tính connection-path, không phải cam kết tốc độ browser/app.",
            entryPoint: "Benchmark > DNS only hoặc DNS + TCP; Kết quả hiển thị Fastest observed DNS.",
            validationEvidence: "BenchmarkResultViewModelTests kiểm tra nhãn fastest-vs-balanced và degraded trust states."
        ),
        ProductGoalReadinessRow(
            id: "balanced-dns",
            title: "Gợi ý DNS cân bằng",
            status: .supported,
            summary: "Gợi ý ưu tiên độ tin cậy, confidence, và giữ DNS hiện tại khi rủi ro cao hơn tốc độ thô.",
            caveat: "VPN, MDM, captive portal, IPv6 reachability, và Secure DNS có thể làm giảm confidence.",
            entryPoint: "Kết quả Benchmark và panel bước tiếp theo.",
            validationEvidence: "Core recommendation safety gates và macOS result trust-state tests."
        ),
        ProductGoalReadinessRow(
            id: "apply-selected-dns",
            title: "Áp dụng DNS đã chọn",
            status: .storeSafeGuided,
            summary: "Profile DNS thường có thể copy và mở macOS Network Settings sau xác nhận.",
            caveat: "Đổi DNS hệ thống một-click thật chỉ có trong Power edition qua DNSPilotPowerActionsEnabled=true, DNSPILOT_ENABLE_POWER_ACTIONS=1, hoặc helper đáng tin cậy ngoài Store build.",
            entryPoint: "Catalog > chọn plain DNS profile > Apply, hoặc Power Apply khi đã bật rõ ràng.",
            validationEvidence: "Guided apply policy tests và MacOSPowerDNSActionRunnerTests kiểm tra admin apply mặc định tắt."
        ),
        ProductGoalReadinessRow(
            id: "flush-dns",
            title: "Flush DNS",
            status: .storeSafeGuided,
            summary: "DNS Pilot cung cấp checklist flush có xác nhận và copy được cho macOS hiện tại.",
            caveat: "Flush cache thật cần admin authorization qua DNSPilotPowerActionsEnabled=true, DNSPILOT_ENABLE_POWER_ACTIONS=1, hoặc trusted helper ngoài Store build.",
            entryPoint: "Menu Bar > Flush DNS, Benchmark System DNS validation, hoặc Power Flush khi đã bật rõ ràng.",
            validationEvidence: "StoreSafeDNSActionViewModel và MacOSPowerDNSActionRunnerTests kiểm tra guided/admin paths."
        ),
        ProductGoalReadinessRow(
            id: "saved-domains",
            title: "Bộ domain đã lưu",
            status: .supported,
            summary: "Có sẵn Azure, YouTube, GitHub, ChatGPT, và bộ domain tùy chỉnh.",
            caveat: "Domain nên được cập nhật khi công ty, game, hoặc SaaS vendor đổi hostname.",
            entryPoint: "Custom DNS > Saved suites, Azure Example, và Benchmark suite picker.",
            validationEvidence: "CustomDomainSuiteSaveRunnerTests và CatalogViewModelTests kiểm tra custom/built-in suites."
        ),
        ProductGoalReadinessRow(
            id: "game-server-checks",
            title: "Kiểm tra server game",
            status: .estimated,
            summary: "Game Ping hỗ trợ Dota 2 SEA, CS2, và Riot/League endpoints bằng DNS + TCP probes.",
            caveat: "Đây không phải ICMP ping hoặc độ trễ UDP trong trận; một số game dùng private routing.",
            entryPoint: "Game Ping > chọn Dota 2 SEA, CS2, Riot, hoặc League preset > Run.",
            validationEvidence: "GamePingPlanViewModelTests kiểm tra preset và DNS + TCP plan construction."
        ),
    ]
}
